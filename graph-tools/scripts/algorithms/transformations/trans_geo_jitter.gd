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

	var target = recorder._target_graph # The live graph!
	
	var target_mask = local_settings.get("target_mask", 0)
	var nodes_to_jitter = recorder.nodes.keys()
	
	# Context Masking
	if target_mask == 1:
		nodes_to_jitter = [] # Override the default
		var context_nodes = get_context_nodes(false)
		# Safely filter out ghost nodes!
		for id in context_nodes:
			if recorder.nodes.has(id):
				nodes_to_jitter.append(id)

	for id in nodes_to_jitter:
		if not recorder.nodes.has(id): continue # Safety check
			
		var pos = recorder.get_node_pos(id)
		var j_x = rng.randf_range(-amt, amt)
		var j_y = rng.randf_range(-amt, amt)
		var new_pos = pos + Vector2(j_x, j_y)
		
		# 1. Quietly update the sandbox so downstream modifiers see the jittered position
		var node = recorder.nodes[id]
		if typeof(node) == TYPE_OBJECT: node.position = new_pos
		else: node["position"] = new_pos
		
		# [NEW] Tell the recorder we touched it so the NEXT step knows!
		# (We have to do this manually because GeoJitter bypasses recorder.set_node_position)
		if not recorder.touched_nodes.has(id): recorder.touched_nodes.append(id)
		
		# 2. Explicitly push the command
		recorder.recorded_commands.append(CmdMoveNode.new(target, id, pos, new_pos))
