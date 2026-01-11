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

static func get_next_step(current_id: String, target_id: String, algo: int, graph: Graph) -> String:
	# If we are already there or data is invalid, stop.
	if current_id == target_id or not graph.nodes.has(current_id):
		return ""

	match algo:
		Algo.RANDOM:
			return _solve_random(current_id, graph)
		Algo.BFS:
			return _solve_bfs(current_id, target_id, graph)
		Algo.DFS:
			return _solve_dfs(current_id, target_id, graph)
		Algo.ASTAR:
			return _solve_astar(current_id, target_id, graph)
			
	return ""

# --- ALGORITHMS ---

static func _solve_random(current_id: String, graph: Graph) -> String:
	var neighbors = graph.get_neighbors(current_id)
	if neighbors.is_empty(): return ""
	return neighbors.pick_random()

static func _solve_bfs(start_id: String, target_id: String, graph: Graph) -> String:
	# Breadth-First Search (Shortest path in unweighted graph)
	if start_id == target_id: return ""
	
	var queue = [start_id]
	var visited = { start_id: true }
	var parent = {} # To reconstruct path
	
	while not queue.is_empty():
		var current = queue.pop_front()
		if current == target_id:
			return _reconstruct_first_step(parent, start_id, target_id)
		
		for next in graph.get_neighbors(current):
			if not visited.has(next):
				visited[next] = true
				parent[next] = current
				queue.append(next)
				
	return "" # No path found

static func _solve_dfs(start_id: String, target_id: String, graph: Graph) -> String:
	# Depth-First Search (Wanders deep, not shortest)
	# NOTE: Iterative DFS to avoid stack overflow
	var stack = [start_id]
	var visited = { start_id: true }
	var parent = {}
	
	while not stack.is_empty():
		var current = stack.pop_back()
		if current == target_id:
			return _reconstruct_first_step(parent, start_id, target_id)
		
		for next in graph.get_neighbors(current):
			if not visited.has(next):
				visited[next] = true
				parent[next] = current
				stack.append(next)
				
	return ""

static func _solve_astar(start_id: String, target_id: String, graph: Graph) -> String:
	# A* Search using PriorityQueue
	if start_id == target_id: return ""
	if not graph.nodes.has(target_id): return "" # Target must exist
	
	var pq = PriorityQueue.new()
	pq.push(start_id, 0.0)
	
	var parent = {}
	var g_score = { start_id: 0.0 }
	
	var end_pos = graph.get_node_pos(target_id)
	
	while not pq.is_empty():
		var current = pq.pop()
		
		if current == target_id:
			return _reconstruct_first_step(parent, start_id, target_id)
		
		for neighbor in graph.get_neighbors(current):
			# Weight is typically distance, but we can default to 1.0 or edge weight
			# Let's use Euclidean distance for accuracy
			var dist = graph.get_node_pos(current).distance_to(graph.get_node_pos(neighbor))
			var tentative_g = g_score[current] + dist
			
			if not g_score.has(neighbor) or tentative_g < g_score[neighbor]:
				parent[neighbor] = current
				g_score[neighbor] = tentative_g
				var h = graph.get_node_pos(neighbor).distance_to(end_pos) # Heuristic
				var f = tentative_g + h
				
				if pq.contains(neighbor):
					pq.update_priority(neighbor, f)
				else:
					pq.push(neighbor, f)
					
	return ""

# --- HELPER ---
static func _reconstruct_first_step(parent_map: Dictionary, start: String, end: String) -> String:
	var curr = end
	# Backtrack from end to start
	while parent_map.has(curr):
		var p = parent_map[curr]
		if p == start:
			return curr # This is the immediate next step from start
		curr = p
	return ""
