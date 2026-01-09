class_name AgentWalker
extends RefCounted

# --- STATE ---
var id: int
var pos: Vector2
var current_node_id: String
var start_node_id: String # [NEW] Tracks origin for Green Marker
var step_count: int = 0 
var history: Array[Dictionary] = [] # [NEW] Tracks path for Trail

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
	start_node_id = start_id # [NEW]
	my_paint_type = initial_type
	steps_per_round = default_steps
	
	# [NEW] Record initial state
	if start_id != "":
		history.append({ "node": start_id, "step": 0 })

func reset_state() -> void:
	step_count = 0
	current_node_id = ""
	pos = Vector2.ZERO
	history.clear() # [NEW]

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
		{ "name": "pos", "type": TYPE_VECTOR2, "default": pos, "step": GraphSettings.CELL_SIZE, "hint": "Head position." },
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

# --- BEHAVIORS ---

func step_grow(graph: GraphRecorder, cell_size: float, merge_overlaps: bool) -> String:
	var dir_idx = randi() % 4
	var step_vector = Vector2.ZERO
	match dir_idx:
		0: step_vector = Vector2(cell_size, 0)
		1: step_vector = Vector2(-cell_size, 0)
		2: step_vector = Vector2(0, cell_size)
		3: step_vector = Vector2(0, -cell_size)
		
	var target_pos = pos + step_vector
	
	if snap_to_grid:
		target_pos = target_pos.snapped(Vector2(cell_size, cell_size))
	
	step_count += 1
	var new_id = ""
	
	var existing_id = graph.get_node_at_position(target_pos, 1.0)
	
	if merge_overlaps and not existing_id.is_empty():
		new_id = existing_id
	else:
		new_id = "walk:%d:%d" % [id, step_count]
		while graph.nodes.has(new_id):
			step_count += 1
			new_id = "walk:%d:%d" % [id, step_count]
		graph.add_node(new_id, target_pos)
	
	if not current_node_id.is_empty() and graph.nodes.has(current_node_id):
		if current_node_id != new_id:
			graph.add_edge(current_node_id, new_id)
	
	pos = target_pos
	current_node_id = new_id
	
	# [NEW] Log History
	history.append({ "node": new_id, "step": step_count })
	
	return new_id

func step_paint(graph: GraphRecorder, branch_randomly: bool, session_path: Array) -> String:
	if not current_node_id.is_empty():
		graph.set_node_type(current_node_id, my_paint_type)
	
	var neighbors = graph.get_neighbors(current_node_id)
	var next_id = ""
	
	if branch_randomly and randf() < 0.2 and not session_path.is_empty():
		var candidate = session_path.pick_random()
		if not graph.get_neighbors(candidate).is_empty():
			next_id = candidate
	
	if next_id == "":
		if neighbors.is_empty():
			if not session_path.is_empty():
				next_id = session_path.pick_random()
			else:
				var all = graph.nodes.keys()
				if not all.is_empty(): next_id = all.pick_random()
		else:
			next_id = neighbors.pick_random()
	
	if next_id != "":
		current_node_id = next_id
		pos = graph.get_node_pos(next_id)
		
		# [NEW] Log History
		history.append({ "node": next_id, "step": step_count })
		
	return current_node_id
