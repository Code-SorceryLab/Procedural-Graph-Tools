class_name StrategyWalker
extends GraphStrategy

# --- DATA ---
var _session_path: Array[String] = []

func _init() -> void:
	strategy_name = "Walker Agents"
	reset_on_generate = false 
	supports_grow = true
	supports_agents = true

# --- SETTINGS UI ---
func get_settings() -> Array[Dictionary]:
	var settings: Array[Dictionary] = []
	
	# 1. Basic Spawning Settings
	settings.append({ 
		"name": "count", 
		"type": TYPE_INT, 
		"default": 1, 
		"min": 0, "max": 10, 
		"hint": "How many to spawn IF the board is empty." 
	})
	
	settings.append({ 
		"name": "action_pick_node", 
		"type": TYPE_BOOL, 
		"hint": "action", 
		"label": "Pick Start Node" 
	})
	
	settings.append({ 
		"name": "start_pos_node", 
		"type": TYPE_STRING, 
		"default": "", 
		"label": "Start Node ID",
		"hint": "Agents will spawn here. Leave empty for random start."
	})
	
	# 2. Agent Template Settings (With Advanced Filters)
	var raw_template = AgentWalker.get_template_settings()
	
	for s in raw_template:
		var item = s.duplicate()
		
		# Define what is "Advanced" (Hidden by default)
		if item.name in ["movement_algo", "target_node", "active", "snap_to_grid"]:
			item["advanced"] = true
			
		# Enforce Defaults for Generator Feel
		if item.name == "global_behavior":
			item.default = 2 # Default to Grow (was 0/Hold)
		if item.name == "snap_to_grid":
			item.default = true
			
		settings.append(item)
	
	# 3. Strategy Actions
	settings.append({ 
		"name": "action_clear_all", 
		"type": TYPE_BOOL, 
		"hint": "action", 
		"label": "Clear All Agents" 
	})
	
	return settings

# --- PUBLIC API ---

func create_agent_for_node(node_id: String, graph: Graph) -> AgentWalker:
	if node_id == "" or not graph.nodes.has(node_id): 
		return null
		
	var pos = graph.get_node_pos(node_id)
	var new_id = graph.agents.size()
	
	var agent = AgentWalker.new(new_id, pos, node_id, 2, 50)
	agent.apply_template_defaults()
	
	return agent

# --- EXECUTION ---
func execute(graph: GraphRecorder, params: Dictionary) -> void:
	_session_path.clear()
	
	# 1. Handle "Clear All" Action
	if params.get("action_clear_all", false):
		graph.agents.clear()
		return
	
	# 2. [NEW] HANDLE "SPAWN ONLY" ACTION
	if params.get("spawn_only", false):
		var target_count = int(params.get("count", 1))
		var start_node = params.get("start_pos_node", "")
		
		# This helper handles creating the "start_0" node if the graph is empty
		_spawn_initial_population(graph, target_count, params, start_node)
		return # <--- EXIT HERE (Do not run simulation)

	# 3. STANDARD EXECUTION (Spawn if empty, then Run)
	var step_budget = int(params.get("steps", 50))
	
	if graph.agents.is_empty():
		# Auto-Spawn if board is empty and we hit "Generate"
		var target_count = int(params.get("count", 1))
		if target_count > 0:
			var start_node = params.get("start_pos_node", "")
			_spawn_initial_population(graph, target_count, params, start_node)
	else:
		# Extend existing agents
		for agent in graph.agents:
			if agent.active:
				agent.steps += step_budget
				agent.is_finished = false
				if agent.branch_randomly:
					_teleport_to_random_branch_point(graph, agent)
	
	# ==============================================================================
	# 4. RUN SIMULATION (Instant Mode)
	# ==============================================================================
	
	# A. SNAPSHOT BEFORE MOVEMENT
	var pre_sim_states = {}
	for w in graph.agents:
		pre_sim_states[w.id] = _snapshot_agent(w)

	# B. Determine Max Ticks needed (We use the budget we just set/added)
	var max_ticks = 0
	for w in graph.agents:
		if w.active and w.steps > max_ticks:
			max_ticks = w.steps
			
	var effective_starts = {} 
	for w in graph.agents:
		effective_starts[w.id] = w.current_node_id
	
	# C. Main Loop
	for tick in range(max_ticks):
		for w in graph.agents:
			if w.active and not w.is_finished and w.step_count < w.steps:
				
				# Hardcode 'merge_overlaps' to true for the Generator Strategy
				var step_params = params.duplicate()
				step_params["merge_overlaps"] = true
				
				w.step(graph, step_params)
				
				var visited_id = w.current_node_id
				if visited_id != "":
					_session_path.append(visited_id)
					if effective_starts[w.id] == "":
						effective_starts[w.id] = visited_id
	
	# D. SNAPSHOT AFTER MOVEMENT
	for w in graph.agents:
		if not pre_sim_states.has(w.id): continue
		var start_state = pre_sim_states[w.id]
		var end_state = _snapshot_agent(w)
		
		if start_state.hash() != end_state.hash():
			var cmd = CmdUpdateAgent.new(graph, w, start_state, end_state)
			if "recorded_commands" in graph:
				graph.recorded_commands.append(cmd)

	# ==============================================================================
	# 5. COMPILE OUTPUT
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

# --- INTERNAL HELPERS ---

func _snapshot_agent(agent) -> Dictionary:
	return {
		"pos": agent.pos,
		"node_id": agent.current_node_id,
		"step_count": agent.step_count, 
		"history": agent.history.duplicate(),
		"active": agent.active,
		"is_finished": agent.is_finished
	}

func _spawn_initial_population(graph: GraphRecorder, count: int, params: Dictionary, force_node_id: String = "") -> void:
	
	# 1. Determine Root ID/Pos
	var root_id = force_node_id
	var root_pos = Vector2.ZERO
	
	# If no specific node picked, pick random or create origin
	if root_id == "" or not graph.nodes.has(root_id):
		if not graph.nodes.is_empty():
			var keys = graph.nodes.keys()
			root_id = keys[randi() % keys.size()]
		else:
			root_id = "start_0"
			
		if not graph.nodes.has(root_id):
			graph.add_node(root_id, Vector2.ZERO)
			
	root_pos = graph.get_node_pos(root_id)

	# 2. Extract Settings
	var template = AgentWalker.get_template_settings()
	var default_steps = int(params.get("steps", 50))
	var default_paint = 2 
	
	# 3. Spawn Agents
	for i in range(count):
		# Random start logic (if multiple and no forced start)
		if force_node_id == "" and not graph.nodes.is_empty() and i > 0:
			var keys = graph.nodes.keys()
			root_id = keys[randi() % keys.size()]
			root_pos = graph.get_node_pos(root_id)
		
		var agent = AgentWalker.new(i, root_pos, root_id, default_paint, default_steps)
		
		for setting in template:
			var key = setting.name
			if params.has(key):
				agent.apply_setting(key, params[key])
				
		graph.add_agent(agent)
	
	print("StrategyWalker: Spawned %d agents." % count)

func _teleport_to_random_branch_point(graph: Graph, agent: AgentWalker) -> void:
	if graph.nodes.is_empty(): return
	
	# Pick a random existing node to start a new branch
	var all_nodes = graph.nodes.keys()
	var branch_id = all_nodes.pick_random()
	var branch_pos = graph.get_node_pos(branch_id)
	
	agent.warp(branch_pos, branch_id)
	# Important: Add a history entry so logic that checks "last node" works
	agent.history.append({ "node": branch_id, "step": agent.step_count })
