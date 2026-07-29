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
	var topo_data = {}
	
	# Extract modular metrics
	topo_data.merge(_get_basic_counts(graph))
	topo_data["connected_components"] = _get_connected_components(graph)
	
	# Cyclomatic Complexity: Edges - Nodes + Connected Components
	topo_data["cyclomatic_complexity"] = topo_data["edge_count"] - topo_data["node_count"] + topo_data["connected_components"]
	
	topo_data.merge(_get_articulation_metrics(graph))
	topo_data.merge(_get_betweenness_centrality(graph))
	
	# Add k-core metrics (Tangles / Dense Arenas)
	topo_data.merge(_get_k_core_metrics(graph))
	
	report["topological"] = topo_data

# --- TOPOLOGY SUB-ROUTINES ---

static func _get_basic_counts(graph: Graph) -> Dictionary:
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

	# Graph Density: Actual Edges / Possible Edges
	var density = 0.0
	if node_count > 1:
		var max_possible_edges = float(node_count * (node_count - 1)) / 2.0
		density = float(edge_count) / max_possible_edges
		
	return {
		"node_count": node_count,
		"edge_count": edge_count,
		"density": snapped(density, 0.0001),
		"shapes": {
			"disconnected": disconnected,
			"dead_ends": dead_ends,
			"corridors": corridors,
			"intersections": intersections
		}
	}

static func _get_connected_components(graph: Graph) -> int:
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
						
	return connected_components

static func _get_articulation_metrics(graph: Graph) -> Dictionary:
	var time = 0
	var disc = {}
	var low = {}
	var parent_map = {}
	var ap_dict = {}
	var bridge_count = 0
	
	for start_node in graph.nodes:
		if disc.has(start_node): continue
			
		var root_children = 0
		var stack = []
		
		# Frame structure: { "u": current_node, "neighbors": [], "idx": neighbor_iterator }
		stack.append({"u": start_node, "neighbors": graph.get_neighbors(start_node), "idx": 0})
		disc[start_node] = time
		low[start_node] = time
		time += 1
		parent_map[start_node] = null
		
		while not stack.is_empty():
			var frame = stack.back()
			var u = frame.u
			var neighbors = frame.neighbors
			var idx = frame.idx
			
			if idx < neighbors.size():
				var v = neighbors[idx]
				frame.idx += 1
				
				if not disc.has(v):
					parent_map[v] = u
					if parent_map[u] == null:
						root_children += 1
						
					disc[v] = time
					low[v] = time
					time += 1
					
					stack.append({"u": v, "neighbors": graph.get_neighbors(v), "idx": 0})
				elif v != parent_map[u]:
					# Back-edge found: updates lowest reachable time
					low[u] = min(low[u], disc[v])
			else:
				# Finished exploring this node
				stack.pop_back()
				if not stack.is_empty():
					var p = stack.back().u
					low[p] = min(low[p], low[u])
					
					# Bridge condition
					if low[u] > disc[p]:
						bridge_count += 1
						
					# Articulation Point condition (for non-roots)
					if parent_map[p] != null and low[u] >= disc[p]:
						ap_dict[p] = true
						
		# Articulation Point condition (for roots)
		if root_children > 1:
			ap_dict[start_node] = true
			
	return {
		"articulation_points": ap_dict.size(),
		"bridges": bridge_count
	}

static func _get_betweenness_centrality(graph: Graph) -> Dictionary:
	var cb = {}
	for id in graph.nodes:
		cb[id] = 0.0
		
	# Brandes' Algorithm (O(V * E))
	for s in graph.nodes:
		var stack = []
		var p = {}
		var sigma = {}
		var d = {}
		
		for id in graph.nodes:
			p[id] = []
			sigma[id] = 0.0
			d[id] = -1
			
		sigma[s] = 1.0
		d[s] = 0
		var queue = [s]
		
		while not queue.is_empty():
			var v = queue.pop_front()
			stack.append(v)
			
			for w in graph.get_neighbors(v):
				# Node found for the first time
				if d[w] < 0:
					queue.append(w)
					d[w] = d[v] + 1
				
				# Shortest path to w via v
				if d[w] == d[v] + 1:
					sigma[w] += sigma[v]
					p[w].append(v)
					
		var delta = {}
		for id in graph.nodes:
			delta[id] = 0.0
			
		# Accumulate dependencies backwards
		while not stack.is_empty():
			var w = stack.pop_back()
			for v in p[w]:
				delta[v] += (sigma[v] / sigma[w]) * (1.0 + delta[w])
			if w != s:
				cb[w] += delta[w]
				
	var max_cb = 0.0
	var avg_cb = 0.0
	var hub_id = "None"
	var node_count = graph.nodes.size()
	
	if node_count > 0:
		for id in cb:
			# Because the graph is undirected, every path is counted twice.
			cb[id] /= 2.0
			avg_cb += cb[id]
			if cb[id] > max_cb:
				max_cb = cb[id]
				hub_id = id
		avg_cb /= float(node_count)
		
	return {
		"max_betweenness": snapped(max_cb, 0.01),
		"average_betweenness": snapped(avg_cb, 0.01),
		"hub_node_id": hub_id
	}

static func _get_k_core_metrics(graph: Graph) -> Dictionary:
	var degrees = {}
	var max_possible_deg = 0
	var active_nodes = {}
	
	# 1. Initialize Degrees and Track Maximum
	for id in graph.nodes:
		var deg = graph.get_neighbors(id).size()
		degrees[id] = deg
		active_nodes[id] = true
		if deg > max_possible_deg:
			max_possible_deg = deg
			
	# 2. Setup O(1) Buckets for Sorting
	var buckets = []
	buckets.resize(max_possible_deg + 1)
	for i in range(buckets.size()):
		buckets[i] = {} # Using dicts as sets for O(1) lookup/removal
		
	for id in degrees:
		buckets[degrees[id]][id] = true
		
	var max_core = 0
	var current_k = 0
	var nodes_processed = 0
	var total_nodes = graph.nodes.size()
	var core_numbers = {}
	
	# 3. Iterative Peeling
	while nodes_processed < total_nodes:
		# Find the lowest populated bucket
		while current_k <= max_possible_deg and buckets[current_k].is_empty():
			current_k += 1
			
		if current_k > max_possible_deg: break
			
		max_core = max(max_core, current_k)
		
		# Pop a node from this bucket
		var id = buckets[current_k].keys()[0]
		buckets[current_k].erase(id)
		active_nodes.erase(id)
		core_numbers[id] = max_core
		nodes_processed += 1
		
		# Demote neighbors
		for neighbor in graph.get_neighbors(id):
			if active_nodes.has(neighbor):
				var old_deg = degrees[neighbor]
				var new_deg = old_deg - 1
				degrees[neighbor] = new_deg
				
				buckets[old_deg].erase(neighbor)
				buckets[new_deg][neighbor] = true
				
				# If demoted below current search head, move head back
				if new_deg < current_k:
					current_k = new_deg
					
	# 4. Measure the Size of the Maximal Core
	var max_core_size = 0
	for id in core_numbers:
		if core_numbers[id] == max_core:
			max_core_size += 1
			
	return {
		"graph_degeneracy": max_core,
		"max_core_size": max_core_size
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
