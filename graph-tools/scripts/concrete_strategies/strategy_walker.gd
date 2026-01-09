class_name StrategyWalker
extends GraphStrategy

# --- DATA ---
var _walkers: Array[AgentWalker] = []
var _session_path: Array[String] = []

func _init() -> void:
	strategy_name = "Walker Agents"
	reset_on_generate = true # Default internal flag
	supports_grow = true

# --- SETTINGS UI ---
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
		{ "name": "count", "type": TYPE_INT, "default": 1, "min": 0, "max": 10, "hint": "How many to spawn IF the board is empty." },
		{ "name": "mode", "type": TYPE_INT, "default": 0, "options": "Grow,Paint", "hint": "Default mode for NEW walkers." },
		{ "name": "paint_type", "type": TYPE_INT, "default": default_idx, "options": options_string, "hint": "Brush color for new walkers." },
		{ "name": "steps", "type": TYPE_INT, "default": 15, "min": 1, "max": 500, "hint": "Steps to take per Generate click." },
		{ "name": "snap_to_grid", "type": TYPE_BOOL, "default": false, "hint": "If true, NEW walkers align to global grid." },
		{ "name": "branch_randomly", "type": TYPE_BOOL, "default": false, "hint": "If true, walkers branch path." },
		{ "name": "action_clear_all", "type": TYPE_BOOL, "hint": "action", "label": "Clear All Agents" },
		
		# [NEW] Composition Toggle
		{
			"name": "clear_graph",
			"type": TYPE_BOOL,
			"default": true, 
			"label": "Clear Previous",
			"hint": "Uncheck to let walkers run on top of existing map."
		}
	]

# --- PUBLIC API (Unchanged) ---
func add_agent_at_node(node_id: String, graph: Graph) -> void:
	if node_id == "" or not graph.nodes.has(node_id): return
	var pos = graph.get_node_pos(node_id)
	var new_id = _walkers.size()
	var agent = AgentWalker.new(new_id, pos, node_id, 2, 50)
	_walkers.append(agent)
	print("StrategyWalker: Manual Agent Spawned at %s" % node_id)

func clear_agents() -> void: _walkers.clear()
func remove_agent(agent: AgentWalker) -> void: _walkers.erase(agent)

# --- EXECUTION ---

func execute(graph: GraphRecorder, params: Dictionary) -> void:
	_session_path.clear()
	
	# 1. Handle Clear / Composition
	var should_clear = params.get("clear_graph", true)
	if should_clear:
		graph.clear()
		_walkers.clear() # Reset agents if we wiped the world
	
	# 2. Spawn Population if empty
	if _walkers.is_empty():
		var target_count = int(params.get("count", 1))
		if target_count == 0:
			# ... (Output clearing logic) ...
			params["out_highlight_nodes"] = []
			params["out_start_nodes"] = []
			params["out_head_nodes"] = []
			return
		
		var default_mode = params.get("mode", 0)
		var default_steps = int(params.get("steps", 50))
		var paint_idx = int(params.get("paint_type", 0))
		var default_snap = params.get("snap_to_grid", false)
		
		var ids = GraphSettings.current_names.keys()
		ids.sort()
		var default_paint = 2
		if paint_idx >= 0 and paint_idx < ids.size(): default_paint = ids[paint_idx]
		
		_spawn_initial_population(graph, target_count, default_mode, default_steps, default_paint, default_snap)
		
	
	# 3. RUN SIMULATION
	var max_ticks = 0
	for w in _walkers:
		if w.active and w.steps_per_round > max_ticks:
			max_ticks = w.steps_per_round
			
	var effective_starts = {} 
	for w in _walkers:
		if w.current_node_id != "":
			effective_starts[w.id] = w.current_node_id
		else:
			effective_starts[w.id] = ""
	
	# Use Global Vector Spacing
	var grid_spacing = GraphSettings.GRID_SPACING
	
	var merge = params.get("merge_overlaps", true)
	var branch = params.get("branch_randomly", false)
	
	for tick in range(max_ticks):
		for w in _walkers:
			if w.active and tick < w.steps_per_round:
				var visited_id = ""
				
				if w.mode == 0: # Grow
					# Pass the Vector2 spacing
					visited_id = w.step_grow(graph, grid_spacing, merge)
				else: # Paint
					visited_id = w.step_paint(graph, branch, _session_path)
				
				if visited_id != "":
					_session_path.append(visited_id)
					if effective_starts.has(w.id) and effective_starts[w.id] == "":
						effective_starts[w.id] = visited_id
	
	# 4. COMPILE OUTPUT
	var start_ids = []
	for uid in effective_starts:
		var s_id = effective_starts[uid]
		if s_id != "": start_ids.append(s_id)
	
	var head_ids = []
	for w in _walkers:
		if w.current_node_id != "":
			head_ids.append(w.current_node_id)
			
	params["out_highlight_nodes"] = _session_path.duplicate()
	params["out_start_nodes"] = start_ids
	params["out_head_nodes"] = head_ids

# --- VISUALIZATION API (Unchanged) ---
func get_all_agent_positions() -> Array[String]:
	var list: Array[String] = []
	for w in _walkers:
		if w.current_node_id != "": list.append(w.current_node_id)
	return list

func get_all_agent_starts() -> Array[String]:
	var list: Array[String] = []
	for w in _walkers:
		if w.start_node_id != "": list.append(w.start_node_id)
	return list

func get_walkers_at_node(node_id: String) -> Array:
	var found = []
	for w in _walkers:
		if w.current_node_id == node_id: found.append(w)
	return found

# --- SPAWN LOGIC (UPDATED) ---
func _spawn_initial_population(graph: GraphRecorder, count: int, mode: int, steps: int, paint_type: int, snap: bool) -> void:
	
	# Scenario A: Graph is Empty (Fresh Start)
	if graph.nodes.is_empty():
		# Create a root node at (0,0) so walkers have somewhere to stand
		var root_id = "start_0"
		graph.add_node(root_id, Vector2.ZERO)
		
		# Spawn ALL walkers here
		for i in range(count):
			var agent = AgentWalker.new(i, Vector2.ZERO, root_id, paint_type, steps)
			agent.mode = mode
			agent.snap_to_grid = snap
			_walkers.append(agent)
			
	# Scenario B: Graph has nodes (Composition)
	else:
		var keys = graph.nodes.keys()
		for i in range(count):
			var rnd_node = keys[randi() % keys.size()]
			var pos = graph.get_node_pos(rnd_node)
			
			var agent = AgentWalker.new(i, pos, rnd_node, paint_type, steps)
			agent.mode = mode
			agent.snap_to_grid = snap
			_walkers.append(agent)
	
	print("StrategyWalker: Spawned %d agents." % count)
