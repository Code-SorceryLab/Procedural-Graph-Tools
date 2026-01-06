class_name GraphSerializer
extends RefCounted

# --- PUBLIC API ---

static func serialize(graph: Graph) -> String:
	var data = {
		"meta": {
			"version": "1.0",
			"timestamp": Time.get_datetime_string_from_system()
		},
		"nodes": [],
		"edges": []
	}
	
	# 1. SERIALIZE NODES
	# We iterate through the graph's nodes and convert them to simple dicts
	for id in graph.nodes:
		var node_obj = graph.nodes[id] # This is the NodeData resource
		var node_dict = {
			"id": id,
			"x": node_obj.position.x,
			"y": node_obj.position.y,
			"type": node_obj.type
		}
		data["nodes"].append(node_dict)
		
		# 2. SERIALIZE EDGES
		# We look at the connections of each node.
		# To avoid duplicates (A->B and B->A), we can filter or just save all.
		# For simplicity/robustness, we save exactly what is in the adjacency list.
		for neighbor_id in node_obj.connections:
			var weight = node_obj.connections[neighbor_id]
			var edge_dict = {
				"from": id,
				"to": neighbor_id,
				"w": weight
			}
			data["edges"].append(edge_dict)
	
	# 3. CONVERT TO JSON STRING
	return JSON.stringify(data, "\t") # "\t" makes it pretty-printed (readable)


static func deserialize(json_string: String) -> Graph:
	# 1. PARSE JSON
	var json = JSON.new()
	var error = json.parse(json_string)
	
	if error != OK:
		push_error("GraphSerializer: JSON Parse Error: %s at line %s" % [json.get_error_message(), json.get_error_line()])
		return null
		
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("GraphSerializer: Invalid JSON format (Root is not a Dictionary)")
		return null
		
	# 2. CONSTRUCT GRAPH
	var new_graph = Graph.new()
	
	# Load Nodes
	if data.has("nodes") and data["nodes"] is Array:
		for n in data["nodes"]:
			var id = n.get("id", "")
			if id == "": continue
			
			var pos = Vector2(n.get("x", 0), n.get("y", 0))
			new_graph.add_node(id, pos)
			
			# Restore Type (Default to 0 if missing)
			var type = n.get("type", 0)
			if new_graph.nodes.has(id):
				new_graph.nodes[id].type = type

	# Load Edges
	if data.has("edges") and data["edges"] is Array:
		for e in data["edges"]:
			var u = e.get("from", "")
			var v = e.get("to", "")
			var w = e.get("w", 1.0)
			
			if u != "" and v != "":
				# Check strict existence to avoid crashes
				if new_graph.nodes.has(u) and new_graph.nodes.has(v):
					new_graph.add_edge(u, v, w, true) # 'true' because JSON stores direction explicitly
	
	return new_graph
