class_name AgentWalker
extends RefCounted

# --- STATE ---
var id: int
var pos: Vector2
var current_node_id: String
var start_node_id: String 
var step_count: int = 0 
var history: Array[Dictionary] = [] 

# --- SETTINGS ---
var my_paint_type: int = 2 
var active: bool = true
var mode: int = 0 # 0 = Grow, 1 = Paint
var snap_to_grid: bool = false
var steps_per_round: int = 50 

# --- INITIALIZATION ---
func _init(uid: int, start_pos: Vector2, start_id: String, initial_type: int, default_steps: int) -> void:
	id = uid
	pos = start_pos
	current_node_id = start_id
	start_node_id = start_id
	my_paint_type = initial_type
	steps_per_round = default_steps
	
	if start_id != "":
		history.append({ "node": start_id, "step": 0 })

func reset_state() -> void:
	step_count = 0
	current_node_id = ""
	pos = Vector2.ZERO
	history.clear()

# --- INSPECTOR UI API ---
func get_agent_settings() -> Array[Dictionary]:
	var ids = GraphSettings.current_names.keys()
	ids.sort()
	var names: PackedStringArray = []
	var default_idx = 0
	for i in range(ids.size()):
		var t_id = ids[i]
		names.append(GraphSettings.get_type_name(t_id))
		if t_id == my_paint_type: default_idx = i
	var type_options = ",".join(names)
	
	return [
		{ "name": "active", "type": TYPE_BOOL, "default": active, "hint": "Pause/Resume this walker." },
		{ "name": "mode", "type": TYPE_INT, "default": mode, "options": "Grow,Paint", "hint": "Behavior for this specific walker." },
		{ "name": "paint_type", "type": TYPE_INT, "default": default_idx, "options": type_options, "hint": "Brush color." },
		{ "name": "steps_per_round", "type": TYPE_INT, "default": steps_per_round, "min": 0, "max": 500, "hint": "Steps to take per Generate click." },
		
		# [REFACTOR] Use GRID_SPACING.x for the step increment
		{ "name": "pos", "type": TYPE_VECTOR2, "default": pos, "step": GraphSettings.GRID_SPACING.x, "hint": "Head position." },
		
		{ "name": "snap_to_grid", "type": TYPE_BOOL, "default": snap_to_grid, "hint": "If true, aligns new nodes to the global grid." },
		{ "name": "action_delete", "type": TYPE_BOOL, "hint": "action", "label": "Delete Agent" }
	]

func apply_setting(key: String, value: Variant) -> void:
	match key:
		"active": active = value
		"mode": mode = value
		"snap_to_grid": snap_to_grid = value
		"steps_per_round": steps_per_round = value
		"pos": pos = value
		"paint_type":
			var ids = GraphSettings.current_names.keys()
			ids.sort()
			if value >= 0 and value < ids.size():
				my_paint_type = ids[value]

# ==============================================================================
# REFACTORED BEHAVIORS
# ==============================================================================

# SHARED LOGIC: The "Committer"
func _commit_step(new_id: String, new_pos: Vector2) -> void:
	pos = new_pos
	current_node_id = new_id
	step_count += 1
	history.append({ "node": new_id, "step": step_count })

# MODE A: GROW
# [REFACTOR] Now accepts Vector2 spacing
func step_grow(graph: GraphRecorder, grid_spacing: Vector2, merge_overlaps: bool) -> String:
	# 1. Calculate Geometry
	var target_pos = pos + _get_random_cardinal_vector(grid_spacing)
	
	if snap_to_grid:
		# [REFACTOR] Snap using the vector
		target_pos = target_pos.snapped(grid_spacing)
	
	# --- PHASE 4: ZONE AWARENESS ---
	# Calculate which logical grid cell we are trying to enter
	var gx = round(target_pos.x / grid_spacing.x)
	var gy = round(target_pos.y / grid_spacing.y)
	var target_grid_pos = Vector2i(gx, gy)
	
	# Ask the Graph who owns this land
	# GraphRecorder inherits from Graph, so it has get_zone_at()
	var zone = graph.get_zone_at(target_grid_pos)
	
	if zone:
		# Check if this zone forbids construction
		if not zone.allow_new_nodes:
			# BLOCKED: Treat as a wall.
			# We return current_node_id to signify "didn't move".
			# The loop in StrategyWalker continues, essentially making the walker "wait" this tick.
			return current_node_id
	# -------------------------------

	# 2. Determine ID (Find existing or Create new)
	var new_id = ""
	var existing_id = graph.get_node_at_position(target_pos, 1.0)
	
	if merge_overlaps and not existing_id.is_empty():
		new_id = existing_id
	else:
		new_id = _generate_unique_id(graph)
		graph.add_node(new_id, target_pos)
	
	# 3. Connect Backwards
	if not current_node_id.is_empty() and graph.nodes.has(current_node_id):
		if current_node_id != new_id:
			graph.add_edge(current_node_id, new_id)
	
	# 4. Commit
	_commit_step(new_id, target_pos)
	return new_id

# MODE B: PAINT (Unchanged)
func step_paint(graph: GraphRecorder, branch_randomly: bool, session_path: Array) -> String:
	if not current_node_id.is_empty():
		graph.set_node_type(current_node_id, my_paint_type)
	
	var next_id = _pick_next_paint_node(graph, branch_randomly, session_path)
	
	if next_id != "":
		var next_pos = graph.get_node_pos(next_id)
		_commit_step(next_id, next_pos)
		
	return current_node_id

# --- INTERNAL HELPERS ---

# [REFACTOR] Use Vector2 scale to allow rectangular steps
func _get_random_cardinal_vector(scale: Vector2) -> Vector2:
	var dir_idx = randi() % 4
	match dir_idx:
		0: return Vector2(scale.x, 0)  # Right
		1: return Vector2(-scale.x, 0) # Left
		2: return Vector2(0, scale.y)  # Down
		3: return Vector2(0, -scale.y) # Up
	return Vector2.ZERO

func _generate_unique_id(graph: GraphRecorder) -> String:
	var temp_count = step_count + 1 
	var new_id = "walk:%d:%d" % [id, temp_count]
	while graph.nodes.has(new_id):
		temp_count += 1
		new_id = "walk:%d:%d" % [id, temp_count]
	return new_id

func _pick_next_paint_node(graph: GraphRecorder, branch_randomly: bool, session_path: Array) -> String:
	var next_id = ""
	
	if branch_randomly and randf() < 0.2 and not session_path.is_empty():
		var candidate = session_path.pick_random()
		if not graph.get_neighbors(candidate).is_empty():
			next_id = candidate
	
	if next_id == "":
		var neighbors = graph.get_neighbors(current_node_id)
		if neighbors.is_empty():
			if not session_path.is_empty():
				next_id = session_path.pick_random()
			else:
				var all = graph.nodes.keys()
				if not all.is_empty(): next_id = all.pick_random()
		else:
			next_id = neighbors.pick_random()
			
	return next_id

# --- VISUALIZATION API ---

func get_history_labels() -> Dictionary:
	var labels = {}
	for entry in history:
		var node_id = entry["node"]
		var step = entry["step"]
		var text = "%d:%d" % [id, step]
		
		if labels.has(node_id):
			labels[node_id] += ", " + text
		else:
			labels[node_id] = text
	return labels
