class_name StrategyWalker
extends GraphStrategy


# --- MAIN STRATEGY ---

var _walkers: Array[AgentWalker] = []
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
		if id == 2: default_idx = i 
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
	
	var ids = GraphSettings.current_names.keys()
	ids.sort()
	var global_paint_id = 2
	if global_paint_idx >= 0 and global_paint_idx < ids.size(): global_paint_id = ids[global_paint_idx]
	
	_manage_population(graph, params, target_count, global_mode, global_steps, global_paint_id)
	
	# 2. CALCULATE SIMULATION LENGTH
	var max_ticks = 0
	for w in _walkers:
		if w.active and w.steps_per_round > max_ticks:
			max_ticks = w.steps_per_round
			
	# 3. CAPTURE INITIAL STARTS
	# Use a Dictionary to track the "Effective Start" for each walker ID
	var effective_starts = {} 
	
	for w in _walkers:
		if w.current_node_id != "":
			effective_starts[w.id] = w.current_node_id
		else:
			# Mark as pending
			effective_starts[w.id] = ""

	# 4. SIMULATION LOOP
	var cell_size = GraphSettings.CELL_SIZE
	var merge = params.get("merge_overlaps", true)
	var branch = params.get("branch_randomly", false)
	
	for tick in range(max_ticks):
		for w in _walkers:
			if w.active and tick < w.steps_per_round:
				var visited_id = ""
				
				if w.mode == 0: # Grow
					visited_id = w.step_grow(graph, cell_size, merge)
				else: # Paint
					visited_id = w.step_paint(graph, branch, _session_path)
				
				if visited_id != "":
					_session_path.append(visited_id)
					
					# [FIX] LATE BINDING START
					# If this walker started in the void (no ID), the first valid node 
					# it visits/creates becomes its effective start.
					if effective_starts.has(w.id) and effective_starts[w.id] == "":
						effective_starts[w.id] = visited_id

	# 5. COMPILE RESULTS
	var start_ids = []
	for uid in effective_starts:
		var s_id = effective_starts[uid]
		if s_id != "":
			start_ids.append(s_id)
	
	var head_ids = []
	for w in _walkers:
		if w.current_node_id != "":
			head_ids.append(w.current_node_id)
			
	params["out_highlight_nodes"] = _session_path.duplicate()
	params["out_start_nodes"] = start_ids
	params["out_head_nodes"] = head_ids

func _manage_population(graph: GraphRecorder, params: Dictionary, target_count: int, default_mode: int, default_steps: int, default_paint: int) -> void:
	var append_mode = params.get("append", false)
	
	# HARD RESET (As requested/accepted)
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
		var w: AgentWalker
		var is_new = false
		
		if i < _walkers.size():
			w = _walkers[i]
		else:
			# Factory Logic
			w = AgentWalker.new(i, Vector2.ZERO, "", default_paint, default_steps)
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

func get_walkers_at_node(node_id: String) -> Array:
	var found = []
	for w in _walkers:
		if w.current_node_id == node_id:
			found.append(w)
	return found
