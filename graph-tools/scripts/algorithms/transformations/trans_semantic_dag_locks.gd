class_name SemanticDAGLocks extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Distribute DAG Locks"
	category = Category.SEMANTIC

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "num_locks", "label": "Number of Locks", "type": TYPE_INT, "default": 3, "min": 1, "max": 20 },
		{ "name": "key_depth", "label": "Depth Data Key", "type": TYPE_STRING, "default": "dag_depth" },
		{ "name": "key_lock", "label": "Lock Prop Key", "type": TYPE_STRING, "default": "requires" },
		{ "name": "key_item", "label": "Item Prop Key", "type": TYPE_STRING, "default": "items" }
	])
	return s

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	if recorder.nodes.is_empty(): return
	
	var max_locks = local_settings.get("num_locks", 3)
	var k_depth = local_settings.get("key_depth", "dag_depth")
	var k_lock = local_settings.get("key_lock", "requires")
	var k_item = local_settings.get("key_item", "items")
	
	if SemanticRegistry:
		SemanticRegistry.ensure_property(SemanticRegistry.TARGET_NODE, k_item, k_item.capitalize(), TYPE_STRING, "", SemanticRegistry.DisplayMode.BADGE, true)
		SemanticRegistry.ensure_property(SemanticRegistry.TARGET_EDGE, k_lock, k_lock.capitalize(), TYPE_STRING, "", SemanticRegistry.DisplayMode.BADGE, true)
	
	var nodes_by_depth = {}
	for id in recorder.nodes:
		var node_data = recorder.nodes[id]
		var depth = node_data.get(k_depth) if k_depth in node_data else node_data.custom_data.get(k_depth, 0)
		if not nodes_by_depth.has(depth): nodes_by_depth[depth] = []
		nodes_by_depth[depth].append(id)
		
	var candidate_edges = []
	for key in recorder.edge_store:
		var e = recorder.edge_store[key]
		var node_u = recorder.nodes[e.u]
		var u_depth = node_u.get(k_depth) if k_depth in node_u else node_u.custom_data.get(k_depth, 0)
		if u_depth > 0: 
			candidate_edges.append({"u": e.u, "v": e.v, "u_depth": u_depth})
			
	var rng_pool = candidate_edges.duplicate()
	var locks_placed = 0
	var colors = ["#e74c3c", "#3498db", "#2ecc71", "#f1c40f", "#9b59b6", "#e67e22"]
	
	while locks_placed < max_locks and not rng_pool.is_empty():
		var rand_idx = rng.randi() % rng_pool.size()
		var edge_data = rng_pool.pop_at(rand_idx)
		
		var valid_key_nodes = []
		for d in range(0, edge_data.u_depth + 1):
			if nodes_by_depth.has(d): valid_key_nodes.append_array(nodes_by_depth[d])
				
		if valid_key_nodes.is_empty(): continue
		
		var color_hex = colors[locks_placed % colors.size()]
		var key_letter = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta"][locks_placed % 6]
		
		var lock_tag = "[lock:%s] Key %s" % [color_hex, key_letter]
		var item_tag = "[key:%s] Key %s" % [color_hex, key_letter]
		
		recorder.set_edge_property(edge_data.u, edge_data.v, k_lock, lock_tag)
		
		var key_node_id = valid_key_nodes[rng.randi() % valid_key_nodes.size()]
		var node_ref = recorder.nodes[key_node_id]
		
		var existing_items = str(node_ref.get(k_item)) if k_item in node_ref else str(node_ref.custom_data.get(k_item, ""))
		var new_val = item_tag if existing_items == "" else existing_items + ", " + item_tag
		recorder.set_node_property(key_node_id, k_item, new_val)
		
		locks_placed += 1
