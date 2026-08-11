class_name SemanticLogicGates extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Distribute Logic Gates"
	category = Category.SEMANTIC

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "prob_and_gate", "label": "AND Gate Probability", "type": TYPE_FLOAT, "default": 0.3, "min": 0.0, "max": 1.0, "step": 0.1 }
	])
	return s

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	if recorder.nodes.is_empty(): return
	
	if SemanticRegistry:
		SemanticRegistry.ensure_property(SemanticRegistry.TARGET_NODE, "logic_gate", "Logic Gate", TYPE_STRING, "", SemanticRegistry.DisplayMode.BADGE, true)

	var prob_and = local_settings.get("prob_and_gate", 0.3)
	var in_degrees = {}
	
	for id in recorder.nodes: in_degrees[id] = 0
		
	for key in recorder.edge_store:
		var e = recorder.edge_store[key]
		if in_degrees.has(e.v):
			in_degrees[e.v] += 1
			
	for id in in_degrees:
		if in_degrees[id] > 1:
			var gate_type = "AND" if rng.randf() < prob_and else "OR"
			recorder.set_node_property(id, "logic_gate", gate_type)
