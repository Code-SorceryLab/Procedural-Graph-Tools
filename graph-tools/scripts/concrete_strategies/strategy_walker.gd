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
		"label": "Pick Start Node (Random)" 
	})
	
	settings.append({ 
		"name": "start_pos_node", 
		"type": TYPE_STRING, 
		"default": "", 
		"label": "Start Node ID",
		"hint": "Agents will spawn here. Leave empty for random start.",
		"advanced": true 
	})
	
	# 2. Agent Template Settings (With Advanced Filters)
	var raw_template = AgentWalker.get_template_settings()
	
	for s in raw_template:
		# Skip obsolete merge toggle
		if s.name == "merge_overlaps": continue 
		
		var item = s.duplicate()
		
		# Inject Picker Button for Target Node
		if item.name == "target_node":
			settings.append({
				"name": "action_pick_target",
				"type": TYPE_BOOL,
				"hint": "action",
				"label": "Pick Target Node",
				"advanced": true 
			})
			item["advanced"] = true
			item["label"] = "Target Node ID"

		elif item.name in ["movement_algo", "active", "snap_to_grid"]:
			item["advanced"] = true
			
		if item.name == "global_behavior":
			item.default = 2 
		if item.name == "snap_to_grid":
			item.default = true
			
		settings.append(item)
	
	return settings

# --- PUBLIC API ---

func create_agent_for_node(node_id: String, graph: Graph) -> AgentWalker:
	if node_id == "" or not graph.nodes.has(node_id): 
		return null
		
	var pos = graph.get_node_pos(node_id)
	
	# [FIX] Use helper to generate IDs
	var ids = _generate_identity(graph)
	
	# 3. Create Agent with 6 arguments
	var agent = AgentWalker.new(ids.uuid, ids.display_id, pos, node_id, 2, 50)
	
	agent.apply_template_defaults()
	return agent

# --- EXECUTION ---
func execute(graph: GraphRecorder, params: Dictionary) -> void:
	_session_path.clear()
	
	# 1. HANDLE "SPAWN ONLY" ACTION
	if params.get("spawn_only", false):
		var target_count = int(params.get("count", 1))
		var start_node = params.get("start_pos_node", "")
		_spawn_initial_population(graph, target_count, params, start_node)
		return 

	# 2. STANDARD EXECUTION
	var step_budget = int(params.get("steps", 50))
	
	if graph.agents.is_empty():
		var target_count = int(params.get("count", 1))
		if target_count > 0:
			var start_node = params.get("start_pos_node", "")
			_spawn_initial_population(graph, target_count, params, start_node)
	else:
		for agent in graph.agents:
			if agent.active:
				agent.steps += step_budget
				agent.is_finished = false
				if agent.branch_randomly:
					_teleport_to_random_branch_point(graph, agent)
	
	# 3. RUN SIMULATION
	var pre_sim_states = {}
	for w in graph.agents:
		pre_sim_states[w.id] = _snapshot_agent(w)

	var max_ticks = 0
	for w in graph.agents:
		if w.active and w.steps > max_ticks:
			max_ticks = w.steps
			
	var effective_starts = {} 
	for w in graph.agents:
		effective_starts[w.id] = w.current_node_id
	
	for tick in range(max_ticks):
		for w in graph.agents:
			if w.active and not w.is_finished and w.step_count < w.steps:
				var step_params = params.duplicate()
				step_params["merge_overlaps"] = true
				
				w.step(graph, step_params)
				
				var visited_id = w.current_node_id
				if visited_id != "":
					_session_path.append(visited_id)
					if effective_starts[w.id] == "":
						effective_starts[w.id] = visited_id
	
	# SNAPSHOT AFTER MOVEMENT
	for w in graph.agents:
		if not pre_sim_states.has(w.id): continue
		var start_state = pre_sim_states[w.id]
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

# ID GENERATION HELPER
# Returns Dictionary { "uuid": String, "display_id": int }
func _generate_identity(graph_context) -> Dictionary:
	var new_uuid = GraphSerializer.generate_uuid()
	var new_display_id = 1
	
	# Thanks to the fix in GraphRecorder, we can just call this directly.
	# It works for both Graph and GraphRecorder now.
	if graph_context.has_method("get_next_display_id"):
		new_display_id = graph_context.get_next_display_id()
	else:
		# Emergency Fallback
		var base = 0
		if "agents" in graph_context: base = graph_context.agents.size()
		new_display_id = base + 1 + (randi() % 9999)
		
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
	
	# 1. Determine Root ID/Pos
	var root_id = force_node_id
	var root_pos = Vector2.ZERO
	
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
		if force_node_id == "" and not graph.nodes.is_empty() and i > 0:
			var keys = graph.nodes.keys()
			root_id = keys[randi() % keys.size()]
			root_pos = graph.get_node_pos(root_id)
		
		# [FIX] Use Helper + New Constructor Signature
		var ids = _generate_identity(graph)
		var agent = AgentWalker.new(ids.uuid, ids.display_id, root_pos, root_id, default_paint, default_steps)
		
		for setting in template:
			var key = setting.name
			if params.has(key):
				agent.apply_setting(key, params[key])
				
		graph.add_agent(agent)
	
	print("StrategyWalker: Spawned %d agents." % count)

func _teleport_to_random_branch_point(graph: Graph, agent: AgentWalker) -> void:
	if graph.nodes.is_empty(): return
	var all_nodes = graph.nodes.keys()
	var branch_id = all_nodes.pick_random()
	var branch_pos = graph.get_node_pos(branch_id)
	agent.warp(branch_pos, branch_id)
	agent.history.append({ "node": branch_id, "step": agent.step_count })
