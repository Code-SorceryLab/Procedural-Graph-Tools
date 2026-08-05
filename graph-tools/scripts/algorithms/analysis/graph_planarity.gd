class_name GraphPlanarity
extends RefCounted

# The master entry point. Returns a dictionary with the boolean result and a mathematical reason.
static func check_planarity(graph: Graph) -> Dictionary:
	var nodes = graph.nodes.keys()
	var v_count = nodes.size()
	
	# 1. Trivial Check
	if v_count <= 3:
		return { "is_planar": true, "reason": "Trivially planar (V <= 3)" }
		
	# Count undirected edges cleanly
	var edge_count = 0
	var processed = {}
	for key in graph.edge_store:
		var e = graph.edge_store[key]
		var pair = [e.u, e.v]
		pair.sort()
		if not processed.has(pair):
			processed[pair] = true
			edge_count += 1
			
	# 2. Euler's Maximal Bound (Fast Reject)
	var max_edges = (3 * v_count) - 6
	if edge_count > max_edges:
		return { "is_planar": false, "reason": "Fails Euler's Bound (E=%d > 3V-6=%d)" % [edge_count, max_edges] }
		
	# 3. Bipartite Tight Bound (Fast Reject)
	var is_bipartite = _check_bipartite(graph, nodes)
	if is_bipartite:
		var max_bipartite_edges = (2 * v_count) - 4
		if edge_count > max_bipartite_edges:
			return { "is_planar": false, "reason": "Fails Bipartite Euler Bound (E=%d > 2V-4=%d)" % [edge_count, max_bipartite_edges] }

	# 4. Topological Spanning Tree Test (Left-Right Bipartite Conflict Graph)
	var structural_check = _run_dfs_conflict_test(graph, nodes)
	if not structural_check:
		return { "is_planar": false, "reason": "Contains interlacing back-edges (Kuratowski Subgraph detected)" }

	return { "is_planar": true, "reason": "Passes all structural topology bounds" }

# --- MATH SUBROUTINES ---

static func _check_bipartite(graph: Graph, nodes: Array) -> bool:
	var colors = {}
	for start_node in nodes:
		if colors.has(start_node): continue
		var queue = [start_node]
		colors[start_node] = 0
		
		while not queue.is_empty():
			var curr = queue.pop_front()
			var current_color = colors[curr]
			var next_color = 1 - current_color
			
			for neighbor in graph.get_neighbors(curr):
				if not colors.has(neighbor):
					colors[neighbor] = next_color
					queue.append(neighbor)
				elif colors[neighbor] == current_color:
					return false
	return true

# Builds a strict DFS Spanning Tree, identifies back-edges, and builds a 
# Conflict Graph to check if they can be safely routed Left and Right.
static func _run_dfs_conflict_test(graph: Graph, nodes: Array) -> bool:
	var entry = {}
	var exit = {}
	var depth = {}
	var time = 0
	var back_edges = []
	var visited = {}
	
	# 1. Build the DFS Tree
	for start_node in nodes:
		if visited.has(start_node): continue
		
		# Frame: { "u": node, "p": parent, "neighbors": [...], "idx": 0 }
		var stack = []
		stack.append({"u": start_node, "p": null, "neighbors": graph.get_neighbors(start_node), "idx": 0})
		
		visited[start_node] = true
		depth[start_node] = 0
		entry[start_node] = time
		time += 1
		
		while not stack.is_empty():
			var frame = stack.back()
			var u = frame.u
			var p = frame.p
			
			if frame.idx < frame.neighbors.size():
				var v = frame.neighbors[frame.idx]
				frame.idx += 1
				
				if not visited.has(v):
					visited[v] = true
					depth[v] = depth[u] + 1
					entry[v] = time
					time += 1
					stack.append({"u": v, "p": u, "neighbors": graph.get_neighbors(v), "idx": 0})
				elif v != p and entry[v] < entry[u]:
					# Back-edge found! v is the ancestor, u is the descendant.
					back_edges.append({"anc": v, "desc": u})
			else:
				exit[u] = time
				time += 1
				stack.pop_back()
				
	# 2. Build the Conflict Graph
	var conflict_adj = []
	conflict_adj.resize(back_edges.size())
	for i in range(back_edges.size()): conflict_adj[i] = []
	
	for i in range(back_edges.size()):
		for j in range(i + 1, back_edges.size()):
			if _edges_interlace(back_edges[i], back_edges[j], entry, exit, depth):
				conflict_adj[i].append(j)
				conflict_adj[j].append(i)
				
	# 3. 2-Color (Left/Right) the Conflict Graph
	var colors = {}
	for i in range(back_edges.size()):
		if colors.has(i): continue
			
		var queue = [i]
		colors[i] = 0
		
		while not queue.is_empty():
			var curr = queue.pop_front()
			var c = colors[curr]
			var next_c = 1 - c
			
			for neighbor in conflict_adj[curr]:
				if not colors.has(neighbor):
					colors[neighbor] = next_c
					queue.append(neighbor)
				elif colors[neighbor] == c:
					# Two conflicting edges were forced onto the same side of the tree!
					# The graph is non-planar.
					return false
					
	return true

# Two back-edges conflict ONLY if they are on the exact same branch and their depths alternate.
static func _edges_interlace(e1: Dictionary, e2: Dictionary, entry: Dictionary, exit: Dictionary, depth: Dictionary) -> bool:
	var anc1 = e1.anc; var desc1 = e1.desc
	var anc2 = e2.anc; var desc2 = e2.desc
	
	# Check if they are on the same branch (one descendant is an ancestor of the other)
	var same_branch = (entry[desc1] <= entry[desc2] and exit[desc1] >= exit[desc2]) or \
					  (entry[desc2] <= entry[desc1] and exit[desc2] >= exit[desc1])
					
	if same_branch:
		var d_a1 = depth[anc1]; var d_d1 = depth[desc1]
		var d_a2 = depth[anc2]; var d_d2 = depth[desc2]
		
		# Do their endpoints mathematically alternate along the branch?
		if d_a1 < d_a2 and d_a2 < d_d1 and d_d1 < d_d2: return true
		if d_a2 < d_a1 and d_a1 < d_d2 and d_d2 < d_d1: return true
		
	return false
