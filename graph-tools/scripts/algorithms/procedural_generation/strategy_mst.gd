class_name StrategyMST
extends GraphStrategy

# Internal helper class for Union-Find (Disjoint Set) - Used by Kruskal
class UnionFind:
	var parent: Dictionary = {}
	
	func _init(nodes: Array):
		for id in nodes:
			parent[id] = id
			
	func find(i: String) -> String:
		if parent[i] != i:
			parent[i] = find(parent[i])
		return parent[i]
		
	func union(i: String, j: String) -> void:
		var root_i = find(i)
		var root_j = find(j)
		if root_i != root_j:
			parent[root_i] = root_j

func _init() -> void:
	strategy_name = "Minimum Spanning Tree"
	reset_on_generate = false
	supports_grow = false
	# [SEED FIX] Initialize base RNG (inherited from GraphStrategy)
	rng = RandomNumberGenerator.new()

func get_settings() -> Array[Dictionary]:
	# [SEED FIX] Pull the seed box from GraphStrategy first!
	var settings: Array[Dictionary] = super.get_settings()
	
	settings.append_array([
		{
			"name": "algorithm",
			"type": TYPE_BOOL, 
			"default": true,
			"hint": GraphSettings.PARAM_TOOLTIPS.mst.algo,
		},
		{
			"name": "search_range",
			"type": TYPE_FLOAT,
			"default": 2.5,
			"min": 1.5, "max": 10.0, "step": 0.5,
			"hint": GraphSettings.PARAM_TOOLTIPS.mst.range
		},
		{
			"name": "braid_chance",
			"type": TYPE_INT,
			"default": 0,
			"min": 0, "max": 50,
			"hint": GraphSettings.PARAM_TOOLTIPS.mst.braid
		}
	])
	
	return settings

func execute(graph: GraphRecorder, params: Dictionary) -> void:
	# [SEED FIX] Setup Deterministic State for this run
	var raw_seed = params.get("strategy_seed", "")
	if raw_seed != "":
		my_seed = SeedUtils.hash_seed(raw_seed)
		rng.seed = my_seed
	else:
		rng.randomize() 
		my_seed = rng.seed
		
	var nodes_list = graph.nodes.keys()
	if nodes_list.is_empty():
		return 
	
	var use_kruskal = params.get("algorithm", true)
	var range_mult = float(params.get("search_range", 2.5))
	var braid_chance = int(params.get("braid_chance", 0)) / 100.0
	
	# Calculate Elliptical Radii
	var spacing = GraphSettings.GRID_SPACING
	var radius_vec = spacing * range_mult
	
	# ==========================================================================
	# 1. UNDO-SAFE EDGE CLEARING & TOPOLOGY PRESERVATION
	# ==========================================================================
	var original_edges: Dictionary = {}
	var edges_to_remove: Array = []
	
	for u_id in graph.nodes:
		for v_id in graph.get_neighbors(u_id):
			var pair = [u_id, v_id]
			pair.sort()
			if not original_edges.has(pair):
				original_edges[pair] = true
				edges_to_remove.append(pair)
				
	for pair in edges_to_remove:
		graph.remove_edge(pair[0], pair[1])
		
	# Shared container for rejected edges (for Braiding)
	var rejected_edges = []
	
	# ==========================================================================
	# 2. ALGORITHM SELECTION
	# ==========================================================================
	if use_kruskal:
		_execute_kruskal(graph, nodes_list, radius_vec, braid_chance, original_edges, rejected_edges)
	else:
		_execute_prim(graph, nodes_list, radius_vec, braid_chance, original_edges, rejected_edges)
		
	# ==========================================================================
	# 3. BRAIDING (Prioritize Original Geometry)
	# ==========================================================================
	if braid_chance > 0.0 and not rejected_edges.is_empty():
		# Partition rejected edges so we can prioritize existing lines over diagonals
		var original_rejects = []
		var spatial_rejects = []
		
		for edge in rejected_edges:
			if edge.existed:
				original_rejects.append(edge)
			else:
				spatial_rejects.append(edge)
				
		# Shuffle the pools independently
		SeedUtils.shuffle(original_rejects, rng)
		SeedUtils.shuffle(spatial_rejects, rng)
		
		# Stitch them together (Original geometry first, then spatial fallbacks)
		var prioritized_rejects = original_rejects + spatial_rejects
		var count_to_add = int(prioritized_rejects.size() * braid_chance)
		
		for i in range(count_to_add):
			var edge = prioritized_rejects[i]
			if not graph.has_edge(edge.u, edge.v):
				graph.add_edge(edge.u, edge.v)

# --- ALGORITHM A: KRUSKAL (Fast, Global) ---
func _execute_kruskal(graph: GraphRecorder, nodes_list: Array, rad_vec: Vector2, braid_chance: float, original_edges: Dictionary, rejected_out: Array) -> void:
	var potential_edges = []
	var max_radius = max(rad_vec.x, rad_vec.y)
	var added_pairs = {}
	
	# 1. Guarantee all original edges are considered
	for pair in original_edges:
		var u_pos = graph.get_node_pos(pair[0])
		var v_pos = graph.get_node_pos(pair[1])
		potential_edges.append({
			"u": pair[0], "v": pair[1],
			"dist": u_pos.distance_squared_to(v_pos),
			"existed": true
		})
		added_pairs[pair] = true
	
	# 2. Add spatial fallbacks
	for u_id in nodes_list:
		var u_pos = graph.get_node_pos(u_id)
		var nearby = graph.get_nodes_near_position(u_pos, max_radius)
		
		for v_id in nearby:
			if u_id >= v_id: continue 
			
			var pair = [u_id, v_id]
			if added_pairs.has(pair): continue
			
			var v_pos = graph.get_node_pos(v_id)
			var dx = abs(u_pos.x - v_pos.x)
			var dy = abs(u_pos.y - v_pos.y)
			
			if (pow(dx / rad_vec.x, 2) + pow(dy / rad_vec.y, 2)) <= 1.0:
				var dist_sq = u_pos.distance_squared_to(v_pos)
				potential_edges.append({ "u": u_id, "v": v_id, "dist": dist_sq, "existed": false })
	
	# Sort: Original edges first, then by distance
	potential_edges.sort_custom(func(a, b): 
		if a.existed != b.existed: return a.existed
		return a.dist < b.dist
	)
	
	var uf = UnionFind.new(nodes_list)
	var edges_count = 0
	var max_edges = nodes_list.size() - 1
	
	for edge in potential_edges:
		if edges_count >= max_edges and braid_chance <= 0.0:
			break
			
		var root_u = uf.find(edge.u)
		var root_v = uf.find(edge.v)
		
		if root_u != root_v:
			uf.union(edge.u, edge.v)
			graph.add_edge(edge.u, edge.v)
			edges_count += 1
		else:
			if braid_chance > 0.0:
				rejected_out.append(edge)

# --- ALGORITHM B: PRIM (Slower, Radial) ---
func _execute_prim(graph: GraphRecorder, nodes_list: Array, rad_vec: Vector2, braid_chance: float, original_edges: Dictionary, rejected_out: Array) -> void:
	var visited = {}
	var start_node = nodes_list[0]
	visited[start_node] = true
	var edges_candidates = []
	var max_radius = max(rad_vec.x, rad_vec.y)
	
	# Fast-lookup adjacency map for original geometry
	var original_adj = {}
	for pair in original_edges:
		if not original_adj.has(pair[0]): original_adj[pair[0]] = []
		if not original_adj.has(pair[1]): original_adj[pair[1]] = []
		original_adj[pair[0]].append(pair[1])
		original_adj[pair[1]].append(pair[0])
	
	var add_candidates = func(u_id):
		var u_pos = graph.get_node_pos(u_id)
		
		# 1. Pull original neighbors
		if original_adj.has(u_id):
			for v_id in original_adj[u_id]:
				if not visited.has(v_id):
					var v_pos = graph.get_node_pos(v_id)
					edges_candidates.append({ "u": u_id, "v": v_id, "dist": u_pos.distance_squared_to(v_pos), "existed": true })
		
		# 2. Pull spatial neighbors
		var nearby = graph.get_nodes_near_position(u_pos, max_radius)
		for v_id in nearby:
			if u_id == v_id: continue
			if visited.has(v_id): continue 
			
			# Sort the strings via array to create a consistent dictionary key
			var pair = [u_id, v_id]
			pair.sort()
			
			if original_edges.has(pair): continue # Already handled above
			
			var v_pos = graph.get_node_pos(v_id)
			var dx = abs(u_pos.x - v_pos.x)
			var dy = abs(u_pos.y - v_pos.y)
			
			if (pow(dx / rad_vec.x, 2) + pow(dy / rad_vec.y, 2)) <= 1.0:
				var dist_sq = u_pos.distance_squared_to(v_pos)
				edges_candidates.append({ "u": u_id, "v": v_id, "dist": dist_sq, "existed": false })

	add_candidates.call(start_node)
	
	var max_iterations = nodes_list.size() * 5 
	var iter = 0
	
	while not edges_candidates.is_empty():
		iter += 1
		if iter > max_iterations: break
		
		# Sort reversed: Smallest distance and existed=true goes to the END for pop_back()
		edges_candidates.sort_custom(func(a, b): 
			if a.existed != b.existed: return not a.existed
			return a.dist > b.dist
		)
		
		var edge = edges_candidates.pop_back()
		
		if visited.has(edge.v):
			if braid_chance > 0.0:
				rejected_out.append(edge)
			continue 
			
		graph.add_edge(edge.u, edge.v)
		visited[edge.v] = true
		
		add_candidates.call(edge.v)
