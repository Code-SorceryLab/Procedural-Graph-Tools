class_name GraphEulerian
extends RefCounted

signal calculation_finished(result: Dictionary)

var _worker_thread: Thread

# Main Entry Point
func calculate_async(graph: Graph, params: Dictionary) -> void:
	var nodes = graph.nodes.keys()
	var n = nodes.size()
	
	if n == 0:
		call_deferred("_on_finished", { "has_path": "No", "has_circuit": "No", "odd_nodes": 0, "path_nodes": [] })
		return
		
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
	
	# Boot the Background Thread
	_worker_thread = Thread.new()
	_worker_thread.start(_run_hierholzer.bind(nodes, adj, degree, edge_count))

# --- BACKGROUND WORKER FUNCS ---

func _run_hierholzer(nodes: Array, adj: Dictionary, degree: Dictionary, total_edges: int) -> void:
	var odd_nodes = []
	var start_node = ""
	var edges_exist = total_edges > 0
	
	for id in nodes:
		if degree[id] % 2 != 0:
			odd_nodes.append(id)
		if degree[id] > 0 and start_node == "":
			start_node = id # Pick any node with edges to start
			
	# Mathematical Eulerian Bounds:
	# A graph has an Eulerian Circuit if there are EXACTLY 0 odd degree nodes.
	# A graph has an Eulerian Path if there are EXACTLY 0 or 2 odd degree nodes.
	var has_circuit = (odd_nodes.size() == 0 and edges_exist)
	var has_path = (odd_nodes.size() == 0 or odd_nodes.size() == 2) and edges_exist
	
	var eulerian_route: Array[String] = []
	
	# Only run the routing algorithm if a path actually exists
	if has_path:
		if odd_nodes.size() == 2:
			start_node = odd_nodes[0] # Must start at one of the odd nodes!
			
		# Make a local copy of adjacency so we can "consume" edges
		var local_adj = {}
		for id in nodes:
			local_adj[id] = adj[id].duplicate()
			
		# Hierholzer's Algorithm (Finds the exact path)
		var curr_path = [start_node]
		var circuit = []
		
		while not curr_path.is_empty():
			var curr_v = curr_path.back()
			
			if local_adj[curr_v].size() > 0:
				var next_v = local_adj[curr_v].pop_back()
				# Remove the reverse edge because it's undirected
				local_adj[next_v].erase(curr_v) 
				curr_path.append(next_v)
			else:
				circuit.append(curr_path.pop_back())
				
		circuit.reverse() # Hierholzer builds the path backwards
		
		# If the graph has isolated islands of edges, the circuit won't contain all edges.
		if circuit.size() == total_edges + 1:
			eulerian_route.assign(circuit)
		else:
			# It failed the connectivity check (multiple islands of edges exist)
			has_path = false
			has_circuit = false
			eulerian_route = []

	var result = {
		"has_circuit": "Yes" if has_circuit else "No",
		"has_path": "Yes" if has_path else "No",
		"odd_nodes": odd_nodes.size(),
		"path_nodes": eulerian_route
	}
	
	call_deferred("_on_finished", result)

# --- MAIN THREAD RESOLUTION ---

func _on_finished(result: Dictionary) -> void:
	if _worker_thread and _worker_thread.is_alive():
		_worker_thread.wait_to_finish()
	calculation_finished.emit(result)
