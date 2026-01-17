class_name InspectorEdge
extends InspectorStrategy

# --- STATE ---
var _tracked_edges: Array = []
var _edge_inputs: Dictionary = {}

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
	if ref_data.is_empty(): return # Should not happen if tracked_edges > 0
	
	var count = _tracked_edges.size()
	var mixed = _detect_mixed_state(ref_data)
	var schema = []
	
	# 2. Build Schema
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
		"name": "type", "label": "Edge Type", "type": TYPE_INT, "default": ref_data.type, 
		"hint": "enum", "hint_string": "Corridor,Door (Open),Door (Locked),Secret Passage,Climbable", 
		"mixed": mixed.type 
	})
	
	schema.append({ 
		"name": "lock_level", "label": "Lock Level", "type": TYPE_INT, "default": ref_data.lock_level, 
		"min": 0, "max": 10, "mixed": mixed.lock_level 
	})
	
	# Dynamic Properties
	var registered_props = GraphSettings.get_properties_for_target("EDGE")
	if not registered_props.is_empty():
		schema.append({ "name": "sep_custom", "type": TYPE_NIL, "hint": "separator" })
		
	for key in registered_props:
		var def = registered_props[key]
		var val = ref_data.custom.get(key, def.default)
		
		var item = { 
			"name": key, "label": key.capitalize(), "type": def.type, "default": val 
		}
		
		if mixed.custom_keys.has(key):
			item["mixed"] = true
			
		schema.append(item)

	# Actions
	schema.append({ "name": "action_add_property", "label": "Add Custom Data...", "type": TYPE_NIL, "hint": "button" })
	
	# 3. Render
	var section = _create_section("Edge Properties")
	_edge_inputs = SettingsUIBuilder.render_dynamic_section(section, schema, _on_input)

# ==============================================================================
# 3. DATA HELPERS
# ==============================================================================

# Returns a clean dictionary of the first edge's properties to act as the "Truth"
func _get_reference_data() -> Dictionary:
	var pair = _tracked_edges[0]
	var u = pair[0]; var v = pair[1]
	var graph = graph_editor.graph
	
	var data = {
		"weight": 1.0,
		"direction": 0,
		"type": 0,
		"lock_level": 0,
		"custom": {}
	}
	
	# Weight
	if graph.has_edge(u, v): data.weight = graph.get_edge_weight(u, v)
	elif graph.has_edge(v, u): data.weight = graph.get_edge_weight(v, u)
	
	# Direction
	var has_ab = graph.has_edge(u, v)
	var has_ba = graph.has_edge(v, u)
	if has_ab and not has_ba: data.direction = 1
	elif not has_ab and has_ba: data.direction = 2
	
	# Properties
	var raw = graph.get_edge_data(u, v)
	if raw.is_empty() and has_ba: raw = graph.get_edge_data(v, u)
	
	data.type = raw.get("type", 0)
	data.lock_level = raw.get("lock_level", 0)
	data.custom = raw # Store ref to the whole dict for custom keys
	
	return data

func _detect_mixed_state(ref: Dictionary) -> Dictionary:
	var mixed = { "weight": false, "direction": false, "type": false, "lock_level": false, "custom_keys": {} }
	if _tracked_edges.size() <= 1: return mixed
	
	var graph = graph_editor.graph
	var registered_props = GraphSettings.get_properties_for_target("EDGE")
	
	for i in range(1, _tracked_edges.size()):
		var pair = _tracked_edges[i]
		var a = pair[0]; var b = pair[1]
		
		# 1. Check Weight
		var w = 1.0
		if graph.has_edge(a, b): w = graph.get_edge_weight(a, b)
		elif graph.has_edge(b, a): w = graph.get_edge_weight(b, a)
		if not is_equal_approx(w, ref.weight): mixed.weight = true
		
		# 2. Check Direction
		var ab = graph.has_edge(a, b); var ba = graph.has_edge(b, a)
		var d = 0
		if ab and not ba: d = 1
		elif not ab and ba: d = 2
		if d != ref.direction: mixed.direction = true
		
		# 3. Check Props
		var raw = graph.get_edge_data(a, b)
		if raw.is_empty() and ba: raw = graph.get_edge_data(b, a)
		
		if int(raw.get("type", 0)) != ref.type: mixed.type = true
		if int(raw.get("lock_level", 0)) != ref.lock_level: mixed.lock_level = true
		
		# 4. Check Custom
		for key in registered_props:
			if mixed.custom_keys.has(key): continue
			var val_other = raw.get(key)
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
		request_wizard.emit("EDGE")
		return
	
	var graph = graph_editor.graph
	
	for pair in _tracked_edges:
		var u = pair[0]; var v = pair[1]
		
		match key:
			"weight":
				if graph.has_edge(u, v): graph_editor.set_edge_weight(u, v, value)
				if graph.has_edge(v, u): graph_editor.set_edge_weight(v, u, value)
			"direction":
				graph_editor.set_edge_directionality(u, v, int(value))
			_:
				# Catch-all for Type, Lock, and Custom Data
				# Note: 'type' and 'lock_level' are just keys in the edge dictionary,
				# so set_edge_property handles them identically to custom data.
				graph_editor.set_edge_property(u, v, key, value)
				if graph.has_edge(v, u):
					graph_editor.set_edge_property(v, u, key, value)
