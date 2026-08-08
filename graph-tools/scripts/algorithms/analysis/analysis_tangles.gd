class_name AnalysisTangle
extends RefCounted

signal calculation_finished(result: Dictionary)
const MAX_BITWISE_NODES = 63

# Instance state variables
var _best_treewidth := 0
var _iters := 0
var _timeout := false
var _current_max_iters := 100000
var _force_exact := false
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
	_current_max_iters = params.get("tangle_max_iters", 100000)
	_force_exact = params.get("tangle_force_exact", false)
	
	var nodes = graph.nodes.keys()
	var n = nodes.size()
	
	if n <= 2:
		return { "treewidth": max(0, n - 1), "is_exact": true, "method": "Trivial" }

	# Extract graph structure safely
	var id_to_idx = {}
	for i in range(n): id_to_idx[nodes[i]] = i
		
	var adj = []
	adj.resize(n)
	for i in range(n):
		var neighbors = []
		for v in graph.get_neighbors(nodes[i]):
			if id_to_idx.has(v): neighbors.append(id_to_idx[v])
		adj[i] = neighbors

	var upper_bound = _greedy_min_degree(adj, n)
	if GraphMetrics._cancel_flag: return {"_was_cancelled": true}
	
	if n <= MAX_BITWISE_NODES:
		var bit_adj = _build_bitmask_adj(adj, n)
		var active_mask = (1 << n) - 1
		
		_best_treewidth = upper_bound
		_iters = 0
		_timeout = false
		
		_branch_and_bound(bit_adj, active_mask, 0, n)
		
		if GraphMetrics._cancel_flag: return {"_was_cancelled": true}
		
		if _timeout:
			return { "treewidth": upper_bound, "is_exact": false, "method": "Greedy (Exact timed out at %d iters)" % _iters }
		else:
			return { "treewidth": _best_treewidth, "is_exact": true, "method": "Exact (Bitwise Branch & Bound in %d iters)" % _iters }
	else:
		return { "treewidth": upper_bound, "is_exact": false, "method": "Greedy (N > 63 prevents 64-bit search)" }

# --- BACKGROUND WORKER FUNCS ---

func _branch_and_bound(adj: Array, active_mask: int, current_max_width: int, n: int) -> void:
	# Catch global abort and trigger the timeout collapse
	if GraphMetrics._cancel_flag: _timeout = true 
	
	if _timeout or current_max_width >= _best_treewidth: return 
	
	if active_mask == 0:
		_best_treewidth = current_max_width
		return
		
	_iters += 1
	if not _force_exact and _iters > _current_max_iters:
		_timeout = true
		return
		
	for u in range(n):
		if (active_mask & (1 << u)) != 0:
			var neighbors_mask = adj[u] & active_mask
			
			var deg = 0
			var temp = neighbors_mask
			while temp > 0:
				temp &= (temp - 1)
				deg += 1
				
			var new_width = max(current_max_width, deg)
			if new_width >= _best_treewidth: continue 
				
			var next_adj = adj.duplicate()
			var next_mask = active_mask & ~(1 << u)
			
			for v in range(n):
				if (neighbors_mask & (1 << v)) != 0:
					next_adj[v] |= neighbors_mask
					next_adj[v] &= ~(1 << v) 
					
			_branch_and_bound(next_adj, next_mask, new_width, n)

func _greedy_min_degree(original_adj: Array, n: int) -> int:
	var adj = original_adj.duplicate(true)
	var active = []
	for i in range(n): active.append(true)
	
	var max_clique_size = 0
	var nodes_left = n
	
	while nodes_left > 0:
		if GraphMetrics._cancel_flag: break # Fast abort for greedy
		
		var min_deg = INF
		var best_u = -1
		
		for i in range(n):
			if active[i]:
				var deg = adj[i].size()
				if deg < min_deg:
					min_deg = deg
					best_u = i
					
		if best_u == -1: break
			
		max_clique_size = max(max_clique_size, min_deg)
		active[best_u] = false
		nodes_left -= 1
		
		var neighbors = adj[best_u]
		for v in neighbors:
			if not active[v]: continue
			for w in neighbors:
				if v != w and active[w] and not adj[v].has(w):
					adj[v].append(w)
					
	return max_clique_size

func _build_bitmask_adj(adj: Array, n: int) -> Array:
	var bit_adj = []
	bit_adj.resize(n)
	for i in range(n):
		var mask = 0
		for v in adj[i]:
			mask |= (1 << v)
		bit_adj[i] = mask
	return bit_adj
