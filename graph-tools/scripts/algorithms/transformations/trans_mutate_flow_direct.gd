class_name MutateFlowDirect extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Flow Direct (Assessor)"
	category = Category.TOPOLOGY

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "target_mask", "label": "Target Nodes", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "All Nodes,Affected by Previous Step" },
		{ "name": "val_root", "label": "Root Type Check", "type": TYPE_STRING, "default": "start" },
		{ "name": "val_sink", "label": "Sink Type Target", "type": TYPE_STRING, "default": "boss" },
		{ "name": "key_depth", "label": "Depth Data Key", "type": TYPE_STRING, "default": "dag_depth" }
	])
	return s

func execute(recorder: GraphRecorder) -> void:
	if recorder.nodes.is_empty(): return
	
	var k_depth = local_settings.get("key_depth", "dag_depth")
	var v_root = local_settings.get("val_root", "start")
	var v_sink = local_settings.get("val_sink", "boss")
	
	# [NEW] Masking setup
	var target_mask = local_settings.get("target_mask", 0)
	var nodes_to_process = recorder.nodes.keys()
	
	if target_mask == 1:
		nodes_to_process = []
		var context_nodes = get_context_nodes(false)
		for id in context_nodes:
			if recorder.nodes.has(id): nodes_to_process.append(id)
			
	if nodes_to_process.is_empty(): return
	
	var node_set = {}
	for id in nodes_to_process: node_set[id] = true
	
	var depths = {}
	var queue = []
	
	# Find root ONLY inside the masked nodes
	var start_node = nodes_to_process[0]
	for id in nodes_to_process:
		if recorder.nodes[id].type == v_root:
			start_node = id
			break
			
	for node_id in nodes_to_process:
		if not depths.has(node_id):
			var root = start_node if depths.is_empty() else node_id
			depths[root] = 0
			queue.append(root)
			
			while not queue.is_empty():
				var curr = queue.pop_front()
				for n in recorder.get_neighbors(curr):
					if not node_set.has(n): continue # <--- CRITICAL FIX
					if not depths.has(n):
						depths[n] = depths[curr] + 1
						queue.append(n)
						
	var edges_to_delete = []
	var edges_to_create = []
	
	for key in recorder.edge_store:
		var e = recorder.edge_store[key]
		
		# <--- CRITICAL FIX: Only process edges bounded entirely inside the mask
		if not node_set.has(e.u) or not node_set.has(e.v): continue 
		
		var d_u = depths[e.u]
		var d_v = depths[e.v]
		var is_directed = (e.direction != 0)
		
		edges_to_delete.append({ "u": e.u, "v": e.v, "dir": is_directed })
		
		if d_u < d_v: edges_to_create.append({ "u": e.u, "v": e.v, "w": e.weight, "data": e.custom })
		elif d_u > d_v: edges_to_create.append({ "u": e.v, "v": e.u, "w": e.weight, "data": e.custom })
		else:
			if e.u < e.v: edges_to_create.append({ "u": e.u, "v": e.v, "w": e.weight, "data": e.custom })
			else: edges_to_create.append({ "u": e.v, "v": e.u, "w": e.weight, "data": e.custom })
				
	for e in edges_to_delete: recorder.remove_edge(e.u, e.v, e.dir)
	for e in edges_to_create: recorder.add_edge(e.u, e.v, e.w, true, e.data)
		
	var out_degrees = {}
	for id in nodes_to_process: out_degrees[id] = 0
	for e in edges_to_create: out_degrees[e.u] += 1
		
	for id in nodes_to_process:
		recorder.set_node_property(id, k_depth, depths[id])
		if depths[id] == 0: recorder.set_node_type(id, v_root)
		elif out_degrees[id] == 0: recorder.set_node_type(id, v_sink)
