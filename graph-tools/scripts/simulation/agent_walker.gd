class_name AgentWalker
extends RefCounted

# --- STATE ---
var id: int
var pos: Vector2
var current_node_id: String
var start_node_id: String 
var step_count: int = 0  # <--- THIS IS THE COUNTER
var history: Array[Dictionary] = [] 

# Brain Parameters
var behavior_mode: int = 0  # 0=Hold, 1=Paint, 2=Grow, 3=Seek
var movement_algo: int = 0  # 0=Random, 1=BFS, 2=DFS, 3=A*
var target_node_id: String = ""

# --- SETTINGS ---
var my_paint_type: int = 2 
var active: bool = true
var mode: int = 0 # 0 = Grow, 1 = Paint
var snap_to_grid: bool = false
var steps: int = 15     # <--- THIS IS THE LIMIT (Max Steps)
var branch_randomly: bool = false



# --- INITIALIZATION ---
func _init(uid: int, start_pos: Vector2, start_id: String, initial_type: int, default_steps: int) -> void:
	id = uid
	pos = start_pos
	current_node_id = start_id
	start_node_id = start_id
	my_paint_type = initial_type
	steps = default_steps
	
	if start_id != "":
		history.append({ "node": start_id, "step": 0 })

func reset_state() -> void:
	step_count = 0
	current_node_id = ""
	pos = Vector2.ZERO
	history.clear()

# --- EXPLICIT ACTIONS ---

# Unified movement function
# If new_node_id is provided, we snap to that node.
# If new_node_id is empty, the agent becomes "floating" at that position.
func warp(new_pos: Vector2, new_node_id: String = "") -> void:
	pos = new_pos
	current_node_id = new_node_id

# --- SHARED SCHEMA (Source of Truth) ---
static func get_template_settings() -> Array[Dictionary]:
	var ids = GraphSettings.current_names.keys()
	ids.sort()
	var names: PackedStringArray = []
	var default_idx = 0
	for i in range(ids.size()):
		var id = ids[i]
		names.append(GraphSettings.get_type_name(id))
		if id == 2: default_idx = i 
	var options_string = ",".join(names)
	
	return [
		{ "name": "active", "type": TYPE_BOOL, "default": true, "hint": "If true, walker will move on Generate." },
		
		{ "name": "mode", "type": TYPE_INT, "default": 0, "options": "Grow,Paint", "hint": "Behavior mode." },
		{ "name": "paint_type", "type": TYPE_INT, "default": default_idx, "options": options_string, "hint": "Brush color." },
		
		# [UPDATED] Default 15, Min 0
		{ "name": "steps", "type": TYPE_INT, "default": 15, "min": 0, "max": 500, "hint": "Steps per Generate click." },
		
		{ "name": "snap_to_grid", "type": TYPE_BOOL, "default": false, "hint": "Align new nodes to grid." },
		{ "name": "branch_randomly", "type": TYPE_BOOL, "default": false, "hint": "Randomly branch path." }
	]

# --- INSPECTOR UI API ---
func get_agent_settings() -> Array[Dictionary]:
	# 1. Get Base Settings
	var settings = AgentWalker.get_template_settings()
	
	# 2. Sync Defaults with Current State
	for s in settings:
		if s.name == "active": s.default = active
		elif s.name == "mode": s.default = mode
		elif s.name == "steps": s.default = steps
		elif s.name == "snap_to_grid": s.default = snap_to_grid
		elif s.name == "branch_randomly": s.default = branch_randomly
		elif s.name == "paint_type":
			var ids = GraphSettings.current_names.keys()
			ids.sort()
			var idx = ids.find(my_paint_type)
			if idx != -1: s.default = idx
			
	# 3. Add Runtime-Only Controls (Pos, Delete)
	# (Active is now handled in the loop above)
	settings.append_array([
		{ "name": "pos", "type": TYPE_VECTOR2, "default": pos, "hint": "Head position." },
		{ "name": "action_delete", "type": TYPE_BOOL, "hint": "action", "label": "Delete Agent" }
	])
	
	return settings

func apply_setting(key: String, value: Variant) -> void:
	match key:
		"global_behavior": behavior_mode = value
		"movement_algo": movement_algo = value
		"target_node": target_node_id = value
		"active": active = value
		"mode": pass # Keep for backward compatibility or map to behavior_mode
		"snap_to_grid": snap_to_grid = value
		"steps": steps = value
		"branch_randomly": branch_randomly = value
		"paint_type":
			var ids = GraphSettings.current_names.keys()
			ids.sort()
			if value >= 0 and value < ids.size():
				my_paint_type = ids[value]
		"pos": warp(value)

# ==============================================================================
# BEHAVIORS
# ==============================================================================

func _commit_step(new_id: String, new_pos: Vector2) -> void:
	pos = new_pos
	current_node_id = new_id
	step_count += 1
	history.append({ "node": new_id, "step": step_count })

# --- NEW GENERIC STEP FUNCTION ---
# This replaces the specific step_grow/step_paint logic for the "Seek" behavior
func step_seek(graph) -> String:
	# 1. Ask Navigator for the next step
	var next_id = AgentNavigator.get_next_step(
		current_node_id, 
		target_node_id, 
		movement_algo, 
		graph
	)
	
	# 2. Execute Move
	if next_id != "":
		var next_pos = graph.get_node_pos(next_id)
		_commit_step(next_id, next_pos)
		
	return current_node_id

# 0. GROW BEHAVIOR (Expansion)
func step_grow(graph, grid_spacing: Vector2, merge_overlaps: bool) -> String:
	# If falling into the void, snap to underfoot
	if current_node_id == "":
		var under_feet = graph.get_node_at_position(pos, -1.0)
		if not under_feet.is_empty(): current_node_id = under_feet

	var start_point = pos
	if snap_to_grid: start_point = pos.snapped(grid_spacing)

	# Pick random direction
	var target_pos = start_point + _get_random_cardinal_vector(grid_spacing)
	
	# Check Zone Permissions
	var gx = round(target_pos.x / grid_spacing.x)
	var gy = round(target_pos.y / grid_spacing.y)
	
	# Note: In Simulation, 'graph' might be the raw graph or recorder. 
	# We use safe access for zones.
	if graph.has_method("get_zone_at"):
		var zone = graph.get_zone_at(Vector2i(gx, gy))
		if zone and not zone.allow_new_nodes: return current_node_id

	var new_id = ""
	var existing_id = graph.get_node_at_position(target_pos, -1.0)
	
	if merge_overlaps and not existing_id.is_empty():
		new_id = existing_id
		target_pos = graph.get_node_pos(new_id)
	else:
		new_id = _generate_unique_id(graph)
		graph.add_node(new_id, target_pos)
	
	if not current_node_id.is_empty() and graph.nodes.has(current_node_id):
		if current_node_id != new_id:
			var prev_pos = graph.get_node_pos(current_node_id)
			var dist = prev_pos.distance_to(target_pos)
			# Only connect if close enough (prevent cross-map jumps)
			if dist < grid_spacing.length() * 1.5:
				graph.add_edge(current_node_id, new_id)
	
	_commit_step(new_id, target_pos)
	return new_id

# 1. PAINT BEHAVIOR (Random Walk)
func step_paint(graph, _ignored_branch_param: bool, session_path: Array) -> String:
	if not current_node_id.is_empty():
		# Action: Paint the ground
		graph.set_node_type(current_node_id, my_paint_type)
	
	# Movement: Random Walk (Different from Seek!)
	var next_id = _pick_next_paint_node(graph, branch_randomly, session_path)
	
	if next_id != "":
		var next_pos = graph.get_node_pos(next_id)
		_commit_step(next_id, next_pos)
	return current_node_id

# ... Internal Helpers ...
func _get_random_cardinal_vector(scale: Vector2) -> Vector2:
	var dir_idx = randi() % 4
	match dir_idx:
		0: return Vector2(scale.x, 0) 
		1: return Vector2(-scale.x, 0)
		2: return Vector2(0, scale.y) 
		3: return Vector2(0, -scale.y)
	return Vector2.ZERO

func _generate_unique_id(graph) -> String:
	var temp_count = step_count + 1 
	var new_id = "walk:%d:%d" % [id, temp_count]
	while graph.nodes.has(new_id):
		temp_count += 1
		new_id = "walk:%d:%d" % [id, temp_count]
	return new_id

func _pick_next_paint_node(graph, do_branch: bool, session_path: Array) -> String:
	var next_id = ""
	if do_branch and randf() < 0.2 and not session_path.is_empty():
		var candidate = session_path.pick_random()
		if not graph.get_neighbors(candidate).is_empty(): next_id = candidate
	if next_id == "":
		var neighbors = graph.get_neighbors(current_node_id)
		if neighbors.is_empty():
			if not session_path.is_empty(): next_id = session_path.pick_random()
			else:
				var all = graph.nodes.keys()
				if not all.is_empty(): next_id = all.pick_random()
		else: next_id = neighbors.pick_random()
	return next_id

func get_history_labels() -> Dictionary:
	var labels = {}
	for entry in history:
		var node_id = entry["node"]
		var step = entry["step"]
		var text = "%d:%d" % [id, step]
		if labels.has(node_id): labels[node_id] += ", " + text
		else: labels[node_id] = text
	return labels
