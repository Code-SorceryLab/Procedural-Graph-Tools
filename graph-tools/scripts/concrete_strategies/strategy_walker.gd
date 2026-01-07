class_name StrategyWalker
extends GraphStrategy

# --- INNER CLASS: THE AGENT ---
class WalkerAgent:
	var id: int
	var pos: Vector2
	var current_node_id: String
	var step_count: int = 0 # Cumulative lifetime steps
	
	# SETTINGS
	var my_paint_type: int = 2 
	var active: bool = true
	var mode: int = 0 # 0 = Grow, 1 = Paint
	var steps_per_round: int = 50 # How many steps to take in THIS generation click
	
	func _init(uid: int, start_pos: Vector2, start_node_id: String, initial_type: int, default_steps: int) -> void:
		id = uid
		pos = start_pos
		current_node_id = start_node_id
		my_paint_type = initial_type
		steps_per_round = default_steps
	
	# INSPECTOR UI
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
			{ "name": "steps_per_round", "type": TYPE_INT, "default": steps_per_round, "min": 1, "max": 500, "hint": "Steps to take per Generate click." },
			{ "name": "pos", "type": TYPE_VECTOR2, "default": pos, "step": GraphSettings.CELL_SIZE, "hint": "Head position." },
			{ "name": "paint_type", "type": TYPE_INT, "default": default_idx, "options": type_options, "hint": "Brush color." }
		]

	func apply_setting(key: String, value: Variant) -> void:
		match key:
			"active": active = value
			"mode": mode = value
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
		names.append(GraphSettings.get_type_name(id))
		if id == 2: default_idx = i # Default to 2 (Treasure/Enemy/etc)
	var options_string = ",".join(names)

	return [
		{ "name": "mode", "type": TYPE_INT, "default": 0, "options": "Grow,Paint", "hint": "Default mode for NEW walkers." },
		{ "name": "count", "type": TYPE_INT, "default": 1, "min": 1, "max": 10, "hint": GraphSettings.PARAM_TOOLTIPS.walker["count"] },
		{ "name": "steps", "type": TYPE_INT, "default": 50, "min": 1, "max": 500, "hint": "Default steps for NEW walkers." },
		{ "name": "paint_type", "type": TYPE_INT, "default": default_idx, "options": options_string, "hint": GraphSettings.PARAM_TOOLTIPS.walker["paint_type"] },
		{ "name": "branch_randomly", "type": TYPE_BOOL, "default": false, "hint": GraphSettings.PARAM_TOOLTIPS.walker["branch"] }
	]

func execute(graph: GraphRecorder, params: Dictionary) -> void:
	_session_path.clear()
	
	# 1. SETUP POPULATION
	var target_count = int(params.get("count", 1))
	var global_mode = params.get("mode", 0)
	var global_steps = int(params.get("steps", 50))
	var global_paint_idx = int(params.get("paint_type", 0))
	
	# Resolve Paint ID
	var ids = GraphSettings.current_names.keys()
	ids.sort()
	var global_paint_id = 2
	if global_paint_idx >= 0 and global_paint_idx < ids.size(): global_paint_id = ids[global_paint_idx]
	
	_manage_population(graph, params, target_count, global_mode, global_steps, global_paint_id)
	
	# 2. CALCULATE SIMULATION LENGTH
	# Run for as long as the most ambitious active walker wants
	var max_ticks = 0
	for w in _walkers:
		if w.active and w.steps_per_round > max_ticks:
			max_ticks = w.steps_per_round
			
	# 3. CAPTURE STARTS (Before movement)
	var start_ids = []
	for w in _walkers:
		# BUG FIX: Always capture inactive/active walkers so markers don't vanish
		if w.current_node_id != "":
			start_ids.append(w.current_node_id)

	# 4. SIMULATION LOOP
	var cell_size = GraphSettings.CELL_SIZE
	var merge = params.get("merge_overlaps", true)
	var branch = params.get("branch_randomly", false)
	
	for tick in range(max_ticks):
		for w in _walkers:
			# Agent Decision Logic
			if w.active and tick < w.steps_per_round:
				var visited_id = ""
				
				if w.mode == 0: # Grow
					visited_id = w.step_grow(graph, cell_size, merge)
				else: # Paint
					visited_id = w.step_paint(graph, branch, _session_path)
				
				if visited_id != "":
					_session_path.append(visited_id)

	# 5. CAPTURE ENDS
	var head_ids = []
	for w in _walkers:
		if w.current_node_id != "":
			head_ids.append(w.current_node_id)
			
	# OUTPUT
	# Only highlight if ANY walker was in Grow mode? 
	# Actually, let's just highlight whatever path was generated.
	params["out_highlight_nodes"] = _session_path.duplicate()
	params["out_start_nodes"] = start_ids
	params["out_head_nodes"] = head_ids

func _manage_population(graph: GraphRecorder, params: Dictionary, target_count: int, default_mode: int, default_steps: int, default_paint: int) -> void:
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
	
	var need_respawn = (append_mode and params.get("branch_randomly", false))
	
	for i in range(target_count):
		var w: WalkerAgent
		var is_new = false
		
		if i < _walkers.size():
			w = _walkers[i]
		else:
			# FACTORY LOGIC: New walkers get the Global defaults
			w = WalkerAgent.new(i, Vector2.ZERO, "", default_paint, default_steps)
			w.mode = default_mode
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
