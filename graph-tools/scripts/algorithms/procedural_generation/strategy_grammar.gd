class_name StrategyGrammar
extends GraphStrategy

func _init() -> void:
	strategy_name = "Graph Grammar"
	reset_on_generate = false

func get_settings() -> Array[Dictionary]:
	var settings: Array[Dictionary] = super.get_settings()
	
	# 1. Execution Mode Toggle
	settings.append({
		"name": "execution_mode",
		"label": "Execution Mode",
		"type": TYPE_INT,
		"default": 0,
		"hint": "enum",
		"hint_string": "Single Rule,Pipeline Sequence",
		"hint_text": "Single Rule loops one specific rule. Pipeline runs a predefined sequence of rules to generate a full level."
	})
	
	# 2. Single Rule Settings
	var rule_keys = GraphSettings.grammar_rules.keys()
	var rule_names = ",".join(rule_keys)
	settings.append({
		"name": "active_rule",
		"label": "Active Rule (If Single)",
		"type": TYPE_INT,
		"default": 0,
		"hint": "enum",
		"hint_string": rule_names
	})
	
	settings.append({
		"name": "generations",
		"label": "Generations (If Single)",
		"type": TYPE_INT,
		"default": 1,
		"min": 1,
		"max": 100
	})
	
	# 3. Pipeline Settings
	var pipe_keys = GraphSettings.grammar_pipelines.keys()
	var pipe_names = ",".join(pipe_keys) if pipe_keys.size() > 0 else "None"
	settings.append({
		"name": "active_pipeline",
		"label": "Active Pipeline (If Sequence)",
		"type": TYPE_INT,
		"default": 0,
		"hint": "enum",
		"hint_string": pipe_names
	})
	
	return settings

func execute(recorder: GraphRecorder, params: Dictionary) -> void:
	var mode = params.get("execution_mode", 0)
	
	if mode == 0:
		# --- SINGLE RULE MODE ---
		var rule_index = params.get("active_rule", 0)
		var rule_keys = GraphSettings.grammar_rules.keys()
		
		if rule_index >= 0 and rule_index < rule_keys.size():
			var rule_name = rule_keys[rule_index]
			var rule = GraphSettings.grammar_rules[rule_name]
			var generations = params.get("generations", 1)
			
			_run_l_system(recorder, rule_name, rule, generations)
			
	else:
		# --- PIPELINE MODE ---
		var pipe_index = params.get("active_pipeline", 0)
		var pipe_keys = GraphSettings.grammar_pipelines.keys()
		
		if pipe_index >= 0 and pipe_index < pipe_keys.size():
			var pipe_name = pipe_keys[pipe_index]
			var sequence = GraphSettings.grammar_pipelines[pipe_name]
			
			print("\n======================================================")
			print("PIPELINE START: ", pipe_name)
			print("======================================================")
			
			for step in sequence:
				var r_name = step.get("rule", "")
				var r_gens = step.get("generations", 1)
				
				if GraphSettings.grammar_rules.has(r_name):
					var rule = GraphSettings.grammar_rules[r_name]
					_run_l_system(recorder, r_name, rule, r_gens)
				else:
					push_warning("Pipeline Error: Rule '%s' not found!" % r_name)
					
			print("======================================================\n")

# ==============================================================================
# THE ORGANIC GROWTH LOOP (Extracted)
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
		
		safe_matches.shuffle()
		
		for match_dict in safe_matches:
			if max_applications > 0 and final_matches.size() >= max_applications:
				break 
			if randf() <= probability:
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
					spawn_pos += Vector2(randf_range(-10, 10), randf_range(-10, 10))
					
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
	
	# Fallback for legacy 2-node rules that lack a match_edges array
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
	
	# Optimization: If this isn't the first variable, look at the required edges.
	# If this variable must connect to an already-mapped variable, we can drastically 
	# narrow our search space to just the neighbors of that mapped node!
	var search_pool = recorder.nodes.keys()
	for edge in req_edges:
		if edge[0] == current_var and mapping.has(edge[1]):
			search_pool = recorder.get_neighbors(mapping[edge[1]])
			break
		elif edge[1] == current_var and mapping.has(edge[0]):
			search_pool = recorder.get_neighbors(mapping[edge[0]])
			break

	for node_id in search_pool:
		# Ensure mapping is strictly 1-to-1 (Injective)
		if mapping.values().has(node_id): continue
			
		if _does_node_match(recorder, node_id, constraints):
			# Temporarily assign to test structural integrity
			mapping[current_var] = node_id
			
			# Validate that all required edges for currently mapped variables exist
			var edges_valid = true
			for edge in req_edges:
				var u_var = edge[0]
				var v_var = edge[1]
				if mapping.has(u_var) and mapping.has(v_var):
					if not recorder.has_edge(mapping[u_var], mapping[v_var]):
						edges_valid = false
						break
			
			# If topology holds, dive deeper!
			if edges_valid:
				_backtrack_match(var_idx + 1, variables, req_edges, rule, recorder, mapping, results)
				
			# Backtrack
			mapping.erase(current_var)


# --- HELPER: Pair Validation ---

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
