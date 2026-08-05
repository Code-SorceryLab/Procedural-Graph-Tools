class_name AnalysisSpectral
extends RefCounted

# Analyzes the graph's Laplacian Matrix to find the Fiedler Vector.
# Returns the Algebraic Connectivity and the optimal bisection cut.
static func analyze_bottlenecks(graph: Graph) -> Dictionary:
	var nodes = graph.nodes.keys()
	var n = nodes.size()

	# Trivial cases
	if n <= 1:
		return { "fiedler_value": 0.0, "side_a": nodes, "side_b": [], "cut_edges": [] }

	# 1. Map string IDs to Matrix Indices
	var node_to_idx = {}
	var idx_to_node = []
	for i in range(n):
		node_to_idx[nodes[i]] = i
		idx_to_node.append(nodes[i])
		
	# 2. Build Adjacency and Degree vectors
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
		if idx_neighbors.size() > max_d:
			max_d = idx_neighbors.size()
			
	# 3. Power Iteration with Deflation
	# We shift the matrix by c to find the smallest non-zero eigenvalue
	var c = float(2 * max_d + 1)
	var v = []
	v.resize(n)
	for i in range(n):
		v[i] = randf_range(-1.0, 1.0)
		
	_orthogonalize_and_normalize(v)
	
	var max_iters = 1000
	var tolerance = 0.00001
	
	for iter in range(max_iters):
		var v_next = []
		v_next.resize(n)
		
		# Apply operator: (c * I - L) * v
		for i in range(n):
			var L_vi = d[i] * v[i]
			for j in adj[i]:
				L_vi -= v[j]
			v_next[i] = c * v[i] - L_vi
			
		_orthogonalize_and_normalize(v_next)
		
		# Check for convergence
		var diff = 0.0
		for i in range(n):
			diff += abs(v_next[i] - v[i])
			
		v = v_next
		if diff < tolerance:
			break
			
	# 4. Calculate the Fiedler Value (Rayleigh Quotient: v^T * L * v)
	var fiedler_value = 0.0
	for i in range(n):
		var L_vi = d[i] * v[i]
		for j in adj[i]:
			L_vi -= v[j]
		fiedler_value += v[i] * L_vi
		
	# 5. Bisect the graph based on Fiedler Vector signs
	var side_a = []
	var side_b = []
	for i in range(n):
		if v[i] >= 0.0:
			side_a.append(idx_to_node[i])
		else:
			side_b.append(idx_to_node[i])
			
	# 6. Find the edges that were cut
	var cut_edges = []
	var processed = {}
	for key in graph.edge_store:
		var e = graph.edge_store[key]
		var pair = [e.u, e.v]
		pair.sort()
		if processed.has(pair): continue
		processed[pair] = true
		
		var is_u_a = v[node_to_idx[e.u]] >= 0.0
		var is_v_a = v[node_to_idx[e.v]] >= 0.0
		
		if is_u_a != is_v_a:
			cut_edges.append(pair)
			
	return {
		"fiedler_value": snapped(fiedler_value, 0.001),
		"side_a": side_a,
		"side_b": side_b,
		"cut_edges": cut_edges
	}

# Helper: Gram-Schmidt orthogonalization against the all-ones vector
static func _orthogonalize_and_normalize(v: Array) -> void:
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
		for i in range(n):
			v[i] /= norm
