class_name PathfinderDFS
extends PathfindingStrategy

func find_path(graph: Graph, start_id: String, target_id: String) -> Array[String]:
	var stack = [start_id]
	var visited = { start_id: true }
	var parent = {}
	
	while not stack.is_empty():
		var current = stack.pop_back()
		
		if current == target_id:
			return _reconstruct_path(parent, target_id)
		
		# Standard neighbor order
		for next in graph.get_neighbors(current):
			if not visited.has(next):
				visited[next] = true
				parent[next] = current
				stack.append(next)
				
	return []

func _reconstruct_path(parent_map: Dictionary, end: String) -> Array[String]:
	var path: Array[String] = []
	var curr = end
	while curr != null:
		path.append(curr)
		curr = parent_map.get(curr)
	path.reverse()
	return path
