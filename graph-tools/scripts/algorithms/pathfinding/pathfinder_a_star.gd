class_name PathfinderAStar
extends PathfindingStrategy

var heuristic_scale: float = 1.0

func _init(scale: float = 1.0) -> void:
	heuristic_scale = scale

func find_path(graph: Graph, start_id: String, target_id: String) -> Array[String]:
	# 1. Reuse existing Graph A* logic, but adapted to be standalone
	# (Copying the logic from Graph.gd here keeps Graph.gd clean)
	
	if start_id == target_id: return [start_id]
	
	var PriorityQueueAStar = load("res://scripts/utils/priority_queue.gd") # Load locally
	var open_set = PriorityQueueAStar.new()
	var came_from: Dictionary = {}
	var g_score: Dictionary = { start_id: 0.0 }
	
	# Push Start
	var h = _heuristic(graph, start_id, target_id)
	open_set.push(start_id, h)
	
	while not open_set.is_empty():
		var current = open_set.pop()
		
		if current == target_id:
			return _reconstruct_path(came_from, current)
			
		# Get Neighbors from Graph
		var neighbors = graph.get_neighbors(current)
		for next in neighbors:
			# 2. Use Graph's Unified Cost Function
			var move_cost = graph.get_travel_cost(current, next)
			if move_cost == INF: continue
			
			var tentative_g = g_score[current] + move_cost
			
			if tentative_g < g_score.get(next, INF):
				came_from[next] = current
				g_score[next] = tentative_g
				
				var f = tentative_g + _heuristic(graph, next, target_id)
				open_set.push(next, f)
				
	return []

func _heuristic(graph: Graph, a: String, b: String) -> float:
	# If scale is 0 (Dijkstra), this returns 0.
	if heuristic_scale == 0: return 0.0
	
	var pos_a = graph.nodes[a].position
	var pos_b = graph.nodes[b].position
	
	# We use the scalable heuristic we discussed earlier
	# Assuming MIN_TRAVERSAL_COST is accessible or hardcoded for now
	var min_cost = 0.1 # Or Graph.MIN_TRAVERSAL_COST if static
	return pos_a.distance_to(pos_b) * min_cost * heuristic_scale

func _reconstruct_path(came_from: Dictionary, current: String) -> Array[String]:
	var path: Array[String] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path
