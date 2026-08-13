class_name SemanticLogicGates extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Distribute Logic Gates"
	category = Category.SEMANTIC

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "target_mask", "label": "Target Nodes", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "All Nodes,Affected by Previous Step" },
		{ "name": "prob_and_gate", "label": "AND Gate Probability", "type": TYPE_FLOAT, "default": 0.3, "min": 0.0, "max": 1.0, "step": 0.1 }
	])
	return s

func get_required_semantics() -> Array[Dictionary]:
	return [
		{
			"type": "property",
			"target": SemanticRegistry.TARGET_NODE,
			"key": "logic_gate",
			"label": "Logic Gate",
			"var_type": TYPE_STRING,
			"default": "",
			"display": SemanticRegistry.DisplayMode.BADGE,
			"is_core": true
		}
	]

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	if recorder.nodes.is_empty(): return
	
	var prob_and = local_settings.get("prob_and_gate", 0.3)
	var in_degrees = {}
	
	var target_mask = local_settings.get("target_mask", 0)
	var nodes_to_process = recorder.nodes.keys()
	
	if target_mask == 1:
		nodes_to_process = []
		# [CRITICAL FIX] Pass false so we don't drop logic gates onto the Grid anchors!
		var context_nodes = get_context_nodes(false) 
		for id in context_nodes:
			if recorder.nodes.has(id): nodes_to_process.append(id)
			
	if nodes_to_process.is_empty(): return
	
	for id in recorder.nodes: in_degrees[id] = 0
		
	for key in recorder.edge_store:
		var e = recorder.edge_store[key]
		if in_degrees.has(e.v):
			in_degrees[e.v] += 1
			
	for id in nodes_to_process:
		if in_degrees[id] > 1:
			var gate_type = "AND" if rng.randf() < prob_and else "OR"
			recorder.set_node_property(id, "logic_gate", gate_type)
