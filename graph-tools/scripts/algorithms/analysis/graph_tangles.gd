class_name GraphTangle
extends RefCounted

const MAX_BITWISE_NODES = 63
const MAX_BRANCH_ITERS = 100000

# Tracks the state of the recursive exact solver
static var _best_treewidth := 0
static var _iters := 0
static var _timeout := false

# Dynamic parameters
static var _current_max_iters := 100000
static var _force_exact := false

# Main Entry Point
static func calculate(graph: Graph, params: Dictionary) -> Dictionary:
	# Extract parameters
	_current_max_iters = params.get("tangle_max_iters", 100000)
	_force_exact = params.get("tangle_force_exact", false)
	
	var nodes = graph.nodes.keys()
	var n = nodes.size()
	
	if n <= 2:
		return { "treewidth": max(0, n - 1), "is_exact": true, "method": "Trivial" }

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
		
		_branch_and_bound(bit_adj, active_mask, 0, n)
		
		if _timeout:
			return { "treewidth": upper_bound, "is_exact": false, "method": "Greedy (Exact timed out at %d iters)" % _iters }
		else:
			return { "treewidth": _best_treewidth, "is_exact": true, "method": "Exact (Bitwise Branch & Bound in %d iters)" % _iters }
	else:
		return { "treewidth": upper_bound, "is_exact": false, "method": "Greedy (N > 63 prevents 64-bit search)" }

# --- APPROXIMATION ALGORITHM ---

# Simulates eliminating nodes from lowest degree to highest.
# When a node is eliminated, all its neighbors form a clique.
static func _greedy_min_degree(original_adj: Array, n: int) -> int:
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
		
		# Connect all neighbors of best_u to each other (form a clique)
		var neighbors = adj[best_u]
		for v in neighbors:
			if not active[v]: continue
			for w in neighbors:
				if v != w and active[w] and not adj[v].has(w):
					adj[v].append(w)
					
	return max_clique_size

# --- EXACT NP-HARD SOLVER (BITWISE) ---

static func _build_bitmask_adj(adj: Array, n: int) -> Array:
	var bit_adj = []
	bit_adj.resize(n)
	for i in range(n):
		var mask = 0
		for v in adj[i]:
			mask |= (1 << v)
		bit_adj[i] = mask
	return bit_adj

# Recursive DFS that searches all possible vertex elimination orderings.
static func _branch_and_bound(adj: Array, active_mask: int, current_max_width: int, n: int) -> void:
	if _timeout or current_max_width >= _best_treewidth:
		return 
		
	if active_mask == 0:
		_best_treewidth = current_max_width
		return
		
	_iters += 1
	
	# Check for timeout ONLY if we aren't forcing exact mode!
	if not _force_exact and _iters > _current_max_iters:
		_timeout = true
		return
		
	# Find a vertex to eliminate
	for u in range(n):
		if (active_mask & (1 << u)) != 0:
			var neighbors_mask = adj[u] & active_mask
			
			# Brian Kernighan's algorithm to count bits (degree)
			var deg = 0
			var temp = neighbors_mask
			while temp > 0:
				temp &= (temp - 1)
				deg += 1
				
			var new_width = max(current_max_width, deg)
			if new_width >= _best_treewidth:
				continue # Eliminating u makes the width too large, skip.
				
			# Create a branched copy of the graph
			var next_adj = adj.duplicate()
			var next_mask = active_mask & ~(1 << u)
			
			# Form a clique among u's neighbors using pure bitwise operations
			for v in range(n):
				if (neighbors_mask & (1 << v)) != 0:
					next_adj[v] |= neighbors_mask
					next_adj[v] &= ~(1 << v) # Remove self-loop
					
			_branch_and_bound(next_adj, next_mask, new_width, n)
