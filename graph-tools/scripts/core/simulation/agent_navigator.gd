class_name AgentNavigator
extends RefCounted

# --- ENUMS (Must match UI Dropdown Indices) ---
enum Algo {
	RANDOM = 0,
	BFS = 1,
	DFS = 2,
	ASTAR = 3
}

# --- PUBLIC API ---

# 1. Used by the Agent to Move (Returns Node ID)
static func get_next_step(current_id: String, target_id: String, algo: int, graph: Graph) -> String:
	if current_id == target_id or not graph.nodes.has(current_id):
		return ""

	match algo:
		Algo.RANDOM:
			return _solve_random(current_id, graph)
		Algo.BFS:
			var path = _solve_bfs_full(current_id, target_id, graph)
			if path.size() > 1: return path[1] # [0] is current, [1] is next
		Algo.DFS:
			var path = _solve_dfs_full(current_id, target_id, graph)
			if path.size() > 1: return path[1]
		Algo.ASTAR:
			# Use the optimized graph function for A*
			var path = graph.get_astar_path(current_id, target_id)
			if path.size() > 1: return path[1]
			
	return ""

# 2. Used by the Editor to Draw Lines (Returns Array of IDs)
static func get_projected_path(current_id: String, target_id: String, algo: int, graph: Graph) -> Array[String]:
	if current_id == target_id or target_id == "" or not graph.nodes.has(current_id):
		return []

	match algo:
		Algo.RANDOM:
			return [] # Random has no projected path (we draw yellow arrows instead)
		Algo.BFS:
			return _solve_bfs_full(current_id, target_id, graph)
		Algo.DFS:
			return _solve_dfs_full(current_id, target_id, graph)
		Algo.ASTAR:
			return graph.get_astar_path(current_id, target_id)
			
	return []

# --- ALGORITHMS ---

static func _solve_random(current_id: String, graph: Graph) -> String:
	var neighbors = graph.get_neighbors(current_id)
	if neighbors.is_empty(): return ""
	return neighbors.pick_random()

# --- FULL PATH SOLVERS ---

# Breadth-First Search (Shortest path in unweighted graph)
static func _solve_bfs_full(start_id: String, target_id: String, graph: Graph) -> Array[String]:
	if start_id == target_id: return []
	
	var queue = [start_id]
	var visited = { start_id: true }
	var parent = {} # To reconstruct path
	
	while not queue.is_empty():
		var current = queue.pop_front()
		
		# Found Target! Reconstruct and return the full chain.
		if current == target_id:
			return _reconstruct_full_path(parent, target_id)
		
		for next in graph.get_neighbors(current):
			if not visited.has(next):
				visited[next] = true
				parent[next] = current
				queue.append(next)
				
	return [] # No path found

# Depth-First Search (Wanders deep)
static func _solve_dfs_full(start_id: String, target_id: String, graph: Graph) -> Array[String]:
	var stack = [start_id]
	var visited = { start_id: true }
	var parent = {}
	
	while not stack.is_empty():
		var current = stack.pop_back()
		
		if current == target_id:
			return _reconstruct_full_path(parent, target_id)
		
		var neighbors = graph.get_neighbors(current)
		
		# NOTE: We keep standard order here to match the visualization.
		# If you shuffle neighbors here, the "Ghost Line" will flicker 
		# every frame because DFS is sensitive to order.
		for next in neighbors:
			if not visited.has(next):
				visited[next] = true
				parent[next] = current
				stack.append(next)
				
	return []

# --- HELPERS ---

# Reconstructs the entire path array [Start, A, B, ... End]
static func _reconstruct_full_path(parent_map: Dictionary, end: String) -> Array[String]:
	var path: Array[String] = []
	var curr = end
	
	# Backtrack from end to start
	while curr != null:
		path.append(curr)
		curr = parent_map.get(curr) # Returns null if key missing
	
	path.reverse() # Flip to be Start -> End
	return path


# --- SAFETY & PHYSICS ---

# Centralized check for Zone restrictions (Terrain, Walls, etc.)
static func is_move_safe(graph: Graph, target_id: String) -> bool:
	if not graph.zones: return true
	
	for zone in graph.zones:
		# We only collide with GEOGRAPHICAL zones (Terrain/Walls)
		if zone.zone_type == GraphZone.ZoneType.GEOGRAPHICAL:
			# If the target node is inside this zone, it's blocked.
			if zone.contains_node(target_id):
				return false
	
	return true
