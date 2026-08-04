extends GraphStrategy
class_name StrategyDAG

func _init() -> void:
	super._init()
	strategy_name = "DAG / Questline"
	# [FIX] Set to false so the Assessor doesn't wipe your existing dungeon!
	reset_on_generate = false 
	supports_grow = false
	supports_agents = false
	supports_zones = true

func get_settings() -> Array[Dictionary]:
	var settings = super.get_settings()
	
	settings.append({
		"name": "dag_mode", "label": "Generator Mode", "type": TYPE_INT,
		"default": 0, "hint": "enum", "hint_string": "Architect (New Graph),Assessor (Analyze Existing)"
	})
	
	# --- SEMANTIC INJECTION SETTINGS ---
	settings.append({ "name": "sep_sem", "type": TYPE_NIL, "hint": "separator" })
	
	settings.append({
		"name": "key_depth", "label": "Depth Key", "type": TYPE_STRING,
		"default": "dag_depth", "hint_text": "The custom data key to store topological depth."
	})
	settings.append({
		"name": "val_root", "label": "Root Room Type", "type": TYPE_STRING,
		"default": "start", "hint_text": "The 'type' string assigned to depth 0 nodes."
	})
	settings.append({
		"name": "val_sink", "label": "Sink Room Type", "type": TYPE_STRING,
		"default": "boss", "hint_text": "The 'type' string assigned to final dead-end nodes."
	})

	# --- ARCHITECT SETTINGS ---
	settings.append({ "name": "sep_arch", "type": TYPE_NIL, "hint": "separator" })
	
	settings.append({
		"name": "total_nodes", "label": "(Arch) Total Nodes", "type": TYPE_INT,
		"default": 15, "min": 3, "max": 100
	})
	settings.append({
		"name": "num_layers", "label": "(Arch) Topological Depth", "type": TYPE_INT,
		"default": 5, "min": 2, "max": 20
	})
	settings.append({
		"name": "extra_edges", "label": "(Arch) Interconnectivity", "type": TYPE_INT,
		"default": 5, "min": 0, "max": 50
	})
	settings.append({
		"name": "spacing_x", "label": "(Arch) Layer Spacing (X)", "type": TYPE_FLOAT,
		"default": 250.0, "step": 10.0
	})
	settings.append({
		"name": "spacing_y", "label": "(Arch) Sibling Spacing (Y)", "type": TYPE_FLOAT,
		"default": 150.0, "step": 10.0
	})
	
	settings.append(_get_zone_setting_def())
	
	return settings

func execute(recorder: GraphRecorder, params: Dictionary) -> void:
	# 1. Seed RNG
	var seed_str = params.get("strategy_seed", "")
	if seed_str != "": rng.seed = seed_str.hash()
	else: rng.randomize()
		
	var mode = params.get("dag_mode", 0)
	
	if mode == 0:
		_run_architect(recorder, params)
	else:
		_run_assessor(recorder, params)

# ==============================================================================
# MODE A: THE ARCHITECT (Generative)
# ==============================================================================
func _run_architect(recorder: GraphRecorder, params: Dictionary) -> void:
	# [FIX] Because reset_on_generate is false, Architect must manually wipe the canvas
	recorder.clear() 
	
	var total_nodes = params.get("total_nodes", 15)
	var num_layers = params.get("num_layers", 5)
	var extra_edges = params.get("extra_edges", 5)
	var spacing = Vector2(params.get("spacing_x", 250.0), params.get("spacing_y", 150.0))
	
	var k_depth = params.get("key_depth", "dag_depth")
	var v_root = params.get("val_root", "start")
	var v_sink = params.get("val_sink", "boss")
	
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
		
	var created_nodes: Array[String] = []
	for layer_idx in range(layers.size()):
		var layer_nodes = layers[layer_idx]
		var layer_size = layer_nodes.size()
		
		for sibling_idx in range(layer_size):
			var id = layer_nodes[sibling_idx]
			var pos_x = layer_idx * spacing.x
			var offset_y = (sibling_idx - (layer_size - 1) / 2.0) * spacing.y
			
			recorder.add_node(id, Vector2(pos_x, offset_y))
			
			# Apply exposed semantics!
			recorder.set_node_property(id, k_depth, layer_idx)
			if layer_idx == 0: recorder.set_node_property(id, "type", v_root)
			elif layer_idx == layers.size() - 1: recorder.set_node_property(id, "type", v_sink)
				
			created_nodes.append(id)
			
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

	if params.get("use_zones", false) and not created_nodes.is_empty():
		recorder.create_zone_from_nodes("Architect Questline", Color(0.8, 0.2, 0.8, 0.5), created_nodes)

# ==============================================================================
# MODE B: THE ASSESSOR (Analytical / Mutative)
# ==============================================================================
func _run_assessor(recorder: GraphRecorder, params: Dictionary) -> void:
	if recorder.nodes.is_empty(): return
	
	var k_depth = params.get("key_depth", "dag_depth")
	var v_root = params.get("val_root", "start")
	var v_sink = params.get("val_sink", "boss")
	
	# 1. Breadth-First Search (BFS)
	var depths = {}
	var queue = []
	
	var start_node = recorder.nodes.keys()[0]
	for id in recorder.nodes:
		if recorder.nodes[id].type == v_root:
			start_node = id
			break
			
	for node_id in recorder.nodes:
		if not depths.has(node_id):
			var root = start_node if depths.is_empty() else node_id
			depths[root] = 0
			queue.append(root)
			
			while not queue.is_empty():
				var curr = queue.pop_front()
				var neighbors = recorder.get_neighbors(curr)
				for n in neighbors:
					if not depths.has(n):
						depths[n] = depths[curr] + 1
						queue.append(n)
						
	# 2. Enforce Acyclicity
	var edges_to_delete = []
	var edges_to_create = []
	
	for key in recorder.edge_store:
		var e = recorder.edge_store[key]
		var u = e.u
		var v = e.v
		var d_u = depths[u]
		var d_v = depths[v]
		var is_directed_currently = (e.direction != 0)
		
		edges_to_delete.append({ "u": u, "v": v, "dir": is_directed_currently })
		
		if d_u < d_v:
			edges_to_create.append({ "u": u, "v": v, "w": e.weight, "data": e.custom })
		elif d_u > d_v:
			edges_to_create.append({ "u": v, "v": u, "w": e.weight, "data": e.custom })
		else:
			if u < v: edges_to_create.append({ "u": u, "v": v, "w": e.weight, "data": e.custom })
			else: edges_to_create.append({ "u": v, "v": u, "w": e.weight, "data": e.custom })
				
	for e in edges_to_delete: recorder.remove_edge(e.u, e.v, e.dir)
	for e in edges_to_create: recorder.add_edge(e.u, e.v, e.w, true, e.data)
		
	# 3. Inject Semantics
	var out_degrees = {}
	for id in recorder.nodes: out_degrees[id] = 0
	for e in edges_to_create: out_degrees[e.u] += 1
		
	for id in recorder.nodes:
		recorder.set_node_property(id, k_depth, depths[id])
		if depths[id] == 0: recorder.set_node_property(id, "type", v_root)
		elif out_degrees[id] == 0: recorder.set_node_property(id, "type", v_sink)
			
	if params.get("use_zones", false):
		var node_keys: Array[String] = []
		node_keys.assign(recorder.nodes.keys())
		recorder.create_zone_from_nodes("Assessed DAG", Color(0.2, 0.8, 0.8, 0.5), node_keys)
