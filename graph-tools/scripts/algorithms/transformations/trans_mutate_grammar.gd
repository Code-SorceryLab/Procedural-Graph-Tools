class_name MutateGrammar extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Graph Rewrite (Grammar)"
	category = Category.TOPOLOGY

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	
	# Dynamically pull the rule names from GraphSettings
	var rule_keys = GraphSettings.grammar_rules.keys()
	var rule_names = ",".join(rule_keys)
	
	s.append_array([
		{
			"name": "active_rule",
			"label": "Grammar Rule",
			"type": TYPE_INT,
			"default": 0,
			"hint": "enum",
			"hint_string": rule_names
		},
		{
			"name": "generations",
			"label": "Generations",
			"type": TYPE_INT,
			"default": 1,
			"min": 1,
			"max": 100
		}
	])
	return s

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	
	var rule_index = local_settings.get("active_rule", 0)
	var rule_keys = GraphSettings.grammar_rules.keys()
	
	if rule_index >= 0 and rule_index < rule_keys.size():
		var rule_name = rule_keys[rule_index]
		var rule = GraphSettings.grammar_rules[rule_name]
		var generations = local_settings.get("generations", 1)
		
		_run_l_system(recorder, rule_name, rule, generations)

# ==============================================================================
# THE ORGANIC GROWTH LOOP
# ==============================================================================
func _run_l_system(recorder: GraphRecorder, rule_name: String, rule: Dictionary, generations: int) -> void:
	print("\n--- L-SYSTEM: Rule '%s' for %d Generations ---" % [rule_name, generations])
	
	for gen in range(generations):
		var raw_matches = _find_subgraph_matches(recorder, rule)
			
		var safe_matches = []
		var locked_nodes = {}
		
		# Prevent Overlapping Mutations
		for match_dict in raw_matches:
			var overlap = false
			for var_name in match_dict:
				if locked_nodes.has(match_dict[var_name]):
					overlap = true
					break
			if not overlap:
				safe_matches.append(match_dict)
				for var_name in match_dict:
					locked_nodes[match_dict[var_name]] = true
					
		# Stochastic Filtering & Limits
		var final_matches = []
		var probability = rule.get("probability", 1.0)
		var max_applications = rule.get("max_applications", -1)
		
		SeedUtils.shuffle(safe_matches, rng)
		
		for match_dict in safe_matches:
			if max_applications > 0 and final_matches.size() >= max_applications:
				break 
			if rng.randf() <= probability:
				final_matches.append(match_dict)
				
		print("Gen %d: Found %d safe matches. Executing %d." % [gen + 1, safe_matches.size(), final_matches.size()])
		
		if final_matches.is_empty():
			print("Graph stabilized. Ending rule early.")
			break
				
		# TRANSFORM (Execute the Rewrite)
		for match_dict in final_matches:
			# A. Remove Edges
			for edge_pair in rule.get("remove_edges", []):
				var u = match_dict[edge_pair[0]]
				var v = match_dict[edge_pair[1]]
				recorder.remove_edge(u, v)
				
			# B. Apply/Spawn Nodes
			for node_key in rule.get("apply_nodes", {}):
				var instructions = rule["apply_nodes"][node_key]
				
				if instructions.get("is_new", false):
					var center_pos = Vector2.ZERO
					var count = 0
					for key in match_dict:
						center_pos += recorder.get_node_pos(match_dict[key])
						count += 1
					
					var spawn_pos = center_pos / float(count) if count > 0 else Vector2.ZERO
					spawn_pos += Vector2(rng.randf_range(-10, 10), rng.randf_range(-10, 10))
					
					var new_id = str(recorder.get_next_display_id())
					recorder.add_node(new_id, spawn_pos)
					recorder.set_node_type(new_id, instructions.get("type", "empty"))
					match_dict[node_key] = new_id
				else:
					var existing_id = match_dict[node_key]
					if instructions.has("type"):
						recorder.set_node_type(existing_id, instructions["type"])
						
			# C. Add Edges
			for edge_array in rule.get("apply_edges", []):
				var u = match_dict[edge_array[0]]
				var v = match_dict[edge_array[1]]
				
				var extra_data = {}
				var weight = 1.0
				
				if edge_array.size() > 2:
					extra_data = edge_array[2]
					weight = extra_data.get("weight", 1.0)
					
				recorder.add_edge(u, v, weight, false, extra_data)

# ==============================================================================
# SUBGRAPH ISOMORPHISM ENGINE
# ==============================================================================
func _find_subgraph_matches(recorder: GraphRecorder, rule: Dictionary) -> Array:
	var variables = rule["match_nodes"].keys()
	var req_edges = rule.get("match_edges", [])
	
	if req_edges.is_empty() and variables.size() == 2:
		req_edges = [[variables[0], variables[1]]]
		
	var valid_matches = []
	var current_mapping = {}
	
	_backtrack_match(0, variables, req_edges, rule, recorder, current_mapping, valid_matches)
	return valid_matches

func _backtrack_match(var_idx: int, variables: Array, req_edges: Array, rule: Dictionary, recorder: GraphRecorder, mapping: Dictionary, results: Array) -> void:
	if var_idx == variables.size():
		results.append(mapping.duplicate())
		return
		
	var current_var = variables[var_idx]
	var constraints = rule["match_nodes"][current_var]
	
	var search_pool = recorder.nodes.keys()
	for edge in req_edges:
		if edge[0] == current_var and mapping.has(edge[1]):
			search_pool = recorder.get_neighbors(mapping[edge[1]])
			break
		elif edge[1] == current_var and mapping.has(edge[0]):
			search_pool = recorder.get_neighbors(mapping[edge[0]])
			break

	for node_id in search_pool:
		if mapping.values().has(node_id): continue
			
		if _does_node_match(recorder, node_id, constraints):
			mapping[current_var] = node_id
			
			var edges_valid = true
			for edge in req_edges:
				var u_var = edge[0]
				var v_var = edge[1]
				if mapping.has(u_var) and mapping.has(v_var):
					if not recorder.has_edge(mapping[u_var], mapping[v_var]):
						edges_valid = false
						break
			
			if edges_valid:
				_backtrack_match(var_idx + 1, variables, req_edges, rule, recorder, mapping, results)
				
			mapping.erase(current_var)

func _does_node_match(recorder: GraphRecorder, node_id: String, constraints: Dictionary) -> bool:
	if constraints.is_empty(): return true
	
	var node = recorder.nodes[node_id] as NodeData
	if not node: return false
	
	if constraints.has("type") and node.type != constraints["type"]: return false
	
	# --- DYNAMIC TOPOLOGY MATCHING ---
	if constraints.has("shape"):
		var required_shape = constraints["shape"]
		var actual_shape = node.shape
		
		if actual_shape == 0:
			var neighbor_count = recorder.get_neighbors(node_id).size()
			if neighbor_count == 1:
				actual_shape = NodeData.RoomShape.DEAD_END
			elif neighbor_count == 2:
				actual_shape = NodeData.RoomShape.CORRIDOR
				
		if actual_shape != required_shape: 
			return false
	
	if constraints.has("custom_data"):
		var required_data = constraints["custom_data"]
		for k in required_data:
			if not node.custom_data.has(k) or node.custom_data[k] != required_data[k]:
				return false
				
	return true
