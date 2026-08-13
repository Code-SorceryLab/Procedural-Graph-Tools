class_name SemanticEdgeWeightsFromDistance
extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Edge Weights from Distance"
	category = Category.SEMANTIC

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "scale_factor", "label": "Scale Factor", "type": TYPE_FLOAT, "default": 1.0, "min": 0.01, "max": 10.0, "step": 0.1, "hint_text": "Multiplies the physical distance to produce the final weight." },
		{ "name": "weight_min", "label": "Minimum Weight", "type": TYPE_FLOAT, "default": 0.1, "min": 0.0, "max": 100.0, "step": 0.1, "hint_text": "Clamps the resulting weight to be at least this value." },
		{ "name": "weight_max", "label": "Maximum Weight", "type": TYPE_FLOAT, "default": -1.0, "min": -1.0, "max": 1000.0, "step": 1.0, "hint_text": "Clamps the resulting weight to be at most this value. -1 = no cap." },
		{ "name": "target_mask", "label": "Target Edges", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "All Edges,Affected by Previous Step" }
	])
	return s

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	if recorder.nodes.is_empty() or recorder.edge_store.is_empty(): return

	var scale_factor = float(local_settings.get("scale_factor", 1.0))
	var weight_min = float(local_settings.get("weight_min", 0.1))
	var weight_max = float(local_settings.get("weight_max", -1.0))

	var target_mask = local_settings.get("target_mask", 0)

	# Build a set of canonical (sorted) edge pairs if we are masking
	var edge_set = {}
	if target_mask == 1:
		var context_edges = get_context_edges()
		for pair in context_edges:
			var p = [pair[0], pair[1]]
			p.sort()
			edge_set[p] = true

	# Iterate over every directed edge record in the store
	for key in recorder.edge_store.keys():
		var e = recorder.edge_store[key]

		if not recorder.nodes.has(e.u) or not recorder.nodes.has(e.v):
			continue

		# If masking, only process edges whose undirected pair is in the touched set
		if target_mask == 1:
			var pair = [e.u, e.v]
			pair.sort()
			if not edge_set.has(pair):
				continue

		var pos_u = recorder.get_node_pos(e.u)
		var pos_v = recorder.get_node_pos(e.v)

		var distance = pos_u.distance_to(pos_v)
		var new_weight = distance * scale_factor

		# Clamp
		new_weight = max(new_weight, weight_min)
		if weight_max >= 0.0:
			new_weight = min(new_weight, weight_max)

		# Record the weight change (ignored if unchanged)
		recorder.set_edge_property(e.u, e.v, "weight", new_weight)
