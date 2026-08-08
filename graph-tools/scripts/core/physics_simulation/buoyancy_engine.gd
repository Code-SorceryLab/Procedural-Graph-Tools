class_name BuoyancyEngine
extends RefCounted

# --- Physics Settings ---
var damping: float = 0.85       # Friction (1.0 = ice, 0.0 = glue)
var max_velocity: float = 20.0  # Speed limit per frame to prevent explosions
var repulsion_multiplier: float = 1500.0 # Global scale for the repulsion math

# --- Crystallization Settings ---
var auto_crystallize: bool = false
var settle_threshold: float = 1.0  # Velocity below this triggers the freeze

# --- Destructive Physics Settings ---
var global_edge_snapping: bool = false
var global_node_fusing: bool = false

# Internal State
var _velocities: Dictionary = {}
var _crystallized_nodes: Array[String] = [] 

# --- THREADING BUFFERS ---
# We use PackedArrays for CPU Cache-Locality and Mutex-free writing!
var _thread_forces: PackedVector2Array
var _thread_positions: PackedVector2Array
var _thread_repulsions: PackedFloat32Array
var _thread_modes: PackedInt32Array
var _thread_fusable: PackedInt32Array

var _thread_fuse_reports: Array = []
var _fuse_mutex: Mutex = Mutex.new()

func clear_velocities() -> void:
	_velocities.clear()

func set_auto_crystallize(active: bool, graph: Graph) -> void:
	auto_crystallize = active
	
	if not active and graph:
		for id in _crystallized_nodes:
			if graph.nodes.has(id):
				var node = graph.nodes[id]
				if "custom_data" in node and node.custom_data.get("physics_mode", 0) == 1:
					node.custom_data["physics_mode"] = 0
		_crystallized_nodes.clear()

# ==============================================================================
# 1. MAIN PIPELINE
# ==============================================================================

func step(graph: Graph, delta: float) -> Dictionary:
	var destruction_report = { "snapped_edges": [], "fused_nodes": [] }
	
	if not graph or graph.nodes.is_empty(): 
		return destruction_report
		
	var node_ids = graph.nodes.keys()
	var n = node_ids.size()
	
	# --- STEP A: FLATTEN DATA ---
	# Move Godot Dictionaries into linear, C-style arrays for the threads
	_thread_positions.resize(n)
	_thread_forces.resize(n)
	_thread_repulsions.resize(n)
	_thread_modes.resize(n)
	_thread_fusable.resize(n)
	_thread_fuse_reports.clear()

	var id_to_idx = {}
	for i in range(n):
		var id = node_ids[i]
		id_to_idx[id] = i
		
		var node = graph.nodes[id]
		_thread_positions[i] = node.position
		_thread_forces[i] = Vector2.ZERO
		
		if "custom_data" in node:
			_thread_modes[i] = node.custom_data.get("physics_mode", 0)
			_thread_repulsions[i] = node.custom_data.get("physics_repulsion", 100.0)
			_thread_fusable[i] = 1 if node.custom_data.get("physics_fusable", false) else 0
		else:
			_thread_modes[i] = 0
			_thread_repulsions[i] = 100.0
			_thread_fusable[i] = 0
			
		if not _velocities.has(id):
			_velocities[id] = Vector2.ZERO

	# --- STEP B: DISPATCH REPULSION THREADS ---
	var task_id = WorkerThreadPool.add_group_task(
		_calculate_repulsion_task.bind(n),
		n, -1, true, "Physics Repulsion"
	)
	
	# --- STEP C: MAIN-THREAD OVERLAP (Springs) ---
	# While the background threads calculate Repulsion, we calculate Edge Tension!
	var main_thread_forces = []
	main_thread_forces.resize(n)
	for i in range(n): main_thread_forces[i] = Vector2.ZERO

	var processed_edges = {}
	for key in graph.edge_store:
		var e = graph.edge_store[key]
		var pair = [e.u, e.v]
		pair.sort()
		if processed_edges.has(pair): continue
		processed_edges[pair] = true
		
		if not id_to_idx.has(e.u) or not id_to_idx.has(e.v): continue
		var idx_u = id_to_idx[e.u]
		var idx_v = id_to_idx[e.v]
		var edge_custom = e.custom
		
		if edge_custom.get("physics_mode", 0) == 1: continue
		
		var ideal_len = float(edge_custom.get("physics_spring_length", 150.0))
		var stiffness = float(edge_custom.get("physics_stiffness", 0.5))
		
		var diff = _thread_positions[idx_v] - _thread_positions[idx_u]
		var dist = diff.length()
		
		var local_snap = edge_custom.get("physics_snappable", false)
		if global_edge_snapping or local_snap:
			var threshold = float(edge_custom.get("physics_snap_threshold", 400.0))
			if dist > threshold:
				destruction_report["snapped_edges"].append([e.u, e.v])
				continue 
		
		if dist > 0.1:
			var displacement = dist - ideal_len
			var force_mag = displacement * stiffness
			var force_vec = (diff / dist) * force_mag
			
			main_thread_forces[idx_u] += force_vec
			main_thread_forces[idx_v] -= force_vec

	# --- STEP D: SYNC AND INTEGRATE ---
	# Wait for the threads to finish repulsion, then merge the math
	WorkerThreadPool.wait_for_group_task_completion(task_id)

	var fused_tracker = {}
	for pair in _thread_fuse_reports:
		var u = node_ids[pair[0]]
		var v = node_ids[pair[1]]
		if not fused_tracker.has(u) and not fused_tracker.has(v):
			destruction_report["fused_nodes"].append([u, v])
			fused_tracker[u] = true
			fused_tracker[v] = true

	for i in range(n):
		var id = node_ids[i]
		if fused_tracker.has(id): continue
		
		var mode = _thread_modes[i]
		if mode != 0:
			_velocities[id] = Vector2.ZERO
			continue
		
		var current_vel = _velocities[id]
		
		# Combine Background Forces (Repulsion) + Main Forces (Springs)
		var total_force = _thread_forces[i] + main_thread_forces[i]
		
		current_vel += total_force * delta
		current_vel *= damping
		
		if current_vel.length() > max_velocity:
			current_vel = current_vel.normalized() * max_velocity
			
		_velocities[id] = current_vel
		
		if current_vel.length_squared() > 0.01:
			var node = graph.nodes[id]
			var new_pos = node.position + current_vel
			
			if auto_crystallize and current_vel.length() < settle_threshold:
				var grid_step = GraphSettings.GRID_SPACING
				if grid_step.x <= 0.01: grid_step.x = 64.0
				if grid_step.y <= 0.01: grid_step.y = 64.0
				
				new_pos.x = round(new_pos.x / grid_step.x) * grid_step.x
				new_pos.y = round(new_pos.y / grid_step.y) * grid_step.y
				
				if not node.get("custom_data"): node.custom_data = {}
				node.custom_data["physics_mode"] = 1
				_velocities[id] = Vector2.ZERO
				
				if not _crystallized_nodes.has(id):
					_crystallized_nodes.append(id)
					
			graph.set_node_position(id, new_pos)
			
	return destruction_report

# ==============================================================================
# 2. THE BACKGROUND THREAD WORKER
# ==============================================================================

func _calculate_repulsion_task(i: int, total_nodes: int) -> void:
	var pos_i = _thread_positions[i]
	var mode_i = _thread_modes[i]
	var rep_i = _thread_repulsions[i]
	var fuse_i = _thread_fusable[i]
	
	var force = Vector2.ZERO
	
	for j in range(total_nodes):
		if i == j: continue
		
		var mode_j = _thread_modes[j]
		if mode_i == 2 or mode_j == 2: continue
		
		var pos_j = _thread_positions[j]
		var diff = pos_i - pos_j
		var dist_sq = diff.length_squared()
		
		# --- [NEW] FAST SPATIAL CULLING ---
		# Beyond ~500 pixels (250,000 dist_sq), the repulsion force is 0.0.
		# By skipping the expensive sqrt() and division, we save millions of operations!
		if dist_sq > 250000.0: continue
		
		# --- Fusing Check ---
		if j > i:
			var fuse_j = _thread_fusable[j]
			var can_fuse_i = global_node_fusing or (fuse_i == 1)
			var can_fuse_j = global_node_fusing or (fuse_j == 1)
			
			if can_fuse_i and can_fuse_j and dist_sq < 400.0:
				_fuse_mutex.lock()
				_thread_fuse_reports.append([i, j])
				_fuse_mutex.unlock()
				continue
				
		if dist_sq < 1.0:
			diff = Vector2(1.0, 0.0).rotated(float(i + j))
			dist_sq = 1.0
			
		var dist = sqrt(dist_sq)
		var rep_j = _thread_repulsions[j]
		var force_mag = ((rep_i + rep_j) * repulsion_multiplier) / dist_sq
		
		force += (diff / dist) * force_mag
		
	# Write-One! No Mutex needed!
	_thread_forces[i] = force
