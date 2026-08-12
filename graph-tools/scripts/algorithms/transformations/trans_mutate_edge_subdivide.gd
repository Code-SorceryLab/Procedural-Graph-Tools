class_name MutateEdgeSubdivide extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Subdivide Edges"
	category = Category.TOPOLOGY

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	
	# Dynamically pull node categories from the Registry
	var type_hint = ""
	if SemanticRegistry:
		var schema = SemanticRegistry.get_category_ui_schema(SemanticRegistry.TARGET_NODE)
		type_hint = schema["hint_string"]
		
	s.append_array([
		{ "name": "subdivide_chance", "label": "Subdivide Chance (%)", "type": TYPE_INT, "default": 50, "min": 0, "max": 100 },
		{ "name": "cuts_per_edge", "label": "Cuts per Edge", "type": TYPE_INT, "default": 1, "min": 1, "max": 10, "hint_text": "1 cut creates 1 new node (2 segments)." },
		{ "name": "target_mask", "label": "Target Nodes", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "All Nodes,Affected by Previous Step" },
		{ "name": "direction_mode", "label": "Edge Direction", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "Match Original,Force Bi-Directional,Force Forward (A->B),Force Reverse (B->A)" },
		{ "name": "new_node_type", "label": "New Node Type", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": type_hint }
	])
	return s

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	
	var chance = float(local_settings.get("subdivide_chance", 50)) / 100.0
	if chance <= 0.0: return
	
	var cuts = local_settings.get("cuts_per_edge", 1)
	var dir_mode = local_settings.get("direction_mode", 0)
	
	var spawn_type = "empty"
	if SemanticRegistry:
		var schema = SemanticRegistry.get_category_ui_schema(SemanticRegistry.TARGET_NODE)
		var type_keys = schema["keys"]
		var ui_idx = local_settings.get("new_node_type", 0)
		if ui_idx >= 0 and ui_idx < type_keys.size():
			spawn_type = type_keys[ui_idx]

	# [NEW] Establish Mask
	var target_mask = local_settings.get("target_mask", 0)
	var node_pool = recorder.nodes.keys()
	
	if target_mask == 1:
		node_pool = []
		# Grab touched nodes AND endpoints of touched edges!
		var context_nodes = get_context_nodes(true) 
		for id in context_nodes:
			if recorder.nodes.has(id): node_pool.append(id)
			
	var node_set = {}
	for id in node_pool: node_set[id] = true

	var edge_keys = recorder.edge_store.keys().duplicate()
	var processed_pairs = {}
	
	for key in edge_keys:
		if not recorder.edge_store.has(key): continue
		
		var e = recorder.edge_store[key]
		var u_id = e.u
		var v_id = e.v
		
		# [CRITICAL FIX] Ensure BOTH endpoints are within the mask!
		if not node_set.has(u_id) or not node_set.has(v_id): continue 
		
		# 1. Deduplicate processing for Bidirectional edges
		var pair = [u_id, v_id]
		pair.sort()
		if processed_pairs.has(pair): continue
		processed_pairs[pair] = true
		
		if rng.randf() > chance: continue
		
		# 2. Check original edge direction state
		var key_fwd = ""
		var key_rev = ""
		
		for k in recorder.edge_store:
			var check_e = recorder.edge_store[k]
			if check_e.u == u_id and check_e.v == v_id: key_fwd = k
			elif check_e.u == v_id and check_e.v == u_id: key_rev = k
			
		var has_fwd = key_fwd != ""
		var has_rev = key_rev != ""
		
		# 3. Determine new directionality rules based on UI setting
		var apply_fwd = has_fwd
		var apply_rev = has_rev
		
		match dir_mode:
			1: # Force Bi-Directional
				apply_fwd = true
				apply_rev = true
			2: # Force Forward (A -> B)
				apply_fwd = true
				apply_rev = false
			3: # Force Reverse (B -> A)
				apply_fwd = false
				apply_rev = true
				
		var pos_start = recorder.get_node_pos(u_id)
		var pos_end = recorder.get_node_pos(v_id)
		
		# 4. Remove the original long edges entirely
		if has_fwd: recorder.remove_edge(u_id, v_id)
		if has_rev: recorder.remove_edge(v_id, u_id)
		
		var previous_id = u_id
		var segments = cuts + 1
		var segment_weight = e.weight / float(segments)
		var custom_data = e.custom.duplicate(true)
		
		# 5. Insert the chain of new nodes
		for i in range(1, segments):
			var t = float(i) / float(segments)
			var spawn_pos = pos_start.lerp(pos_end, t)
			
			var new_id = str(recorder.get_next_display_id())
			recorder.add_node(new_id, spawn_pos)
			recorder.set_node_type(new_id, spawn_type)
			
			# Connect the chain using our exact directionality rules
			if apply_fwd: recorder.add_edge(previous_id, new_id, segment_weight, true, custom_data.duplicate(true))
			if apply_rev: recorder.add_edge(new_id, previous_id, segment_weight, true, custom_data.duplicate(true))
			
			previous_id = new_id
			
		# 6. Connect the final new node to the original destination
		if apply_fwd: recorder.add_edge(previous_id, v_id, segment_weight, true, custom_data.duplicate(true))
		if apply_rev: recorder.add_edge(v_id, previous_id, segment_weight, true, custom_data.duplicate(true))
