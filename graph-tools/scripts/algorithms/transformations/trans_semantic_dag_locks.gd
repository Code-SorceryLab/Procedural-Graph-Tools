class_name SemanticDAGLocks extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Distribute DAG Locks"
	category = Category.SEMANTIC

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "target_mask", "label": "Target Nodes", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "All Nodes,Affected by Previous Step" },
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
	
	var target_mask = local_settings.get("target_mask", 0)
	var nodes_to_process = recorder.nodes.keys()
	var strict_nodes = {} # Strictly NO anchors!
	var edge_set = {} # [NEW] Strictly touched edges!
	
	if target_mask == 1:
		nodes_to_process = []
		var loose_context = get_context_nodes(true) 
		var strict_context = get_context_nodes(false)
		
		for id in loose_context:
			if recorder.nodes.has(id): nodes_to_process.append(id)
			
		for id in strict_context:
			if recorder.nodes.has(id): strict_nodes[id] = true
			
		# [NEW] Extract the explicit edge footprint
		var context_edges = get_context_edges()
		for pair in context_edges:
			var p = [pair[0], pair[1]]
			p.sort()
			edge_set[p] = true
	else:
		for id in nodes_to_process: strict_nodes[id] = true
			
	if nodes_to_process.is_empty(): return
	
	var node_set = {}
	for id in nodes_to_process: node_set[id] = true
	
	if SemanticRegistry:
		SemanticRegistry.ensure_property(SemanticRegistry.TARGET_NODE, k_item, k_item.capitalize(), TYPE_STRING, "", SemanticRegistry.DisplayMode.BADGE, true)
		SemanticRegistry.ensure_property(SemanticRegistry.TARGET_EDGE, k_lock, k_lock.capitalize(), TYPE_STRING, "", SemanticRegistry.DisplayMode.BADGE, true)
	
	# --- 1. DEPTH RESOLUTION ---
	var temp_depths = {}
	var max_depth_found = 0
	
	for id in nodes_to_process:
		var node_data = recorder.nodes[id]
		var depth = node_data.get(k_depth) if k_depth in node_data else node_data.custom_data.get(k_depth, 0)
		temp_depths[id] = depth
		max_depth_found = max(max_depth_found, depth)
		
	# FALLBACK: Ensure all disconnected branches are mapped!
	if max_depth_found == 0:
		var unvisited = node_set.duplicate()
		while not unvisited.is_empty():
			var start_node = unvisited.keys()[0]
			for id in unvisited:
				if recorder.nodes[id].type == "start":
					start_node = id; break
					
			var q = [start_node]
			unvisited.erase(start_node)
			temp_depths[start_node] = 0
			
			while not q.is_empty():
				var curr = q.pop_front()
				for n in recorder.get_neighbors(curr):
					if not unvisited.has(n): continue
					unvisited.erase(n)
					temp_depths[n] = temp_depths[curr] + 1
					q.append(n)
					
	# --- 2. GATHER CANDIDATES ---
	var nodes_by_depth = {}
	for id in nodes_to_process:
		var d = temp_depths[id]
		if not nodes_by_depth.has(d): nodes_by_depth[d] = []
		nodes_by_depth[d].append(id)
		
	var candidate_edges = []
	var processed_pairs = {} # Deduplicate bidirectional edges!
	
	for key in recorder.edge_store:
		var e = recorder.edge_store[key]
		var pair = [e.u, e.v]
		pair.sort()
		if processed_pairs.has(pair): continue
		processed_pairs[pair] = true
		
		if not node_set.has(e.u) or not node_set.has(e.v): continue 
		
		# [CRITICAL FIX] Ensure the edge itself was actually modified by the previous step!
		if target_mask == 1 and not edge_set.has(pair): continue
		
		var d_u = temp_depths[e.u]
		var d_v = temp_depths[e.v]
		
		if d_u < d_v: candidate_edges.append({"u": e.u, "v": e.v, "u_depth": d_u})
		elif d_v < d_u: candidate_edges.append({"u": e.v, "v": e.u, "u_depth": d_v})
			
	# --- 3. DISTRIBUTE LOCKS ---
	var rng_pool = candidate_edges.duplicate()
	var locks_placed = 0
	var colors = ["#e74c3c", "#3498db", "#2ecc71", "#f1c40f", "#9b59b6", "#e67e22"]
	
	while locks_placed < max_locks and not rng_pool.is_empty():
		var rand_idx = rng.randi() % rng_pool.size()
		var edge_data = rng_pool.pop_at(rand_idx)
		
		var valid_key_nodes = []
		for d in range(0, edge_data.u_depth + 1):
			if nodes_by_depth.has(d): 
				for kn in nodes_by_depth[d]:
					# Do NOT place keys on Anchor Nodes!
					if strict_nodes.has(kn): valid_key_nodes.append(kn)
				
		# If there is nowhere to put the key, skip this lock entirely to maintain the pairing!
		if valid_key_nodes.is_empty(): continue
		
		var color_hex = colors[locks_placed % colors.size()]
		var key_letter = ["Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta"][locks_placed % 6]
		
		var lock_tag = "[lock:%s] Key %s" % [color_hex, key_letter]
		var item_tag = "[key:%s] Key %s" % [color_hex, key_letter]
		
		# Set Lock on BOTH sides of the edge to guarantee the renderer draws it!
		recorder.set_edge_property(edge_data.u, edge_data.v, k_lock, lock_tag)
		if recorder.has_edge(edge_data.v, edge_data.u):
			recorder.set_edge_property(edge_data.v, edge_data.u, k_lock, lock_tag)
		
		var key_node_id = valid_key_nodes[rng.randi() % valid_key_nodes.size()]
		var node_ref = recorder.nodes[key_node_id]
		
		var existing_items = str(node_ref.get(k_item)) if k_item in node_ref else str(node_ref.custom_data.get(k_item, ""))
		var new_val = item_tag if existing_items == "" else existing_items + ", " + item_tag
		recorder.set_node_property(key_node_id, k_item, new_val)
		
		locks_placed += 1
