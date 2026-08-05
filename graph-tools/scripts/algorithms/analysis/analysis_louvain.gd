class_name AnalysisLouvain
extends RefCounted

signal calculation_finished(result: Dictionary)

var _worker_thread: Thread

# Main Entry Point
func calculate_async(graph: Graph, params: Dictionary) -> void:
	var nodes = graph.nodes.keys()
	var n = nodes.size()

	if n == 0:
		call_deferred("_on_finished", { "communities": 0, "modularity": 0.0, "communities_map": {} })
		return

	var adj = {}
	var m2 = 0 # 2 * m (sum of all degrees in the graph)
	
	for id in nodes:
		var neighbors = graph.get_neighbors(id)
		adj[id] = neighbors.duplicate()
		m2 += neighbors.size()

	if m2 == 0:
		call_deferred("_on_finished", { "communities": n, "modularity": 0.0, "communities_map": {} })
		return

	# Boot the Background Thread
	_worker_thread = Thread.new()
	_worker_thread.start(_run_louvain.bind(nodes, adj, m2))

# --- BACKGROUND WORKER FUNCS ---

func _run_louvain(nodes: Array, adj: Dictionary, m2: int) -> void:
	# 1. Initialize: Every node starts in its own isolated community
	var com = {}
	var tot = {} # sum of degrees of nodes in community C
	var deg = {} # degree of node i

	for id in nodes:
		com[id] = id
		var d = adj[id].size()
		deg[id] = d
		tot[id] = d

	var improvement = true
	var iters = 0
	var max_iters = 100 # Safety valve (Louvain usually converges in <10 iterations)

	# 2. Local Optimization Phase
	while improvement and iters < max_iters:
		improvement = false
		iters += 1

		for i in nodes:
			var c_i = com[i]
			var k_i = deg[i]

			# Count edges connecting node i to each neighboring community
			var k_i_in = {}
			for neighbor in adj[i]:
				var c_neighbor = com[neighbor]
				k_i_in[c_neighbor] = k_i_in.get(c_neighbor, 0) + 1

			# Temporarily remove node i from its current community
			tot[c_i] -= k_i

			var best_c = c_i
			var best_dq = 0.0

			# Evaluate Modularity change (Delta Q) for moving to a neighboring community
			for c_neighbor in k_i_in.keys():
				var k_in = k_i_in[c_neighbor]
				var s_tot = tot[c_neighbor]
				
				# Louvain Delta Q Formula
				var dq = float(k_in) - float(s_tot * k_i) / float(m2)
				
				if dq > best_dq:
					best_dq = dq
					best_c = c_neighbor

			# Move to the best community
			com[i] = best_c
			tot[best_c] += k_i

			if best_c != c_i:
				improvement = true

	# 3. Clean up the community indices (0, 1, 2, 3...)
	var unique_coms = {}
	var com_id_counter = 0
	var final_map = {}

	for id in nodes:
		var c = com[id]
		if not unique_coms.has(c):
			unique_coms[c] = com_id_counter
			com_id_counter += 1
		final_map[id] = unique_coms[c]

	# 4. Calculate Final Modularity (Q)
	var q = 0.0
	for i in nodes:
		for j in adj[i]:
			if com[i] == com[j]:
				q += 1.0 - float(deg[i] * deg[j]) / float(m2)
	q /= float(m2)

	var result = {
		"communities": com_id_counter,
		"modularity": snapped(q, 0.001),
		"communities_map": final_map
	}

	call_deferred("_on_finished", result)

# --- MAIN THREAD RESOLUTION ---

func _on_finished(result: Dictionary) -> void:
	if _worker_thread and _worker_thread.is_alive():
		_worker_thread.wait_to_finish()
	calculation_finished.emit(result)
