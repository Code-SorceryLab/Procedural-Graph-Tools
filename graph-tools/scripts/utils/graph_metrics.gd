class_name GraphMetrics
extends RefCounted

# --- MODULAR ANALYSIS SCHEMA ---
static func get_analysis_options_schema() -> Array[Dictionary]:
	return [
		# Tangles
		{ "name": "do_tangles", "label": "Calculate Tangles & Treewidth", "type": TYPE_BOOL, "default": false, 
		  "hint": "Extracts the exact Treewidth.\nWarning: Computationally heavy." },
		{ "name": "tangle_force_exact", "label": "Force Exact Tangles (May freeze editor!)", "type": TYPE_BOOL, "default": false, 
		  "hint": "If true, ignores the iteration limit and computes until finished.\n(Still capped at 63 nodes due to 64-bit math limits)." },
		{ "name": "tangle_max_iters", "label": "Tangle Iteration Limit", "type": TYPE_INT, "default": 100000, "min": 1000, "max": 10000000, "step": 1000, 
		  "hint": "Maximum iterations before falling back\nto the greedy approximation." },

		# Chromatic Math
		{ "name": "do_chromatic", "label": "Calculate Chromatic Number", "type": TYPE_BOOL, "default": false, 
		  "hint": "Finds the minimum number of colors\nneeded to paint the graph." },
		{ "name": "chromatic_force_exact", "label": "Force Exact Chromatic (May freeze!)", "type": TYPE_BOOL, "default": false, 
		  "hint": "Ignores the iteration limit to find\nthe exact mathematically perfect coloring." },
		{ "name": "chromatic_max_iters", "label": "Chromatic Iteration Limit", "type": TYPE_INT, "default": 100000, "min": 1000, "max": 10000000, "step": 1000, 
		  "hint": "Max recursive branches before aborting." },
	
		# Max Exploration Math
		{ "name": "do_longest_path", "label": "Calculate Max Exploration (Longest Path)", "type": TYPE_BOOL, "default": false, 
		  "hint": "Finds the longest possible continuous path\nwithout revisiting any nodes." },
		{ "name": "longest_path_force_exact", "label": "Force Exact Longest Path", "type": TYPE_BOOL, "default": false, 
		  "hint": "Bypasses iteration limits to guarantee\nthe absolute longest path." },
		{ "name": "longest_path_max_iters", "label": "Longest Path Iteration Limit", "type": TYPE_INT, "default": 200000, "min": 1000, "max": 10000000, "step": 1000, 
		  "hint": "Max permutations to check before yielding\nthe best path found so far." },
		
		# Eulerian Math
		{ "name": "do_eulerian", "label": "Calculate Edge Traversal (Eulerian Path)", "type": TYPE_BOOL, "default": false, 
		  "hint": "Checks if an agent can traverse\nevery edge exactly once." },
		
		# Community Detection
		{ "name": "do_louvain", "label": "Calculate Biomes (Community Detection)", "type": TYPE_BOOL, "default": false, 
		  "hint": "Uses the Louvain Method to cluster nodes\ninto logical districts based on edge density." }
	]


# The 'await' keyword inside this function automatically turns it into a Coroutine!
static func generate_report(graph: Graph, params: Dictionary = {}) -> Dictionary:
	var report = {
		"timestamp": Time.get_datetime_string_from_system(),
		"_selection_data": {},
		"topological": {},
		"spatial": {},
		"agents": {},
		"markov_flow": {},
		"zones": {}
	}
	
	_calculate_topology(graph, report)
	_calculate_spatial(graph, report)
	_calculate_agents(graph, report)
	_calculate_markov(graph, report)
	_calculate_zones(graph, report)
	
	# Pause execution here if we are threading the Tangles
	if params.get("do_tangles", false):
		await _calculate_tangles(graph, report, params)
	
	# Pause for the Chromatic thread
	if params.get("do_chromatic", false):
		await _calculate_chromatic(graph, report, params)
	
	# Pause for the Longest Path thread!
	if params.get("do_longest_path", false):
		await _calculate_longest_path(graph, report, params)
	
	# Pause for Eulerian Thread
	if params.get("do_eulerian", false):
		await _calculate_eulerian(graph, report, params)
	
	# Pause for Louvain Thread
	if params.get("do_louvain", false):
		await _calculate_louvain(graph, report, params)
	
	return report
	



# --- 1. TOPOLOGICAL METRICS ---
static func _calculate_topology(graph: Graph, report: Dictionary) -> void:
	var topo_data = {}
	
	topo_data.merge(_get_basic_counts(graph, report))
	topo_data["connected_components"] = _get_connected_components(graph)
	
	# Cyclomatic Complexity: Edges - Nodes + Connected Components
	topo_data["cyclomatic_complexity"] = topo_data["edge_count"] - topo_data["node_count"] + topo_data["connected_components"]
	
	# Mathematical Planarity Check
	var planarity_data = GraphPlanarity.check_planarity(graph)
	topo_data["is_planar"] = "Yes" if planarity_data["is_planar"] else "No"
	topo_data["planarity_reason"] = planarity_data["reason"]
	
	topo_data.merge(_get_articulation_metrics(graph, report))
	topo_data.merge(_get_betweenness_centrality(graph))
	topo_data.merge(_get_k_core_metrics(graph, report))
	
	# --- Spectral Graph Theory (Bottlenecks) ---
	var spectral_data = GraphSpectral.analyze_bottlenecks(graph)
	topo_data["algebraic_connectivity"] = spectral_data["fiedler_value"]
	topo_data["bisection_side_a"] = spectral_data["side_a"].size()
	topo_data["bisection_side_b"] = spectral_data["side_b"].size()
	topo_data["bisection_cut_edges"] = spectral_data["cut_edges"].size()
	
	# --- Information Theory ---
	var entropy_data = GraphEntropy.calculate(graph)
	topo_data["structural_entropy"] = entropy_data["shannon_entropy"]
	
	# Stash them for the interactive UI links!
	if not report.has("_selection_data"): report["_selection_data"] = {}
	report["_selection_data"]["bisection_side_a"] = { "nodes": spectral_data["side_a"], "edges": [] }
	report["_selection_data"]["bisection_side_b"] = { "nodes": spectral_data["side_b"], "edges": [] }
	report["_selection_data"]["bisection_cut_edges"] = { "nodes": [], "edges": spectral_data["cut_edges"] }
	
	report["topological"] = topo_data

# --- TOPOLOGY SUB-ROUTINES ---
static func _get_basic_counts(graph: Graph, report: Dictionary) -> Dictionary:
	var node_count = graph.nodes.size()
	var edge_count = 0
	var processed_pairs = {}
	
	for key in graph.edge_store:
		var e = graph.edge_store[key]
		var pair = [e.u, e.v]
		pair.sort()
		if not processed_pairs.has(pair):
			processed_pairs[pair] = true
			edge_count += 1
			
	# Shape Analysis & Selection Tracking
	var dead_ends = []; var corridors = []; var intersections = []; var disconnected = []
	
	for id in graph.nodes:
		var deg = graph.get_neighbors(id).size()
		if deg == 0: disconnected.append(id)
		elif deg == 1: dead_ends.append(id)
		elif deg == 2: corridors.append(id)
		elif deg >= 3: intersections.append(id)

	var density = 0.0
	if node_count > 1:
		var max_possible_edges = float(node_count * (node_count - 1)) / 2.0
		density = float(edge_count) / max_possible_edges
		
	# Stash the arrays for the UI to use!
	report["_selection_data"]["disconnected"] = { "nodes": disconnected, "edges": [] }
	report["_selection_data"]["dead_ends"] = { "nodes": dead_ends, "edges": [] }
	report["_selection_data"]["corridors"] = { "nodes": corridors, "edges": [] }
	report["_selection_data"]["intersections"] = { "nodes": intersections, "edges": [] }
		
	return {
		"node_count": node_count,
		"edge_count": edge_count,
		"density": snapped(density, 0.0001),
		"shapes": {
			"disconnected": disconnected.size(),
			"dead_ends": dead_ends.size(),
			"corridors": corridors.size(),
			"intersections": intersections.size()
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

static func _get_articulation_metrics(graph: Graph, report: Dictionary) -> Dictionary:
	var time = 0
	var disc = {}
	var low = {}
	var parent_map = {}
	var ap_dict = {}
	var bridges = []
	
	for start_node in graph.nodes:
		if disc.has(start_node): continue
			
		var root_children = 0
		var stack = []
		
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
					low[u] = min(low[u], disc[v])
			else:
				stack.pop_back()
				if not stack.is_empty():
					var p = stack.back().u
					low[p] = min(low[p], low[u])
					
					# Bridge condition
					if low[u] > disc[p]:
						var pair = [p, u]
						pair.sort()
						bridges.append(pair)
						
					# Articulation Point condition (for non-roots)
					if parent_map[p] != null and low[u] >= disc[p]:
						ap_dict[p] = true
						
		# Articulation Point condition (for roots)
		if root_children > 1:
			ap_dict[start_node] = true
			
	# --- [NEW] CYCLE DETECTION ---
	# Any edge that is NOT a bridge is part of a cycle!
	var cycle_edges = []
	var cycle_nodes_dict = {}
	var processed_pairs = {}
	
	for key in graph.edge_store:
		var e = graph.edge_store[key]
		var pair = [e.u, e.v]
		pair.sort()
		
		if processed_pairs.has(pair): continue
		processed_pairs[pair] = true
		
		var is_bridge = false
		for b in bridges:
			if b[0] == pair[0] and b[1] == pair[1]:
				is_bridge = true
				break
				
		if not is_bridge:
			cycle_edges.append(pair)
			cycle_nodes_dict[pair[0]] = true
			cycle_nodes_dict[pair[1]] = true
			
	# Stash everything in the report so the UI can click it!
	if not report.has("_selection_data"): report["_selection_data"] = {}
	report["_selection_data"]["articulation_points"] = { "nodes": ap_dict.keys(), "edges": [] }
	report["_selection_data"]["bridges"] = { "nodes": [], "edges": bridges }
	report["_selection_data"]["cyclomatic_complexity"] = { "nodes": cycle_nodes_dict.keys(), "edges": cycle_edges }
			
	return {
		"articulation_points": ap_dict.size(),
		"bridges": bridges.size()
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

static func _get_k_core_metrics(graph: Graph, report: Dictionary) -> Dictionary:
	var degrees = {}
	var max_possible_deg = 0
	var active_nodes = {}
	
	for id in graph.nodes:
		var deg = graph.get_neighbors(id).size()
		degrees[id] = deg
		active_nodes[id] = true
		if deg > max_possible_deg:
			max_possible_deg = deg
			
	var buckets = []
	buckets.resize(max_possible_deg + 1)
	for i in range(buckets.size()):
		buckets[i] = {}
		
	for id in degrees:
		buckets[degrees[id]][id] = true
		
	var max_core = 0
	var current_k = 0
	var nodes_processed = 0
	var total_nodes = graph.nodes.size()
	var core_numbers = {}
	
	while nodes_processed < total_nodes:
		while current_k <= max_possible_deg and buckets[current_k].is_empty():
			current_k += 1
			
		if current_k > max_possible_deg: break
			
		max_core = max(max_core, current_k)
		
		var id = buckets[current_k].keys()[0]
		buckets[current_k].erase(id)
		active_nodes.erase(id)
		core_numbers[id] = max_core
		nodes_processed += 1
		
		for neighbor in graph.get_neighbors(id):
			if active_nodes.has(neighbor):
				var old_deg = degrees[neighbor]
				var new_deg = old_deg - 1
				degrees[neighbor] = new_deg
				
				buckets[old_deg].erase(neighbor)
				buckets[new_deg][neighbor] = true
				
				if new_deg < current_k:
					current_k = new_deg
					
	# Extract the core cluster to make it clickable
	var max_core_size = 0
	var core_nodes: Array[String] = []
	
	for id in core_numbers:
		if core_numbers[id] == max_core:
			max_core_size += 1
			core_nodes.append(id)
			
	var core_edges = []
	var processed = {}
	for key in graph.edge_store:
		var e = graph.edge_store[key]
		var pair = [e.u, e.v]
		pair.sort()
		if processed.has(pair): continue
		processed[pair] = true
		
		# If both ends of an edge are inside the max core, include the edge in the selection!
		if core_nodes.has(e.u) and core_nodes.has(e.v):
			core_edges.append(pair)
			
	if not report.has("_selection_data"): report["_selection_data"] = {}
	report["_selection_data"]["max_core_size"] = { "nodes": core_nodes, "edges": core_edges }
	report["_selection_data"]["graph_degeneracy"] = { "nodes": core_nodes, "edges": core_edges }
			
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

# --- 4. MARKOV CHAIN FLOW ANALYSIS ---
static func _calculate_markov(graph: Graph, report: Dictionary) -> void:
	var flow_data = GraphMarkov.analyze_flow(graph)
	
	if flow_data.get("status") == "Success":
		# Wire up the bottleneck ID to the interactive UI selection system!
		var flow_id = flow_data.get("flow_bottleneck_id", "None")
		if flow_id != "None":
			if not report.has("_selection_data"): report["_selection_data"] = {}
			report["_selection_data"]["flow_bottleneck_id"] = { "nodes": [flow_id], "edges": [] }
			
	report["markov_flow"] = flow_data

# --- 5. ZONE METRICS ---
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

# --- 6. HEAVY METRICS ---
# Changed to an async coroutine
static func _calculate_tangles(graph: Graph, report: Dictionary, params: Dictionary) -> void:
	var tangle_solver = GraphTangle.new()
	tangle_solver.calculate_async(graph, params)
	
	# Suspend execution until the background thread fires this signal
	var tangle_data = await tangle_solver.calculation_finished
	
	report["robertson_seymour_tangles"] = {
		"tangle_treewidth": tangle_data["treewidth"],
		"tangle_calculation_method": tangle_data["method"]
	}
	
# Coroutine Caller
static func _calculate_chromatic(graph: Graph, report: Dictionary, params: Dictionary) -> void:
	var chromatic_solver = GraphChromatic.new()
	chromatic_solver.calculate_async(graph, params)
	
	var c_data = await chromatic_solver.calculation_finished
	
	report["chromatic_coloring"] = {
		"chromatic_number": c_data["chromatic_number"],
		"chromatic_calculation_method": c_data["method"]
	}

# Coroutine Caller
static func _calculate_longest_path(graph: Graph, report: Dictionary, params: Dictionary) -> void:
	var path_solver = GraphLongestPath.new()
	path_solver.calculate_async(graph, params)
	
	var path_data = await path_solver.calculation_finished
	
	report["max_exploration_path"] = {
		"max_path_length": path_data["max_path_length"],
		"is_hamiltonian": path_data["is_hamiltonian"],
		"longest_path_calculation_method": path_data["method"]
	}
	
	# Convert the ordered path array into edge pairs for interactive highlighting!
	var ordered_nodes = path_data["path_nodes"]
	var path_edges = []
	for i in range(ordered_nodes.size() - 1):
		var pair = [ordered_nodes[i], ordered_nodes[i+1]]
		pair.sort()
		path_edges.append(pair)
		
	if not report.has("_selection_data"): report["_selection_data"] = {}
	report["_selection_data"]["max_path_length"] = { "nodes": ordered_nodes, "edges": path_edges }

# Coroutine Caller
static func _calculate_eulerian(graph: Graph, report: Dictionary, params: Dictionary) -> void:
	var eulerian_solver = GraphEulerian.new()
	eulerian_solver.calculate_async(graph, params)
	
	var e_data = await eulerian_solver.calculation_finished
	
	report["eulerian_edge_traversal"] = {
		"has_eulerian_circuit": e_data["has_circuit"],
		"has_eulerian_path": e_data["has_path"],
		"odd_degree_nodes": e_data["odd_nodes"]
	}
	
	# Interactive Highlighting setup
	var ordered_nodes = e_data["path_nodes"]
	if not ordered_nodes.is_empty():
		var path_edges = []
		for i in range(ordered_nodes.size() - 1):
			var pair = [ordered_nodes[i], ordered_nodes[i+1]]
			pair.sort()
			path_edges.append(pair)
			
		# Show the exact count of the path (which equals Edge Count) so we have a clickable UI element
		report["eulerian_edge_traversal"]["full_traversal_route_length"] = ordered_nodes.size()
		
		if not report.has("_selection_data"): report["_selection_data"] = {}
		report["_selection_data"]["full_traversal_route_length"] = { "nodes": ordered_nodes, "edges": path_edges }

# Coroutine Caller
static func _calculate_louvain(graph: Graph, report: Dictionary, params: Dictionary) -> void:
	var louvain_solver = GraphLouvain.new()
	louvain_solver.calculate_async(graph, params)
	
	var c_data = await louvain_solver.calculation_finished
	
	report["community_detection"] = {
		"modularity_score": c_data["modularity"],
		"detected_communities": c_data["communities"],
		"districts": {} # We will list them as nested clickables!
	}
	
	# Group the nodes by their detected Community ID
	var districts = {}
	var c_map = c_data["communities_map"]
	
	for node_id in c_map:
		var c_id = c_map[node_id]
		if not districts.has(c_id): districts[c_id] = []
		districts[c_id].append(node_id)
		
	if not report.has("_selection_data"): report["_selection_data"] = {}
	
	# Create a clickable UI link for every single biome detected!
	for c_id in districts.keys():
		var dist_name = "district_%d" % c_id
		var count = districts[c_id].size()
		
		report["community_detection"]["districts"][dist_name] = count
		report["_selection_data"][dist_name] = { "nodes": districts[c_id], "edges": [] }
