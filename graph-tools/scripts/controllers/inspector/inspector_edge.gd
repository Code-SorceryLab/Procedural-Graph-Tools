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
	
	# Add Snappable Toggle
	var snap_val = ref_data.custom.get("physics_snappable", false)
	schema.append({
		"name": "physics_snappable", "label": "Can Snap (Tension)", "type": TYPE_BOOL,
		"default": snap_val, "mixed": mixed.custom_keys.has("physics_snappable")
	})
	
	# Add Snap Threshold
	var thresh_val = ref_data.custom.get("physics_snap_threshold", 400.0)
	schema.append({
		"name": "physics_snap_threshold", "label": "Snap Threshold", "type": TYPE_FLOAT,
		"default": thresh_val, "step": 10.0, "mixed": mixed.custom_keys.has("physics_snap_threshold")
	})
	
	# Dynamic Properties
	var registered_props = SemanticRegistry.get_properties_for_target(SemanticRegistry.TARGET_EDGE)
	if not registered_props.is_empty():
		
		# Skip our hardcoded physics keys
		var skip_keys = ["physics_spring_length", "physics_stiffness", "physics_mode", "physics_snappable", "physics_snap_threshold"]
		
		# Check if there are actual custom properties besides our intercepted physics ones
		var has_custom = false
		for k in registered_props:
			if k not in skip_keys:
				has_custom = true
				break
				
		if has_custom:
			schema.append({ "name": "sep_custom", "type": TYPE_NIL, "hint": "separator" })
			
			for key in registered_props:
				if key in skip_keys: continue # Skip!
				
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
	
	var key_fwd = graph.get_edge_key(u, v)
	var key_rev = graph.get_edge_key(v, u)
	
	var has_fwd = graph.edge_store.has(key_fwd)
	var has_rev = graph.edge_store.has(key_rev)
	
	var ref_edge = null
	var dir = 0
	
	# Determine Direction Status & grab a reference record
	if has_fwd and has_rev:
		dir = 0
		ref_edge = graph.edge_store[key_fwd]
	elif has_fwd:
		dir = 1
		ref_edge = graph.edge_store[key_fwd]
	elif has_rev:
		dir = 2
		ref_edge = graph.edge_store[key_rev]
	else:
		return { "weight": 1.0, "direction": 0, "type": "corridor", "custom": {} }
		
	return {
		"weight": ref_edge.weight,
		"direction": dir,
		"type": str(ref_edge.custom.get("type", "corridor")), 
		"custom": ref_edge.custom 
	}

func _detect_mixed_state(ref: Dictionary) -> Dictionary:
	var mixed = { "weight": false, "direction": false, "type": false, "custom_keys": {} }
	var graph = graph_editor.graph
	var registered_props = SemanticRegistry.get_properties_for_target(SemanticRegistry.TARGET_EDGE)
	
	# Notice we start from 0! Even a single selected edge might be internally 
	# asymmetrical (e.g. A->B weight is 1.0, B->A weight is 5.0)
	for pair in _tracked_edges:
		var key_fwd = graph.get_edge_key(pair[0], pair[1])
		var key_rev = graph.get_edge_key(pair[1], pair[0])
		
		var has_fwd = graph.edge_store.has(key_fwd)
		var has_rev = graph.edge_store.has(key_rev)
		
		# 1. Check Direction Mixed
		var d = 0
		if has_fwd and has_rev: d = 0
		elif has_fwd: d = 1
		elif has_rev: d = 2
		if d != ref.direction: mixed.direction = true
		
		# Helper to compare any edge record against our reference
		var check_edge = func(e):
			if not is_equal_approx(e.weight, ref.weight): mixed.weight = true
			if str(e.custom.get("type", "corridor")) != ref.type: mixed.type = true
			for key in registered_props:
				if mixed.custom_keys.has(key): continue
				if str(e.custom.get(key)) != str(ref.custom.get(key)):
					mixed.custom_keys[key] = true

		# 2. Check Data Mixed (Evaluate both sides of the line if they exist!)
		if has_fwd: check_edge.call(graph.edge_store[key_fwd])
		if has_rev: check_edge.call(graph.edge_store[key_rev])
			
	return mixed

# ==============================================================================
# 4. INPUT HANDLER
# ==============================================================================

func _on_input(key: String, value: Variant) -> void:
	if _tracked_edges.is_empty(): return
	
	if key == "action_add_property":
		request_wizard.emit(SemanticRegistry.TARGET_EDGE)
		return
	
	var graph = graph_editor.graph
	
	# ALWAYS wrap edge edits in a transaction, because modifying a single 
	# bidirectional line on the screen means modifying TWO records in the database.
	graph_editor.start_undo_transaction("Edit Edge Properties")
	
	for pair in _tracked_edges:
		var u = pair[0]; var v = pair[1]
		
		var has_fwd = graph.edge_store.has(graph.get_edge_key(u, v))
		var has_rev = graph.edge_store.has(graph.get_edge_key(v, u))
		
		match key:
			"weight":
				if has_fwd: graph_editor.set_edge_weight(u, v, value)
				if has_rev: graph_editor.set_edge_weight(v, u, value)
			"direction":
				graph_editor.set_edge_directionality(u, v, int(value))
			"type":
				var ui_idx = int(value)
				if ui_idx >= 0 and ui_idx < _type_keys_cache.size():
					var string_type = _type_keys_cache[ui_idx]
					if has_fwd: graph_editor.set_edge_property(u, v, "type", string_type)
					if has_rev: graph_editor.set_edge_property(v, u, "type", string_type)
			_:
				# Catch-all for Custom Data (AND our physics properties!)
				if has_fwd: graph_editor.set_edge_property(u, v, key, value)
				if has_rev: graph_editor.set_edge_property(v, u, key, value)
				
	graph_editor.commit_undo_transaction()
