class_name MutateBraid extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Braid Nodes"
	category = Category.TOPOLOGY

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "target_mode", "label": "Target Nodes", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "Dead-Ends Only,All Nodes" },
		{ "name": "target_mask", "label": "Pipeline Mask", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "All Nodes,Affected by Previous Step" },
		{ "name": "braid_chance", "label": "Braid Chance (%)", "type": TYPE_INT, "default": 50, "min": 0, "max": 100 },
		{ "name": "selection_mode", "label": "Connection Type", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "Nearest Valid,Random in Range" },
		{ "name": "max_connections", "label": "Max Connections", "type": TYPE_INT, "default": 1, "min": 1, "max": 8, "hint_text": "How many new edges a selected node is allowed to form." },
		{ "name": "search_range", "label": "Search Radius Multiplier", "type": TYPE_FLOAT, "default": 2.5, "min": 1.0, "max": 10.0, "step": 0.5 }
	])
	return s

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	
	var chance = float(local_settings.get("braid_chance", 50)) / 100.0
	if chance <= 0.0: return
	
	var target_mode = local_settings.get("target_mode", 0)
	var pipeline_mask = local_settings.get("target_mask", 0)
	var selection_mode = local_settings.get("selection_mode", 0)
	var max_conn = local_settings.get("max_connections", 1)
	var radius = max(GraphSettings.GRID_SPACING.x, GraphSettings.GRID_SPACING.y) * local_settings.get("search_range", 2.5)
	
	# [NEW] Establish our restricted processing pool!
	var node_pool = recorder.nodes.keys()
	if pipeline_mask == 1:
		node_pool = []
		var context_nodes = get_context_nodes(false)
		for id in context_nodes:
			if recorder.nodes.has(id): node_pool.append(id)
	
	# 1. Gather Source Nodes
	var source_nodes = []
	for id in node_pool:
		if target_mode == 0:
			# Dead-Ends only (Nodes with 1 or 0 edges)
			if recorder.get_neighbors(id).size() <= 1:
				source_nodes.append(id)
		else:
			# All Nodes
			source_nodes.append(id)
			
	var node_set = {}
	for id in node_pool: node_set[id] = true
			
	# 2. Process Braiding
	for u_id in source_nodes:
		if rng.randf() > chance: continue
		
		var u_pos = recorder.get_node_pos(u_id)
		var existing_neighbors = recorder.get_neighbors(u_id)
		
		var nearby = recorder.get_nodes_near_position(u_pos, radius)
		var valid_candidates = []
		
		# Filter candidates
		for v_id in nearby:
			if not node_set.has(v_id): continue # <--- CRITICAL FIX
			if v_id == u_id or existing_neighbors.has(v_id): continue
			var dist = u_pos.distance_squared_to(recorder.get_node_pos(v_id))
			valid_candidates.append({ "id": v_id, "dist": dist })
			
		if valid_candidates.is_empty(): continue
		
		# Sort or Shuffle based on Connection Type
		if selection_mode == 0:
			# Nearest Valid
			valid_candidates.sort_custom(func(a, b): return a.dist < b.dist)
		else:
			# Random in Range (Deterministic Fisher-Yates shuffle)
			for i in range(valid_candidates.size() - 1, 0, -1):
				var j = rng.randi() % (i + 1)
				var temp = valid_candidates[i]
				valid_candidates[i] = valid_candidates[j]
				valid_candidates[j] = temp
				
		# Connect up to the maximum allowed limit
		var connections_made = 0
		for cand in valid_candidates:
			if connections_made >= max_conn: break
			
			recorder.add_edge(u_id, cand.id)
			existing_neighbors.append(cand.id) # Prevent redundant reciprocal logic in same pass
			connections_made += 1
