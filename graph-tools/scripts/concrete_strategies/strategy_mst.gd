class_name StrategyMST
extends GraphStrategy

func _init() -> void:
	strategy_name = "Minimum Spanning Tree"
	# Decorator: Operates on existing nodes, so do NOT reset.
	reset_on_generate = false
	supports_grow = false

# --- NEW DYNAMIC UI DEFINITION ---
func get_settings() -> Array[Dictionary]:
	# MST is pure logic with no tunable parameters yet.
	# We return an empty array so the Controller knows to CLEAR the UI.
	return [] 

func execute(graph: GraphRecorder, params: Dictionary) -> void:
	# 1. Validation
	var nodes_list = graph.nodes.keys()
	if nodes_list.is_empty():
		return # Nothing to process
		
	# 2. Prim's Algorithm (Simplified)
	# We want to keep all nodes, but remove edges to form a tree.
	# Easier to: Clear all edges, then rebuild them.
	
	# Store positions, clear edges
	graph.clear_edges() 
	
	var visited = {}
	var start_node = nodes_list[0]
	visited[start_node] = true
	
	# Priority Queue simulated with Array (can be slow for huge graphs, fine for <1000)
	# Tuple: { "u": source_id, "v": target_id, "dist": float }
	var edges_candidates = []
	
	# Helper to add candidates from a node
	var add_candidates = func(u_id):
		for v_id in nodes_list:
			if not visited.has(v_id) and u_id != v_id:
				var dist = graph.nodes[u_id].position.distance_to(graph.nodes[v_id].position)
				# Optimization: Only consider "nearby" nodes to avoid N^2 connections
				if dist < GraphSettings.CELL_SIZE * 3.0: 
					edges_candidates.append({ "u": u_id, "v": v_id, "dist": dist })

	add_candidates.call(start_node)
	
	# Loop until all nodes connected
	while visited.size() < nodes_list.size() and not edges_candidates.is_empty():
		# Sort by distance (Smallest first)
		edges_candidates.sort_custom(func(a, b): return a.dist < b.dist)
		
		# Pop smallest
		var edge = edges_candidates.pop_front()
		
		if visited.has(edge.v):
			continue # Already connected
			
		# Connect
		graph.add_edge(edge.u, edge.v)
		visited[edge.v] = true
		
		# Add new candidates
		add_candidates.call(edge.v)
