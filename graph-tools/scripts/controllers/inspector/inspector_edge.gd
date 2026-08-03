class_name InspectorEdge
extends InspectorStrategy

# --- STATE ---
var _tracked_edges: Array = []
var _edge_inputs: Dictionary = {}
var _type_keys_cache: Array = [] # aps UI integers to Registry String Keys

# ==============================================================================
# 1. LIFECYCLE
# ==============================================================================

func can_handle(_nodes, edges: Array, _agents, _zones) -> bool:
	return not edges.is_empty()

func enter(_nodes, edges: Array, _agents, _zones) -> void:
	super.enter(_nodes, edges, _agents, _zones)
	_tracked_edges = edges
	_rebuild_edge_ui()

func update(_nodes, edges: Array, _agents, _zones) -> void:
	_tracked_edges = edges
	_rebuild_edge_ui()

func exit() -> void:
	super.exit()
	_tracked_edges.clear()
	_edge_inputs.clear()

# ==============================================================================
# 2. UI CONSTRUCTION
# ==============================================================================

func _rebuild_edge_ui() -> void:
	if _tracked_edges.is_empty(): return
	
	# 1. Gather Data
	var ref_data = _get_reference_data()
	if ref_data.is_empty(): return 
	
	var count = _tracked_edges.size()
	var mixed = _detect_mixed_state(ref_data)
	
	# 2. Prepare Shared Data
	var schema_data = SemanticRegistry.get_category_ui_schema(SemanticRegistry.TARGET_EDGE)
	_type_keys_cache = schema_data["keys"]
	var type_hint = schema_data["hint_string"]
	
	var default_type_idx = _type_keys_cache.find(ref_data.type)
	if default_type_idx == -1: default_type_idx = 0
	
	var schema = []
	
	# 3. Build Schema
	var title = "%d Edge(s)" % count if count > 1 else "Edge Selection"
	schema.append({ "name": "header_basic", "label": "Selection", "type": TYPE_STRING, "default": title, "hint": "read_only" })
	
	# Core Logic
	schema.append({ 
		"name": "weight", "label": "Weight (Cost)", "type": TYPE_FLOAT, "default": ref_data.weight, 
		"min": 0.1, "max": 100.0, "step": 0.1, "mixed": mixed.weight 
	})
	
	schema.append({ 
		"name": "direction", "label": "Orientation", "type": TYPE_INT, "default": ref_data.direction, 
		"hint": "enum", "hint_string": "Bi-Directional,Forward (A->B),Reverse (B->A)", 
		"mixed": mixed.direction 
	})
	
	# Semantic Logic
	schema.append({ "name": "sep_logic", "type": TYPE_NIL, "hint": "separator" })
	
	schema.append({ 
		"name": "type", "label": "Edge Type", "type": TYPE_INT, "default": default_type_idx, 
		"hint": "enum", "hint_string": type_hint, 
		"mixed": mixed.type 
	})
	
	# HARDCODED PHYSICS INJECTION
	# Intercepting these so they belong to the Core Properties visually.
	var phys_mode_val = ref_data.custom.get("physics_mode", 0)
	schema.append({
		"name": "physics_mode", "label": "Physics Mode", "type": TYPE_INT,
		"default": phys_mode_val, "hint": "enum", "hint_string": "Active Spring,Ignored",
		"mixed": mixed.custom_keys.has("physics_mode")
	})

	var spring_len_val = ref_data.custom.get("physics_spring_length", 150.0)
	schema.append({
		"name": "physics_spring_length", "label": "Spring Length", "type": TYPE_FLOAT,
		"default": spring_len_val, "mixed": mixed.custom_keys.has("physics_spring_length")
	})

	var stiff_val = ref_data.custom.get("physics_stiffness", 0.5)
	schema.append({
		"name": "physics_stiffness", "label": "Spring Stiffness", "type": TYPE_FLOAT,
		"default": stiff_val, "step": 0.1, "mixed": mixed.custom_keys.has("physics_stiffness")
	})
	
	# Dynamic Properties
	var registered_props = SemanticRegistry.get_properties_for_target(SemanticRegistry.TARGET_EDGE)
	if not registered_props.is_empty():
		
		# Check if there are actual custom properties besides our intercepted physics ones
		var has_custom = false
		for k in registered_props:
			if k not in ["physics_spring_length", "physics_stiffness", "physics_mode"]:
				has_custom = true
				break
				
		if has_custom:
			schema.append({ "name": "sep_custom", "type": TYPE_NIL, "hint": "separator" })
			
			for key in registered_props:
				if key in ["physics_spring_length", "physics_stiffness", "physics_mode"]: continue # Skip!
				
				var def = registered_props[key]
				var val = ref_data.custom.get(key, def.default)
				
				var item = { 
					"name": key, "label": def.get("label", key.capitalize()), "type": def.type, "default": val 
				}
				
				if mixed.custom_keys.has(key):
					item["mixed"] = true
					
				schema.append(item)

	# Actions
	schema.append({ "name": "action_add_property", "label": "Add Custom Data...", "type": TYPE_NIL, "hint": "button" })
	
	# 4. Render
	var section = _create_section("Edge Properties")
	_edge_inputs = SettingsUIBuilder.render_dynamic_section(section, schema, _on_input)

# ==============================================================================
# 3. DATA HELPERS
# ==============================================================================

func _get_reference_data() -> Dictionary:
	var pair = _tracked_edges[0]
	var u = pair[0]; var v = pair[1]
	var graph = graph_editor.graph
	
	var edge_key = graph.get_edge_key(u, v)
	
	# Fallback if edge doesn't exist
	if not graph.edge_store.has(edge_key):
		return { "weight": 1.0, "direction": 0, "type": "corridor", "custom": {} }
		
	var e = graph.edge_store[edge_key]
	
	var data = {
		"weight": e.weight,
		"direction": e.direction,
		"type": str(e.custom.get("type", "corridor")), 
		"custom": e.custom 
	}
	
	return data

func _detect_mixed_state(ref: Dictionary) -> Dictionary:
	var mixed = { "weight": false, "direction": false, "type": false, "custom_keys": {} }
	if _tracked_edges.size() <= 1: return mixed
	
	var graph = graph_editor.graph
	var registered_props = SemanticRegistry.get_properties_for_target(SemanticRegistry.TARGET_EDGE)
	
	for i in range(1, _tracked_edges.size()):
		var pair = _tracked_edges[i]
		var edge_key = graph.get_edge_key(pair[0], pair[1])
		
		if not graph.edge_store.has(edge_key): continue
		var e = graph.edge_store[edge_key]
		
		# 1. Check Core Variables
		if not is_equal_approx(e.weight, ref.weight): mixed.weight = true
		if e.direction != ref.direction: mixed.direction = true
		
		# 2. Check Type
		if str(e.custom.get("type", "corridor")) != ref.type: mixed.type = true
		
		# 3. Check Custom
		for key in registered_props:
			if mixed.custom_keys.has(key): continue
			var val_other = e.custom.get(key)
			var val_ref = ref.custom.get(key)
			if str(val_other) != str(val_ref):
				mixed.custom_keys[key] = true
				
	return mixed

# ==============================================================================
# 4. INPUT HANDLER
# ==============================================================================

func _on_input(key: String, value: Variant) -> void:
	if _tracked_edges.is_empty(): return
	
	if key == "action_add_property":
		request_wizard.emit(SemanticRegistry.TARGET_EDGE)
		return
	
	#var graph = graph_editor.graph
	var is_bulk = _tracked_edges.size() > 1
	
	# Wrap bulk edits in a single Undo Transaction!
	if is_bulk:
		graph_editor.start_undo_transaction("Bulk Edit Edges")
	
	for pair in _tracked_edges:
		var u = pair[0]; var v = pair[1]
		
		match key:
			"weight":
				graph_editor.set_edge_weight(u, v, value)
			"direction":
				graph_editor.set_edge_directionality(u, v, int(value))
			"type":
				var ui_idx = int(value)
				if ui_idx >= 0 and ui_idx < _type_keys_cache.size():
					var string_type = _type_keys_cache[ui_idx]
					graph_editor.set_edge_property(u, v, "type", string_type)
			_:
				# Catch-all for Custom Data (AND our physics properties!)
				graph_editor.set_edge_property(u, v, key, value)
				
	if is_bulk:
		graph_editor.commit_undo_transaction()
