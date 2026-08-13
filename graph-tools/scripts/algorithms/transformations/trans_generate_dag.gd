class_name GenerateDAG extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Generate DAG"
	category = Category.GENERATOR

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "total_nodes", "label": "Total Nodes", "type": TYPE_INT, "default": 15, "min": 3, "max": 100 },
		{ "name": "num_layers", "label": "Topological Depth", "type": TYPE_INT, "default": 5, "min": 2, "max": 20 },
		{ "name": "extra_edges", "label": "Interconnectivity", "type": TYPE_INT, "default": 5, "min": 0, "max": 50 },
		{ "name": "spacing_x", "label": "Layer Spacing (X)", "type": TYPE_FLOAT, "default": 250.0, "step": 10.0 },
		{ "name": "spacing_y", "label": "Sibling Spacing (Y)", "type": TYPE_FLOAT, "default": 150.0, "step": 10.0 },
		{ "name": "val_root", "label": "Root Type", "type": TYPE_STRING, "default": "start" },
		{ "name": "val_sink", "label": "Sink Type", "type": TYPE_STRING, "default": "boss" },
		{ "name": "key_depth", "label": "Depth Data Key", "type": TYPE_STRING, "default": "dag_depth" }
	])
	return s

func get_required_semantics() -> Array[Dictionary]:
	var reqs: Array[Dictionary] = []
	var v_root: String = local_settings.get("val_root", "start")
	var v_sink: String = local_settings.get("val_sink", "boss")
	var k_depth: String = local_settings.get("key_depth", "dag_depth")

	reqs.append({
		"type": "category",
		"target": SemanticRegistry.TARGET_NODE,
		"key": v_root,
		"name": v_root.capitalize(),
		"color": Color(0.2, 0.8, 0.2),
		"is_core": true
	})

	reqs.append({
		"type": "category",
		"target": SemanticRegistry.TARGET_NODE,
		"key": v_sink,
		"name": v_sink.capitalize(),
		"color": Color(0.8, 0.2, 0.2),
		"is_core": true
	})

	reqs.append({
		"type": "property",
		"target": SemanticRegistry.TARGET_NODE,
		"key": k_depth,
		"label": "DAG Depth",
		"var_type": TYPE_INT,
		"default": 0,
		"display": SemanticRegistry.DisplayMode.LABEL,
		"is_core": true
	})

	return reqs

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	
	var total_nodes = local_settings.get("total_nodes", 15)
	var num_layers = local_settings.get("num_layers", 5)
	var extra_edges = local_settings.get("extra_edges", 5)
	var spacing = Vector2(local_settings.get("spacing_x", 250.0), local_settings.get("spacing_y", 150.0))
	var v_root = local_settings.get("val_root", "start")
	var v_sink = local_settings.get("val_sink", "boss")
	var k_depth = local_settings.get("key_depth", "dag_depth")
	
	if total_nodes < num_layers: total_nodes = num_layers
	

	var layers: Array = []
	for i in range(num_layers): layers.append([])
	
	var node_counter = 1
	layers[0].append("dag_0")
	layers[num_layers - 1].append("dag_%d" % (total_nodes - 1))
	
	var middle_nodes = total_nodes - 2
	for i in range(middle_nodes):
		var target_layer = 1 if num_layers <= 2 else rng.randi_range(1, num_layers - 2)
		layers[target_layer].append("dag_%d" % node_counter)
		node_counter += 1
		
	for layer_idx in range(layers.size()):
		var layer_nodes = layers[layer_idx]
		var layer_size = layer_nodes.size()
		for sibling_idx in range(layer_size):
			var id = layer_nodes[sibling_idx]
			var pos_x = layer_idx * spacing.x
			var offset_y = (sibling_idx - (layer_size - 1) / 2.0) * spacing.y
			
			recorder.add_node(id, Vector2(pos_x, offset_y))
			recorder.set_node_property(id, k_depth, layer_idx)
			
			if layer_idx == 0: recorder.set_node_type(id, v_root)
			elif layer_idx == layers.size() - 1: recorder.set_node_type(id, v_sink)
				
	for layer_idx in range(1, layers.size()):
		var current_layer = layers[layer_idx]
		var prev_layer = layers[layer_idx - 1]
		for node_id in current_layer:
			var parent_id = prev_layer[rng.randi() % prev_layer.size()]
			recorder.add_edge(parent_id, node_id, 1.0, true)
			
	for i in range(extra_edges):
		var layer_u_idx = rng.randi_range(0, layers.size() - 2)
		var layer_v_idx = rng.randi_range(layer_u_idx + 1, layers.size() - 1)
		var pool_u = layers[layer_u_idx]
		var pool_v = layers[layer_v_idx]
		if pool_u.is_empty() or pool_v.is_empty(): continue
		var node_u = pool_u[rng.randi() % pool_u.size()]
		var node_v = pool_v[rng.randi() % pool_v.size()]
		recorder.add_edge(node_u, node_v, 1.0, true)
