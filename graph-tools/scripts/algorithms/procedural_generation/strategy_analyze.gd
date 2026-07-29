class_name StrategyAnalyze
extends GraphStrategy

func _init() -> void:
	strategy_name = "Analyze Rooms"
	# Analyzer: Decorator that runs on existing nodes.
	reset_on_generate = false 
	# [SEED FIX] Initialize local RNG
	rng = RandomNumberGenerator.new()

func get_settings() -> Array[Dictionary]:
	# [SEED FIX] Inherit the base settings (the Seed Box)
	var settings: Array[Dictionary] = super.get_settings()
	
	settings.append({ 
		"name": "auto_assign_types", 
		"type": TYPE_BOOL, 
		"default": true,
		"hint": GraphSettings.PARAM_TOOLTIPS.analyze.auto
	})
	
	return settings

func execute(recorder: GraphRecorder, params: Dictionary) -> void:
	# [SEED FIX] Setup Deterministic State for this run
	var raw_seed = params.get("strategy_seed", "")
	if raw_seed != "":
		my_seed = SeedUtils.hash_seed(raw_seed)
		rng.seed = my_seed
	else:
		rng.randomize() 
		my_seed = rng.seed

	# 1. Extract Params
	var auto_types = params.get("auto_assign_types", true)
	
	if recorder.nodes.is_empty():
		return

	# 1. FIND SPAWN (Start Node)
	var start_id = _find_closest_to_center(recorder)
	
	# 2. CALCULATE DEPTH (BFS)
	var queue: Array = [start_id]
	var visited: Dictionary = { start_id: true }
	var depths: Dictionary = { start_id: 0 }
	
	var max_depth_id = start_id
	var max_depth_val = 0
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var current_depth = depths[current]
		
		# Track max depth (for Boss placement)
		if current_depth > max_depth_val:
			max_depth_val = current_depth
			max_depth_id = current
		
		# Write Depth to Simulation Node (safe, but transient)
		var current_node = recorder.nodes[current] as NodeData
		if current_node:
			current_node.set_data("depth", current_depth)
		
		# Get neighbors 
		for neighbor in recorder.get_neighbors(current):
			if not visited.has(neighbor):
				visited[neighbor] = true
				depths[neighbor] = current_depth + 1
				queue.append(neighbor)

	# 3. ASSIGN SHAPES & TYPES
	for id: String in recorder.nodes:
		var node = recorder.nodes[id] as NodeData
		if not node: continue
			
		var neighbor_count = recorder.get_neighbors(id).size()
		
		# A. Assign Shape (Simulation Only for now)
		match neighbor_count:
			0: node.shape = NodeData.RoomShape.CLOSED
			1: node.shape = NodeData.RoomShape.DEAD_END
			2: node.shape = NodeData.RoomShape.CORRIDOR
			3: node.shape = NodeData.RoomShape.THREE_WAY
			4: node.shape = NodeData.RoomShape.FOUR_WAY
			_: node.shape = NodeData.RoomShape.FOUR_WAY 

		# B. Assign Type (Recorded via Command)
		if auto_types:
			var new_type = NodeData.RoomType.EMPTY
			
			if id == start_id:
				new_type = NodeData.RoomType.SPAWN
			elif id == max_depth_id:
				new_type = NodeData.RoomType.BOSS
			elif neighbor_count == 1 and node.get_data("depth", 0) > 2:
				# [SEED FIX] Use deterministic RNG for room contents
				if rng.randf() < 0.3:
					new_type = NodeData.RoomType.TREASURE
				else:
					new_type = NodeData.RoomType.ENEMY
			
			if node.type != new_type:
				recorder.set_node_type(id, new_type)

# --- Helper ---
func _find_closest_to_center(graph: Graph) -> String:
	var best_id = ""
	var min_dist = INF
	
	for id in graph.nodes:
		var dist = graph.nodes[id].position.length_squared()
		if dist < min_dist:
			min_dist = dist
			best_id = id
			
	return best_id
