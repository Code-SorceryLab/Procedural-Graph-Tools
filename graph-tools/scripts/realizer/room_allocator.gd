class_name RoomAllocator
extends RefCounted

static func allocate(graph: Graph, realizer: GraphRealizer, default_floor_id: int, params: Dictionary) -> void:
	var grid = realizer.grid
	
	var master_seed_input = params.get("realizer_seed", "default_realizer")
	var master_seed_hash = SeedUtils.hash_seed(master_seed_input)
	var rng = RandomNumberGenerator.new()
	var biome_overrides = params.get("biomes", {})
	
	# --- PHASE 1: PRE-CALCULATE & STAMP BASES ---
	var room_data_cache: Array[Dictionary] = []
	
	for node_id in graph.nodes:
		var node = graph.nodes[node_id] as NodeData
		var world_pos = graph.get_node_pos(node_id)
		var grid_pos = realizer.world_to_grid(world_pos)
		
		# Biome Resolution
		# [FIXED] Firewall-protected param merge
		var effective_params = params.duplicate()
		if biome_overrides.has(node.type):
			effective_params.merge(biome_overrides[node.type], true)
		
		var min_r = effective_params.get("room_radius_min", 2)
		var max_r = effective_params.get("room_radius_max", 3)
		var w_sq = effective_params.get("ratio_square", 1)
		var w_circ = effective_params.get("ratio_circle", 0)
		var w_tri = effective_params.get("ratio_triangle", 0)
		var total_weight = w_sq + w_circ + w_tri
		
		# Extract the merging settings
		var allow_merging = effective_params.get("enable_room_merging", true)
		var merge_tolerance = effective_params.get("room_merge_tolerance", 1.2)
		
		# Sizing
		rng.seed = SeedUtils.hash_seed(str(master_seed_hash) + "_" + str(node_id))
		var radius = rng.randi_range(min_r, max_r)
		if node.custom_data.has("room_radius"):
			radius = int(node.custom_data["room_radius"])
			
		var floor_id = default_floor_id
		if node.type != "":
			if realizer.semantic_floor_ids.has(node.type):
				floor_id = realizer.semantic_floor_ids[node.type]
		
		# Shape Selection
		var shape = 0 # 0=Square, 1=Circle, 2=Triangle
		if total_weight > 0:
			var roll = rng.randi() % int(total_weight)
			if roll < w_sq: shape = 0
			elif roll < w_sq + w_circ: shape = 1
			else: shape = 2
		
		# Store for Merger Phase
		room_data_cache.append({
			"id": node_id,
			"type": node.type,
			"pos": grid_pos,
			"radius": radius,
			"shape": shape,
			"floor_id": floor_id,
			"allow_merging": allow_merging,
			"merge_tolerance": merge_tolerance # <--- Cache the range!
		})
		
		# Stamp Base Footprint
		if shape == 1:
			grid.fill_circle(grid_pos.x, grid_pos.y, radius, floor_id)
		elif shape == 2:
			for dy in range(-radius, radius + 1):
				var progress = float(dy + radius) / (radius * 2.0)
				var half_width = int(progress * radius)
				for dx in range(-half_width, half_width + 1):
					grid.set_cell(grid_pos.x + dx, grid_pos.y + dy, floor_id)
		else:
			var width = (radius * 2) + 1
			var rect = Rect2i(grid_pos.x - radius, grid_pos.y - radius, width, width)
			grid.fill_rect(rect, floor_id)
		
		node.custom_data["_grid_center"] = grid_pos

	# --- PHASE 2: GEOMETRIC BRIDGING (THE MERGER) ---
	
	for i in range(room_data_cache.size()):
		var r1 = room_data_cache[i]
		for j in range(i + 1, room_data_cache.size()):
			var r2 = room_data_cache[j]
			
			# RULE 1: Must be the same type!
			if r1.type != r2.type: continue
			
			# RULE 2: BOTH rooms must explicitly allow merging
			if not r1.allow_merging or not r2.allow_merging: continue
			
			var p1: Vector2i = r1.pos
			var p2: Vector2i = r2.pos
			var dist = Vector2(p1).distance_to(Vector2(p2))
			
			# RULE 3: Determine if they fall within the configurable Merge Range
			var active_tolerance = max(r1.merge_tolerance, r2.merge_tolerance)
			var overlap_threshold = float(r1.radius + r2.radius) * active_tolerance
			
			if dist <= overlap_threshold:
				var min_x = min(p1.x - r1.radius, p2.x - r2.radius)
				var max_x = max(p1.x + r1.radius, p2.x + r2.radius)
				var min_y = min(p1.y - r1.radius, p2.y - r2.radius)
				var max_y = max(p1.y + r1.radius, p2.y + r2.radius)
				
				for y in range(min_y, max_y + 1):
					for x in range(min_x, max_x + 1):
						var current_point = Vector2(x, y)
						
						# [MATH UPGRADE] Get both the distance AND the exact linear projection (t)
						var projection_data = _dist_to_segment_data(current_point, Vector2(p1), Vector2(p2))
						var d = projection_data["dist"]
						var t = projection_data["t"]
						
						# Perfectly taper the bridge between the two radii!
						var interpolated_radius = lerpf(float(r1.radius), float(r2.radius), t)
						
						if d <= interpolated_radius - 0.5:
							grid.set_cell(x, y, r1.floor_id)

	# --- PHASE 3: LOG PROTECTED CELLS ---
	for y in range(grid.height):
		for x in range(grid.width):
			if grid.get_cell(x, y) != TilePalette.VOID_ID:
				realizer.room_cells[Vector2i(x, y)] = true


# --- MATH HELPER ---
# Returns the exact distance AND the projection scalar (t) along the segment
static func _dist_to_segment_data(p: Vector2, v: Vector2, w: Vector2) -> Dictionary:
	var l2 = v.distance_squared_to(w)
	if l2 == 0.0: return {"dist": p.distance_to(v), "t": 0.5}
	
	var t = max(0.0, min(1.0, (p - v).dot(w - v) / l2))
	var projection = v + t * (w - v)
	return {"dist": p.distance_to(projection), "t": t}
