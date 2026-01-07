class_name StrategyWalker
extends GraphStrategy

# --- INNER CLASS: THE AGENT ---
class WalkerAgent:
	var id: int
	var pos: Vector2
	var current_node_id: String
	var step_count: int = 0
	var my_paint_type: int = 2 
	var active: bool = true
	
	func _init(uid: int, start_pos: Vector2, start_node_id: String, initial_type: int) -> void:
		id = uid
		pos = start_pos
		current_node_id = start_node_id
		my_paint_type = initial_type
	
	# MODE A: GROW
	func step_grow(graph: GraphRecorder, cell_size: float, merge_overlaps: bool) -> String:
		# CHECK ACTIVE STATE
		if not active: return current_node_id
		
		var dir_idx = randi() % 4
		var step_vector = Vector2.ZERO
		match dir_idx:
			0: step_vector = Vector2(cell_size, 0)
			1: step_vector = Vector2(-cell_size, 0)
			2: step_vector = Vector2(0, cell_size)
			3: step_vector = Vector2(0, -cell_size)
			
		var target_pos = pos + step_vector
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
		return new_id

	# MODE B: PAINT
	func step_paint(graph: GraphRecorder, branch_randomly: bool, session_path: Array) -> String:
		# CHECK ACTIVE STATE
		if not active: return current_node_id
		
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
			
		return current_node_id

# --- MAIN STRATEGY ---

var _walkers: Array[WalkerAgent] = []
var _session_path: Array[String] = []

func _init() -> void:
	strategy_name = "Random Walker"
	reset_on_generate = true
	supports_grow = true

func get_settings() -> Array[Dictionary]:
	var ids = GraphSettings.current_names.keys()
	ids.sort()
	var names: PackedStringArray = []
	var default_idx = 0
	for i in range(ids.size()):
		var id = ids[i]
		var type_name = GraphSettings.get_type_name(id) 
		names.append(type_name)
		if type_name == "Treasure" or type_name == "Enemy": default_idx = i
	var options_string = ",".join(names)

	return [
		{ "name": "mode", "type": TYPE_INT, "default": 0, "options": "Grow,Paint", "hint": GraphSettings.PARAM_TOOLTIPS.walker["mode"] },
		{ "name": "count", "type": TYPE_INT, "default": 1, "min": 1, "max": 10, "hint": GraphSettings.PARAM_TOOLTIPS.walker["count"] },
		{ "name": "steps", "type": TYPE_INT, "default": 50, "min": 1, "max": 500, "hint": GraphSettings.PARAM_TOOLTIPS.walker["steps"] },
		{ "name": "paint_type", "type": TYPE_INT, "default": default_idx, "options": options_string, "hint": GraphSettings.PARAM_TOOLTIPS.walker["paint_type"] },
		{ "name": "branch_randomly", "type": TYPE_BOOL, "default": false, "hint": GraphSettings.PARAM_TOOLTIPS.walker["branch"] }
	]

func execute(graph: GraphRecorder, params: Dictionary) -> void:
	_session_path.clear()
	var mode = params.get("mode", 0) 
	var steps = int(params.get("steps", 50))
	var target_count = int(params.get("count", 1))
	
	# 1. Resolve Global Paint Type (Factory Setting)
	var type_idx = int(params.get("paint_type", 0))
	var ids = GraphSettings.current_names.keys()
	ids.sort()
	var global_paint_type = 2
	if type_idx >= 0 and type_idx < ids.size(): global_paint_type = ids[type_idx]
	
	# 2. Manage Population
	_manage_population(graph, params, target_count, global_paint_type)
	
	# 3. Capture Starts
	var start_ids = []
	for w in _walkers:
		if w.current_node_id != "":
			start_ids.append(w.current_node_id)

	# 4. Execute Steps
	for i in range(steps):
		for w in _walkers:
			var visited_id = ""
			if mode == 0:
				visited_id = w.step_grow(graph, GraphSettings.CELL_SIZE, params.get("merge_overlaps", true))
			else:
				# Uses walker's internal color now (no override passed)
				visited_id = w.step_paint(graph, params.get("branch_randomly", false), _session_path)
			
			_session_path.append(visited_id)

	# 5. Capture Heads
	var head_ids = []
	for w in _walkers:
		if w.current_node_id != "":
			head_ids.append(w.current_node_id)
			
	# OUTPUT
	if mode == 0:
		params["out_highlight_nodes"] = _session_path.duplicate()
	else:
		params["out_highlight_nodes"] = []
	
	params["out_start_nodes"] = start_ids
	params["out_head_nodes"] = head_ids

func _manage_population(graph: GraphRecorder, params: Dictionary, target_count: int, global_type: int) -> void:
	var append_mode = params.get("append", false)
	
	if not append_mode:
		_walkers.clear()

	# Prune invalid
	for i in range(_walkers.size() - 1, -1, -1):
		if _walkers[i].current_node_id != "" and not graph.nodes.has(_walkers[i].current_node_id):
			_walkers[i].current_node_id = ""

	# Resize
	if _walkers.size() > target_count:
		_walkers.resize(target_count)
	
	# REMOVED: Logic that forced existing walkers to update colors
	
	var need_respawn = (append_mode and params.get("branch_randomly", false))
	
	for i in range(target_count):
		var w: WalkerAgent
		var is_new = false
		
		if i < _walkers.size():
			w = _walkers[i]
		else:
			# Spawn new walker with GLOBAL type (The Factory logic)
			w = WalkerAgent.new(i, Vector2.ZERO, "", global_type)
			_walkers.append(w)
			is_new = true
			
		if is_new or w.current_node_id == "" or need_respawn:
			if not graph.nodes.is_empty():
				var keys = graph.nodes.keys()
				var rnd = keys[randi() % keys.size()]
				w.current_node_id = rnd
				w.pos = graph.get_node_pos(rnd)
			else:
				w.pos = Vector2.ZERO
				w.current_node_id = ""

# --- INSPECTOR API ---
func get_walkers_at_node(node_id: String) -> Array:
	var found = []
	for w in _walkers:
		if w.current_node_id == node_id:
			found.append(w)
	return found
