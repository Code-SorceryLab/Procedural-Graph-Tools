class_name GraphPatternExtractor
extends RefCounted

enum ExtractMode { TOPOLOGICAL, SEMANTIC }

# Core extraction function
static func extract_patterns(source_graph: Graph, mode: ExtractMode, depth: int, use_rotations: bool = false) -> Array[Dictionary]:
	var results = {}
	
	# 1. Iterate every node as a potential "Seed" for a motif
	for seed_id in source_graph.nodes:
		# 2. Perform a bounded BFS to gather the local neighborhood
		var subgraph_nodes = _gather_neighborhood(source_graph, seed_id, depth)
		var subgraph_edges = _gather_internal_edges(source_graph, subgraph_nodes)
		
		# 3. Generate a Canonical Signature
		# This is the secret sauce. A signature must be identical for two graphs 
		# that have the exact same shape/tags, regardless of rotation or node IDs.
		var signature = _generate_canonical_signature(source_graph, subgraph_nodes, subgraph_edges, mode)
		
		# 4. Tally and Store
		if results.has(signature):
			results[signature]["frequency"] += 1
		else:
			# First time seeing this pattern; build a standalone mini-Graph for it
			var mini_graph = _build_isolated_subgraph(source_graph, subgraph_nodes, subgraph_edges)
			results[signature] = {
				"signature": signature,
				"frequency": 1,
				"graph": mini_graph
			}
			
	# 5. Convert dictionary to a sorted array (highest frequency first)
	var final_array: Array[Dictionary] = []
	final_array.assign(results.values())
	final_array.sort_custom(func(a, b): return a["frequency"] > b["frequency"])
	
	return final_array

# --- INTERNAL ALGORITHMS ---

static func _gather_neighborhood(graph: Graph, start_id: String, max_depth: int) -> Array[String]:
	# We use a dictionary to track which nodes we've seen AND how far away they are.
	var visited = {start_id: 0} 
	var queue = [start_id]
	var result: Array[String] = [start_id]
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var current_depth = visited[current]
		
		# If we haven't hit the boundary yet, keep looking outward
		if current_depth < max_depth:
			for neighbor in graph.get_neighbors(current):
				if not visited.has(neighbor):
					visited[neighbor] = current_depth + 1
					queue.append(neighbor)
					result.append(neighbor)
					
	return result

static func _gather_internal_edges(graph: Graph, node_subset: Array[String]) -> Array:
	var internal_edges = []
	
	# Convert array to a hash map for O(1) lookups
	var subset_dict = {}
	for id in node_subset: 
		subset_dict[id] = true
	
	for key in graph.edge_store:
		var e = graph.edge_store[key]
		
		# Only keep the edge if BOTH ends exist inside our extracted bubble
		if subset_dict.has(e.u) and subset_dict.has(e.v):
			internal_edges.append(e)
			
	return internal_edges

static func _generate_canonical_signature(graph: Graph, nodes: Array[String], edges: Array, mode: ExtractMode) -> String:
	if mode == ExtractMode.TOPOLOGICAL:
		return _generate_topological_signature(graph, nodes, edges)
	else:
		return _generate_semantic_signature(graph, nodes, edges)

static func _build_isolated_subgraph(source: Graph, nodes: Array[String], edges: Array) -> Graph:
	var mini = Graph.new()
	
	# 1. Calculate the center of mass of the sub-graph
	var center_of_mass = Vector2.ZERO
	for id in nodes:
		center_of_mass += source.nodes[id].position
	center_of_mass /= max(1.0, float(nodes.size()))
	
	# 2. Clone the Nodes and shift their positions relative to the center
	for id in nodes:
		var orig_data = source.nodes[id]
		
		# [FIX] Use add_node, which accepts the ID and position
		mini.add_node(id, orig_data.position - center_of_mass)
		
		# Copy all semantic metadata
		mini.nodes[id].type = orig_data.type
		mini.nodes[id].custom_data = orig_data.custom_data.duplicate(true)
		
	# 3. Clone the Edges
	for e in edges:
		mini.add_edge(e.u, e.v)
		
		# Note: add_edge generates forward (and backward if undirected) records.
		# We just need to copy the custom data into the primary record.
		var new_edge_key = mini.get_edge_key(e.u, e.v)
		if mini.edge_store.has(new_edge_key):
			mini.edge_store[new_edge_key].custom = e.custom.duplicate(true)
		
	return mini


static func _generate_topological_signature(graph: Graph, nodes: Array[String], edges: Array) -> String:
	var degree_map = {}
	
	# Initialize degrees
	for id in nodes:
		degree_map[id] = 0
		
	# Count connections within the isolated subgraph
	for e in edges:
		if degree_map.has(e.u): degree_map[e.u] += 1
		if degree_map.has(e.v): degree_map[e.v] += 1
		
	# Extract just the numbers
	var degree_sequence = degree_map.values()
	
	# Sort them descending (e.g., [3, 1, 1, 1] for a Hub connected to 3 Leaves)
	degree_sequence.sort()
	degree_sequence.reverse()
	
	# Stringify the sequence
	var sig = "Topo_Deg:"
	for d in degree_sequence:
		sig += str(d) + "-"
		
	# Add Edge Count to prevent collisions between graphs with identical degree 
	# sequences but different loop structures.
	sig += "_E" + str(edges.size())
		
	return sig
	

static func _generate_semantic_signature(graph: Graph, nodes: Array[String], edges: Array) -> String:
	# In Semantic WFC extraction, we assume the first node in the array is our 'Seed'
	var seed_id = nodes[0]
	var seed_type = graph.nodes[seed_id].type
	
	var neighbor_types = []
	
	# Find all semantic types connected to our seed
	for e in edges:
		if e.u == seed_id and nodes.has(e.v):
			neighbor_types.append(graph.nodes[e.v].type)
		elif e.v == seed_id and nodes.has(e.u):
			neighbor_types.append(graph.nodes[e.u].type)
			
	# Sort the neighbor tags alphabetically so order doesn't matter
	# E.g., a Boss touching [Corridor, Treasure] is identical to a Boss touching [Treasure, Corridor]
	neighbor_types.sort()
	
	# Stringify
	var sig = "Sem_" + seed_type + "_to_["
	for t in neighbor_types:
		sig += t + ","
	sig += "]"
	
	return sig
