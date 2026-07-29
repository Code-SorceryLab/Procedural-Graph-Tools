class_name GraphSerializer
extends RefCounted

# --- PUBLIC API ---

static func serialize(graph: Graph) -> String:
	var data = {
		"meta": {
			"version": "1.4", # Bumped for Zone Support
			"timestamp": Time.get_datetime_string_from_system(),
			"next_ticket": graph._next_display_id
		},
		"legend": _serialize_legend(),
		"schema": GraphSettings.property_definitions,
		"nodes": [],
		"edges": [],
		"agents": [],
		"zones": [] # Zone Container
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
		
		if "custom_data" in node_obj:
			node_dict["custom_data"] = node_obj.custom_data
			
		data["nodes"].append(node_dict)
		
	# 2. SERIALIZE EDGES
	var processed_pairs = {} 
	
	for id_a in graph.edge_data:
		for id_b in graph.edge_data[id_a]:
			var pair_key = [id_a, id_b]
			pair_key.sort()
			if processed_pairs.has(pair_key): continue
			
			var data_ab = graph.edge_data[id_a][id_b]
			var is_bidir = false
			
			if graph.edge_data.has(id_b) and graph.edge_data[id_b].has(id_a):
				var data_ba = graph.edge_data[id_b][id_a]
				if data_ab.hash() == data_ba.hash():
					is_bidir = true
			
			if is_bidir:
				processed_pairs[pair_key] = true
				data["edges"].append({
					"u": id_a, "v": id_b,
					"bidir": true,
					"data": data_ab
				})
			else:
				data["edges"].append({
					"u": id_a, "v": id_b,
					"bidir": false,
					"data": data_ab
				})
			
	# 3. SERIALIZE AGENTS
	for agent in graph.agents:
		if agent.has_method("serialize"):
			data["agents"].append(agent.serialize())

	# 4. SERIALIZE ZONES
	if "zones" in graph:
		for zone in graph.zones:
			if zone.has_method("serialize"):
				data["zones"].append(zone.serialize())
			
	return JSON.stringify(data, "\t")

static func deserialize(json_string: String) -> Graph:
	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK: 
		push_error("JSON Parse Error: %s" % json.get_error_message())
		return null
	
	var data = json.data
	
	# 1. Restore Legend & Schema
	if data.has("legend"): _deserialize_legend(data["legend"])
	else: GraphSettings.reset_legend()
	
	GraphSettings.clear_schema()
	if data.has("schema"):
		var loaded_schema = data["schema"]
		for key in loaded_schema:
			var def = loaded_schema[key]
			var target = def.get("target", "NODE")
			var type = int(def.get("type", TYPE_STRING))
			var default = def.get("default", null)
			
			if target in ["NODE", "EDGE", "AGENT"]:
				GraphSettings.register_property(key, target, type, default)
		
	var new_graph = Graph.new()
	
	# 2. Restore Meta-Data
	if data.has("meta"):
		new_graph._next_display_id = int(data["meta"].get("next_ticket", 1))
	
	# 3. Restore Nodes
	if data.has("nodes"):
		for n in data["nodes"]:
			var id = n.get("id", "")
			var pos = Vector2(n.get("x", 0), n.get("y", 0))
			
			# Note: We use add_node here, which triggers the sync logic.
			# BUT, since zones aren't loaded yet, the sync does nothing here.
			# This is why we need post_load_fixup() at the end.
			new_graph.add_node(id, pos)
			
			var type = n.get("type", 0)
			if new_graph.nodes.has(id):
				var node_ref = new_graph.nodes[id]
				node_ref.type = type
				if n.has("custom_data") and "custom_data" in node_ref:
					node_ref.custom_data = n["custom_data"]
				
	# 4. Restore Edges
	if data.has("edges"):
		for e in data["edges"]:
			var u = e.get("u") if e.has("u") else e.get("from")
			var v = e.get("v") if e.has("v") else e.get("to")
			
			if not new_graph.nodes.has(u) or not new_graph.nodes.has(v): continue
				
			var edge_data = e.get("data", {})
			if e.has("w") and not edge_data.has("weight"): edge_data["weight"] = e["w"]
				
			var weight = edge_data.get("weight", 1.0)
			var is_bidir = e.get("bidir", true)
			
			new_graph.add_edge(u, v, weight, not is_bidir, edge_data)

	# 5. Restore Zones
	if data.has("zones"):
		for z_data in data["zones"]:
			var zone = GraphZone.deserialize(z_data)
			new_graph.add_zone(zone)

	# 6. Restore Agents
	if data.has("agents"):
		for a_data in data["agents"]:
			var agent = AgentWalker.deserialize(a_data)
			if agent:
				new_graph.add_agent(agent)
				
	# [NEW] 7. POST-LOAD REPAIR
	# Now that Nodes AND Zones exist, we force a sync so the rosters populate.
	# This also rebuilds the spatial grid for selection.
	if new_graph.has_method("post_load_fixup"):
		new_graph.post_load_fixup()
				
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


# --- GRAPHML EXPORT ---
static func export_graphml(graph: Graph) -> String:
	var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
	xml += "<graphml xmlns=\"http://graphml.graphdrawing.org/xmlns\"\n"
	xml += "         xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"\n"
	xml += "         xsi:schemaLocation=\"http://graphml.graphdrawing.org/xmlns\n"
	xml += "         http://graphml.graphdrawing.org/xmlns/1.0/graphml.xsd\">\n"

	# 1. Define Hardcoded Core Keys
	xml += "\t<!-- Node Core Properties -->\n"
	xml += "\t<key id=\"x\" for=\"node\" attr.name=\"x\" attr.type=\"double\"/>\n"
	xml += "\t<key id=\"y\" for=\"node\" attr.name=\"y\" attr.type=\"double\"/>\n"
	xml += "\t<key id=\"type\" for=\"node\" attr.name=\"type\" attr.type=\"int\"/>\n"
	xml += "\t<key id=\"shape\" for=\"node\" attr.name=\"shape\" attr.type=\"int\"/>\n"

	# 2. Dynamically Discover Semantic Keys (Custom Data)
	var custom_keys = {}
	for id in graph.nodes:
		var node = graph.nodes[id] as NodeData
		for c_key in node.custom_data:
			var val = node.custom_data[c_key]
			if not custom_keys.has(c_key):
				# Map GDScript variants to GraphML accepted types
				var attr_type = "string"
				if val is int: attr_type = "int"
				elif val is float: attr_type = "double"
				elif val is bool: attr_type = "boolean"
				
				custom_keys[c_key] = attr_type
				xml += "\t<key id=\"%s\" for=\"node\" attr.name=\"%s\" attr.type=\"%s\"/>\n" % [c_key, c_key, attr_type]

	xml += "\t<!-- Edge Properties -->\n"
	xml += "\t<key id=\"weight\" for=\"edge\" attr.name=\"weight\" attr.type=\"double\"/>\n"

	# 3. Open the Graph definition (Undirected by default)
	xml += "\n\t<graph id=\"G\" edgedefault=\"undirected\">\n"

	# 4. Write Nodes
	for id in graph.nodes:
		var node = graph.nodes[id] as NodeData
		xml += "\t\t<node id=\"%s\">\n" % id
		xml += "\t\t\t<data key=\"x\">%f</data>\n" % node.position.x
		xml += "\t\t\t<data key=\"y\">%f</data>\n" % node.position.y
		xml += "\t\t\t<data key=\"type\">%d</data>\n" % node.type
		xml += "\t\t\t<data key=\"shape\">%d</data>\n" % node.shape

		# Append any custom semantic tags (depth, temp, etc.)
		for c_key in node.custom_data:
			var val_str = str(node.custom_data[c_key]).xml_escape()
			xml += "\t\t\t<data key=\"%s\">%s</data>\n" % [c_key, val_str]

		xml += "\t\t</node>\n"

	# 5. Write Edges (Deduplicated)
	var processed_pairs = {}
	var edge_id_counter = 0

	for a in graph.edge_data:
		for b in graph.edge_data[a]:
			var pair = [a, b]
			pair.sort()
			
			if not processed_pairs.has(pair):
				processed_pairs[pair] = true
				var weight = graph.edge_data[a][b]
				
				# Safely cast the variant to a float via string conversion
				var safe_weight = str(weight).to_float()
				
				xml += "\t\t<edge id=\"e%d\" source=\"%s\" target=\"%s\">\n" % [edge_id_counter, a, b]
				xml += "\t\t\t<data key=\"weight\">%f</data>\n" % safe_weight
				xml += "\t\t</edge>\n"
				
				edge_id_counter += 1

	xml += "\t</graph>\n"
	xml += "</graphml>\n"

	return xml

# --- GEXF EXPORT ---
static func export_gexf(graph: Graph) -> String:
	var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
	xml += "<gexf xmlns=\"http://www.gexf.net/1.2draft\" version=\"1.2\">\n"
	xml += "\t<meta>\n\t\t<creator>GraphTools</creator>\n\t\t<description>Procedural Dungeon Graph</description>\n\t</meta>\n"
	
	# Open Graph (Undirected)
	xml += "\t<graph defaultedgetype=\"undirected\">\n"

	# 1. Define Core Attributes
	xml += "\t\t<attributes class=\"node\">\n"
	xml += "\t\t\t<attribute id=\"x\" title=\"x\" type=\"float\"/>\n"
	xml += "\t\t\t<attribute id=\"y\" title=\"y\" type=\"float\"/>\n"
	xml += "\t\t\t<attribute id=\"type\" title=\"type\" type=\"integer\"/>\n"
	xml += "\t\t\t<attribute id=\"shape\" title=\"shape\" type=\"integer\"/>\n"

	# 2. Dynamically Discover Semantic Keys (Custom Data)
	var custom_keys = {}
	for id in graph.nodes:
		var node = graph.nodes[id] as NodeData
		for c_key in node.custom_data:
			var val = node.custom_data[c_key]
			if not custom_keys.has(c_key):
				# Map GDScript variants to GEXF accepted types
				var attr_type = "string"
				if val is int: attr_type = "integer"
				elif val is float: attr_type = "float"
				elif val is bool: attr_type = "boolean"
				
				custom_keys[c_key] = attr_type
				xml += "\t\t\t<attribute id=\"%s\" title=\"%s\" type=\"%s\"/>\n" % [c_key, c_key, attr_type]
	xml += "\t\t</attributes>\n"

	# 3. Write Nodes
	xml += "\t\t<nodes>\n"
	for id in graph.nodes:
		var node = graph.nodes[id] as NodeData
		xml += "\t\t\t<node id=\"%s\" label=\"%s\">\n" % [id, id]
		xml += "\t\t\t\t<attvalues>\n"
		
		# Core Data
		xml += "\t\t\t\t\t<attvalue for=\"x\" value=\"%f\"/>\n" % node.position.x
		xml += "\t\t\t\t\t<attvalue for=\"y\" value=\"%f\"/>\n" % node.position.y
		xml += "\t\t\t\t\t<attvalue for=\"type\" value=\"%d\"/>\n" % node.type
		xml += "\t\t\t\t\t<attvalue for=\"shape\" value=\"%d\"/>\n" % node.shape

		# Custom Data
		for c_key in node.custom_data:
			var val_str = str(node.custom_data[c_key]).xml_escape()
			xml += "\t\t\t\t\t<attvalue for=\"%s\" value=\"%s\"/>\n" % [c_key, val_str]
			
		xml += "\t\t\t\t</attvalues>\n"
		xml += "\t\t\t</node>\n"
	xml += "\t\t</nodes>\n"

	# 4. Write Edges
	xml += "\t\t<edges>\n"
	var processed_pairs = {}
	var edge_id_counter = 0

	for a in graph.edge_data:
		for b in graph.edge_data[a]:
			var pair = [a, b]
			pair.sort()
			
			if not processed_pairs.has(pair):
				processed_pairs[pair] = true
				var weight = str(graph.edge_data[a][b]).to_float()
				
				xml += "\t\t\t<edge id=\"e%d\" source=\"%s\" target=\"%s\" weight=\"%f\"/>\n" % [edge_id_counter, a, b, weight]
				edge_id_counter += 1
	xml += "\t\t</edges>\n"

	xml += "\t</graph>\n"
	xml += "</gexf>\n"

	return xml
