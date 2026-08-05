class_name GraphTangle
extends RefCounted

# We emit this when the background thread completes!
signal calculation_finished(result: Dictionary)

const MAX_BITWISE_NODES = 63

# Instance state variables (Thread-Safe)
var _best_treewidth := 0
var _iters := 0
var _timeout := false
var _current_max_iters := 100000
var _force_exact := false

var _worker_thread: Thread

# Main Entry Point (Called from Main Thread)
func calculate_async(graph: Graph, params: Dictionary) -> void:
	_current_max_iters = params.get("tangle_max_iters", 100000)
	_force_exact = params.get("tangle_force_exact", false)
	
	var nodes = graph.nodes.keys()
	var n = nodes.size()
	
	if n <= 2:
		call_deferred("_on_finished", { "treewidth": max(0, n - 1), "is_exact": true, "method": "Trivial" })
		return

	# Extract graph structure safely on the MAIN thread before booting the worker
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
	
	if n <= MAX_BITWISE_NODES:
		var bit_adj = _build_bitmask_adj(adj, n)
		var active_mask = (1 << n) - 1
		
		_best_treewidth = upper_bound
		_iters = 0
		_timeout = false
		
		# --- BOOT THE BACKGROUND THREAD ---
		_worker_thread = Thread.new()
		_worker_thread.start(_run_exact_search.bind(bit_adj, active_mask, n, upper_bound))
	else:
		call_deferred("_on_finished", { "treewidth": upper_bound, "is_exact": false, "method": "Greedy (N > 63 prevents 64-bit search)" })


# --- BACKGROUND WORKER FUNCS ---

func _run_exact_search(bit_adj: Array, active_mask: int, n: int, upper_bound: int) -> void:
	# This runs on a separate CPU core! It will not block the Godot Editor.
	_branch_and_bound(bit_adj, active_mask, 0, n)
	
	var result = {}
	if _timeout:
		result = { "treewidth": upper_bound, "is_exact": false, "method": "Greedy (Exact timed out at %d iters)" }
	else:
		result = { "treewidth": _best_treewidth, "is_exact": true, "method": "Exact (Bitwise Branch & Bound in %d iters)" % _iters }
		
	# Route the result safely back to the Main Thread
	call_deferred("_on_finished", result)

func _branch_and_bound(adj: Array, active_mask: int, current_max_width: int, n: int) -> void:
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


# --- MAIN THREAD RESOLUTION ---

func _on_finished(result: Dictionary) -> void:
	# Clean up the thread and broadcast the data to GraphMetrics
	if _worker_thread and _worker_thread.is_alive():
		_worker_thread.wait_to_finish()
	calculation_finished.emit(result)

func _greedy_min_degree(original_adj: Array, n: int) -> int:
	var adj = original_adj.duplicate(true)
	var active = []
	for i in range(n): active.append(true)
	
	var max_clique_size = 0
	var nodes_left = n
	
	while nodes_left > 0:
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
