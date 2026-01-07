class_name StrategyWalker
extends GraphStrategy

# Walker memory
var _walkers: Array[Dictionary] = []
var _session_path: Array[String] = []

func _init() -> void:
	strategy_name = "Random Walker"
	reset_on_generate = true
	supports_grow = true

func get_settings() -> Array[Dictionary]:
	# 1. GENERATE OPTIONS FROM DYNAMIC LEGEND
	# We use the global GraphSettings to get the current loaded legend (e.g. Magma)
	var ids = GraphSettings.current_names.keys()
	ids.sort() # CRITICAL: Must sort to ensure Index matches ID later
	
	var names: PackedStringArray = []
	var default_idx = 0
	
	for i in range(ids.size()):
		var id = ids[i]
		# Get the name (e.g., "Spawn", "Magma Chamber")
		var type_name = GraphSettings.get_type_name(id) 
		names.append(type_name)
		
		# Heuristic: Default to "Treasure" or "Enemy" if available
		if type_name == "Treasure" or type_name == "Enemy":
			default_idx = i
			
	var options_string = ",".join(names)

	return [
		{ 
			"name": "mode", 
			"type": TYPE_INT, 
			"default": 0,
			"options": "Grow,Paint", 
			"hint": "Grow: Creates new nodes.\nPaint: Traverses existing nodes and changes their type."
		},
		{ 
			"name": "steps", 
			"type": TYPE_INT, 
			"default": 50, 
			"min": 1, "max": 500,
			"hint": GraphSettings.PARAM_TOOLTIPS.walker.steps
		},
		{ 
			"name": "paint_type",
			"type": TYPE_INT,
			"default": default_idx, 
			"options": options_string, # Dynamic list!
			"hint": "The RoomType to apply when Painting."
		},
		{ 
			"name": "branch_randomly", 
			"type": TYPE_BOOL, 
			"default": false,
			"hint": GraphSettings.PARAM_TOOLTIPS.walker.branch
		}
	]

func execute(graph: GraphRecorder, params: Dictionary) -> void:
	_session_path.clear()
	
	var mode = params.get("mode", 0) 
	var steps = int(params.get("steps", 50))
	
	if mode == 0:
		_execute_grow(graph, params, steps)
	else:
		_execute_paint(graph, params, steps)
		
	# --- OUTPUT TO EDITOR ---
	params["out_highlight_nodes"] = _session_path.duplicate()
	
	if not _walkers.is_empty():
		params["out_head_node"] = _walkers[0].current_node_id

# --- MODE A: GROW ---
func _execute_grow(graph: GraphRecorder, params: Dictionary, steps: int) -> void:
	var branch_randomly = params.get("branch_randomly", false)
	var append_mode = params.get("append", false)
	var merge_overlaps = params.get("merge_overlaps", true)
	
	if not append_mode:
		_walkers.clear()

	# Validate memory
	for w in _walkers:
		if w.current_node_id != "" and not graph.nodes.has(w.current_node_id):
			w.current_node_id = ""
	
	# Respawn logic
	var need_respawn = (append_mode and branch_randomly)
	if not _walkers.is_empty() and _walkers[0].current_node_id == "":
		need_respawn = true

	if need_respawn:
		if not graph.nodes.is_empty():
			var keys = graph.nodes.keys()
			var random_id = keys[randi() % keys.size()]
			var random_pos = graph.get_node_pos(random_id)
			
			if _walkers.is_empty():
				_walkers.append({ "id": 0, "pos": random_pos, "current_node_id": random_id, "step_count": 0 })
			else:
				_walkers[0].pos = random_pos
				_walkers[0].current_node_id = random_id
		else:
			if _walkers.is_empty():
				_walkers.append({ "id": 0, "pos": Vector2.ZERO, "current_node_id": "", "step_count": 0 })
			else:
				_walkers[0].pos = Vector2.ZERO
				_walkers[0].current_node_id = ""

	if _walkers.is_empty():
		_walkers.append({ "id": 0, "pos": Vector2.ZERO, "current_node_id": "", "step_count": 0 })

	# --- CAPTURE START NODE ---
	var start_id = _walkers[0].current_node_id

	# SIMULATION LOOP
	for i in range(steps):
		for w in _walkers:
			_step_walker_grow(graph, w, merge_overlaps)

	# --- POST-PROCESS START NODE ---
	if start_id == "" and not _session_path.is_empty():
		start_id = _session_path[0]

	params["out_start_node"] = start_id


# --- MODE B: PAINT ---
func _execute_paint(graph: GraphRecorder, params: Dictionary, steps: int) -> void:
	# 1. RESOLVE UI INDEX -> REAL ID
	# The params give us the Index (e.g., 3), but we need the ID (e.g., 99).
	var type_idx = int(params.get("paint_type", 0))
	
	var ids = GraphSettings.current_names.keys()
	ids.sort() # Must match the sort order in get_settings()
	
	var target_type = 2 # Fallback
	if type_idx >= 0 and type_idx < ids.size():
		target_type = ids[type_idx]
	
	var branch_randomly = params.get("branch_randomly", false)
	
	var keys = graph.nodes.keys()
	if keys.is_empty():
		return
		
	var current_id = keys.pick_random()
	
	# Capture Start for Paint Mode
	params["out_start_node"] = current_id
	
	_session_path.append(current_id)
	
	for i in range(steps):
		graph.set_node_type(current_id, target_type)
		
		var neighbors = graph.get_neighbors(current_id)
		
		if branch_randomly and randf() < 0.2 and not _session_path.is_empty():
			var jump_candidate = _session_path.pick_random()
			if not graph.get_neighbors(jump_candidate).is_empty():
				current_id = jump_candidate
				continue
		
		if neighbors.is_empty():
			current_id = keys.pick_random()
		else:
			current_id = neighbors.pick_random()
			
		_session_path.append(current_id)

# --- INTERNAL HELPER ---
func _step_walker_grow(graph: GraphRecorder, walker: Dictionary, merge_overlaps: bool) -> void:
	var dir_idx = randi() % 4
	var step_vector = Vector2.ZERO
	match dir_idx:
		0: step_vector = Vector2(GraphSettings.CELL_SIZE, 0)
		1: step_vector = Vector2(-GraphSettings.CELL_SIZE, 0)
		2: step_vector = Vector2(0, GraphSettings.CELL_SIZE)
		3: step_vector = Vector2(0, -GraphSettings.CELL_SIZE)
		
	var target_pos = walker.pos + step_vector
	walker.step_count += 1
	var current_id = ""
	
	var existing_id = graph.get_node_at_position(target_pos, 1.0)
	
	if merge_overlaps and not existing_id.is_empty():
		current_id = existing_id
	else:
		current_id = "walk:%d:%d" % [walker.id, walker.step_count]
		while graph.nodes.has(current_id):
			walker.step_count += 1
			current_id = "walk:%d:%d" % [walker.id, walker.step_count]
		graph.add_node(current_id, target_pos)
	
	if not walker.current_node_id.is_empty():
		if graph.nodes.has(walker.current_node_id):
			if walker.current_node_id != current_id:
				graph.add_edge(walker.current_node_id, current_id)
			
	walker.pos = target_pos
	walker.current_node_id = current_id
	_session_path.append(current_id)
