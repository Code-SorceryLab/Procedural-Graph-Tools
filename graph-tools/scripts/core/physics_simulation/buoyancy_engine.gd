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

# Internal State: Tracks velocity vectors for each node between frames
var _velocities: Dictionary = {}
var _crystallized_nodes: Array[String] = [] # Tracks what we froze

func clear_velocities() -> void:
	_velocities.clear()

# Safely toggles crystallization and thaws nodes when turned off
func set_auto_crystallize(active: bool, graph: Graph) -> void:
	auto_crystallize = active
	
	if not active and graph:
		# Thaw only the nodes that THIS engine froze
		for id in _crystallized_nodes:
			if graph.nodes.has(id):
				var node = graph.nodes[id]
				# Only unfreeze if it is still anchored (in case the user manually painted it in the meantime!)
				if "custom_data" in node and node.custom_data.get("physics_mode", 0) == 1:
					node.custom_data["physics_mode"] = 0
					
		_crystallized_nodes.clear()

# Steps the physics simulation forward by one frame.
# Now returns a Dictionary of destructive events to be handled safely by the Editor!
func step(graph: Graph, delta: float) -> Dictionary:
	var destruction_report = {
		"snapped_edges": [],
		"fused_nodes": []
	}
	
	if not graph or graph.nodes.is_empty(): 
		return destruction_report
		
	var forces: Dictionary = {}
	var node_ids = graph.nodes.keys()
	
	for id in node_ids:
		forces[id] = Vector2.ZERO
		if not _velocities.has(id):
			_velocities[id] = Vector2.ZERO

	# --- 1. REPULSION & COLLISION (Fusing) ---
	var fused_tracker = {} # Prevent chain-reaction fusing in a single frame
	
	for i in range(node_ids.size()):
		var id_u = node_ids[i]
		if fused_tracker.has(id_u): continue
		
		var node_u = graph.nodes[id_u]
		var mode_u = node_u.custom_data.get("physics_mode", 0) if "custom_data" in node_u else 0
		var rep_u = node_u.custom_data.get("physics_repulsion", 100.0) if "custom_data" in node_u else 100.0
		
		for j in range(i + 1, node_ids.size()):
			var id_v = node_ids[j]
			if fused_tracker.has(id_v): continue
			
			var node_v = graph.nodes[id_v]
			var mode_v = node_v.custom_data.get("physics_mode", 0) if "custom_data" in node_v else 0
			if mode_u == 2 or mode_v == 2: continue
			
			var diff = node_u.position - node_v.position
			var dist_sq = diff.length_squared()
			
			# --- NODE FUSING LOGIC ---
			var local_fuse_u = node_u.custom_data.get("physics_fusable", false) if "custom_data" in node_u else false
			var local_fuse_v = node_v.custom_data.get("physics_fusable", false) if "custom_data" in node_v else false
			
			# Fuse if BOTH nodes have the local property, OR if the Global Override is active
			var can_fuse_u = global_node_fusing or local_fuse_u
			var can_fuse_v = global_node_fusing or local_fuse_v
			
			if (can_fuse_u and can_fuse_v) and dist_sq < 400.0: # ~20 pixels overlap
				destruction_report["fused_nodes"].append([id_u, id_v])
				fused_tracker[id_u] = true
				fused_tracker[id_v] = true
				continue # Skip repulsion, they are melting!
			
			if dist_sq < 1.0:
				diff = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
				dist_sq = 1.0
				
			var dist = sqrt(dist_sq)
			var rep_v = node_v.custom_data.get("physics_repulsion", 100.0) if "custom_data" in node_v else 100.0
			var force_mag = ((rep_u + rep_v) * repulsion_multiplier) / dist_sq
			var force_vec = (diff / dist) * force_mag
			
			forces[id_u] += force_vec
			forces[id_v] -= force_vec

	# --- 2. ATTRACTION & TENSION (Snapping) ---
	var processed_edges = {}
	
	for key in graph.edge_store:
		var e = graph.edge_store[key]
		var u = e.u
		var v = e.v
		
		var pair = [u, v]
		pair.sort()
		if processed_edges.has(pair): continue
		processed_edges[pair] = true
		
		if not graph.nodes.has(u) or not graph.nodes.has(v): continue
		
		var node_u = graph.nodes[u]
		var node_v = graph.nodes[v]
		var edge_custom = e.custom
		
		if edge_custom.get("physics_mode", 0) == 1: continue
		
		var ideal_len = float(edge_custom.get("physics_spring_length", 150.0))
		var stiffness = float(edge_custom.get("physics_stiffness", 0.5))
		
		var diff = node_v.position - node_u.position
		var dist = diff.length()
		
		# --- EDGE TENSION LOGIC ---
		var local_snap = edge_custom.get("physics_snappable", false)
		
		# Snap if the edge has the local property, OR if the Global Override is active
		if global_edge_snapping or local_snap:
			var threshold = float(edge_custom.get("physics_snap_threshold", 400.0))
			if dist > threshold:
				destruction_report["snapped_edges"].append([u, v])
				continue # Skip spring physics, the edge broke!
		
		if dist > 0.1:
			var displacement = dist - ideal_len
			var force_mag = displacement * stiffness
			var force_vec = (diff / dist) * force_mag
			
			forces[u] += force_vec
			forces[v] -= force_vec

	# --- 3. INTEGRATION ---
	for id in node_ids:
		# Don't move a node if it was just flagged for destruction!
		if fused_tracker.has(id): continue
		
		var node = graph.nodes[id]
		var mode = node.custom_data.get("physics_mode", 0) if "custom_data" in node else 0
		
		if mode != 0:
			_velocities[id] = Vector2.ZERO
			continue
		
		var current_vel = _velocities[id]
		current_vel += forces[id] * delta
		current_vel *= damping
		
		if current_vel.length() > max_velocity:
			current_vel = current_vel.normalized() * max_velocity
			
		_velocities[id] = current_vel
		
		if current_vel.length_squared() > 0.01:
			var new_pos = node.position + current_vel
			
			# Crystallization logic...
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
