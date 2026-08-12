class_name GeoJitter extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Jitter Geometry"
	category = Category.GEOMETRY

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append({ "name": "amount", "label": "Jitter Amount", "type": TYPE_FLOAT, "default": 10.0, "min": 0.0, "max": 150.0 })
	# [NEW] Target Mask Setting
	s.append({ "name": "target_mask", "label": "Target Nodes", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "All Nodes,Affected by Previous Step" })
	return s

func execute(recorder: GraphRecorder) -> void:
	setup_rng()

	var amt = float(local_settings.get("amount", 10.0))
	if amt <= 0.0: return

	var target_mask = local_settings.get("target_mask", 0)
	var nodes_to_jitter = recorder.nodes.keys()

	# Context Masking
	if target_mask == 1:
		nodes_to_jitter = []
		var context_nodes = get_context_nodes(false)
		for id in context_nodes:
			if recorder.nodes.has(id):
				nodes_to_jitter.append(id)

	for id in nodes_to_jitter:
		if not recorder.nodes.has(id): continue

		var pos = recorder.get_node_pos(id)
		var j_x = rng.randf_range(-amt, amt)
		var j_y = rng.randf_range(-amt, amt)
		var new_pos = pos + Vector2(j_x, j_y)

		# Single API call updates sandbox, tracks touched_nodes, and records CmdMoveNode
		recorder.set_node_position(id, new_pos)
