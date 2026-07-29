class_name GraphMetrics
extends RefCounted

# Generates a flat, JSON-safe dictionary of all graph statistics.
static func generate_report(graph: Graph) -> Dictionary:
	var report = {
		"timestamp": Time.get_datetime_string_from_system(),
		"topological": {},
		"spatial": {},
		"agents": {},
		"zones": {}
	}
	
	_calculate_topology(graph, report)
	_calculate_spatial(graph, report)
	_calculate_agents(graph, report)
	_calculate_zones(graph, report)
	
	return report

# --- 1. TOPOLOGICAL METRICS ---
static func _calculate_topology(graph: Graph, report: Dictionary) -> void:
	var node_count = graph.nodes.size()
	
	var edge_count = 0
	var processed_pairs = {}
	
	# Undirected Edge Deduplication
	for a in graph.edge_data:
		for b in graph.edge_data[a]:
			var pair = [a, b]
			pair.sort()
			if not processed_pairs.has(pair):
				processed_pairs[pair] = true
				edge_count += 1
				
	# Node Degrees (Shape analysis)
	var disconnected = 0
	var dead_ends = 0
	var corridors = 0
	var intersections = 0
	
	for id in graph.nodes:
		var deg = graph.get_neighbors(id).size()
		if deg == 0: disconnected += 1
		elif deg == 1: dead_ends += 1
		elif deg == 2: corridors += 1
		elif deg >= 3: intersections += 1

	# Graph Density
	var density = 0.0
	if node_count > 1:
		var max_possible_edges = float(node_count * (node_count - 1)) / 2.0
		density = float(edge_count) / max_possible_edges

	# --- Connected Components (Islands) ---
	var visited = {}
	var connected_components = 0
	
	for id in graph.nodes:
		if not visited.has(id):
			connected_components += 1
			# Run BFS to discover the entire island
			var queue = [id]
			visited[id] = true
			
			while not queue.is_empty():
				var curr = queue.pop_front()
				for neighbor in graph.get_neighbors(curr):
					if not visited.has(neighbor):
						visited[neighbor] = true
						queue.append(neighbor)

	# --- Cyclomatic Complexity ---
	# Formula: Edges - Nodes + Connected Components
	var cyclomatic_complexity = edge_count - node_count + connected_components

	report["topological"] = {
		"node_count": node_count,
		"edge_count": edge_count,
		"density": snapped(density, 0.0001),
		"connected_components": connected_components,
		"cyclomatic_complexity": cyclomatic_complexity,
		"shapes": {
			"disconnected": disconnected,
			"dead_ends": dead_ends,
			"corridors": corridors,
			"intersections": intersections
		}
	}

# --- 2. SPATIAL METRICS ---
static func _calculate_spatial(graph: Graph, report: Dictionary) -> void:
	if graph.nodes.is_empty():
		report["spatial"] = { "is_empty": true }
		return
		
	var stats = graph.get_spatial_stats()
	var bounds: Rect2 = stats.get("bounds", Rect2())
	
	report["spatial"] = {
		"total_cells_used": stats.get("total_cells", 0),
		"avg_nodes_per_cell": snapped(stats.get("avg_nodes_per_cell", 0.0), 0.01),
		"bounds": {
			"x": bounds.position.x,
			"y": bounds.position.y,
			"width": bounds.size.x,
			"height": bounds.size.y,
			"area": bounds.get_area()
		}
	}

# --- 3. AGENT METRICS ---
static func _calculate_agents(graph: Graph, report: Dictionary) -> void:
	var total_agents = graph.agents.size()
	var completed = 0
	var total_steps = 0
	
	for agent in graph.agents:
		if agent.is_finished:
			completed += 1
		total_steps += agent.step_count
		
	var avg_steps = 0.0
	var completion_rate = 0.0
	
	if total_agents > 0:
		avg_steps = float(total_steps) / float(total_agents)
		completion_rate = float(completed) / float(total_agents)
		
	report["agents"] = {
		"total_spawned": total_agents,
		"total_completed": completed,
		"completion_rate_percent": snapped(completion_rate * 100.0, 0.1),
		"average_steps": snapped(avg_steps, 0.1),
		"total_aggregate_steps": total_steps
	}

# --- 4. ZONE METRICS ---
static func _calculate_zones(graph: Graph, report: Dictionary) -> void:
	var total_zones = 0
	var total_area = 0
	
	if "zones" in graph:
		total_zones = graph.zones.size()
		for z in graph.zones:
			if z.has_method("get_area_size"):
				total_area += z.get_area_size()
			elif "registered_nodes" in z:
				total_area += z.registered_nodes.size() # Fallback approximation
				
	report["zones"] = {
		"total_zones": total_zones,
		"aggregate_area_size": total_area
	}
