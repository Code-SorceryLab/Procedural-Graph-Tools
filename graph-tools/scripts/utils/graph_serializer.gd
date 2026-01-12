class_name GraphSerializer
extends RefCounted

# --- PUBLIC API ---

static func serialize(graph: Graph) -> String:
	var data = {
		"meta": {
			"version": "1.1", # Bumped version
			"timestamp": Time.get_datetime_string_from_system()
		},
		# NEW: Save the Legend!
		"legend": _serialize_legend(), 
		"nodes": [],
		"edges": []
	}
	
	# ... (Keep existing Node/Edge serialization) ...
	
	# 1. SERIALIZE NODES (Unchanged)
	for id in graph.nodes:
		var node_obj = graph.nodes[id]
		var node_dict = {
			"id": id,
			"x": node_obj.position.x,
			"y": node_obj.position.y,
			"type": node_obj.type 
		}
		data["nodes"].append(node_dict)
		
	# 2. SERIALIZE EDGES (Unchanged)
	for id in graph.nodes:
		var node_obj = graph.nodes[id]
		for neighbor_id in node_obj.connections:
			var weight = node_obj.connections[neighbor_id]
			var edge_dict = {
				"from": id,
				"to": neighbor_id,
				"w": weight
			}
			data["edges"].append(edge_dict)
			
	return JSON.stringify(data, "\t")

static func deserialize(json_string: String) -> Graph:
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK: return null
	
	var data = json.data
	
	# NEW: Restore Legend first!
	if data.has("legend"):
		_deserialize_legend(data["legend"])
	else:
		# If loading an old file, reset to defaults
		GraphSettings.reset_legend()
		
	# ... (Keep existing Graph construction) ...
	var new_graph = Graph.new()
	
	# Load Nodes (Unchanged)
	if data.has("nodes"):
		for n in data["nodes"]:
			var id = n.get("id", "")
			var pos = Vector2(n.get("x", 0), n.get("y", 0))
			new_graph.add_node(id, pos)
			
			var type = n.get("type", 0)
			if new_graph.nodes.has(id):
				new_graph.nodes[id].type = type
				
	# Load Edges (Unchanged)
	if data.has("edges"):
		for e in data["edges"]:
			var u = e.get("from", "")
			var v = e.get("to", "")
			var w = e.get("w", 1.0)
			if new_graph.nodes.has(u) and new_graph.nodes.has(v):
				new_graph.add_edge(u, v, w, true)
				
	return new_graph

# --- PRIVATE HELPERS ---

static func _serialize_legend() -> Dictionary:
	var export_data = {}
	# We iterate through the current settings
	for type_id in GraphSettings.current_names:
		export_data[str(type_id)] = {
			"name": GraphSettings.current_names[type_id],
			"color": GraphSettings.current_colors[type_id].to_html() # Save as Hex String
		}
	return export_data

static func _deserialize_legend(legend_data: Dictionary) -> void:
	GraphSettings.reset_legend()
	
	for type_id_str in legend_data:
		var id = type_id_str.to_int()
		var entry = legend_data[type_id_str]
		
		var name = entry.get("name", "Unknown")
		var color_html = entry.get("color", "ff00ff")
		var color = Color(color_html)
		
		GraphSettings.register_custom_type(id, name, color)




static func generate_uuid() -> String:
	# Generates a pseudo-random UUID v4 string
	# Format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
	var uuid = ""
	var chars = "0123456789abcdef"
	
	for i in range(36):
		if i == 8 or i == 13 or i == 18 or i == 23:
			uuid += "-"
		elif i == 14:
			uuid += "4" # UUID v4 signature
		elif i == 19:
			# variant 10xx
			var idx = randi() % 4
			uuid += chars[8 + idx] 
		else:
			uuid += chars[randi() % 16]
			
	return uuid
