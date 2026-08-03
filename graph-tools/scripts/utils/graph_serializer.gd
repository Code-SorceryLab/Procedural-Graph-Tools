class_name GraphSerializer
extends RefCounted

# --- PUBLIC API ---

static func serialize(graph: Graph) -> String:
	var data = {
		"meta": {
			"version": "1.6", # Bumped for Canonical Edge Store
			"timestamp": Time.get_datetime_string_from_system(),
			"next_ticket": graph._next_display_id
		},
		"legend": _serialize_categories(),
		"schema": _serialize_properties(),
		"nodes": [],
		"edges": [],
		"agents": [],
		"zones": []
	}
	
	# 1. SERIALIZE NODES
	for id in graph.nodes:
		var node_obj = graph.nodes[id]
		var node_dict = {
			"id": id,
			"x": node_obj.position.x,
			"y": node_obj.position.y,
			"type": node_obj.type,
			"shape": node_obj.shape
		}
		
		if "custom_data" in node_obj:
			node_dict["custom_data"] = node_obj.custom_data
			
		data["nodes"].append(node_dict)
		
	# 2. SERIALIZE EDGES [UPDATED FOR CANONICAL STORE]
	for key in graph.edge_store:
		var e = graph.edge_store[key]
		data["edges"].append({
			"u": e.u,
			"v": e.v,
			"w": e.weight,
			"dir": e.direction,
			"data": e.custom
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
	
	# 1. Restore Semantic Registry
	if data.has("legend"): _deserialize_categories(data["legend"])
	if data.has("schema"): _deserialize_properties(data["schema"])
		
	var new_graph = Graph.new()
	
	# 2. Restore Meta-Data
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
				if n.has("custom_data") and "custom_data" in node_ref:
					node_ref.custom_data = n["custom_data"]
				
	# 4. Restore Edges [UPDATED FOR CANONICAL STORE]
	if data.has("edges"):
		for e in data["edges"]:
			var u = e.get("u") if e.has("u") else e.get("from")
			var v = e.get("v") if e.has("v") else e.get("to")
			
			if not new_graph.nodes.has(u) or not new_graph.nodes.has(v): continue
				
			var weight = e.get("w", e.get("weight", 1.0))
			
			# Handle legacy 'bidir' bool fallback if 'dir' int isn't present
			var is_directed = false
			var forced_dir = 0
			
			if e.has("dir"):
				is_directed = (int(e["dir"]) != 0)
				forced_dir = int(e["dir"])
			elif e.has("bidir"):
				is_directed = not e["bidir"]
				forced_dir = 1 if is_directed else 0
			
			var edge_data = e.get("data", {})
			new_graph.add_edge(u, v, weight, is_directed, edge_data)
			
			# If we imported a legacy file and it forced a Reverse direction, patch it
			if forced_dir == 2:
				var key = new_graph.get_edge_key(u, v)
				if new_graph.edge_store.has(key): new_graph.edge_store[key].direction = 2

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
				
	# 7. POST-LOAD REPAIR
	if new_graph.has_method("post_load_fixup"):
		new_graph.post_load_fixup()
				
	return new_graph

# --- PRIVATE HELPERS ---

static func _serialize_categories() -> Dictionary:
	var export_data = {}
	for target in SemanticRegistry.categories:
		export_data[target] = {}
		for key in SemanticRegistry.categories[target]:
			var cat = SemanticRegistry.categories[target][key]
			export_data[target][key] = {
				"name": cat["name"],
				"color": cat["color"].to_html()
			}
	return export_data

static func _deserialize_categories(data: Dictionary) -> void:
	for target in data:
		if not SemanticRegistry.categories.has(target): continue
		SemanticRegistry.categories[target].clear()
		for key in data[target]:
			var entry = data[target][key]
			SemanticRegistry.register_category(target, key, entry.get("name", key), Color(entry.get("color", "ff00ff")))

static func _serialize_properties() -> Dictionary:
	return SemanticRegistry.properties.duplicate(true)

static func _deserialize_properties(data: Dictionary) -> void:
	for target in data:
		if not SemanticRegistry.properties.has(target): continue
		SemanticRegistry.properties[target].clear()
		for key in data[target]:
			var def = data[target][key]
			SemanticRegistry.register_property(target, key, def.get("label", key), int(def.get("type", TYPE_STRING)), def.get("default", null))

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

	xml += "\t<!-- Node Core Properties -->\n"
	xml += "\t<key id=\"x\" for=\"node\" attr.name=\"x\" attr.type=\"double\"/>\n"
	xml += "\t<key id=\"y\" for=\"node\" attr.name=\"y\" attr.type=\"double\"/>\n"
	xml += "\t<key id=\"type\" for=\"node\" attr.name=\"type\" attr.type=\"string\"/>\n"
	xml += "\t<key id=\"shape\" for=\"node\" attr.name=\"shape\" attr.type=\"int\"/>\n"

	var custom_keys = {}
	for id in graph.nodes:
		var node = graph.nodes[id] as NodeData
		for c_key in node.custom_data:
			var val = node.custom_data[c_key]
			if not custom_keys.has(c_key):
				var attr_type = "string"
				if val is int: attr_type = "int"
				elif val is float: attr_type = "double"
				elif val is bool: attr_type = "boolean"
				
				custom_keys[c_key] = attr_type
				xml += "\t<key id=\"%s\" for=\"node\" attr.name=\"%s\" attr.type=\"%s\"/>\n" % [c_key, c_key, attr_type]

	xml += "\t<!-- Edge Properties -->\n"
	xml += "\t<key id=\"weight\" for=\"edge\" attr.name=\"weight\" attr.type=\"double\"/>\n"
	xml += "\n\t<graph id=\"G\" edgedefault=\"directed\">\n"

	# Write Nodes
	for id in graph.nodes:
		var node = graph.nodes[id] as NodeData
		xml += "\t\t<node id=\"%s\">\n" % id
		xml += "\t\t\t<data key=\"x\">%f</data>\n" % node.position.x
		xml += "\t\t\t<data key=\"y\">%f</data>\n" % node.position.y
		xml += "\t\t\t<data key=\"type\">%s</data>\n" % node.type
		xml += "\t\t\t<data key=\"shape\">%d</data>\n" % node.shape

		for c_key in node.custom_data:
			var val_str = str(node.custom_data[c_key]).xml_escape()
			xml += "\t\t\t<data key=\"%s\">%s</data>\n" % [c_key, val_str]

		xml += "\t\t</node>\n"

	# Write Edges [UPDATED FOR CANONICAL STORE]
	var edge_id_counter = 0
	for key in graph.edge_store:
		var e = graph.edge_store[key]
		
		# GraphML needs explicit source and target depending on direction
		var src = e.u
		var tgt = e.v
		if e.direction == 2:
			src = e.v
			tgt = e.u
			
		var dir_str = "false" if e.direction == 0 else "true"
		
		xml += "\t\t<edge id=\"e%d\" source=\"%s\" target=\"%s\" directed=\"%s\">\n" % [edge_id_counter, src, tgt, dir_str]
		xml += "\t\t\t<data key=\"weight\">%f</data>\n" % e.weight
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
	
	# Pre-scan for directionality [UPDATED FOR CANONICAL STORE]
	var has_unidirectional = false
	for key in graph.edge_store:
		if graph.edge_store[key].direction != 0:
			has_unidirectional = true
			break

	var e_default = "directed" if has_unidirectional else "undirected"
	xml += "\t<graph defaultedgetype=\"%s\">\n" % e_default

	xml += "\t\t<attributes class=\"node\">\n"
	xml += "\t\t\t<attribute id=\"x\" title=\"x\" type=\"float\"/>\n"
	xml += "\t\t\t<attribute id=\"y\" title=\"y\" type=\"float\"/>\n"
	xml += "\t\t\t<attribute id=\"type\" title=\"type\" type=\"string\"/>\n"
	xml += "\t\t\t<attribute id=\"shape\" title=\"shape\" type=\"integer\"/>\n"

	var custom_keys = {}
	for id in graph.nodes:
		var node = graph.nodes[id] as NodeData
		for c_key in node.custom_data:
			var val = node.custom_data[c_key]
			if not custom_keys.has(c_key):
				var attr_type = "string"
				if val is int: attr_type = "integer"
				elif val is float: attr_type = "float"
				elif val is bool: attr_type = "boolean"
				
				custom_keys[c_key] = attr_type
				xml += "\t\t\t<attribute id=\"%s\" title=\"%s\" type=\"%s\"/>\n" % [c_key, c_key, attr_type]
	xml += "\t\t</attributes>\n"

	# Write Nodes
	xml += "\t\t<nodes>\n"
	for id in graph.nodes:
		var node = graph.nodes[id] as NodeData
		xml += "\t\t\t<node id=\"%s\" label=\"%s\">\n" % [id, id]
		xml += "\t\t\t\t<attvalues>\n"
		xml += "\t\t\t\t\t<attvalue for=\"x\" value=\"%f\"/>\n" % node.position.x
		xml += "\t\t\t\t\t<attvalue for=\"y\" value=\"%f\"/>\n" % node.position.y
		xml += "\t\t\t\t\t<attvalue for=\"type\" value=\"%s\"/>\n" % node.type
		xml += "\t\t\t\t\t<attvalue for=\"shape\" value=\"%d\"/>\n" % node.shape

		for c_key in node.custom_data:
			var val_str = str(node.custom_data[c_key]).xml_escape()
			xml += "\t\t\t\t\t<attvalue for=\"%s\" value=\"%s\"/>\n" % [c_key, val_str]
			
		xml += "\t\t\t\t</attvalues>\n"
		xml += "\t\t\t</node>\n"
	xml += "\t\t</nodes>\n"

	# Write Edges [UPDATED FOR CANONICAL STORE]
	xml += "\t\t<edges>\n"
	var edge_id_counter = 0
	for key in graph.edge_store:
		var e = graph.edge_store[key]
		
		var src = e.u
		var tgt = e.v
		if e.direction == 2:
			src = e.v
			tgt = e.u
			
		xml += "\t\t\t<edge id=\"e%d\" source=\"%s\" target=\"%s\" weight=\"%f\"/>\n" % [edge_id_counter, src, tgt, e.weight]
		edge_id_counter += 1
			
	xml += "\t\t</edges>\n"
	xml += "\t</graph>\n"
	xml += "</gexf>\n"

	return xml

# --- GRAPHML IMPORT ---
static func import_graphml(xml_string: String) -> Graph:
	var parser = XMLParser.new()
	if parser.open_buffer(xml_string.to_utf8_buffer()) != OK:
		push_error("GraphSerializer: Failed to parse XML string.")
		return null
		
	var graph = Graph.new()
	var key_map = {} 
	
	var default_directed = false
	var current_node_id = ""
	var current_edge_source = ""
	var current_edge_target = ""
	var current_edge_directed = false
	var current_data_key = ""
	var pending_edge_weight = 1.0
	
	while parser.read() == OK:
		var node_type = parser.get_node_type()
		
		# 1. Opening Tag <tag>
		if node_type == XMLParser.NODE_ELEMENT:
			var tag_name = parser.get_node_name()
			
			if tag_name == "graph":
				var e_def = _get_attr(parser, "edgedefault")
				default_directed = (e_def == "directed")
				
			elif tag_name == "key":
				var k_id = _get_attr(parser, "id")
				key_map[k_id] = {
					"name": _get_attr(parser, "attr.name"),
					"type": _get_attr(parser, "attr.type")
				}
				
			elif tag_name == "node":
				current_node_id = _get_attr(parser, "id")
				graph.nodes[current_node_id] = NodeData.new()
				
			elif tag_name == "edge":
				current_edge_source = _get_attr(parser, "source")
				current_edge_target = _get_attr(parser, "target")
				pending_edge_weight = 1.0
				
				var dir_attr = _get_attr(parser, "directed")
				if dir_attr != "":
					current_edge_directed = (dir_attr.to_lower() == "true")
				else:
					current_edge_directed = default_directed
				
			elif tag_name == "data":
				current_data_key = _get_attr(parser, "key")
				
		# 2. Text Inside Tags: <tag>TEXT</tag>
		elif node_type == XMLParser.NODE_TEXT:
			var text = parser.get_node_data().strip_edges()
			if text == "" or current_data_key == "":
				continue
				
			var attr_name = current_data_key
			var attr_type = "string"
			
			if key_map.has(current_data_key):
				attr_name = key_map[current_data_key]["name"]
				attr_type = key_map[current_data_key]["type"]
				
			var parsed_val = _parse_xml_value(text, attr_type)
			
			if current_node_id != "":
				var n_data = graph.nodes[current_node_id] as NodeData
				match attr_name:
					"x": n_data.position.x = parsed_val
					"y": n_data.position.y = parsed_val
					"type": n_data.type = parsed_val
					"shape": n_data.shape = parsed_val
					_: n_data.set_data(attr_name, parsed_val)
					
			elif current_edge_source != "" and current_edge_target != "":
				if attr_name == "weight":
					pending_edge_weight = float(parsed_val)
					
		# 3. Closing Tag </tag>
		elif node_type == XMLParser.NODE_ELEMENT_END:
			var tag_name = parser.get_node_name()
			if tag_name == "node":
				current_node_id = ""
			elif tag_name == "edge":
				# COMMIT THE EDGE [UPDATED FOR CANONICAL STORE]
				var src = current_edge_source
				var tgt = current_edge_target
				if graph.nodes.has(src) and graph.nodes.has(tgt):
					var is_directed = current_edge_directed
					var is_reversed = (src > tgt)
					
					graph.add_edge(src, tgt, pending_edge_weight, is_directed)
					
					if is_directed and is_reversed:
						var key = graph.get_edge_key(src, tgt)
						if graph.edge_store.has(key): graph.edge_store[key].direction = 2
					
				current_edge_source = ""
				current_edge_target = ""
				current_edge_directed = false
			elif tag_name == "data":
				current_data_key = ""
				
	return graph

# --- GEXF IMPORT ---
static func import_gexf(xml_string: String) -> Graph:
	var parser = XMLParser.new()
	if parser.open_buffer(xml_string.to_utf8_buffer()) != OK:
		push_error("GraphSerializer: Failed to parse GEXF string.")
		return null
		
	var graph = Graph.new()
	var key_map = {} 
	
	var default_directed = false
	var current_node_id = ""
	
	while parser.read() == OK:
		var node_type = parser.get_node_type()
		
		if node_type == XMLParser.NODE_ELEMENT:
			var tag_name = parser.get_node_name()
			
			if tag_name == "graph":
				var e_def = _get_attr(parser, "defaultedgetype")
				default_directed = (e_def == "directed")
				
			elif tag_name == "attribute":
				var k_id = _get_attr(parser, "id")
				key_map[k_id] = {
					"name": _get_attr(parser, "title"),
					"type": _get_attr(parser, "type")
				}
				
			elif tag_name == "node":
				current_node_id = _get_attr(parser, "id")
				graph.nodes[current_node_id] = NodeData.new()
				
			elif tag_name == "attvalue":
				var for_id = _get_attr(parser, "for")
				var val_str = _get_attr(parser, "value")
				
				if current_node_id != "":
					var attr_name = for_id
					var attr_type = "string"
					
					if key_map.has(for_id):
						attr_name = key_map[for_id]["name"]
						attr_type = key_map[for_id]["type"]
						
					var parsed_val = _parse_xml_value(val_str, attr_type)
					var n_data = graph.nodes[current_node_id] as NodeData
					
					match attr_name:
						"x": n_data.position.x = parsed_val
						"y": n_data.position.y = parsed_val
						"type": n_data.type = parsed_val
						"shape": n_data.shape = parsed_val
						_: n_data.set_data(attr_name, parsed_val)
						
			elif tag_name == "edge":
				var src = _get_attr(parser, "source")
				var tgt = _get_attr(parser, "target")
				var weight_str = _get_attr(parser, "weight")
				
				var w = 1.0
				if weight_str != "":
					w = float(weight_str)
					
				# COMMIT THE EDGE [UPDATED FOR CANONICAL STORE]
				if graph.nodes.has(src) and graph.nodes.has(tgt):
					var is_directed = default_directed
					var is_reversed = (src > tgt)
					
					graph.add_edge(src, tgt, w, is_directed)
					
					if is_directed and is_reversed:
						var key = graph.get_edge_key(src, tgt)
						if graph.edge_store.has(key): graph.edge_store[key].direction = 2

		elif node_type == XMLParser.NODE_ELEMENT_END:
			if parser.get_node_name() == "node":
				current_node_id = ""
				
	return graph

# Helper: Safely extract XML attributes
static func _get_attr(parser: XMLParser, attr_name: String) -> String:
	if parser.has_attribute(attr_name):
		return parser.get_named_attribute_value(attr_name)
	return ""

# Helper: Map GraphML types to Godot variants
static func _parse_xml_value(text: String, type: String) -> Variant:
	match type:
		"int", "integer": return text.to_int()
		"double", "float": return text.to_float()
		"boolean": return text.to_lower() == "true"
		_: return text
