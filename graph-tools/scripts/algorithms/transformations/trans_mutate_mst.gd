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
		{ "name": "search_range", "label": "Spatial Range Multiplier", "type": TYPE_FLOAT, "default": 2.5, "min": 1.5, "max": 10.0, "step": 0.5 },
		{ "name": "target_mask", "label": "Target Nodes", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "All Nodes,Affected by Previous Step" }
	])
	return s

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	
	var target_mask = local_settings.get("target_mask", 0)
	var nodes_list = recorder.nodes.keys()
	
	if target_mask == 1:
		nodes_list = []
		var context_nodes = get_context_nodes(false)
		for id in context_nodes:
			if recorder.nodes.has(id): nodes_list.append(id)
			
	if nodes_list.is_empty(): return 
	
	var use_kruskal = local_settings.get("algorithm", true)
	var range_mult = float(local_settings.get("search_range", 2.5))
	var spacing = GraphSettings.GRID_SPACING
	var radius_vec = spacing * range_mult
	
	var node_set = {}
	for id in nodes_list: node_set[id] = true
	
	# Snapshot original edge direction data before removal
	var original_records: Dictionary = {}
	var edges_to_remove: Array = []
	
	for u_id in nodes_list:
		for v_id in recorder.get_neighbors(u_id):
			if not node_set.has(v_id): continue
			
			var pair = [u_id, v_id]
			pair.sort()
			var key_str = pair[0] + "::" + pair[1]
			if original_records.has(key_str): continue
			
			# Determine canonical direction from sorted pair
			var can_fwd_key = recorder.get_edge_key(pair[0], pair[1])
			var can_rev_key = recorder.get_edge_key(pair[1], pair[0])
			
			var has_canon_fwd = recorder.edge_store.has(can_fwd_key)
			var has_canon_rev = recorder.edge_store.has(can_rev_key)
			
			var weight_fwd = recorder.get_edge_weight(pair[0], pair[1])
			var weight_rev = recorder.get_edge_weight(pair[1], pair[0])
			
			var custom_fwd = {}
			if has_canon_fwd:
				custom_fwd = recorder.edge_store[can_fwd_key].custom.duplicate(true)
			var custom_rev = {}
			if has_canon_rev:
				custom_rev = recorder.edge_store[can_rev_key].custom.duplicate(true)
			
			original_records[key_str] = {
				"u": pair[0],
				"v": pair[1],
				"has_fwd": has_canon_fwd,
				"has_rev": has_canon_rev,
				"weight_fwd": weight_fwd,
				"weight_rev": weight_rev,
				"custom_fwd": custom_fwd,
				"custom_rev": custom_rev
			}
			
			edges_to_remove.append(pair)
	
	# Remove all original edges among targeted nodes
	for pair in edges_to_remove:
		recorder.remove_edge(pair[0], pair[1])   # directed=false removes both directions if present
	
	if use_kruskal:
		_execute_kruskal(recorder, nodes_list, radius_vec, original_records, node_set)
	else:
		_execute_prim(recorder, nodes_list, radius_vec, original_records, node_set)

# Helper: add an MST edge, restoring original direction/custom if the edge existed before
func _add_or_restore_edge(recorder: GraphRecorder, edge: Dictionary, original_records: Dictionary) -> void:
	if edge.get("existed", false) and edge.has("key"):
		var key_str: String = edge["key"]
		if original_records.has(key_str):
			var rec: Dictionary = original_records[key_str]
			if rec.has_fwd:
				recorder.add_edge(rec.u, rec.v, rec.weight_fwd, true, rec.custom_fwd)
			if rec.has_rev:
				recorder.add_edge(rec.v, rec.u, rec.weight_rev, true, rec.custom_rev)
		else:
			# Fallback (should not happen)
			recorder.add_edge(edge.u, edge.v, 1.0, false)
	else:
		# New edge: simple undirected default
		recorder.add_edge(edge.u, edge.v, 1.0, false)

func _execute_kruskal(recorder: GraphRecorder, nodes_list: Array, rad_vec: Vector2, original_records: Dictionary, node_set: Dictionary) -> void:
	var potential_edges = []
	var added_pairs = {}
	var max_radius = max(rad_vec.x, rad_vec.y)
	
	# Include original edges with key_str
	for key_str in original_records:
		var rec: Dictionary = original_records[key_str]
		var u_pos = recorder.get_node_pos(rec.u)
		var v_pos = recorder.get_node_pos(rec.v)
		potential_edges.append({
			"u": rec.u,
			"v": rec.v,
			"dist": u_pos.distance_squared_to(v_pos),
			"existed": true,
			"key": key_str
		})
		added_pairs[key_str] = true
	
	# Add new potential edges within radius
	for u_id in nodes_list:
		var u_pos = recorder.get_node_pos(u_id)
		var nearby = recorder.get_nodes_near_position(u_pos, max_radius)
		for v_id in nearby:
			if not node_set.has(v_id): continue
			if u_id >= v_id: continue
			var pair = [u_id, v_id]
			pair.sort()
			var key_str = pair[0] + "::" + pair[1]
			if added_pairs.has(key_str): continue
			
			var v_pos = recorder.get_node_pos(v_id)
			var dx = abs(u_pos.x - v_pos.x)
			var dy = abs(u_pos.y - v_pos.y)
			
			if (pow(dx / rad_vec.x, 2) + pow(dy / rad_vec.y, 2)) <= 1.0:
				potential_edges.append({
					"u": u_id,
					"v": v_id,
					"dist": u_pos.distance_squared_to(v_pos),
					"existed": false,
					"key": key_str
				})
				added_pairs[key_str] = true
	
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
			_add_or_restore_edge(recorder, edge, original_records)
			edges_count += 1

func _execute_prim(recorder: GraphRecorder, nodes_list: Array, rad_vec: Vector2, original_records: Dictionary, node_set: Dictionary) -> void:
	var visited = {}
	var start_node = nodes_list[0]
	visited[start_node] = true
	var edges_candidates = []
	var max_radius = max(rad_vec.x, rad_vec.y)
	
	# Build adjacency from original records for fast candidate generation
	var original_adj = {}
	for key_str in original_records:
		var rec: Dictionary = original_records[key_str]
		if not original_adj.has(rec.u): original_adj[rec.u] = []
		if not original_adj.has(rec.v): original_adj[rec.v] = []
		original_adj[rec.u].append({ "id": rec.v, "key": key_str })
		original_adj[rec.v].append({ "id": rec.u, "key": key_str })
	
	var add_candidates = func(u_id):
		var u_pos = recorder.get_node_pos(u_id)
		
		# Existing original edges
		if original_adj.has(u_id):
			for neighbor_info in original_adj[u_id]:
				var v_id = neighbor_info["id"]
				if visited.has(v_id): continue
				var v_pos = recorder.get_node_pos(v_id)
				edges_candidates.append({
					"u": u_id,
					"v": v_id,
					"dist": u_pos.distance_squared_to(v_pos),
					"existed": true,
					"key": neighbor_info["key"]
				})
		
		# New possible edges within radius
		var nearby = recorder.get_nodes_near_position(u_pos, max_radius)
		for v_id in nearby:
			if not node_set.has(v_id): continue
			if u_id == v_id: continue
			if visited.has(v_id): continue
			
			var pair = [u_id, v_id]
			pair.sort()
			var key_str = pair[0] + "::" + pair[1]
			if original_records.has(key_str): continue
			
			var v_pos = recorder.get_node_pos(v_id)
			var dx = abs(u_pos.x - v_pos.x)
			var dy = abs(u_pos.y - v_pos.y)
			
			if (pow(dx / rad_vec.x, 2) + pow(dy / rad_vec.y, 2)) <= 1.0:
				edges_candidates.append({
					"u": u_id,
					"v": v_id,
					"dist": u_pos.distance_squared_to(v_pos),
					"existed": false,
					"key": key_str
				})
	
	add_candidates.call(start_node)
	var max_iterations = nodes_list.size() * 5
	var iter = 0
	
	while not edges_candidates.is_empty():
		iter += 1
		if iter > max_iterations: break
		
		# Clean sort: existing edges first, then shorter distance
		edges_candidates.sort_custom(func(a, b):
			if a.existed != b.existed: return a.existed
			return a.dist < b.dist
		)
		
		var edge = edges_candidates.pop_front()
		if visited.has(edge.v): continue
		
		_add_or_restore_edge(recorder, edge, original_records)
		visited[edge.v] = true
		add_candidates.call(edge.v)
