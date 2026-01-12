class_name StrategyWalker
extends GraphStrategy

# --- DATA ---
var _session_path: Array[String] = []

func _init() -> void:
	strategy_name = "Walker Agents"
	reset_on_generate = false 
	supports_grow = true

# --- SETTINGS UI ---
func get_settings() -> Array[Dictionary]:
	var settings: Array[Dictionary] = [
		{ "name": "count", "type": TYPE_INT, "default": 1, "min": 0, "max": 10, "hint": "How many to spawn IF the board is empty." },
	]
	
	# 2. Agent Template Settings
	settings.append_array(AgentWalker.get_template_settings())
	
	# 3. Strategy Overrides
	settings.append_array([
		{ "name": "use_override_pos", "type": TYPE_BOOL, "default": false, "label": "Use Manual Start", "hint": "If checked, forces spawn at the coordinates below." },
		{ "name": "start_pos", "type": TYPE_VECTOR2, "default": Vector2.ZERO, "label": "Start Position", "hint": "Coordinates to spawn at (if 'Use Manual Start' is on)." },
		{ "name": "action_clear_all", "type": TYPE_BOOL, "hint": "action", "label": "Clear All Agents" },
	])
	
	return settings

# --- PUBLIC API ---

# [FACTORY] Creates an agent object (but does not add it to graph)
# Used by the Manual Spawner Tool
func create_agent_for_node(node_id: String, graph: Graph) -> AgentWalker:
	if node_id == "" or not graph.nodes.has(node_id): 
		return null
		
	var pos = graph.get_node_pos(node_id)
	var new_id = graph.agents.size()
	
	var agent = AgentWalker.new(new_id, pos, node_id, 2, 50)
	
	agent.apply_template_defaults()
	
	print("StrategyWalker: Created Agent Object for %s" % node_id)
	return agent

# --- EXECUTION ---
func execute(graph: GraphRecorder, params: Dictionary) -> void:
	_session_path.clear()
	
	print("StrategyWalker: Execute. Agents: %d" % graph.agents.size())
	
	# 1. Handle "Clear All" Action
	if params.get("action_clear_all", false):
		graph.agents.clear()
		return
	
	# 2. Spawn Population if Empty
	if graph.agents.is_empty():
		var target_count = int(params.get("count", 1))
		if target_count == 0:
			params["out_highlight_nodes"] = []; params["out_start_nodes"] = []; params["out_head_nodes"] = []
			return
		
		var manual_start = Vector2.INF
		if params.get("use_override_pos", false):
			manual_start = params.get("start_pos", Vector2.ZERO)
		
		_spawn_initial_population(graph, target_count, params, manual_start)
	
	# ==============================================================================
	# 3. RUN SIMULATION
	# ==============================================================================
	
	# A. SNAPSHOT BEFORE MOVEMENT (For Undo)
	var pre_sim_states = {}
	for w in graph.agents:
		pre_sim_states[w.id] = _snapshot_agent(w)

	# B. Determine Simulation Length
	var max_ticks = 0
	for w in graph.agents:
		if w.active and w.steps > max_ticks:
			max_ticks = w.steps
			
	var effective_starts = {} 
	for w in graph.agents:
		effective_starts[w.id] = w.current_node_id if w.current_node_id != "" else ""
	
	var grid_spacing = GraphSettings.GRID_SPACING
	var merge = params.get("merge_overlaps", true)
	
	# C. Main Loop
	for tick in range(max_ticks):
		for w in graph.agents:
			if w.active and tick < w.steps:
				var visited_id = ""
				if w.mode == 0: # Grow
					visited_id = w.step_grow(graph, grid_spacing, merge)
				else: # Paint
					visited_id = w.step_paint(graph, false, _session_path)
				
				if visited_id != "":
					_session_path.append(visited_id)
					if effective_starts.has(w.id) and effective_starts[w.id] == "":
						effective_starts[w.id] = visited_id
	
	# D. SNAPSHOT AFTER MOVEMENT (For Undo)
	for w in graph.agents:
		if not pre_sim_states.has(w.id): continue
		
		var start_state = pre_sim_states[w.id]
		var end_state = _snapshot_agent(w)
		
		if start_state.hash() != end_state.hash():
			var cmd = CmdUpdateAgent.new(graph, w, start_state, end_state)
			if "recorded_commands" in graph:
				graph.recorded_commands.append(cmd)

	# ==============================================================================
	# 4. COMPILE OUTPUT
	# ==============================================================================
	var start_ids = []
	for uid in effective_starts:
		if effective_starts[uid] != "": start_ids.append(effective_starts[uid])
	
	var head_ids = []
	for w in graph.agents:
		if w.current_node_id != "": head_ids.append(w.current_node_id)
			
	params["out_highlight_nodes"] = _session_path.duplicate()
	params["out_start_nodes"] = start_ids
	params["out_head_nodes"] = head_ids


# --- VISUALIZATION API ---

func get_all_agent_positions(graph: Graph) -> Array[String]:
	var list: Array[String] = []
	for w in graph.agents:
		if w.current_node_id != "": list.append(w.current_node_id)
	return list

func get_all_agent_starts(graph: Graph) -> Array[String]:
	var list: Array[String] = []
	for w in graph.agents:
		if w.start_node_id != "": list.append(w.start_node_id)
	return list

# [UPDATED] Delegated to Graph
func get_walkers_at_node(node_id: String, graph: Graph) -> Array:
	return graph.get_agents_at_node(node_id)

# --- INTERNAL HELPERS ---

func _snapshot_agent(agent) -> Dictionary:
	return {
		"pos": agent.pos,
		"node_id": agent.current_node_id,
		"step_count": agent.step_count, 
		"history": agent.history.duplicate(),
		"active": agent.active
	}

func _spawn_initial_population(graph: GraphRecorder, count: int, params: Dictionary, manual_pos: Vector2 = Vector2.INF) -> void:
	
	var force_pos = manual_pos
	if force_pos != Vector2.INF:
		force_pos = force_pos.snapped(GraphSettings.GRID_SPACING)

	# 1. Determine Root Pos & ID
	var root_pos = Vector2.ZERO
	var root_id = ""
	
	if graph.nodes.is_empty() or force_pos != Vector2.INF:
		if force_pos != Vector2.INF: root_pos = force_pos
		
		var existing_id = graph.get_node_at_position(root_pos, -1.0)
		if not existing_id.is_empty():
			root_id = existing_id
			root_pos = graph.get_node_pos(existing_id)
		else:
			root_id = "start_0"
			if force_pos != Vector2.INF:
				root_id = "start_man_%d_%d" % [int(root_pos.x), int(root_pos.y)]
			
			if not graph.nodes.has(root_id):
				graph.add_node(root_id, root_pos)
				
	else:
		var keys = graph.nodes.keys()
		root_id = keys[randi() % keys.size()]
		root_pos = graph.get_node_pos(root_id)

	# 2. Extract Settings
	var template = AgentWalker.get_template_settings()
	var default_steps = int(params.get("steps", 50))
	var default_paint = 2 
	
	# 3. Spawn Agents
	for i in range(count):
		# Random start logic (if multiple)
		if force_pos == Vector2.INF and not graph.nodes.is_empty() and i > 0:
			var keys = graph.nodes.keys()
			root_id = keys[randi() % keys.size()]
			root_pos = graph.get_node_pos(root_id)
		
		var agent = AgentWalker.new(i, root_pos, root_id, default_paint, default_steps)
		
		for setting in template:
			var key = setting.name
			if params.has(key):
				agent.apply_setting(key, params[key])
				
		graph.add_agent(agent)
	
	print("StrategyWalker: Spawned %d agents via Graph." % count)
