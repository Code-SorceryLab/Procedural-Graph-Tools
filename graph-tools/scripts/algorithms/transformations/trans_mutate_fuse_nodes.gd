class_name MutateFuseNodes
extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Fuse Nodes"
	category = Category.TOPOLOGY

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "selection_mode", "label": "Fusion Source", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "Random Edge,All Edges (Nearest),Spatial Clusters" },
		{ "name": "target_mask", "label": "Pipeline Mask", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "All Nodes/Edges,Affected by Previous Step" },
		{ "name": "fusion_count", "label": "Max Fusions", "type": TYPE_INT, "default": 1, "min": -1, "max": 1000, "hint_text": "Number of fusions to perform. -1 = as many as possible." },
		{ "name": "position_mode", "label": "Result Position", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "Midpoint,Keep A,Keep B" },
		{ "name": "property_mode", "label": "Merge Properties", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "Prefer A,Prefer B,Combine" },
		{ "name": "duplicate_policy", "label": "Duplicate Edges", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "Average Weight,Keep First" },
		{ "name": "preserve_self_loop", "label": "Preserve Self-Loop", "type": TYPE_BOOL, "default": false, "hint_text": "If A and B were directly connected, keep that edge as a self-loop on the new node." },
		{ "name": "fuse_threshold", "label": "Spatial Radius Multiplier", "type": TYPE_FLOAT, "default": 0.5, "min": 0.1, "max": 5.0, "step": 0.1, "hint_text": "Only used in Spatial Clusters mode. Multiplier of GRID_SPACING." },
		{ "name": "new_id_prefix", "label": "New Node ID Prefix", "type": TYPE_STRING, "default": "fused", "hint_text": "Prefix for the newly created node ID." }
	])
	return s

func execute(recorder: GraphRecorder) -> void:
	setup_rng()

	var selection_mode = local_settings.get("selection_mode", 0)
	var target_mask = local_settings.get("target_mask", 0)
	var fusion_count = int(local_settings.get("fusion_count", 1))
	var position_mode = local_settings.get("position_mode", 0)
	var property_mode = local_settings.get("property_mode", 0)
	var duplicate_policy = local_settings.get("duplicate_policy", 0)
	var preserve_self_loop = local_settings.get("preserve_self_loop", false)
	var fuse_threshold = float(local_settings.get("fuse_threshold", 0.5))
	var prefix = str(local_settings.get("new_id_prefix", "fused"))

	# --- Build context sets for mask ---
	var context_node_set = {}
	var context_edge_set = {}
	if target_mask == 1:
		for id in get_context_nodes(false):
			if recorder.nodes.has(id):
				context_node_set[id] = true
		for pair in get_context_edges():
			var p = [pair[0], pair[1]]
			p.sort()
			context_edge_set[p] = true

	# --- Gather candidate pairs ---
	var candidate_pairs: Array = []
	var seen_pairs = {}

	if selection_mode == 0:  # Random Edge
		# Gather all undirected edge pairs, respecting mask
		var edge_pairs = []
		var seen_edges = {}
		for key in recorder.edge_store.keys():
			var e = recorder.edge_store[key]
			if not recorder.nodes.has(e.u) or not recorder.nodes.has(e.v):
				continue
			var pair = [e.u, e.v]
			pair.sort()
			if seen_edges.has(pair):
				continue
			seen_edges[pair] = true

			# Apply mask if needed
			if target_mask == 1:
				if not (context_edge_set.has(pair) or context_node_set.has(pair[0]) or context_node_set.has(pair[1])):
					continue
			edge_pairs.append(pair)

		# Directly pick random edges without sorting
		if edge_pairs.is_empty():
			return

		var num_to_pick = edge_pairs.size()
		if fusion_count >= 0:
			num_to_pick = min(fusion_count, edge_pairs.size())

		candidate_pairs = []
		var temp_pool = edge_pairs.duplicate()
		for i in range(num_to_pick):
			var idx = rng.randi() % temp_pool.size()
			candidate_pairs.append(temp_pool[idx])
			temp_pool.remove_at(idx)

	elif selection_mode == 1:  # All Edges (Nearest)
		# Gather all undirected edge pairs, respecting mask
		var seen_edges = {}
		for key in recorder.edge_store.keys():
			var e = recorder.edge_store[key]
			if not recorder.nodes.has(e.u) or not recorder.nodes.has(e.v):
				continue
			var pair = [e.u, e.v]
			pair.sort()
			if seen_edges.has(pair):
				continue
			seen_edges[pair] = true

			# Apply mask if needed
			if target_mask == 1:
				if not (context_edge_set.has(pair) or context_node_set.has(pair[0]) or context_node_set.has(pair[1])):
					continue
			candidate_pairs.append(pair)

		# Sort by spatial distance (ascending)
		candidate_pairs.sort_custom(func(a, b):
			var dist_a = recorder.get_node_pos(a[0]).distance_squared_to(recorder.get_node_pos(a[1]))
			var dist_b = recorder.get_node_pos(b[0]).distance_squared_to(recorder.get_node_pos(b[1]))
			return dist_a < dist_b
		)

	else:  # Spatial Clusters
		var threshold = fuse_threshold * max(GraphSettings.GRID_SPACING.x, GraphSettings.GRID_SPACING.y)
		var node_ids = recorder.nodes.keys()
		for i in range(node_ids.size()):
			var id_a = node_ids[i]
			var pos_a = recorder.get_node_pos(id_a)
			for j in range(i + 1, node_ids.size()):
				var id_b = node_ids[j]
				var pos_b = recorder.get_node_pos(id_b)
				if pos_a.distance_to(pos_b) <= threshold:
					var pair = [id_a, id_b]
					pair.sort()
					if seen_pairs.has(pair):
						continue
					seen_pairs[pair] = true

					if target_mask == 1:
						if not (context_node_set.has(id_a) or context_node_set.has(id_b)):
							continue
					candidate_pairs.append(pair)

	# Sort candidates by spatial distance for deterministic order
	candidate_pairs.sort_custom(func(a, b):
		var dist_a = recorder.get_node_pos(a[0]).distance_squared_to(recorder.get_node_pos(a[1]))
		var dist_b = recorder.get_node_pos(b[0]).distance_squared_to(recorder.get_node_pos(b[1]))
		return dist_a < dist_b
	)

	# --- Apply fusion limit ---
	var fusions_to_do = candidate_pairs.size()
	if fusion_count >= 0:
		fusions_to_do = min(fusions_to_do, fusion_count)

	var performed = 0
	for pair in candidate_pairs:
		if performed >= fusions_to_do:
			break

		var id_a = pair[0]
		var id_b = pair[1]
		if not recorder.nodes.has(id_a) or not recorder.nodes.has(id_b):
			continue

		_fuse_pair(recorder, id_a, id_b, {
			"position_mode": position_mode,
			"property_mode": property_mode,
			"duplicate_policy": duplicate_policy,
			"preserve_self_loop": preserve_self_loop,
			"prefix": prefix
		})
		performed += 1

# ------------------------------------------------------------------------------
# CORE FUSION LOGIC
# ------------------------------------------------------------------------------

func _fuse_pair(recorder: GraphRecorder, id_a: String, id_b: String, params: Dictionary) -> void:
	# 1. Determine new node position
	var pos_a = recorder.get_node_pos(id_a)
	var pos_b = recorder.get_node_pos(id_b)
	var new_pos: Vector2
	match int(params.get("position_mode", 0)):
		0: new_pos = (pos_a + pos_b) / 2.0
		1: new_pos = pos_a
		2: new_pos = pos_b
		_: new_pos = (pos_a + pos_b) / 2.0

	# 2. Generate unique ID
	var prefix = params.get("prefix", "fused")
	var new_id = _generate_unique_node_id(recorder, prefix)

	# 3. Determine merged node type and custom data
	var node_a = recorder.nodes[id_a]
	var node_b = recorder.nodes[id_b]

	var new_type = node_a.type
	var new_custom = {}
	if "custom_data" in node_a:
		new_custom = node_a.custom_data.duplicate(true)

	match int(params.get("property_mode", 0)):
		0: # Prefer A
			pass
		1: # Prefer B
			new_type = node_b.type
			new_custom = node_b.custom_data.duplicate(true) if "custom_data" in node_b else {}
		2: # Combine
			if new_type == "empty" and node_b.type != "empty":
				new_type = node_b.type
			if "custom_data" in node_b:
				for k in node_b.custom_data:
					if not new_custom.has(k):
						new_custom[k] = node_b.custom_data[k]

	# 4. Create the new node
	recorder.add_node(new_id, new_pos)
	recorder.set_node_type(new_id, new_type)
	if not new_custom.is_empty():
		for k in new_custom:
			recorder.set_node_property(new_id, k, new_custom[k])

	# 5. Move agents from A/B to new node
	var agents_to_move = []
	for agent in recorder.agents:
		if agent.current_node_id == id_a or agent.current_node_id == id_b:
			agents_to_move.append(agent)

	for agent in agents_to_move:
		var before = _snapshot_agent(agent)
		var after = before.duplicate(true)
		after["pos"] = new_pos
		after["node_id"] = new_id
		recorder.recorded_commands.append(CmdUpdateAgent.new(recorder._target_graph, agent, before, after))

	# 6. Collect all directed edge records involving A or B
	var edge_records = []
	for key in recorder.edge_store.keys():
		var e = recorder.edge_store[key]
		if e.u == id_a or e.v == id_a or e.u == id_b or e.v == id_b:
			edge_records.append(e.duplicate(true))

	# 7. Transform edges to use new node, deduplicate and combine
	var transformed = {}  # "src->tgt" -> { "u": src, "v": tgt, "weight_sum": float, "count": int, "custom": Dictionary }
	for e in edge_records:
		var src = e.u
		var tgt = e.v

		# Ignore direct edge between A and B unless preserve_self_loop
		if (src == id_a or src == id_b) and (tgt == id_a or tgt == id_b):
			if not params.get("preserve_self_loop", false):
				continue
			src = new_id
			tgt = new_id
		else:
			if src == id_a or src == id_b:
				src = new_id
			if tgt == id_a or tgt == id_b:
				tgt = new_id

		var directed_key = src + "->" + tgt
		if not transformed.has(directed_key):
			transformed[directed_key] = {
				"u": src,
				"v": tgt,
				"weight_sum": float(e.weight),
				"count": 1,
				"custom": e.custom.duplicate(true)
			}
		else:
			var rec = transformed[directed_key]
			rec.weight_sum += float(e.weight)
			rec.count += 1
			# Merge custom with first one taking precedence
			for k in e.custom:
				if not rec.custom.has(k):
					rec.custom[k] = e.custom[k]

	# 8. Add new edges
	for key in transformed:
		var rec = transformed[key]
		var final_weight = rec.weight_sum / float(rec.count) if params.get("duplicate_policy", 0) == 0 else rec.weight_sum
		recorder.add_edge(rec.u, rec.v, final_weight, true, rec.custom)

	# 9. Preserve zone memberships from A/B for logical zones
	for zone in recorder.zones:
		if zone.contains_node(id_a) or zone.contains_node(id_b):
			if not zone.contains_node(new_id):
				zone.register_node(new_id)

	# 10. Remove the original nodes
	recorder.remove_node(id_a)
	recorder.remove_node(id_b)

# ------------------------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------------------------

func _get_incoming_neighbors(recorder: GraphRecorder, node_id: String) -> Array:
	var result = []
	for key in recorder.edge_store.keys():
		var e = recorder.edge_store[key]
		if e.v == node_id:
			result.append(e.u)
	return result

func _snapshot_agent(agent) -> Dictionary:
	return {
		"pos": agent.pos,
		"node_id": agent.current_node_id,
		"step_count": agent.step_count,
		"history": agent.history.duplicate(),
		"active": agent.active,
		"is_finished": agent.is_finished,
		"last_bump_pos": agent.last_bump_pos
	}

func _generate_unique_node_id(recorder: GraphRecorder, prefix: String) -> String:
	var index = 0
	var candidate = "%s_%d" % [prefix, index]
	while recorder.nodes.has(candidate):
		index += 1
		candidate = "%s_%d" % [prefix, index]
	return candidate
