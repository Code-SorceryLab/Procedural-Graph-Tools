extends GraphStrategy
class_name StrategyAnalyze

func _init() -> void:
	strategy_name = "Analyze Rooms"
	required_params = [] 
	toggle_text = "Auto-Assign Types"
	toggle_key = "auto_types"

func execute(graph: Graph, params: Dictionary) -> void:
	var auto_types = params.get("auto_types", false)
	
	if graph.nodes.is_empty():
		return

	# 1. FIND SPAWN (Start Node)
	# Find node closest to 0,0
	var start_id = _find_closest_to_center(graph)
	
	# 2. CALCULATE DEPTH (BFS)
	var queue: Array = [start_id]
	var visited: Dictionary = { start_id: true }
	var depths: Dictionary = { start_id: 0 }
	var max_depth_id = start_id
	var max_depth_val = 0
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var current_depth = depths[current]
		
		# Track max depth
		if current_depth > max_depth_val:
			max_depth_val = current_depth
			max_depth_id = current
		
		# Write Depth to NodeData
		# Note: We access the NodeData resource directly
		if graph.nodes[current] is NodeData:
			graph.nodes[current].depth = current_depth
		
		# Get neighbors
		for neighbor in graph.get_neighbors(current):
			if not visited.has(neighbor):
				visited[neighbor] = true
				depths[neighbor] = current_depth + 1
				queue.append(neighbor)

	# 3. ASSIGN SHAPES & TYPES
	for id: String in graph.nodes:
		var node = graph.nodes[id] as NodeData
		if not node: continue
			
		var neighbor_count = graph.get_neighbors(id).size()
		
		# A. Assign Shape based on topology
		match neighbor_count:
			0: node.shape = NodeData.RoomShape.CLOSED
			1: node.shape = NodeData.RoomShape.DEAD_END
			2: node.shape = NodeData.RoomShape.CORRIDOR
			3: node.shape = NodeData.RoomShape.THREE_WAY
			4: node.shape = NodeData.RoomShape.FOUR_WAY
			_: node.shape = NodeData.RoomShape.FOUR_WAY 

		# B. Assign Type (Simple Rules)
		if auto_types:
			# Reset to empty first so we don't have lingering data
			node.type = NodeData.RoomType.EMPTY
			
			if id == start_id:
				node.type = NodeData.RoomType.SPAWN
			elif id == max_depth_id:
				node.type = NodeData.RoomType.BOSS
			elif neighbor_count == 1 and node.depth > 2:
				# Dead ends far from spawn might be Treasure or Enemy
				if randf() < 0.3:
					node.type = NodeData.RoomType.TREASURE
				else:
					node.type = NodeData.RoomType.ENEMY

# --- Helper ---
func _find_closest_to_center(graph: Graph) -> String:
	var best_id = ""
	var min_dist = INF
	for id in graph.nodes:
		var dist = graph.get_node_pos(id).length_squared()
		if dist < min_dist:
			min_dist = dist
			best_id = id
	return best_id
