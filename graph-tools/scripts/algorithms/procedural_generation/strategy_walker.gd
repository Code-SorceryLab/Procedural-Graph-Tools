class_name StrategyWalker
extends GraphStrategy

# --- DATA ---
var _session_path: Array[String] = []

func _init() -> void:
	strategy_name = "Walker Agents"
	reset_on_generate = false 
	supports_grow = true
	supports_agents = true
	rng = RandomNumberGenerator.new()

# --- SETTINGS UI ---
func get_settings() -> Array[Dictionary]:
	var settings: Array[Dictionary] = []
	
	# [FIX 1] Safely copy the base settings to prevent array poisoning
	var base_settings: Array = super.get_settings()
	for b in base_settings:
		settings.append(b.duplicate(true))
	
	settings.append({ "name": "sep_spawn", "type": TYPE_NIL, "hint": "separator" })
	
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
		"label": "Pick Start Node (Random)",
		"hint_text": "Enables an interactive tool to click directly on the graph to assign the agent's starting location."
	})
	
	settings.append({ 
		"name": "start_pos_node", 
		"type": TYPE_STRING, 
		"default": "", 
		"label": "Start Node ID",
		"hint_text": "The exact unique identifier where the agent will spawn. Leave empty for a random start.",
		"advanced": true 
	})
	
	# 2. Agent Template Settings (With Advanced Filters)
	var raw_template = AgentWalker.get_template_settings()
	
	for s in raw_template:
		# [FIX 2] Use .get("name") instead of .name
		if s.get("name") == "merge_overlaps": continue 
		
		var item = s.duplicate(true)
		var i_name = item.get("name", "")
		
		if i_name == "target_node":
			settings.append({
				"name": "action_pick_target",
				"type": TYPE_BOOL,
				"hint": "action",
				"label": "Pick Target Node",
				"advanced": true,
				"hint_text": "Enables an interactive tool to click directly on the graph to assign this agent's destination."
			})
			item["advanced"] = true
			item["label"] = "Target Node ID"
		elif i_name == "use_geometric_fc":
			item["advanced"] = true
			item["label"] = "Forward Checking (Smart)"
			 
		elif i_name in ["movement_algo", "active", "snap_to_grid"]:
			item["advanced"] = true
			
		if i_name == "global_behavior":
			item["default"] = 2 
		if i_name == "snap_to_grid":
			item["default"] = true 
			
		settings.append(item)
	
	return settings

# --- PUBLIC API ---

func create_agent_for_node(node_id: String, graph: Graph) -> AgentWalker:
	if node_id == "" or not graph.nodes.has(node_id): 
		return null
		
	var pos = graph.get_node_pos(node_id)
	var ids = _generate_identity(graph)
	
	var agent = AgentWalker.new(ids.uuid, ids.display_id, pos, node_id, 2, 50)
	agent.apply_template_defaults()
	
	agent.set_seed(rng.randi()) 
	
	return agent

# --- EXECUTION ---
func execute(graph: GraphRecorder, params: Dictionary) -> void:
	_session_path.clear()
	
	# 0. Setup Deterministic State for this run
	var raw_seed = params.get("strategy_seed", "")
	if raw_seed != "":
		my_seed = SeedUtils.hash_seed(raw_seed)
		
		# [CRITICAL FIX] RNG Salting
		# If we click "Spawn" multiple times, we must alter the seed slightly based on 
		# how many agents already exist, otherwise we generate exact clones!
		var existing_agents = graph.agents.size() if "agents" in graph else 0
		if existing_agents > 0:
			rng.seed = hash(str(my_seed) + "_salt_" + str(existing_agents))
		else:
			rng.seed = my_seed
	else:
		rng.randomize() 
		my_seed = rng.seed

	# 1. HANDLE "SPAWN ONLY" ACTION
	if params.get("spawn_only", false):
		var target_count = int(params.get("count", 1))
		var start_node = params.get("start_pos_node", "")
		_spawn_initial_population(graph, target_count, params, start_node)
		return 

	# 2. STANDARD EXECUTION
	var step_budget = int(params.get("steps", 15))
	
	if graph.agents.is_empty():
		var target_count = int(params.get("count", 1))
		if target_count > 0:
			var start_node = params.get("start_pos_node", "")
			_spawn_initial_population(graph, target_count, params, start_node)
	else:
		for agent in graph.agents:
			if agent.active:
				if step_budget == -1:
					agent.steps = -1 
				elif agent.steps != -1:
					agent.steps += step_budget 
				
				agent.is_finished = false
				if agent.custom_data.get("branch_randomly", false):
					_teleport_to_random_branch_point(graph, agent)
	
	# 3. RUN SIMULATION
	var pre_sim_states = {}
	for w in graph.agents:
		pre_sim_states[w.uuid] = _snapshot_agent(w)

	var max_ticks = 0
	for w in graph.agents:
		if w.active:
			var effective_limit = w.steps
			if effective_limit == -1: 
				effective_limit = 100 
			
			if effective_limit > max_ticks:
				max_ticks = effective_limit
			
	var effective_starts = {} 
	for w in graph.agents:
		effective_starts[w.uuid] = w.current_node_id
	
	for tick in range(max_ticks):
		for w in graph.agents:
			if w.active and not w.is_finished and (w.steps == -1 or w.step_count < w.steps):
				var step_params = params.duplicate()
				step_params["merge_overlaps"] = true
				
				w.step(graph, step_params)
				
				var visited_id = w.current_node_id
				if visited_id != "":
					_session_path.append(visited_id)
					if effective_starts[w.uuid] == "":
						effective_starts[w.uuid] = visited_id
	
	# SNAPSHOT AFTER MOVEMENT
	for w in graph.agents:
		if not pre_sim_states.has(w.uuid): continue
		var start_state = pre_sim_states[w.uuid]
		var end_state = _snapshot_agent(w)
		
		if start_state.hash() != end_state.hash():
			var cmd = CmdUpdateAgent.new(graph, w, start_state, end_state)
			if "recorded_commands" in graph:
				graph.recorded_commands.append(cmd)

	# 4. COMPILE OUTPUT
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

func _generate_identity(graph_context) -> Dictionary:
	var new_uuid = GraphSerializer.generate_uuid()
	var new_display_id = 1
	
	if graph_context.has_method("get_next_display_id"):
		new_display_id = graph_context.get_next_display_id()
	else:
		var base = 0
		if "agents" in graph_context: base = graph_context.agents.size()
		new_display_id = base + 1 + (rng.randi() % 9999)
		
	return { "uuid": new_uuid, "display_id": new_display_id }

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
	var root_id = force_node_id
	var root_pos = Vector2.ZERO
	
	if root_id == "" or not graph.nodes.has(root_id):
		if not graph.nodes.is_empty():
			var keys = graph.nodes.keys()
			root_id = SeedUtils.pick_random(keys, rng)
		else:
			root_id = "start_0"
			
		if not graph.nodes.has(root_id):
			graph.add_node(root_id, Vector2.ZERO)
			
	root_pos = graph.get_node_pos(root_id)

	var template = AgentWalker.get_template_settings()
	var default_steps = int(params.get("steps", 50))
	var default_paint = 2 
	
	# [NEW] Check for manual agent seed from the UI
	var manual_agent_seed = params.get("agent_seed", "")
	
	for i in range(count):
		if force_node_id == "" and not graph.nodes.is_empty() and i > 0:
			var keys = graph.nodes.keys()
			root_id = SeedUtils.pick_random(keys, rng)
			root_pos = graph.get_node_pos(root_id)
		
		var ids = _generate_identity(graph)
		var agent = AgentWalker.new(ids.uuid, ids.display_id, root_pos, root_id, default_paint, default_steps)
		
		# [NEW] Seed Assignment Logic
		if manual_agent_seed != "":
			# Salt it with the loop index so if you set count=2 with a manual seed, 
			# they don't clone each other either.
			var salted = manual_agent_seed + "_" + str(i)
			agent.set_seed(SeedUtils.hash_seed(salted))
		else:
			agent.set_seed(rng.randi())
		
		for setting in template:
			var key = setting.get("name", "")
			if params.has(key):
				agent.apply_setting(key, params[key])
				
		graph.add_agent(agent)
	
	print("StrategyWalker: Spawned %d agents with Seed [%s]." % [count, str(my_seed)])

func _teleport_to_random_branch_point(graph: Graph, agent: AgentWalker) -> void:
	if graph.nodes.is_empty(): return
	var all_nodes = graph.nodes.keys()
	var branch_id = SeedUtils.pick_random(all_nodes, agent.rng)
	var branch_pos = graph.get_node_pos(branch_id)
	agent.warp(branch_pos, branch_id)
	agent.history.append({ "node": branch_id, "step": agent.step_count })
