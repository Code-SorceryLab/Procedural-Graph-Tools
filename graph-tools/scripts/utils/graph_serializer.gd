class_name GraphSerializer
extends RefCounted

# --- PUBLIC API ---

static func serialize(graph: Graph) -> String:
	var data = {
		"meta": {
			"version": "1.2", # Bumped for Hybrid IDs + Rich Data
			"timestamp": Time.get_datetime_string_from_system(),
			# [CRITICAL] Save the Ticket Counter so IDs don't reset on load
			"next_ticket": graph._next_display_id 
		},
		"legend": _serialize_legend(), 
		"nodes": [],
		"edges": [],
		"agents": []
	}
	
	# 1. SERIALIZE NODES
	for id in graph.nodes:
		var node_obj = graph.nodes[id]
		var node_dict = {
			"id": id,
			"x": node_obj.position.x,
			"y": node_obj.position.y,
			"type": node_obj.type 
		}
		
		# [FUTURE PROOFING] If NodeData eventually gets custom_data, save it here
		if "custom_data" in node_obj:
			node_dict["custom_data"] = node_obj.custom_data
			
		data["nodes"].append(node_dict)
		
	# 2. SERIALIZE EDGES (Smart Logic)
	# We iterate edge_data to capture rich custom fields
	var processed_pairs = {} # Keeps track of bidirectionals we already saved
	
	for id_a in graph.edge_data:
		for id_b in graph.edge_data[id_a]:
			# Check if we already handled this pair
			var pair_key = [id_a, id_b]
			pair_key.sort()
			if processed_pairs.has(pair_key): continue
			
			var data_ab = graph.edge_data[id_a][id_b]
			var is_bidir = false
			
			# Check symmetry: Does B->A exist?
			if graph.edge_data.has(id_b) and graph.edge_data[id_b].has(id_a):
				var data_ba = graph.edge_data[id_b][id_a]
				# Deep Equality Check: Are they effectively the same edge?
				if data_ab.hash() == data_ba.hash():
					is_bidir = true
			
			if is_bidir:
				# Save ONCE as Bi-Directional
				processed_pairs[pair_key] = true
				data["edges"].append({
					"u": id_a, "v": id_b,
					"bidir": true,
					"data": data_ab # Saves weight, type, lock_level, etc.
				})
			else:
				# Save as One-Way (Directed)
				# We do NOT mark processed_pairs, so B->A will be checked later
				data["edges"].append({
					"u": id_a, "v": id_b,
					"bidir": false,
					"data": data_ab
				})
			
	# 3. SERIALIZE AGENTS
	for agent in graph.agents:
		if agent.has_method("serialize"):
			data["agents"].append(agent.serialize())
			
	return JSON.stringify(data, "\t")

static func deserialize(json_string: String) -> Graph:
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK: 
		push_error("JSON Parse Error: %s" % json.get_error_message())
		return null
	
	var data = json.data
	
	# 1. Restore Legend
	if data.has("legend"):
		_deserialize_legend(data["legend"])
	else:
		GraphSettings.reset_legend()
		
	var new_graph = Graph.new()
	
	# 2. Restore Meta-Data (Ticket Counter)
	if data.has("meta"):
		new_graph._next_display_id = int(data["meta"].get("next_ticket", 1))
	
	# 3. Restore Nodes
	if data.has("nodes"):
		for n in data["nodes"]:
			var id = n.get("id", "")
			var pos = Vector2(n.get("x", 0), n.get("y", 0))
			new_graph.add_node(id, pos)
			
			var type = n.get("type", 0)
			if new_graph.nodes.has(id):
				var node_ref = new_graph.nodes[id]
				node_ref.type = type
				# Restore Custom Data if present
				if n.has("custom_data") and "custom_data" in node_ref:
					node_ref.custom_data = n["custom_data"]
				
	# 4. Restore Edges
	if data.has("edges"):
		for e in data["edges"]:
			# Support v1.0 ("from/to") and v1.2 ("u/v")
			var u = e.get("u") if e.has("u") else e.get("from")
			var v = e.get("v") if e.has("v") else e.get("to")
			
			if not new_graph.nodes.has(u) or not new_graph.nodes.has(v):
				continue
				
			# Extract Data
			var edge_data = e.get("data", {})
			# Compat: If v1.0 "w" exists, ensure it's in data
			if e.has("w") and not edge_data.has("weight"):
				edge_data["weight"] = e["w"]
				
			var weight = edge_data.get("weight", 1.0)
			var is_bidir = e.get("bidir", true) # Default to true for old saves
			
			# Add to Graph
			# Note: 'directed' param is the inverse of 'bidir'
			new_graph.add_edge(u, v, weight, not is_bidir, edge_data)

	# 5. Restore Agents
	if data.has("agents"):
		for a_data in data["agents"]:
			var agent = AgentWalker.deserialize(a_data)
			if agent:
				new_graph.add_agent(agent)
				
	return new_graph

# --- PRIVATE HELPERS ---

static func _serialize_legend() -> Dictionary:
	var export_data = {}
	for type_id in GraphSettings.current_names:
		export_data[str(type_id)] = {
			"name": GraphSettings.current_names[type_id],
			"color": GraphSettings.current_colors[type_id].to_html()
		}
	return export_data

static func _deserialize_legend(legend_data: Dictionary) -> void:
	GraphSettings.reset_legend()
	for type_id_str in legend_data:
		var id = type_id_str.to_int()
		var entry = legend_data[type_id_str]
		var name = entry.get("name", "Unknown")
		var color_html = entry.get("color", "ff00ff")
		GraphSettings.register_custom_type(id, name, Color(color_html))

static func generate_uuid() -> String:
	var uuid = ""
	var chars = "0123456789abcdef"
	for i in range(36):
		if i == 8 or i == 13 or i == 18 or i == 23:
			uuid += "-"
		elif i == 14:
			uuid += "4" 
		elif i == 19:
			var idx = randi() % 4
			uuid += chars[8 + idx] 
		else:
			uuid += chars[randi() % 16]
	return uuid
