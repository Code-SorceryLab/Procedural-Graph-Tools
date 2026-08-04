class_name InspectorNode
extends InspectorStrategy

# --- STATE ---
var _tracked_nodes: Array[String] = []
var _node_inputs: Dictionary = {}
var _type_keys_cache: Array = [] 

# ==============================================================================
# 1. LIFECYCLE
# ==============================================================================

func _init(p_editor: GraphEditor, p_container: Control) -> void:
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
	var schema_data = SemanticRegistry.get_category_ui_schema(SemanticRegistry.TARGET_NODE)
	_type_keys_cache = schema_data["keys"]
	var type_hint = schema_data["hint_string"]
	
	var default_type_idx = _type_keys_cache.find(first_node.type)
	if default_type_idx == -1: default_type_idx = 0
	
	var schema = []
	
	# 3. Detect Mixed Values
	var mixed_keys = {}
	if count > 1:
		mixed_keys = _detect_mixed_values(valid_nodes, graph)
	
	# --- BUILD HEADER ---
	if count == 1:
		schema.append({ "name": "head", "label": "ID: %s" % first_id, "type": TYPE_STRING, "default": "", "hint": "read_only" })
	else:
		schema.append({ "name": "head", "label": "Selection", "type": TYPE_STRING, "default": "%d Nodes Selected" % count, "hint": "read_only" })
	
	# --- BUILD CORE PROPERTIES ---
	
	# Position
	if count == 1:
		schema.append({ "name": "pos_x", "label": "Position X", "type": TYPE_FLOAT, "default": first_node.position.x, "step": GraphSettings.INSPECTOR_POS_STEP })
		schema.append({ "name": "pos_y", "label": "Position Y", "type": TYPE_FLOAT, "default": first_node.position.y, "step": GraphSettings.INSPECTOR_POS_STEP })
	else:
		var center_sum = Vector2.ZERO
		for id in valid_nodes: center_sum += graph.nodes[id].position
		var avg = center_sum / count
		schema.append({ "name": "stat_center", "label": "Avg Center", "type": TYPE_VECTOR2, "default": avg, "hint": "read_only" })

	# Type
	schema.append({ 
		"name": "type", 
		"label": "Room Type", 
		"type": TYPE_INT, 
		"default": default_type_idx,
		"hint": "enum", 
		"hint_string": type_hint,
		"mixed": mixed_keys.get("type", false)
	})
	
	# Neighbors
	if count == 1:
		var neighbors = graph.get_neighbors(first_id)
		var neighbor_text = "(None)" if neighbors.is_empty() else "\n".join(neighbors)
		schema.append({ "name": "info_n", "label": "Neighbors", "type": TYPE_STRING, "default": neighbor_text, "hint": "read_only_multiline" })

	# HARDCODED PHYSICS INJECTION
	# We intercept it here so it belongs to the Core Properties visually.
	var phys_mode_val = 0
	var phys_rep_val = 100.0
	
	if "custom_data" in first_node:
		phys_mode_val = first_node.custom_data.get("physics_mode", 0)
		phys_rep_val = first_node.custom_data.get("physics_repulsion", 100.0)
		
	schema.append({
		"name": "physics_mode", "label": "Physics Mode", "type": TYPE_INT,
		"default": phys_mode_val, "hint": "enum", "hint_string": "Dynamic (Normal),Anchored (Fixed),Ghost (Ignored)",
		"mixed": mixed_keys.get("physics_mode", false)
	})
		
	schema.append({
		"name": "physics_repulsion", "label": "Physics Repulsion", "type": TYPE_FLOAT,
		"default": phys_rep_val, "mixed": mixed_keys.get("physics_repulsion", false)
	})

	# --- DYNAMIC PROPERTIES ---
	var registered_props = SemanticRegistry.get_properties_for_target(SemanticRegistry.TARGET_NODE)
	if not registered_props.is_empty():
		
		# Check if there are any custom properties BESIDES the physics ones
		var has_custom = false
		for k in registered_props:
			if k not in ["physics_repulsion", "physics_mode"]:
				has_custom = true
				break
				
		if has_custom:
			schema.append({ "name": "sep_custom", "type": TYPE_NIL, "hint": "separator" })
			
			for key in registered_props:
				if key in ["physics_repulsion", "physics_mode"]: continue # Skip! We already rendered them above!
				
				var def = registered_props[key]
				var val = def.default
				
				if "custom_data" in first_node:
					val = first_node.custom_data.get(key, def.default)
					
				var item = { 
					"name": key, 
					"label": def.get("label", key.capitalize()),
					"type": def.type, 
					"default": val 
				}
				
				if mixed_keys.get(key, false): item["mixed"] = true
				schema.append(item)

	# Wizard Button
	schema.append({ "name": "action_add_property", "label": "Add Custom Data...", "type": TYPE_NIL, "hint": "button" })

	# --- RENDER ---
	var title = "Node Properties" if count == 1 else "Bulk Node Properties"
	var section = _create_section(title)
	
	_node_inputs = SettingsUIBuilder.render_dynamic_section(section, schema, _on_input)

# ==============================================================================
# 3. HELPERS
# ==============================================================================

func _detect_mixed_values(nodes: Array, graph: Graph) -> Dictionary:
	var mixed = {}
	var ref_node = graph.nodes[nodes[0]]
	
	for i in range(1, nodes.size()):
		var other = graph.nodes[nodes[i]]
		
		if ref_node.type != other.type:
			mixed["type"] = true
			
		var registered = SemanticRegistry.get_properties_for_target(SemanticRegistry.TARGET_NODE)
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

	if _tracked_nodes.size() == 1:
		var id = _tracked_nodes[0]
		var current_pos = graph.get_node_pos(id)
		
		match key:
			"pos_x": graph_editor.set_node_position(id, Vector2(value, current_pos.y))
			"pos_y": graph_editor.set_node_position(id, Vector2(current_pos.x, value))
			"type": 
				var ui_idx = int(value)
				if ui_idx >= 0 and ui_idx < _type_keys_cache.size():
					graph_editor.set_node_type(id, _type_keys_cache[ui_idx])
			_:
				graph_editor.set_node_property(id, key, value)
				
	else:
		# BULK EDIT PATH
		graph_editor.start_undo_transaction("Bulk Edit Node Property")
		
		if key == "type":
			var ui_idx = int(value)
			if ui_idx >= 0 and ui_idx < _type_keys_cache.size():
				graph_editor.set_node_type_bulk(_tracked_nodes, _type_keys_cache[ui_idx])
		else:
			for id in _tracked_nodes:
				graph_editor.set_node_property(id, key, value)
				
		graph_editor.commit_undo_transaction()
