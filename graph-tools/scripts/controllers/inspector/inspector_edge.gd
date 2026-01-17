class_name InspectorEdge
extends InspectorStrategy

# State
var _tracked_edges: Array = []
var _edge_inputs: Dictionary = {}

func can_handle(_nodes, edges: Array, _agents, _zones) -> bool:
	return not edges.is_empty()

func enter(_nodes, edges: Array, _agents, _zones) -> void:
	super.enter(_nodes, edges, _agents, _zones)
	_tracked_edges = edges
	_rebuild_ui()

func update(_nodes, edges: Array, _agents, _zones) -> void:
	_tracked_edges = edges
	_rebuild_ui()

func exit() -> void:
	super.exit()
	_tracked_edges.clear()

# --- VIEW LOGIC ---

func _rebuild_ui() -> void:
	var schema = _get_schema()
	_edge_inputs = SettingsUIBuilder.render_dynamic_section(container, schema, _on_input)

func _get_schema() -> Array:
	if _tracked_edges.is_empty(): return []
	var graph = graph_editor.graph
	
	var schema = []
	
	# --- 1. SETUP REFERENCE (Truth) ---
	var first_pair = _tracked_edges[0]
	var u = first_pair[0]; var v = first_pair[1]
	
	# A. Reference Weight
	var ref_weight = 1.0
	if graph.has_edge(u, v): ref_weight = graph.get_edge_weight(u, v)
	elif graph.has_edge(v, u): ref_weight = graph.get_edge_weight(v, u)
	
	# B. Reference Direction
	var has_ab = graph.has_edge(u, v)
	var has_ba = graph.has_edge(v, u)
	var ref_dir = 0 
	if has_ab and not has_ba: ref_dir = 1
	elif not has_ab and has_ba: ref_dir = 2
	
	# C. Reference Data (Semantic)
	var ref_data = graph.get_edge_data(u, v)
	if ref_data.is_empty() and has_ba: ref_data = graph.get_edge_data(v, u)
	
	var ref_type = ref_data.get("type", 0)
	var ref_lock = ref_data.get("lock_level", 0)
	
	# --- 2. DETECT MIXED STATE (CORE & DYNAMIC) ---
	var mixed = { "weight": false, "direction": false, "type": false, "lock_level": false }
	var mixed_custom_keys = {}
	
	var registered_props = GraphSettings.get_properties_for_target("EDGE")
	var count = _tracked_edges.size()
	
	# Only loop if we have multiple edges
	if count > 1:
		# Limit analysis for performance if selecting 1000s of edges
		var limit = min(count, GraphSettings.MAX_ANALYSIS_COUNT)
		
		for i in range(1, limit):
			var pair = _tracked_edges[i]
			var a = pair[0]; var b = pair[1]
			
			# 2a. Compare Weight
			var w = 1.0
			if graph.has_edge(a, b): w = graph.get_edge_weight(a, b)
			elif graph.has_edge(b, a): w = graph.get_edge_weight(b, a)
			
			if not is_equal_approx(w, ref_weight): 
				mixed.weight = true
			
			# 2b. Compare Direction
			var ab = graph.has_edge(a, b)
			var ba = graph.has_edge(b, a)
			var d = 0
			if ab and not ba: d = 1
			elif not ab and ba: d = 2
			
			if d != ref_dir: 
				mixed.direction = true
				
			# 2c. Get Other Data
			var other_data = graph.get_edge_data(a, b)
			if other_data.is_empty() and ba: other_data = graph.get_edge_data(b, a)
			
			# 2d. Compare Core Semantics
			if int(other_data.get("type", 0)) != ref_type: mixed.type = true
			if int(other_data.get("lock_level", 0)) != ref_lock: mixed.lock_level = true
			
			# 2e. Compare Dynamic Properties
			for key in registered_props:
				# If we already marked it mixed, skip
				if mixed_custom_keys.has(key): continue
				
				var val_ref = ref_data.get(key)
				var val_other = other_data.get(key)
				
				if str(val_ref) != str(val_other):
					mixed_custom_keys[key] = true

	# --- 3. BUILD SCHEMA ARRAY ---
	
	schema.append_array([
		{ "name": "header_basic", "label": "Selection", "type": TYPE_STRING, "default": "%d Edge(s)" % count, "hint": "read_only" },
		{ "name": "weight", "label": "Weight (Cost)", "type": TYPE_FLOAT, "default": ref_weight, "min": 0.1, "max": 100.0, "step": 0.1, "mixed": mixed.weight },
		{ "name": "direction", "label": "Orientation", "type": TYPE_INT, "default": ref_dir, "hint": "enum", "hint_string": "Bi-Directional,Forward (A->B),Reverse (B->A)", "mixed": mixed.direction },
		{ "name": "header_semantic", "label": "Logic & Gameplay", "type": TYPE_STRING, "default": "Custom Data", "hint": "read_only" },
		{ "name": "type", "label": "Edge Type", "type": TYPE_INT, "default": ref_type, "hint": "enum", "hint_string": "Corridor,Door (Open),Door (Locked),Secret Passage,Climbable", "mixed": mixed.type },
		{ "name": "lock_level", "label": "Lock Level", "type": TYPE_INT, "default": ref_lock, "min": 0, "max": 10, "mixed": mixed.lock_level }
	])
	
	# --- 4. INJECT DYNAMIC PROPERTIES ---
	for key in registered_props:
		var def = registered_props[key]
		var val = ref_data.get(key, def.default)
		
		var item = { 
			"name": key, 
			"label": key.capitalize(), 
			"type": def.type, 
			"default": val 
		}
		
		# Apply Mixed Flag
		if mixed_custom_keys.has(key):
			item["mixed"] = true
			
		schema.append(item)

	# --- 5. ADD WIZARD BUTTON ---
	schema.append({ "name": "action_add_property", "label": "Add Custom Data...", "type": TYPE_NIL, "hint": "button" })
	
	return schema

# --- INPUT HANDLER ---

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
				graph_editor.set_edge_property(u, v, key, value)
				if graph.has_edge(v, u):
					graph_editor.set_edge_property(v, u, key, value)
