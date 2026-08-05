class_name AnalysisLongestPath
extends RefCounted

signal calculation_finished(result: Dictionary)

# Thread-safe instance state
var _max_path_len := 0
var _best_path_indices := []
var _iters := 0
var _timeout := false
var _current_max_iters := 100000
var _force_exact := false
var _total_nodes := 0
var _worker_thread: Thread

# Main Entry Point
func calculate_async(graph: Graph, params: Dictionary) -> void:
	_current_max_iters = params.get("longest_path_max_iters", 100000)
	_force_exact = params.get("longest_path_force_exact", false)
	
	var nodes = graph.nodes.keys()
	_total_nodes = nodes.size()
	
	if _total_nodes == 0:
		call_deferred("_on_finished", { "max_path_length": 0, "is_hamiltonian": "No", "method": "Trivial", "path_nodes": [] })
		return
		
	# Map String IDs to fast integer indices
	var id_to_idx = {}
	var idx_to_id = []
	for i in range(_total_nodes):
		id_to_idx[nodes[i]] = i
		idx_to_id.append(nodes[i])
		
	var adj = []
	adj.resize(_total_nodes)
	for i in range(_total_nodes):
		var neighbors = []
		for v in graph.get_neighbors(nodes[i]):
			if id_to_idx.has(v): neighbors.append(id_to_idx[v])
		adj[i] = neighbors
		
	_max_path_len = 0
	_best_path_indices = []
	_iters = 0
	_timeout = false
	
	# Boot the Background Thread
	_worker_thread = Thread.new()
	_worker_thread.start(_run_exact_search.bind(adj, idx_to_id))


# --- BACKGROUND WORKER FUNCS ---

func _run_exact_search(adj: Array, idx_to_id: Array) -> void:
	var visited = []
	visited.resize(_total_nodes)
	for i in range(_total_nodes): visited[i] = false
	
	var current_path = []
	
	# We attempt to start the path from every single node in the graph
	for i in range(_total_nodes):
		# Pruning: If we already found a path that touches every node, we can stop!
		if _timeout or _max_path_len == _total_nodes: break
		_backtrack(i, adj, visited, current_path)
		
	var final_path_ids: Array[String] = []
	for idx in _best_path_indices:
		final_path_ids.append(idx_to_id[idx])
		
	var is_hamil = "Yes" if _max_path_len == _total_nodes else "No"
	
	var result = {}
	if _timeout:
		result = { "max_path_length": _max_path_len, "is_hamiltonian": is_hamil, "method": "Approximation (Exact search timed out at %d iters)" % _iters, "path_nodes": final_path_ids }
	else:
		result = { "max_path_length": _max_path_len, "is_hamiltonian": is_hamil, "method": "Exact (Backtracking DFS in %d iters)" % _iters, "path_nodes": final_path_ids }
		
	call_deferred("_on_finished", result)

func _backtrack(u: int, adj: Array, visited: Array, current_path: Array) -> void:
	if _timeout or _max_path_len == _total_nodes: return
	
	visited[u] = true
	current_path.append(u)
	
	var current_len = current_path.size()
	if current_len > _max_path_len:
		_max_path_len = current_len
		_best_path_indices = current_path.duplicate()
		
	_iters += 1
	if not _force_exact and _iters > _current_max_iters:
		_timeout = true
		visited[u] = false
		current_path.pop_back()
		return
		
	for v in adj[u]:
		if not visited[v]:
			_backtrack(v, adj, visited, current_path)
			if _timeout or _max_path_len == _total_nodes: break
			
	# Backtrack
	visited[u] = false
	current_path.pop_back()


# --- MAIN THREAD RESOLUTION ---

func _on_finished(result: Dictionary) -> void:
	if _worker_thread and _worker_thread.is_alive():
		_worker_thread.wait_to_finish()
	calculation_finished.emit(result)
