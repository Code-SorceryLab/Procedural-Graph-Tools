class_name StrategyWalker
extends GraphStrategy

# --- DATA ---
var _walkers: Array[AgentWalker] = []
var _session_path: Array[String] = []

func _init() -> void:
	strategy_name = "Walker Agents"
	reset_on_generate = false 
	supports_grow = true

# --- SETTINGS UI ---
func get_settings() -> Array[Dictionary]:
	# [FIX] Explicitly type this array so Godot knows it matches the return type
	var settings: Array[Dictionary] = [
		{ "name": "count", "type": TYPE_INT, "default": 1, "min": 0, "max": 10, "hint": "How many to spawn IF the board is empty." },
	]
	
	# 2. Agent Template Settings (Imported from Source of Truth)
	settings.append_array(AgentWalker.get_template_settings())
	
	# 3. Strategy Overrides
	settings.append_array([
		{ "name": "use_override_pos", "type": TYPE_BOOL, "default": false, "label": "Use Manual Start", "hint": "If checked, forces spawn at the coordinates below." },
		{ "name": "start_pos", "type": TYPE_VECTOR2, "default": Vector2.ZERO, "label": "Start Position", "hint": "Coordinates to spawn at (if 'Use Manual Start' is on)." },
		{ "name": "action_clear_all", "type": TYPE_BOOL, "hint": "action", "label": "Clear All Agents" },
	])
	
	return settings

# --- PUBLIC API ---
func add_agent_at_node(node_id: String, graph: Graph) -> void:
	if node_id == "" or not graph.nodes.has(node_id): return
	var pos = graph.get_node_pos(node_id)
	var new_id = _walkers.size()
	
	# Default settings for manual spawn
	var agent = AgentWalker.new(new_id, pos, node_id, 2, 50)
	_walkers.append(agent)
	print("StrategyWalker: Manual Agent Spawned at %s" % node_id)

func clear_agents() -> void: _walkers.clear()
func remove_agent(agent: AgentWalker) -> void: _walkers.erase(agent)

# --- EXECUTION ---
func execute(graph: GraphRecorder, params: Dictionary) -> void:
	_session_path.clear()
	
	# 1. Spawn Population if needed
	if _walkers.is_empty():
		var target_count = int(params.get("count", 1))
		if target_count == 0:
			params["out_highlight_nodes"] = []; params["out_start_nodes"] = []; params["out_head_nodes"] = []
			return
		
		var manual_start = Vector2.INF
		if params.get("use_override_pos", false):
			manual_start = params.get("start_pos", Vector2.ZERO)
		
		# Pass the entire params dictionary so the spawner can extract agent settings
		_spawn_initial_population(graph, target_count, params, manual_start)
		
	
	# 2. RUN SIMULATION
	var max_ticks = 0
	for w in _walkers:
		# Update Max Ticks based on variable agent steps
		if w.active and w.steps > max_ticks:
			max_ticks = w.steps
			
	var effective_starts = {} 
	for w in _walkers:
		effective_starts[w.id] = w.current_node_id if w.current_node_id != "" else ""
	
	var grid_spacing = GraphSettings.GRID_SPACING
	var merge = params.get("merge_overlaps", true)
	
	# Note: 'branch_randomly' is now inside the agent, so we don't pass it globally
	
	for tick in range(max_ticks):
		for w in _walkers:
			if w.active and tick < w.steps:
				var visited_id = ""
				if w.mode == 0: # Grow
					visited_id = w.step_grow(graph, grid_spacing, merge)
				else: # Paint
					# Pass dummy bool for branch since agent uses internal var now
					visited_id = w.step_paint(graph, false, _session_path)
				
				if visited_id != "":
					_session_path.append(visited_id)
					if effective_starts.has(w.id) and effective_starts[w.id] == "":
						effective_starts[w.id] = visited_id
	
	# 3. COMPILE OUTPUT
	var start_ids = []
	for uid in effective_starts:
		if effective_starts[uid] != "": start_ids.append(effective_starts[uid])
	
	var head_ids = []
	for w in _walkers:
		if w.current_node_id != "": head_ids.append(w.current_node_id)
			
	params["out_highlight_nodes"] = _session_path.duplicate()
	params["out_start_nodes"] = start_ids
	params["out_head_nodes"] = head_ids

# --- VISUALIZATION API ---
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

# --- SPAWN LOGIC ---
func _spawn_initial_population(graph: GraphRecorder, count: int, params: Dictionary, manual_pos: Vector2 = Vector2.INF) -> void:
	
	var force_pos = manual_pos
	if force_pos != Vector2.INF:
		force_pos = force_pos.snapped(GraphSettings.GRID_SPACING)

	# 1. Determine Root Pos & ID
	var root_pos = Vector2.ZERO
	var root_id = ""
	
	if graph.nodes.is_empty() or force_pos != Vector2.INF:
		if force_pos != Vector2.INF: root_pos = force_pos
		
		# Check for existing node
		var existing_id = graph.get_node_at_position(root_pos, -1.0)
		if not existing_id.is_empty():
			root_id = existing_id
			root_pos = graph.get_node_pos(existing_id)
		else:
			# Create new start node
			root_id = "start_0"
			if force_pos != Vector2.INF:
				root_id = "start_man_%d_%d" % [int(root_pos.x), int(root_pos.y)]
			
			if not graph.nodes.has(root_id):
				graph.add_node(root_id, root_pos)
				
	else:
		# Random Start
		var keys = graph.nodes.keys()
		root_id = keys[randi() % keys.size()]
		root_pos = graph.get_node_pos(root_id)

	# 2. Extract Agent Settings from Strategy Params
	# We use the template keys to pull values from the params dictionary
	var template = AgentWalker.get_template_settings()
	
	# 3. Spawn Agents
	for i in range(count):
		# If random start, pick a new node for each agent
		if force_pos == Vector2.INF and not graph.nodes.is_empty() and i > 0:
			var keys = graph.nodes.keys()
			root_id = keys[randi() % keys.size()]
			root_pos = graph.get_node_pos(root_id)
			
		# Initialize Agent
		# Note: We pass defaults, then apply overrides
		var default_steps = int(params.get("steps", 50))
		var default_paint = 2 # Fallback
		
		var agent = AgentWalker.new(i, root_pos, root_id, default_paint, default_steps)
		
		# Apply all settings from params to agent
		for setting in template:
			var key = setting.name
			if params.has(key):
				agent.apply_setting(key, params[key])
				
		_walkers.append(agent)
	
	print("StrategyWalker: Spawned %d agents." % count)
