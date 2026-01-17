class_name InspectorNode
extends InspectorStrategy

# Dependencies
var single_container: Control
var group_container: Control

# State
var _tracked_nodes: Array[String] = []
var _node_inputs: Dictionary = {}

func _init(p_editor: GraphEditor, p_single: Control, p_group: Control) -> void:
	# Use 'null' for the generic container since we manage two specific ones manually
	super._init(p_editor, null) 
	single_container = p_single
	group_container = p_group

func can_handle(nodes: Array, _edges, _agents, _zones) -> bool:
	return not nodes.is_empty()

func enter(nodes: Array, _edges, _agents, _zones) -> void:
	_tracked_nodes = nodes
	_refresh_view()

func update(nodes: Array, _edges, _agents, _zones) -> void:
	_tracked_nodes = nodes
	_refresh_view()

func exit() -> void:
	single_container.visible = false
	group_container.visible = false
	_tracked_nodes.clear()

# --- VIEW LOGIC ---

func _refresh_view() -> void:
	var count = _tracked_nodes.size()
	
	single_container.visible = (count == 1)
	group_container.visible = (count > 1)
	
	if count == 1:
		_build_single_inspector(_tracked_nodes[0])
	elif count > 1:
		_build_group_inspector()

func _build_single_inspector(node_id: String) -> void:
	var graph = graph_editor.graph
	if not graph.nodes.has(node_id): return
	
	var node_data = graph.nodes[node_id]
	var neighbors = graph.get_neighbors(node_id)
	
	# 1. Prepare Data
	var neighbor_text = ""
	for n_id in neighbors: neighbor_text += "%s\n" % n_id
	if neighbor_text == "": neighbor_text = "(None)"
	
	var ids = GraphSettings.current_names.keys()
	ids.sort() 
	var type_names = []
	for id in ids: type_names.append(GraphSettings.get_type_name(id))
	var type_hint = ",".join(type_names)
	
	# 2. Schema
	var schema = [
		{ "name": "head", "label": "ID: %s" % node_id, "type": TYPE_STRING, "default": "", "hint": "read_only" },
		{ "name": "pos_x", "label": "Position X", "type": TYPE_FLOAT, "default": node_data.position.x, "step": GraphSettings.INSPECTOR_POS_STEP },
		{ "name": "pos_y", "label": "Position Y", "type": TYPE_FLOAT, "default": node_data.position.y, "step": GraphSettings.INSPECTOR_POS_STEP },
		{ "name": "type", "label": "Room Type", "type": TYPE_INT, "default": node_data.type, "hint": "enum", "hint_string": type_hint },
		{ "name": "info_n", "label": "Neighbors", "type": TYPE_STRING, "default": neighbor_text, "hint": "read_only_multiline" }
	]
	
	# 3. Dynamic Props
	var registered_props = GraphSettings.get_properties_for_target("NODE")
	for key in registered_props:
		var def = registered_props[key]
		var val = def.default
		if "custom_data" in node_data:
			val = node_data.custom_data.get(key, def.default)
		schema.append({ "name": key, "label": key.capitalize(), "type": def.type, "default": val })

	# 4. Wizard Button
	schema.append({ "name": "action_add_property", "label": "Add Custom Data...", "type": TYPE_NIL, "hint": "button" })

	# 5. Render
	_node_inputs = SettingsUIBuilder.render_dynamic_section(single_container, schema, _on_input)

func _build_group_inspector() -> void:
	var graph = graph_editor.graph
	var valid_nodes: Array[String] = []
	
	# Validate
	for id in _tracked_nodes:
		if graph.nodes.has(id): valid_nodes.append(id)
	if valid_nodes.is_empty(): return
	
	var count = valid_nodes.size()
	
	# Stats & Mixed State (Basic Properties)
	var center_sum = Vector2.ZERO
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	var first_type = graph.nodes[valid_nodes[0]].type
	var is_mixed_type = false
	
	for id in valid_nodes:
		var n = graph.nodes[id]
		center_sum += n.position
		min_pos.x = min(min_pos.x, n.position.x)
		min_pos.y = min(min_pos.y, n.position.y)
		max_pos.x = max(max_pos.x, n.position.x)
		max_pos.y = max(max_pos.y, n.position.y)
		if n.type != first_type: is_mixed_type = true

	var avg_center = center_sum / count
	var bounds = max_pos - min_pos
	
	var ids = GraphSettings.current_names.keys()
	ids.sort() 
	var type_names = []
	for id in ids: type_names.append(GraphSettings.get_type_name(id))
	var type_hint_string = ",".join(type_names)

	# [NEW] Detect Mixed Custom Data
	var first_node = graph.nodes[valid_nodes[0]]
	var mixed_custom_keys = {}
	
	# Get all potential custom keys from registry
	var registered_props = GraphSettings.get_properties_for_target("NODE")
	
	for key in registered_props:
		var ref_val = null
		# Use a helper or direct access depending on your Node data structure
		if "custom_data" in first_node:
			ref_val = first_node.custom_data.get(key)
		
		# Compare against all other selected nodes
		for i in range(1, count):
			var other_node = graph.nodes[valid_nodes[i]]
			var other_val = null
			if "custom_data" in other_node:
				other_val = other_node.custom_data.get(key)
			
			# Simple string comparison handles most types safely
			if str(ref_val) != str(other_val):
				mixed_custom_keys[key] = true
				break

	# Build Schema
	var schema = [
		{ "name": "head", "label": "Selection", "type": TYPE_STRING, "default": "%d Nodes" % count, "hint": "read_only" },
		{ "name": "stat_center", "label": "Center", "type": TYPE_VECTOR2, "default": avg_center, "hint": "read_only" },
		{ "name": "stat_bounds", "label": "Bounds", "type": TYPE_VECTOR2, "default": bounds, "hint": "read_only" },
		{ "name": "type", "label": "Bulk Type", "type": TYPE_INT, "default": first_type, "hint": "enum", "hint_string": type_hint_string, "mixed": is_mixed_type }
	]
	
	# Inject Dynamic Properties with Mixed Flags
	if not registered_props.is_empty():
		schema.append({ "name": "sep_custom", "type": TYPE_NIL, "hint": "separator" })

	for key in registered_props:
		var def = registered_props[key]
		var val = def.default
		
		# Use first node as reference value for the input field default
		if "custom_data" in first_node:
			val = first_node.custom_data.get(key, def.default)
			
		var item = { 
			"name": key, 
			"label": key.capitalize(), 
			"type": def.type, 
			"default": val 
		}
		
		# Apply the flag if we detected differences earlier
		if mixed_custom_keys.has(key):
			item["mixed"] = true
			
		schema.append(item)
	
	schema.append({ "name": "action_add_property", "label": "Add Custom Data...", "type": TYPE_NIL, "hint": "button" })
	
	_node_inputs = SettingsUIBuilder.render_dynamic_section(group_container, schema, _on_input)

# --- INPUT HANDLER ---

func _on_input(key: String, value: Variant) -> void:
	if _tracked_nodes.is_empty(): return
	var graph = graph_editor.graph
	
	if key == "action_add_property":
		request_wizard.emit("NODE")
		return

	# Single Mode
	if _tracked_nodes.size() == 1:
		var id = _tracked_nodes[0]
		var current_pos = graph.get_node_pos(id)
		
		match key:
			"pos_x": graph_editor.set_node_position(id, Vector2(value, current_pos.y))
			"pos_y": graph_editor.set_node_position(id, Vector2(current_pos.x, value))
			"type": graph_editor.set_node_type(id, int(value))
			_:
				# Dynamic Property
				var node_obj = graph.nodes[id]
				if node_obj.has_method("set_data"): node_obj.set_data(key, value)
				elif "custom_data" in node_obj: node_obj.custom_data[key] = value

	# Batch Mode
	else:
		if key == "type":
			graph_editor.set_node_type_bulk(_tracked_nodes, int(value))
