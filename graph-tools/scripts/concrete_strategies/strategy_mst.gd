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

func get_settings() -> Array[Dictionary]:
	return [
		{
			"name": "algorithm",
			"type": TYPE_BOOL, # Boolean toggle for simplicity
			"default": true,
			"hint": GraphSettings.PARAM_TOOLTIPS.mst.algo,
			# We can use a custom hint string to make the checkbox text clearer if using Inspector,
			# but for your UI builder, a Bool is simplest. 
			# True = Kruskal, False = Prim
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
	]

func execute(graph: GraphRecorder, params: Dictionary) -> void:
	var nodes_list = graph.nodes.keys()
	if nodes_list.is_empty():
		return 
	
	var use_kruskal = params.get("algorithm", true)
	var range_mult = float(params.get("search_range", 2.5))
	var braid_chance = int(params.get("braid_chance", 0)) / 100.0
	var cell_size = GraphSettings.CELL_SIZE
	var search_radius = cell_size * range_mult
	
	# ==========================================================================
	# 1. UNDO-SAFE EDGE CLEARING
	# ==========================================================================
	var edges_to_remove: Array = []
	var processed_pairs: Dictionary = {}
	
	for u_id in graph.nodes:
		for v_id in graph.get_neighbors(u_id):
			var pair = [u_id, v_id]
			pair.sort()
			if not processed_pairs.has(pair):
				processed_pairs[pair] = true
				edges_to_remove.append(pair)
	
	for pair in edges_to_remove:
		graph.remove_edge(pair[0], pair[1])
		
	# Shared container for rejected edges (for Braiding)
	var rejected_edges = []
	
	# ==========================================================================
	# 2. ALGORITHM SELECTION
	# ==========================================================================
	
	if use_kruskal:
		_execute_kruskal(graph, nodes_list, search_radius, braid_chance, rejected_edges)
	else:
		_execute_prim(graph, nodes_list, search_radius, braid_chance, rejected_edges)

	# ==========================================================================
	# 3. BRAIDING (Restore Loops)
	# ==========================================================================
	if braid_chance > 0.0 and not rejected_edges.is_empty():
		rejected_edges.shuffle()
		var count_to_add = int(rejected_edges.size() * braid_chance)
		
		for i in range(count_to_add):
			var edge = rejected_edges[i]
			if not graph.has_edge(edge.u, edge.v):
				graph.add_edge(edge.u, edge.v)


# --- ALGORITHM A: KRUSKAL (Fast, Global) ---
func _execute_kruskal(graph: GraphRecorder, nodes_list: Array, radius: float, braid_chance: float, rejected_out: Array) -> void:
	# A. Collect Edges
	var potential_edges = []
	
	for u_id in nodes_list:
		var u_pos = graph.get_node_pos(u_id)
		var nearby = graph.get_nodes_near_position(u_pos, radius)
		
		for v_id in nearby:
			if u_id == v_id: continue
			if u_id > v_id: continue # Unique pairs only
			
			var dist_sq = u_pos.distance_squared_to(graph.get_node_pos(v_id))
			potential_edges.append({ "u": u_id, "v": v_id, "dist": dist_sq })
	
	# B. Sort Once
	potential_edges.sort_custom(func(a, b): return a.dist < b.dist)
	
	# C. Union-Find
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
func _execute_prim(graph: GraphRecorder, nodes_list: Array, radius: float, braid_chance: float, rejected_out: Array) -> void:
	var visited = {}
	var start_node = nodes_list[0]
	visited[start_node] = true
	
	var edges_candidates = []
	
	# Helper to add local candidates
	var add_candidates = func(u_id):
		var u_pos = graph.get_node_pos(u_id)
		var nearby = graph.get_nodes_near_position(u_pos, radius)
		
		for v_id in nearby:
			if u_id == v_id: continue
			if visited.has(v_id): continue 
			
			var dist_sq = u_pos.distance_squared_to(graph.get_node_pos(v_id))
			edges_candidates.append({ "u": u_id, "v": v_id, "dist": dist_sq })

	add_candidates.call(start_node)
	
	# Safety Break for Prim on huge graphs
	var max_iterations = nodes_list.size() * 5 
	var iter = 0
	
	while not edges_candidates.is_empty():
		iter += 1
		if iter > max_iterations: break
		
		# Sorting every loop is the bottleneck!
		# Use largest distance at start so we can pop_back (cheapest array op)
		edges_candidates.sort_custom(func(a, b): return a.dist > b.dist)
		
		var edge = edges_candidates.pop_back()
		
		if visited.has(edge.v):
			if braid_chance > 0.0:
				rejected_out.append(edge)
			continue 
			
		graph.add_edge(edge.u, edge.v)
		visited[edge.v] = true
		
		add_candidates.call(edge.v)
