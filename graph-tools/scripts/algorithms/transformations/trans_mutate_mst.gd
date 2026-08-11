class_name MutateMST extends GraphModifier

class UnionFind:
	var parent: Dictionary = {}
	func _init(nodes: Array):
		for id in nodes: parent[id] = id
	func find(i: String) -> String:
		if parent[i] != i: parent[i] = find(parent[i])
		return parent[i]
	func union(i: String, j: String) -> void:
		var root_i = find(i)
		var root_j = find(j)
		if root_i != root_j: parent[root_i] = root_j

func _init() -> void:
	super._init()
	modifier_name = "Prune to MST"
	category = Category.TOPOLOGY

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "algorithm", "label": "Use Kruskal (Fast)", "type": TYPE_BOOL, "default": true, "hint_text": "True = Kruskal (Global shortest path). False = Prim (Radial outward growth)." },
		{ "name": "search_range", "label": "Spatial Range Multiplier", "type": TYPE_FLOAT, "default": 2.5, "min": 1.5, "max": 10.0, "step": 0.5 }
	])
	return s

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	
	var nodes_list = recorder.nodes.keys()
	if nodes_list.is_empty(): return 
	
	var use_kruskal = local_settings.get("algorithm", true)
	var range_mult = float(local_settings.get("search_range", 2.5))
	
	var spacing = GraphSettings.GRID_SPACING
	var radius_vec = spacing * range_mult
	
	# 1. UNDO-SAFE EDGE CLEARING
	var original_edges: Dictionary = {}
	var edges_to_remove: Array = []
	for u_id in recorder.nodes:
		for v_id in recorder.get_neighbors(u_id):
			var pair = [u_id, v_id]
			pair.sort()
			if not original_edges.has(pair):
				original_edges[pair] = true
				edges_to_remove.append(pair)
				
	for pair in edges_to_remove:
		recorder.remove_edge(pair[0], pair[1])
		
	# 2. ROUTE TO ALGORITHM
	if use_kruskal:
		_execute_kruskal(recorder, nodes_list, radius_vec, original_edges)
	else:
		_execute_prim(recorder, nodes_list, radius_vec, original_edges)


# --- ALGORITHM A: KRUSKAL (Global) ---
func _execute_kruskal(recorder: GraphRecorder, nodes_list: Array, rad_vec: Vector2, original_edges: Dictionary) -> void:
	var potential_edges = []
	var added_pairs = {}
	var max_radius = max(rad_vec.x, rad_vec.y)
	
	for pair in original_edges:
		var u_pos = recorder.get_node_pos(pair[0])
		var v_pos = recorder.get_node_pos(pair[1])
		potential_edges.append({ "u": pair[0], "v": pair[1], "dist": u_pos.distance_squared_to(v_pos), "existed": true })
		added_pairs[pair] = true
		
	for u_id in nodes_list:
		var u_pos = recorder.get_node_pos(u_id)
		var nearby = recorder.get_nodes_near_position(u_pos, max_radius)
		for v_id in nearby:
			if u_id >= v_id: continue 
			var pair = [u_id, v_id]
			if added_pairs.has(pair): continue
			
			var v_pos = recorder.get_node_pos(v_id)
			var dx = abs(u_pos.x - v_pos.x)
			var dy = abs(u_pos.y - v_pos.y)
			
			if (pow(dx / rad_vec.x, 2) + pow(dy / rad_vec.y, 2)) <= 1.0:
				potential_edges.append({ "u": u_id, "v": v_id, "dist": u_pos.distance_squared_to(v_pos), "existed": false })

	potential_edges.sort_custom(func(a, b): 
		if a.existed != b.existed: return a.existed
		return a.dist < b.dist
	)
	
	var uf = UnionFind.new(nodes_list)
	var edges_count = 0
	var max_edges = nodes_list.size() - 1
	
	for edge in potential_edges:
		if edges_count >= max_edges: break
		var root_u = uf.find(edge.u)
		var root_v = uf.find(edge.v)
		if root_u != root_v:
			uf.union(edge.u, edge.v)
			recorder.add_edge(edge.u, edge.v)
			edges_count += 1


# --- ALGORITHM B: PRIM (Radial Outward) ---
func _execute_prim(recorder: GraphRecorder, nodes_list: Array, rad_vec: Vector2, original_edges: Dictionary) -> void:
	var visited = {}
	var start_node = nodes_list[0]
	visited[start_node] = true
	var edges_candidates = []
	var max_radius = max(rad_vec.x, rad_vec.y)
	
	var original_adj = {}
	for pair in original_edges:
		if not original_adj.has(pair[0]): original_adj[pair[0]] = []
		if not original_adj.has(pair[1]): original_adj[pair[1]] = []
		original_adj[pair[0]].append(pair[1])
		original_adj[pair[1]].append(pair[0])
		
	var add_candidates = func(u_id):
		var u_pos = recorder.get_node_pos(u_id)
		
		if original_adj.has(u_id):
			for v_id in original_adj[u_id]:
				if not visited.has(v_id):
					var v_pos = recorder.get_node_pos(v_id)
					edges_candidates.append({ "u": u_id, "v": v_id, "dist": u_pos.distance_squared_to(v_pos), "existed": true })
					
		var nearby = recorder.get_nodes_near_position(u_pos, max_radius)
		for v_id in nearby:
			if u_id == v_id: continue
			if visited.has(v_id): continue 
			
			var pair = [u_id, v_id]
			pair.sort()
			if original_edges.has(pair): continue
			
			var v_pos = recorder.get_node_pos(v_id)
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
		
		# Sort reversed so pop_back() gets the SMALLEST distance (and prioritizes existing edges)
		edges_candidates.sort_custom(func(a, b): 
			if a.existed != b.existed: return not a.existed
			return a.dist > b.dist
		)
		
		var edge = edges_candidates.pop_back()
		if visited.has(edge.v): continue 
		
		recorder.add_edge(edge.u, edge.v)
		visited[edge.v] = true
		add_candidates.call(edge.v)
