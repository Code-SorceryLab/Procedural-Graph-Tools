extends GraphStrategy
class_name StrategyMST

func _init() -> void:
	strategy_name = "Prune to MST (Filter)"
	# No params needed: it works on whatever data is already there
	required_params = [] 

func execute(graph: Graph, _params: Dictionary) -> void:
	# SAFETY CHECK: 
	# If the user clicked "Generate" (which clears nodes first), there is nothing to prune.
	# This strategy only works if nodes already exist (via Grow mode or Manual placement).
	if graph.nodes.is_empty():
		push_warning("MST Strategy: Graph is empty. Use 'Grow (+)' to apply this to an existing graph.")
		return

	# 1. Collect ALL Existing Edges
	# We use a Dictionary key trick to deduplicate edges (A->B is same as B->A)
	var existing_edges: Array[Dictionary] = []
	var processed_pairs = {} 
	
	for u_id in graph.nodes:
		var neighbors = graph.get_neighbors(u_id)
		for v_id in neighbors:
			# Create a sorted pair so [A, B] and [B, A] look identical
			var pair = [u_id, v_id]
			pair.sort() 
			
			if not processed_pairs.has(pair):
				processed_pairs[pair] = true
				existing_edges.append({ 
					"u": pair[0], 
					"v": pair[1],
					# We assign a random weight here to make the maze random
					# If we used real distance, it would create "Rivers" (shortest paths)
					"weight": randf() 
				})

	# 2. Clear All Current Connections
	# We keep the nodes, but we cut all the wires.
	for id in graph.nodes:
		var node = graph.nodes[id]
		if node is NodeData: # Check type safety
			node.connections.clear()

	# 3. Kruskal's Algorithm (The Re-connection)
	# Sort by the random weights we assigned
	existing_edges.sort_custom(func(a, b): return a["weight"] < b["weight"])
	
	var ds = DisjointSet.new(graph.nodes.keys())
	var restored_count = 0
	
	for edge in existing_edges:
		var u = edge["u"]
		var v = edge["v"]
		
		# If connecting u and v doesn't create a cycle (loop)...
		if ds.find(u) != ds.find(v):
			ds.union(u, v)
			graph.add_edge(u, v)
			restored_count += 1
			
	print("MST Filter Applied. Restored %d edges." % restored_count)

# --- Inner Helper Class: Disjoint Set (Union-Find) ---
# (This logic remains exactly the same as before)
class DisjointSet:
	var parent: Dictionary = {}
	
	func _init(node_ids: Array) -> void:
		for id in node_ids:
			parent[id] = id

	func find(i: String) -> String:
		if parent[i] != i:
			parent[i] = find(parent[i]) 
		return parent[i]

	func union(i: String, j: String) -> void:
		var root_i = find(i)
		var root_j = find(j)
		if root_i != root_j:
			parent[root_i] = root_j
