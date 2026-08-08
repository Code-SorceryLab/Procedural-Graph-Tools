class_name AnalysisEulerian
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
	
	if n == 0:
		return { "has_path": "No", "has_circuit": "No", "odd_nodes": 0, "path_nodes": [] }
		
	# Extract graph adjacency and degrees
	var adj = {}
	var degree = {}
	var edge_count = 0
	
	for id in nodes:
		var neighbors = graph.get_neighbors(id)
		adj[id] = neighbors.duplicate()
		degree[id] = neighbors.size()
		edge_count += neighbors.size()
		
	edge_count /= 2 # Undirected graph edges were counted twice
	
	var odd_nodes = []
	var start_node = ""
	var edges_exist = edge_count > 0
	
	for id in nodes:
		if degree[id] % 2 != 0:
			odd_nodes.append(id)
		if degree[id] > 0 and start_node == "":
			start_node = id # Pick any node with edges to start
			
	var has_circuit = (odd_nodes.size() == 0 and edges_exist)
	var has_path = (odd_nodes.size() == 0 or odd_nodes.size() == 2) and edges_exist
	var eulerian_route: Array[String] = []
	
	# Only run the routing algorithm if a path actually exists
	if has_path:
		if odd_nodes.size() == 2:
			start_node = odd_nodes[0] 
			
		var local_adj = {}
		for id in nodes:
			local_adj[id] = adj[id].duplicate()
			
		var curr_path = [start_node]
		var circuit = []
		
		while not curr_path.is_empty():
			if GraphMetrics._cancel_flag: return {"_was_cancelled": true}
			var curr_v = curr_path.back()
			
			if local_adj[curr_v].size() > 0:
				var next_v = local_adj[curr_v].pop_back()
				local_adj[next_v].erase(curr_v) 
				curr_path.append(next_v)
			else:
				circuit.append(curr_path.pop_back())
				
		circuit.reverse()
		
		if circuit.size() == edge_count + 1:
			eulerian_route.assign(circuit)
		else:
			has_path = false
			has_circuit = false
			eulerian_route = []

	return {
		"has_circuit": "Yes" if has_circuit else "No",
		"has_path": "Yes" if has_path else "No",
		"odd_nodes": odd_nodes.size(),
		"path_nodes": eulerian_route
	}
