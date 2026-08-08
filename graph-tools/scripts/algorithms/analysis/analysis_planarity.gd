class_name AnalysisPlanarity
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
	var v_count = nodes.size()
	
	if v_count <= 3:
		return { "is_planar": true, "reason": "Trivially planar (V <= 3)" }
		
	# Extract graph structure safely
	var adj = {}
	var edges = []
	var processed = {}
	
	for id in nodes:
		adj[id] = graph.get_neighbors(id).duplicate()
		
	for key in graph.edge_store:
		var e = graph.edge_store[key]
		var pair = [e.u, e.v]; pair.sort()
		if not processed.has(pair):
			processed[pair] = true
			edges.append(pair)
			
	var edge_count = edges.size()
	
	# 1. Euler's Maximal Bound (Fast Reject)
	var max_edges = (3 * v_count) - 6
	if edge_count > max_edges:
		return { "is_planar": false, "reason": "Fails Euler's Bound (E=%d > 3V-6=%d)" % [edge_count, max_edges] }
		
	# 2. Bipartite Tight Bound (Fast Reject)
	if _check_bipartite(adj, nodes):
		var max_bip = (2 * v_count) - 4
		if edge_count > max_bip:
			return { "is_planar": false, "reason": "Fails Bipartite Euler Bound (E=%d > 2V-4=%d)" % [edge_count, max_bip] }

	# 3. Tarjan's Biconnected Component Extraction
	var bccs = _get_bccs(adj, nodes)
	if GraphMetrics._cancel_flag: return { "_was_cancelled": true }
	
	# 4. Exact DMP Topological Embedding Test
	for bcc in bccs:
		if GraphMetrics._cancel_flag: break
		if not _dmp_is_planar(bcc.nodes, bcc.edges):
			return { "is_planar": false, "reason": "Failed DMP Path Routing (Kuratowski Tangle detected in a biconnected core)" }

	if GraphMetrics._cancel_flag: return { "_was_cancelled": true }

	return { "is_planar": true, "reason": "Passes exact DMP (Demoucron, Malgrange, Pertuiset) topological embedding" }


# ==============================================================================
# EXACT DMP PLANARITY TESTER
# ==============================================================================

func _dmp_is_planar(bcc_nodes: Array, bcc_edges: Array) -> bool:
	var cycle = _find_cycle(bcc_edges)
	if cycle.is_empty(): return true
		
	var faces = [cycle.duplicate(), cycle.duplicate()]
	faces[1].reverse()
	
	var emb_nodes = {}
	for n in cycle: emb_nodes[n] = true
	
	var emb_edges = {}
	for i in range(cycle.size()):
		var pair = [cycle[i], cycle[(i + 1) % cycle.size()]]; pair.sort()
		emb_edges[pair] = true
		
	while emb_edges.size() < bcc_edges.size():
		if GraphMetrics._cancel_flag: return false
		
		var unembedded = []
		for e in bcc_edges:
			if not emb_edges.has(e): unembedded.append(e)
			
		var fragments = _get_fragments(unembedded, emb_nodes)
		if fragments.is_empty(): break
		
		var best_frag = null
		var best_admissible = []
		
		for frag in fragments:
			var admissible = []
			for face in faces:
				var has_all = true
				for c in frag.contacts:
					if not face.has(c):
						has_all = false
						break
				if has_all: admissible.append(face)
				
			if admissible.is_empty(): return false
			
			if best_frag == null or admissible.size() < best_admissible.size():
				best_frag = frag
				best_admissible = admissible
				
		var chosen_face = best_admissible[0]
		var path = _find_path_in_fragment(best_frag)
		
		faces.erase(chosen_face)
		var new_faces = _split_face(chosen_face, path)
		faces.append(new_faces[0])
		faces.append(new_faces[1])
		
		for n in path: emb_nodes[n] = true
		for i in range(path.size() - 1):
			var pair = [path[i], path[i+1]]; pair.sort()
			emb_edges[pair] = true
			
	return true

# --- DMP SUBROUTINES ---

func _get_fragments(unembedded: Array, emb_nodes: Dictionary) -> Array:
	var fragments = []
	var visited = {}
	
	var adj = {}
	for e in unembedded:
		if not adj.has(e[0]): adj[e[0]] = []
		if not adj.has(e[1]): adj[e[1]] = []
		adj[e[0]].append(e)
		adj[e[1]].append(e)
		
	for e in unembedded:
		if visited.has(e): continue
		
		var f_edges = []
		var f_nodes = {}
		var contacts = {}
		var q = [e]
		visited[e] = true
		
		while not q.is_empty():
			if GraphMetrics._cancel_flag: return []
			
			var curr = q.pop_front()
			f_edges.append(curr)
			
			for v in curr:
				f_nodes[v] = true
				if emb_nodes.has(v):
					contacts[v] = true
				else:
					if adj.has(v):
						for next_e in adj[v]:
							if not visited.has(next_e):
								visited[next_e] = true
								q.append(next_e)
								
		fragments.append({"edges": f_edges, "contacts": contacts.keys()})
	return fragments

func _find_path_in_fragment(frag: Dictionary) -> Array:
	var c1 = frag.contacts[0]
	var c2 = frag.contacts[1]
	
	if frag.edges.size() == 1: return [c1, c2]
		
	var adj = {}
	for e in frag.edges:
		if not adj.has(e[0]): adj[e[0]] = []
		if not adj.has(e[1]): adj[e[1]] = []
		adj[e[0]].append(e[1])
		adj[e[1]].append(e[0])
		
	var q = [ [c1] ]
	var visited = { c1: true }
	
	while not q.is_empty():
		if GraphMetrics._cancel_flag: return []
		
		var p = q.pop_front()
		var curr = p.back()
		if curr == c2: return p
		
		if adj.has(curr):
			for v in adj[curr]:
				if not visited.has(v):
					visited[v] = true
					var new_p = p.duplicate()
					new_p.append(v)
					q.append(new_p)
	return []

func _split_face(face: Array, path: Array) -> Array:
	var c1 = path[0]
	var c2 = path[path.size() - 1]
	
	var idx1 = face.find(c1)
	var rot_face = []
	for i in range(face.size()): rot_face.append(face[(idx1 + i) % face.size()])
		
	var idx2 = rot_face.find(c2)
	var faceA = []
	var faceB = []
	
	for i in range(idx2 + 1): faceA.append(rot_face[i])
	for i in range(path.size() - 2, 0, -1): faceA.append(path[i])
		
	for i in range(idx2, rot_face.size()): faceB.append(rot_face[i])
	if faceB.back() != rot_face[0]: faceB.append(rot_face[0])
	for i in range(1, path.size() - 1): faceB.append(path[i])
		
	return [faceA, faceB]

# ==============================================================================
# STRUCTURAL EXTRACTION SUBROUTINES
# ==============================================================================

func _get_bccs(adj: Dictionary, nodes: Array) -> Array:
	var time = 0
	var disc = {}; var low = {}; var parent = {}; var visited = {}
	var edge_stack = []; var bccs = []
	
	for start_node in nodes:
		if visited.has(start_node): continue
		var stack = [{"u": start_node, "neighbors": adj[start_node], "idx": 0}]
		disc[start_node] = time
		low[start_node] = time
		time += 1
		parent[start_node] = null
		visited[start_node] = true
		
		while not stack.is_empty():
			if GraphMetrics._cancel_flag: return []
			
			var frame = stack.back()
			var u = frame.u
			
			if frame.idx < frame.neighbors.size():
				var v = frame.neighbors[frame.idx]
				frame.idx += 1
				if v == parent[u]: continue
				var pair = [u, v]; pair.sort()
				
				if not visited.has(v):
					edge_stack.append(pair)
					parent[v] = u
					visited[v] = true
					disc[v] = time
					low[v] = time
					time += 1
					stack.append({"u": v, "neighbors": adj[v], "idx": 0})
				elif disc[v] < disc[u]:
					edge_stack.append(pair)
					low[u] = min(low[u], disc[v])
			else:
				stack.pop_back()
				if not stack.is_empty():
					var p = stack.back().u
					low[p] = min(low[p], low[u])
					
					if low[u] >= disc[p]:
						var bcc_edges = []
						var bcc_nodes = {}
						while not edge_stack.is_empty():
							var e = edge_stack.pop_back()
							bcc_edges.append(e)
							bcc_nodes[e[0]] = true
							bcc_nodes[e[1]] = true
							if (e[0] == p and e[1] == u) or (e[1] == p and e[0] == u): break
						if bcc_nodes.size() > 2:
							bccs.append({"nodes": bcc_nodes.keys(), "edges": bcc_edges})
	return bccs

func _find_cycle(edges: Array) -> Array:
	var adj = {}
	for e in edges:
		if not adj.has(e[0]): adj[e[0]] = []
		if not adj.has(e[1]): adj[e[1]] = []
		adj[e[0]].append(e[1])
		adj[e[1]].append(e[0])
		
	var start = adj.keys()[0]
	var stack = [{"u": start, "p": null, "path": [start]}]
	var vis = {}
	
	while not stack.is_empty():
		if GraphMetrics._cancel_flag: return []
		
		var frame = stack.pop_back()
		var u = frame.u
		vis[u] = true
		
		for v in adj[u]:
			if v == frame.p: continue
			if vis.has(v):
				var idx = frame.path.find(v)
				var cycle = []
				for i in range(idx, frame.path.size()): cycle.append(frame.path[i])
				return cycle
			else:
				var new_path = frame.path.duplicate()
				new_path.append(v)
				stack.append({"u": v, "p": u, "path": new_path})
	return []

func _check_bipartite(adj: Dictionary, nodes: Array) -> bool:
	var colors = {}
	for start_node in nodes:
		if colors.has(start_node): continue
		var queue = [start_node]
		colors[start_node] = 0
		
		while not queue.is_empty():
			if GraphMetrics._cancel_flag: return false 
			
			var curr = queue.pop_front()
			var current_color = colors[curr]
			var next_color = 1 - current_color
			
			for neighbor in adj[curr]:
				if not colors.has(neighbor):
					colors[neighbor] = next_color
					queue.append(neighbor)
				elif colors[neighbor] == current_color:
					return false
	return true
