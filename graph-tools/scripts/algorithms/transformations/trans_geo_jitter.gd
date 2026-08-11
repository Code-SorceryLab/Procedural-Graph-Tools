class_name GeoJitter extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Jitter Geometry"
	category = Category.GEOMETRY

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append({ "name": "amount", "label": "Jitter Amount", "type": TYPE_FLOAT, "default": 10.0, "min": 0.0, "max": 150.0 })
	return s

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	
	var amt = float(local_settings.get("amount", 10.0))
	if amt <= 0.0: return

	var target = recorder._target_graph # The live graph!

	for id in recorder.nodes:
		var pos = recorder.get_node_pos(id)
		var j_x = rng.randf_range(-amt, amt)
		var j_y = rng.randf_range(-amt, amt)
		var new_pos = pos + Vector2(j_x, j_y)
		
		# 1. Quietly update the sandbox so downstream modifiers see the jittered position
		var node = recorder.nodes[id]
		if typeof(node) == TYPE_OBJECT: node.position = new_pos
		else: node["position"] = new_pos
		
		# 2. Explicitly push the command
		recorder.recorded_commands.append(CmdMoveNode.new(target, id, pos, new_pos))
