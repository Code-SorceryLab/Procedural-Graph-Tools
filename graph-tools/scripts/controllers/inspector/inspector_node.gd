class_name InspectorNode
extends InspectorStrategy

# --- STATE ---
var _tracked_nodes: Array[String] = []
var _node_inputs: Dictionary = {}

# ==============================================================================
# 1. LIFECYCLE
# ==============================================================================

func _init(p_editor: GraphEditor, p_container: Control) -> void:
	# [CHANGE] We now use the standard container from the base class
	# Update InspectorController to pass just ONE container (e.g. 'single_container' or a new 'node_container')
	super._init(p_editor, p_container)

func can_handle(nodes: Array, _edges, _agents, _zones) -> bool:
	return not nodes.is_empty()

func enter(nodes: Array, _edges, _agents, _zones) -> void:
	super.enter(nodes, _edges, _agents, _zones)
	_tracked_nodes = nodes
	_rebuild_node_ui()

func update(nodes: Array, _edges, _agents, _zones) -> void:
	_tracked_nodes = nodes
	_rebuild_node_ui()

func exit() -> void:
	super.exit()
	_tracked_nodes.clear()
	_node_inputs.clear()

# ==============================================================================
# 2. UI CONSTRUCTION
# ==============================================================================

func _rebuild_node_ui() -> void:
	if _tracked_nodes.is_empty(): return
	var graph = graph_editor.graph
	
	# 1. Validate Nodes exist in Graph
	var valid_nodes: Array[String] = []
	for id in _tracked_nodes:
		if graph.nodes.has(id): valid_nodes.append(id)
	if valid_nodes.is_empty(): return
	
	var count = valid_nodes.size()
	var first_id = valid_nodes[0]
	var first_node = graph.nodes[first_id]
	
	# 2. Prepare Shared Data
	var type_hint = _get_type_hint_string()
	var schema = []
	
	# 3. Detect Mixed Values (for Batch Selection)
	var mixed_keys = {}
	if count > 1:
		mixed_keys = _detect_mixed_values(valid_nodes, graph)
	
	# --- BUILD HEADER ---
	if count == 1:
		schema.append({ "name": "head", "label": "ID: %s" % first_id, "type": TYPE_STRING, "default": "", "hint": "read_only" })
	else:
		schema.append({ "name": "head", "label": "Selection", "type": TYPE_STRING, "default": "%d Nodes Selected" % count, "hint": "read_only" })
	
	# --- BUILD CORE PROPERTIES ---
	
	# Position (Show editable for Single, or Average for Group)
	if count == 1:
		schema.append({ "name": "pos_x", "label": "Position X", "type": TYPE_FLOAT, "default": first_node.position.x, "step": GraphSettings.INSPECTOR_POS_STEP })
		schema.append({ "name": "pos_y", "label": "Position Y", "type": TYPE_FLOAT, "default": first_node.position.y, "step": GraphSettings.INSPECTOR_POS_STEP })
	else:
		# Calculate Bounding Box Center
		var center_sum = Vector2.ZERO
		for id in valid_nodes: center_sum += graph.nodes[id].position
		var avg = center_sum / count
		schema.append({ "name": "stat_center", "label": "Avg Center", "type": TYPE_VECTOR2, "default": avg, "hint": "read_only" })

	# Type (Editable in both modes)
	schema.append({ 
		"name": "type", 
		"label": "Room Type", 
		"type": TYPE_INT, 
		"default": first_node.type, 
		"hint": "enum", 
		"hint_string": type_hint,
		"mixed": mixed_keys.get("type", false)
	})
	
	# Neighbors (Single Only)
	if count == 1:
		var neighbors = graph.get_neighbors(first_id)
		var neighbor_text = "(None)" if neighbors.is_empty() else "\n".join(neighbors)
		schema.append({ "name": "info_n", "label": "Neighbors", "type": TYPE_STRING, "default": neighbor_text, "hint": "read_only_multiline" })

	# --- DYNAMIC PROPERTIES ---
	var registered_props = GraphSettings.get_properties_for_target("NODE")
	if not registered_props.is_empty():
		schema.append({ "name": "sep_custom", "type": TYPE_NIL, "hint": "separator" })
		
	for key in registered_props:
		var def = registered_props[key]
		var val = def.default
		
		# Use first node as reference
		if "custom_data" in first_node:
			val = first_node.custom_data.get(key, def.default)
			
		var item = { 
			"name": key, 
			"label": key.capitalize(), 
			"type": def.type, 
			"default": val 
		}
		
		if mixed_keys.get(key, false):
			item["mixed"] = true
			
		schema.append(item)

	# Wizard Button
	schema.append({ "name": "action_add_property", "label": "Add Custom Data...", "type": TYPE_NIL, "hint": "button" })

	# --- RENDER ---
	# [CHANGE] Use collapsible section
	var title = "Node Properties" if count == 1 else "Bulk Node Properties"
	var section = _create_section(title)
	
	_node_inputs = SettingsUIBuilder.render_dynamic_section(section, schema, _on_input)

# ==============================================================================
# 3. HELPERS
# ==============================================================================

func _get_type_hint_string() -> String:
	var ids = GraphSettings.current_names.keys()
	ids.sort() 
	var type_names = []
	for id in ids: type_names.append(GraphSettings.get_type_name(id))
	return ",".join(type_names)

func _detect_mixed_values(nodes: Array, graph: Graph) -> Dictionary:
	var mixed = {}
	var ref_node = graph.nodes[nodes[0]]
	
	for i in range(1, nodes.size()):
		var other = graph.nodes[nodes[i]]
		
		# Check Type
		if ref_node.type != other.type:
			mixed["type"] = true
			
		# Check Custom Data
		var registered = GraphSettings.get_properties_for_target("NODE")
		for key in registered:
			var val_a = ref_node.custom_data.get(key) if "custom_data" in ref_node else null
			var val_b = other.custom_data.get(key) if "custom_data" in other else null
			if str(val_a) != str(val_b):
				mixed[key] = true
				
	return mixed

# ==============================================================================
# 4. INPUT HANDLER
# ==============================================================================

func _on_input(key: String, value: Variant) -> void:
	if _tracked_nodes.is_empty(): return
	var graph = graph_editor.graph
	
	if key == "action_add_property":
		request_wizard.emit("NODE")
		return

	# Single Mode Updates
	if _tracked_nodes.size() == 1:
		var id = _tracked_nodes[0]
		var current_pos = graph.get_node_pos(id)
		
		match key:
			"pos_x": graph_editor.set_node_position(id, Vector2(value, current_pos.y))
			"pos_y": graph_editor.set_node_position(id, Vector2(current_pos.x, value))
			"type": graph_editor.set_node_type(id, int(value))
			_:
				# Dynamic Property
				# Use a specific setter if available, else direct dict access
				var node_obj = graph.nodes[id]
				if node_obj.has_method("set_data"): node_obj.set_data(key, value)
				elif "custom_data" in node_obj: node_obj.custom_data[key] = value
				
	# Batch Mode Updates
	else:
		if key == "type":
			graph_editor.set_node_type_bulk(_tracked_nodes, int(value))
		else:
			# Handle Batch Custom Properties
			# Note: Ideally you'd add a 'set_node_property_bulk' to GraphEditor later
			for id in _tracked_nodes:
				var node_obj = graph.nodes[id]
				if node_obj.has_method("set_data"): node_obj.set_data(key, value)
				elif "custom_data" in node_obj: node_obj.custom_data[key] = value
