class_name StrategyWalker
extends GraphStrategy

# --- DATA ---
var _walkers: Array[AgentWalker] = []
var _session_path: Array[String] = []

func _init() -> void:
	strategy_name = "Agent Simulation" 
	reset_on_generate = false # [IMPORTANT] We manage resets manually now
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
		{ "name": "steps", "type": TYPE_INT, "default": 50, "min": 1, "max": 500, "hint": "Steps to take per Generate click." },
		{ "name": "snap_to_grid", "type": TYPE_BOOL, "default": false, "hint": "If true, NEW walkers align to global grid." },
		
		{ "name": "branch_randomly", "type": TYPE_BOOL, "default": false, "hint": "If true, walkers branch path." },
		{ "name": "action_clear_all", "type": TYPE_BOOL, "hint": "action", "label": "Clear All Agents" },
	]

# --- PUBLIC API ---

func add_agent_at_node(node_id: String, graph: Graph) -> void:
	if node_id == "" or not graph.nodes.has(node_id):
		return
		
	var pos = graph.get_node_pos(node_id)
	var new_id = _walkers.size()
	
	var agent = AgentWalker.new(new_id, pos, node_id, 2, 50)
	_walkers.append(agent)
	print("StrategyWalker: Manual Agent Spawned at %s" % node_id)

# Helper for the Controllers
func clear_agents() -> void:
	_walkers.clear()

func remove_agent(agent: AgentWalker) -> void:
	_walkers.erase(agent)

# --- EXECUTION ---

func execute(graph: GraphRecorder, params: Dictionary) -> void:
	_session_path.clear()
	
	if _walkers.is_empty():
		var target_count = int(params.get("count", 1))
		# Check for 0 count
		if target_count == 0:
			print("StrategyWalker: Count is 0. No agents spawned.")
			# Clear output params so the visualizer doesn't freak out
			params["out_highlight_nodes"] = []
			params["out_start_nodes"] = []
			params["out_head_nodes"] = []
			return

		var default_mode = params.get("mode", 0)
		var default_steps = int(params.get("steps", 50))
		var paint_idx = int(params.get("paint_type", 0))
		var default_snap = params.get("snap_to_grid", false) # [NEW]
		
		var ids = GraphSettings.current_names.keys()
		ids.sort()
		var default_paint = 2
		if paint_idx >= 0 and paint_idx < ids.size(): default_paint = ids[paint_idx]
		
		_spawn_initial_population(graph, target_count, default_mode, default_steps, default_paint, default_snap)
		
	
	# 2. RUN SIMULATION
	# Calculate simulation length based on the most ambitious agent
	var max_ticks = 0
	for w in _walkers:
		if w.active and w.steps_per_round > max_ticks:
			max_ticks = w.steps_per_round
			
	# Capture "Effective Starts" for visualization
	var effective_starts = {} 
	for w in _walkers:
		if w.current_node_id != "":
			effective_starts[w.id] = w.current_node_id
		else:
			effective_starts[w.id] = ""

	# Simulation Loop
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
					# Late Binding Start Logic
					if effective_starts.has(w.id) and effective_starts[w.id] == "":
						effective_starts[w.id] = visited_id

	# 3. COMPILE OUTPUT
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

# --- VISUALIZATION API ---
func get_all_agent_positions() -> Array[String]:
	var list: Array[String] = []
	for w in _walkers:
		if w.current_node_id != "":
			list.append(w.current_node_id)
	return list

func get_all_agent_starts() -> Array[String]:
	var list: Array[String] = []
	for w in _walkers:
		if w.start_node_id != "":
			list.append(w.start_node_id)
	return list

func _spawn_initial_population(graph: GraphRecorder, count: int, mode: int, steps: int, paint_type: int, snap: bool) -> void:
	if graph.nodes.is_empty():
		return 
		
	var keys = graph.nodes.keys()
	
	for i in range(count):
		var rnd_node = keys[randi() % keys.size()]
		var pos = graph.get_node_pos(rnd_node)
		
		var agent = AgentWalker.new(i, pos, rnd_node, paint_type, steps)
		agent.mode = mode
		agent.snap_to_grid = snap # [NEW]
		_walkers.append(agent)
	
	print("StrategyWalker: Auto-Spawned %d agents." % count)

func get_walkers_at_node(node_id: String) -> Array:
	var found = []
	for w in _walkers:
		if w.current_node_id == node_id:
			found.append(w)
	return found
