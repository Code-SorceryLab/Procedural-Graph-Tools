class_name AnalysisChromatic
extends RefCounted

signal calculation_finished(result: Dictionary)

# Thread-safe instance state
var _best_colors := 0
var _iters := 0
var _timeout := false
var _current_max_iters := 100000
var _force_exact := false
var _worker_thread: Thread

# Main Entry Point
func calculate_async(graph: Graph, params: Dictionary) -> void:
	_current_max_iters = params.get("chromatic_max_iters", 100000)
	_force_exact = params.get("chromatic_force_exact", false)
	
	var nodes = graph.nodes.keys()
	var n = nodes.size()
	
	if n == 0:
		call_deferred("_on_finished", { "chromatic_number": 0, "is_exact": true, "method": "Trivial" })
		return
	if n == 1:
		call_deferred("_on_finished", { "chromatic_number": 1, "is_exact": true, "method": "Trivial" })
		return

	# 1. Sort nodes by degree descending (Welsh-Powell heuristic)
	# This drastically speeds up the exact solver by forcing early conflicts and maximizing pruning.
	var node_degrees = []
	for id in nodes:
		node_degrees.append({"id": id, "deg": graph.get_neighbors(id).size()})
		
	node_degrees.sort_custom(func(a, b): return a.deg > b.deg)
	
	# Map to fast integer indices
	var id_to_idx = {}
	for i in range(n):
		id_to_idx[node_degrees[i].id] = i
		
	var adj = []
	adj.resize(n)
	for i in range(n):
		var neighbors = []
		for v in graph.get_neighbors(node_degrees[i].id):
			if id_to_idx.has(v): neighbors.append(id_to_idx[v])
		adj[i] = neighbors

	# 2. Fast Upper Bound (Greedy Coloring)
	var upper_bound = _greedy_coloring(adj, n)
	
	# If the greedy algorithm colored it in 1 or 2 colors, it's mathematically optimal.
	if upper_bound <= 2:
		call_deferred("_on_finished", { "chromatic_number": upper_bound, "is_exact": true, "method": "Greedy (Mathematically Optimal)" })
		return
		
	_best_colors = upper_bound
	_iters = 0
	_timeout = false
	
	# 3. Boot the Background Thread for NP-Hard Exact Search
	_worker_thread = Thread.new()
	_worker_thread.start(_run_exact_search.bind(adj, n, upper_bound))

# --- BACKGROUND WORKER FUNCS ---

func _run_exact_search(adj: Array, n: int, upper_bound: int) -> void:
	var colors = []
	colors.resize(n)
	for i in range(n): colors[i] = -1
	
	_backtrack(0, 0, adj, colors, n)
	
	var result = {}
	if _timeout:
		result = { "chromatic_number": upper_bound, "is_exact": false, "method": "Greedy (Exact search timed out at %d iters)" % _iters }
	else:
		result = { "chromatic_number": _best_colors, "is_exact": true, "method": "Exact (Backtracking B&B in %d iters)" % _iters }
		
	call_deferred("_on_finished", result)

func _backtrack(node_idx: int, max_color_used: int, adj: Array, colors: Array, n: int) -> void:
	# Pruning Conditions:
	# 1. If we hit timeout.
	# 2. If our best known bound is 2 (minimum for graphs with edges), we can't do better.
	if _timeout or _best_colors <= 2: return
		
	# If we successfully colored all nodes!
	if node_idx == n:
		if max_color_used < _best_colors:
			_best_colors = max_color_used
		return
		
	_iters += 1
	if not _force_exact and _iters > _current_max_iters:
		_timeout = true
		return
		
	# We try assigning a color from 0 up to max_color_used (testing existing colors + 1 new color).
	# PRUNING: We never test a color index >= _best_colors - 1.
	var color_limit = min(max_color_used, _best_colors - 2)
	
	for c in range(color_limit + 1):
		var safe = true
		for neighbor in adj[node_idx]:
			if colors[neighbor] == c:
				safe = false
				break
				
		if safe:
			colors[node_idx] = c
			_backtrack(node_idx + 1, max(max_color_used, c + 1), adj, colors, n)
			colors[node_idx] = -1 # Backtrack
			
			if _timeout: return

# --- MAIN THREAD RESOLUTION ---

func _on_finished(result: Dictionary) -> void:
	if _worker_thread and _worker_thread.is_alive():
		_worker_thread.wait_to_finish()
	calculation_finished.emit(result)

func _greedy_coloring(adj: Array, n: int) -> int:
	var result = []
	result.resize(n)
	for i in range(n): result[i] = -1
	
	result[0] = 0
	var available = []
	available.resize(n)
	for i in range(n): available[i] = true
		
	var max_color = 0
	for u in range(1, n):
		for i in range(n): available[i] = true
			
		for i in adj[u]:
			if result[i] != -1:
				available[result[i]] = false
				
		var cr = 0
		while cr < n:
			if available[cr]: break
			cr += 1
			
		result[u] = cr
		if cr > max_color: max_color = cr
		
	return max_color + 1
