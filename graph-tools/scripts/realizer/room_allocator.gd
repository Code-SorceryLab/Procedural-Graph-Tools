class_name RoomAllocator
extends RefCounted

static func allocate(graph: Graph, realizer: GraphRealizer, default_floor_id: int, params: Dictionary) -> void:
	var grid = realizer.grid
	
	var master_seed_input = params.get("realizer_seed", "default_realizer")
	var master_seed_hash = SeedUtils.hash_seed(master_seed_input)
	var rng = RandomNumberGenerator.new()
	
	var biome_overrides = params.get("biomes", {})
	
	for node_id in graph.nodes:
		var node = graph.nodes[node_id] as NodeData
		var world_pos = graph.get_node_pos(node_id)
		var grid_pos = realizer.world_to_grid(world_pos)
		
		# --- BIOME RESOLUTION ---
		var effective_params = params
		
		if biome_overrides.has(node.type):
			if biome_overrides[node.type].get("override_enabled", false):
				effective_params = params.duplicate()
				effective_params.merge(biome_overrides[node.type], true)
		
		# Fetch the values specifically for THIS room's active biome
		var min_r = effective_params.get("room_radius_min", 2)
		var max_r = effective_params.get("room_radius_max", 3)
		var w_sq = effective_params.get("ratio_square", 1)
		var w_circ = effective_params.get("ratio_circle", 0)
		var w_tri = effective_params.get("ratio_triangle", 0)
		var total_weight = w_sq + w_circ + w_tri
		
		# 1. Order-Independent Deterministic Sizing
		rng.seed = SeedUtils.hash_seed(str(master_seed_hash) + "_" + str(node_id))
		var radius = rng.randi_range(min_r, max_r)
		
		if node.custom_data.has("room_radius"):
			radius = int(node.custom_data["room_radius"])
			
		var floor_id = default_floor_id
		if node.type != "" and node.type != "default":
			if realizer.semantic_floor_ids.has(node.type):
				floor_id = realizer.semantic_floor_ids[node.type]
		
		# 2. Weighted Shape Selection
		var shape = 0 # Default to square
		if total_weight > 0:
			var roll = rng.randi() % total_weight
			if roll < w_sq: shape = 0
			elif roll < w_sq + w_circ: shape = 1
			else: shape = 2
		
		# 3. Stamp the footprint
		if shape == 1:
			# Circle
			grid.fill_circle(grid_pos.x, grid_pos.y, radius, floor_id)
		elif shape == 2:
			# Triangle (Upward Pointing)
			for dy in range(-radius, radius + 1):
				# Calculate horizontal width mapped linearly from 0 (top) to radius (bottom)
				var progress = float(dy + radius) / (radius * 2.0)
				var half_width = int(progress * radius)
				for dx in range(-half_width, half_width + 1):
					grid.set_cell(grid_pos.x + dx, grid_pos.y + dy, floor_id)
		else:
			# Square
			var width = (radius * 2) + 1
			var rect = Rect2i(grid_pos.x - radius, grid_pos.y - radius, width, width)
			grid.fill_rect(rect, floor_id)
		
		node.custom_data["_grid_center"] = grid_pos
