class_name AnalysisSpectral
extends RefCounted

signal calculation_finished(result: Dictionary)
var _worker_thread: Thread

# ==============================================================================
# 1. ASYNC ENDPOINT (Used by UI / GraphMetrics)
# ==============================================================================
func calculate_async(graph: Graph, params: Dictionary = {}) -> void:
	_worker_thread = Thread.new()
	_worker_thread.start(_thread_runner.bind(graph, params))

func _thread_runner(graph: Graph, params: Dictionary) -> void:
	var result = calculate(graph, params)
	call_deferred("_on_finished", result)

func _on_finished(result: Dictionary) -> void:
	if _worker_thread and _worker_thread.is_started():
		_worker_thread.wait_to_finish()
	calculation_finished.emit(result)

# ==============================================================================
# 2. SYNC ENDPOINT (Used by ExperimentRunner)
# ==============================================================================
func calculate(graph: Graph, params: Dictionary = {}) -> Dictionary:
	var nodes = graph.nodes.keys()
	var n = nodes.size()

	if n <= 1:
		return { "fiedler_value": 0.0, "side_a": nodes, "side_b": [], "cut_edges": [] }

	# Extract safely on Main Thread
	var node_to_idx = {}
	var idx_to_node = []
	for i in range(n):
		node_to_idx[nodes[i]] = i
		idx_to_node.append(nodes[i])
		
	var d = []
	var adj = []
	var max_d = 0
	
	for i in range(n):
		var id = idx_to_node[i]
		var neighbors = graph.get_neighbors(id)
		var idx_neighbors = []
		for neighbor in neighbors:
			if node_to_idx.has(neighbor):
				idx_neighbors.append(node_to_idx[neighbor])
				
		adj.append(idx_neighbors)
		d.append(idx_neighbors.size())
		if idx_neighbors.size() > max_d: max_d = idx_neighbors.size()

	var edge_pairs = []
	var processed = {}
	for key in graph.edge_store:
		var e = graph.edge_store[key]
		var pair = [e.u, e.v]
		pair.sort()
		if not processed.has(pair):
			processed[pair] = true
			edge_pairs.append(pair)
			
	var c = float(2 * max_d + 1)
	var v = []
	v.resize(n)
	for i in range(n): v[i] = randf_range(-1.0, 1.0)
		
	_orthogonalize_and_normalize(v)
	
	var max_iters = 1000
	var tolerance = 0.00001
	
	for iter in range(max_iters):
		if GraphMetrics._cancel_flag: 
			return {"_was_cancelled": true}
			
		var v_next = []
		v_next.resize(n)
		
		for i in range(n):
			var L_vi = d[i] * v[i]
			for j in adj[i]: L_vi -= v[j]
			v_next[i] = c * v[i] - L_vi
			
		_orthogonalize_and_normalize(v_next)
		
		var diff = 0.0
		for i in range(n): diff += abs(v_next[i] - v[i])
			
		v = v_next
		if diff < tolerance: break
			
	var fiedler_value = 0.0
	for i in range(n):
		var L_vi = d[i] * v[i]
		for j in adj[i]: L_vi -= v[j]
		fiedler_value += v[i] * L_vi
		
	var side_a = []
	var side_b = []
	for i in range(n):
		if v[i] >= 0.0: side_a.append(idx_to_node[i])
		else: side_b.append(idx_to_node[i])
			
	var cut_edges = []
	for pair in edge_pairs:
		var is_u_a = v[node_to_idx[pair[0]]] >= 0.0
		var is_v_a = v[node_to_idx[pair[1]]] >= 0.0
		if is_u_a != is_v_a: cut_edges.append(pair)
			
	return {
		"fiedler_value": snapped(fiedler_value, 0.001),
		"side_a": side_a,
		"side_b": side_b,
		"cut_edges": cut_edges
	}

# --- MATH HELPER ---
func _orthogonalize_and_normalize(v: Array) -> void:
	var n = v.size()
	var sum = 0.0
	for i in range(n): sum += v[i]
	var mean = sum / float(n)
	
	var norm_sq = 0.0
	for i in range(n):
		v[i] -= mean
		norm_sq += v[i] * v[i]
		
	var norm = sqrt(norm_sq)
	if norm > 0.000001:
		for i in range(n): v[i] /= norm
