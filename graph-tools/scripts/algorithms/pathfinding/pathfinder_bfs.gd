class_name PathfinderBFS
extends PathfindingStrategy

func find_path(graph: Graph, start_id: String, target_id: String) -> Array[String]:
	if start_id == target_id: return []
	
	var queue = [start_id]
	var visited = { start_id: true }
	var parent = {} 
	
	while not queue.is_empty():
		var current = queue.pop_front()
		
		if current == target_id:
			return _reconstruct_path(parent, target_id)
		
		for next in graph.get_neighbors(current):
			if not visited.has(next):
				visited[next] = true
				parent[next] = current
				queue.append(next)
				
	return []

func _reconstruct_path(parent_map: Dictionary, end: String) -> Array[String]:
	var path: Array[String] = []
	var curr = end
	while curr != null:
		path.append(curr)
		curr = parent_map.get(curr)
	path.reverse()
	return path
