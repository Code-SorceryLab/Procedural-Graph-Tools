class_name RoomAllocator
extends RefCounted

static func allocate(graph: Graph, realizer: GraphRealizer, default_floor_id: int, params: Dictionary) -> void:
	var grid = realizer.grid
	
	var min_r = params.get("room_radius_min", 2)
	var max_r = params.get("room_radius_max", 3)
	var shape = params.get("room_shape", 0) # 0 = Square, 1 = Circle
	
	# Pull a master seed (allows us to generate different room sizes for the exact same graph!)
	var master_seed_input = params.get("realizer_seed", "default_realizer")
	var master_seed_hash = SeedUtils.hash_seed(master_seed_input)
	
	var rng = RandomNumberGenerator.new()
	
	for node_id in graph.nodes:
		var node = graph.nodes[node_id] as NodeData
		var world_pos = graph.get_node_pos(node_id)
		var grid_pos = realizer.world_to_grid(world_pos)
		
		# 1. Order-Independent Deterministic Sizing
		rng.seed = SeedUtils.hash_seed(str(master_seed_hash) + "_" + str(node_id))
		var radius = rng.randi_range(min_r, max_r)
		
		if node.custom_data.has("room_radius"):
			radius = int(node.custom_data["room_radius"])
			
		# Check semantic type for Floor ID
		var floor_id = default_floor_id
		if node.type != "" and node.type != "default":
			if realizer.semantic_floor_ids.has(node.type):
				floor_id = realizer.semantic_floor_ids[node.type]
		
		# 2. Stamp the footprint based on Shape setting
		if shape == 1:
			grid.fill_circle(grid_pos.x, grid_pos.y, radius, floor_id)
		else:
			var width = (radius * 2) + 1
			var height = (radius * 2) + 1
			var rect = Rect2i(grid_pos.x - radius, grid_pos.y - radius, width, height)
			grid.fill_rect(rect, floor_id)
		
		# Save the grid center for the Edge Router
		node.custom_data["_grid_center"] = grid_pos
