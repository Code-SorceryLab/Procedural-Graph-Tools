class_name StrategyGrammar
extends GraphStrategy

func _init() -> void:
	strategy_name = "Graph Grammar"
	reset_on_generate = false

func get_settings() -> Array[Dictionary]:
	var settings: Array[Dictionary] = super.get_settings()
	
	var rule_keys = GraphSettings.grammar_rules.keys()
	var rule_names = ",".join(rule_keys)
	
	# Dynamically build a comprehensive tooltip
	var dynamic_tooltip = GraphSettings.PARAM_TOOLTIPS.grammar.active_rule + "\n\nAvailable Rules:"
	for key in rule_keys:
		var desc = GraphSettings.grammar_rules[key].get("description", "No description available.")
		dynamic_tooltip += "\n- " + key + ": " + desc
	
	settings.append({
		"name": "active_rule",
		"type": TYPE_INT,
		"default": 0,
		"hint": "enum",
		"hint_string": rule_names,
		"hint_text": dynamic_tooltip
	})
	
	return settings

func execute(recorder: GraphRecorder, params: Dictionary) -> void:
	var rule_index = params.get("active_rule", 0)
	
	var rule_keys = GraphSettings.grammar_rules.keys()
	if rule_index < 0 or rule_index >= rule_keys.size():
		return
		
	var rule_name = rule_keys[rule_index]
	var rule = GraphSettings.grammar_rules[rule_name]
	
	# --- DIAGNOSTIC PRINT ---
	print("--- GRAMMAR SCAN START: ", rule_name, " ---")
	for node_id in recorder.nodes:
		var n = recorder.nodes[node_id] as NodeData
		print("Node ", node_id, " -> type: ", n.type, ", shape: ", n.shape)
	# --------------------------
	
	var raw_matches = []
	var processed_edges = {}
	
	for a_id in recorder.nodes:
		for b_id in recorder.get_neighbors(a_id):
			var edge_key = [a_id, b_id]
			edge_key.sort()
			
			if processed_edges.has(edge_key): continue
			processed_edges[edge_key] = true
			
			if _check_pair_match(recorder, a_id, b_id, rule):
				raw_matches.append({ "A": a_id, "B": b_id })
			elif _check_pair_match(recorder, b_id, a_id, rule):
				raw_matches.append({ "A": b_id, "B": a_id })
				
	var safe_matches = []
	var locked_nodes = {}
	
	for match_dict in raw_matches:
		var a = match_dict["A"]
		var b = match_dict["B"]
		
		if not locked_nodes.has(a) and not locked_nodes.has(b):
			safe_matches.append(match_dict)
			locked_nodes[a] = true
			locked_nodes[b] = true
			
	print("StrategyGrammar: Rule '%s' found %d valid transformations." % [rule_name, safe_matches.size()])
			
	# ==========================================================================
	# 3. TRANSFORM (Execute the Rewrite)
	# ==========================================================================
	for match_dict in safe_matches:
		
		# A. Remove Edges
		for edge_pair in rule.get("remove_edges", []):
			var u = match_dict[edge_pair[0]]
			var v = match_dict[edge_pair[1]]
			recorder.remove_edge(u, v)
			
		# B. Apply/Spawn Nodes
		for node_key in rule.get("apply_nodes", {}):
			var instructions = rule["apply_nodes"][node_key]
			
			if instructions.get("is_new", false):
				var pos_a = recorder.get_node_pos(match_dict["A"])
				var pos_b = recorder.get_node_pos(match_dict["B"])
				var spawn_pos = (pos_a + pos_b) / 2.0
				
				var new_id = str(recorder.get_next_display_id())
				recorder.add_node(new_id, spawn_pos)
				recorder.set_node_type(new_id, instructions.get("type", "empty"))
				match_dict[node_key] = new_id
			else:
				var existing_id = match_dict[node_key]
				if instructions.has("type"):
					recorder.set_node_type(existing_id, instructions["type"])
					
		# C. Add Edges (Now supports Extra Data Dictionary!)
		for edge_array in rule.get("apply_edges", []):
			var u = match_dict[edge_array[0]]
			var v = match_dict[edge_array[1]]
			
			var extra_data = {}
			var weight = 1.0
			
			# If the rule includes a 3rd element (the dictionary)
			if edge_array.size() > 2:
				extra_data = edge_array[2]
				weight = extra_data.get("weight", 1.0)
				
			recorder.add_edge(u, v, weight, false, extra_data)

# --- HELPER: Pair Validation ---
func _check_pair_match(recorder: GraphRecorder, id_a: String, id_b: String, rule: Dictionary) -> bool:
	var constraints_a = rule["match_nodes"].get("A", {})
	var constraints_b = rule["match_nodes"].get("B", {})
	
	return _does_node_match(recorder, id_a, constraints_a) and _does_node_match(recorder, id_b, constraints_b)

func _does_node_match(recorder: GraphRecorder, node_id: String, constraints: Dictionary) -> bool:
	if constraints.is_empty(): return true
	
	var node = recorder.nodes[node_id] as NodeData
	if not node: return false
	
	if constraints.has("type") and node.type != constraints["type"]: return false
	
	# --- DYNAMIC TOPOLOGY MATCHING ---
	if constraints.has("shape"):
		var required_shape = constraints["shape"]
		var actual_shape = node.shape
		
		# If the node hasn't been explicitly analyzed, deduce it from its edges!
		if actual_shape == 0:
			var neighbor_count = recorder.get_neighbors(node_id).size()
			if neighbor_count == 1:
				actual_shape = NodeData.RoomShape.DEAD_END
			elif neighbor_count == 2:
				actual_shape = NodeData.RoomShape.CORRIDOR
				
		if actual_shape != required_shape: 
			return false
	# ---------------------------------
	
	# Check semantic custom data (e.g. depth, temp)
	if constraints.has("custom_data"):
		var required_data = constraints["custom_data"]
		for k in required_data:
			if not node.custom_data.has(k) or node.custom_data[k] != required_data[k]:
				return false
				
	return true
