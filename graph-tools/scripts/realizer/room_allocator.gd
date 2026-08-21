class_name RoomAllocator
extends RefCounted

static func allocate(graph: Graph, realizer: GraphRealizer, default_floor_id: int, params: Dictionary) -> void:
	var grid = realizer.grid
	
	var master_seed_input = params.get("realizer_seed", "default_realizer")
	var master_seed_hash = SeedUtils.hash_seed(master_seed_input)
	var rng = RandomNumberGenerator.new()
	var biome_overrides = params.get("biomes", {})
	
	var custom_rooms = params.get("custom_rooms", {})
	var room_lists = params.get("room_shopping_lists", {}) # The Distribution Engine output
	
	# --- PHASE 1: PRE-CALCULATE & STAMP BASES ---
	var room_data_cache: Array[Dictionary] = []
	var metric_custom_rooms = 0 # Diagnostic tracker
	var metric_rejected_custom_rooms = 0 # Tracks overlaps

	for node_id in graph.nodes:
		var node = graph.nodes[node_id] as NodeData
		
		# --- PURGE STALE DATA FROM PREVIOUS GENERATIONS ---
		node.custom_data.erase("_is_custom_room")
		node.custom_data.erase("_custom_doorways")
		node.custom_data.erase("_custom_room_id")
		node.custom_data.erase("_custom_room_ref")
		node.custom_data.erase("_grid_center")
		
		var world_pos = graph.get_node_pos(node_id)
		var grid_pos = realizer.world_to_grid(world_pos)
		
		# Biome Resolution
		var effective_params = params.duplicate()
		if biome_overrides.has(node.type):
			effective_params.merge(biome_overrides[node.type], true)
			
		var min_r = effective_params.get("room_radius_min", 2)
		var max_r = effective_params.get("room_radius_max", 3)
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
		
		# --- RESOLVE THE SHOPPING LIST ---
		var chosen_type = "preset"
		var chosen_ref = "preset_square" # Fallback if list is empty
		
		if room_lists.has(node_id) and room_lists[node_id].size() > 0:
			var items = room_lists[node_id]
			
			# Priority Sort: Custom Rooms override Standard Presets
			items.sort_custom(func(a, b):
				if a["type"] == "custom_room" and b["type"] != "custom_room": return true
				return false
			)
			
			var best_item = items[0]
			chosen_type = best_item["type"]
			chosen_ref = best_item["ref_id"]

		# --- CUSTOM ROOM STAMPING ---
		var custom_room_stamped = false
		
		if chosen_type == "custom_room" and custom_rooms.has(chosen_ref):
			var c_room = custom_rooms[chosen_ref]
			var anchor = c_room.get("anchor", Vector2i.ZERO)
			var room_rot = rng.randi() % 4
			
			var to_global = func(local_pos: Vector2i) -> Vector2i:
				var rel = local_pos - anchor
				return grid_pos + _rotate_point(rel, room_rot)
				
			# --- [NEW] STRICT OVERLAP CHECK ---
			var is_overlapping = false
			for cat in ["floors", "walls", "exact_floors", "exact_walls", "reserved", "doorways"]:
				if c_room.has(cat):
					for l_pos in c_room[cat]:
						var g_pos = to_global.call(l_pos)
						
						# If it falls off the map, or touches ANY existing tile, reject it!
						if not grid.in_bounds_vec(g_pos) or grid.get_cell(g_pos.x, g_pos.y) != TilePalette.VOID_ID or realizer.reserved_cells.has(g_pos):
							is_overlapping = true; break
				if is_overlapping: break
				
			if is_overlapping:
				metric_rejected_custom_rooms += 1
				chosen_type = "preset"
				chosen_ref = "preset_square" # Downgrade so it processes safely as a standard room
			else:
				var global_doorways = []
				var room_cells = []
				var wall_id = realizer.semantic_wall_map.get(floor_id, TilePalette.VOID_ID)
					
				# 1. Stamp Semantic Floors
				if c_room.has("floors"):
					for l_pos in c_room["floors"]:
						var g_pos = to_global.call(l_pos)
						grid.set_cell(g_pos.x, g_pos.y, floor_id)
						room_cells.append(g_pos)
						
				# 2. Stamp Semantic Walls
				if c_room.has("walls"):
					for l_pos in c_room["walls"]:
						var g_pos = to_global.call(l_pos)
						if wall_id != TilePalette.VOID_ID: grid.set_cell(g_pos.x, g_pos.y, wall_id)
						room_cells.append(g_pos)
						
				# 2.5 Stamp Exact Visual Tiles
				if c_room.has("exact_floors"):
					for l_pos in c_room["exact_floors"]:
						var g_pos = to_global.call(l_pos)
						var atlas = c_room["exact_floors"][l_pos]
						grid.set_cell_atlas(g_pos.x, g_pos.y, floor_id, atlas)
						room_cells.append(g_pos)
						
				if c_room.has("exact_walls"):
					for l_pos in c_room["exact_walls"]:
						var g_pos = to_global.call(l_pos)
						var atlas = c_room["exact_walls"][l_pos]
						if wall_id != TilePalette.VOID_ID: 
							grid.set_cell_atlas(g_pos.x, g_pos.y, wall_id, atlas)
						room_cells.append(g_pos)
						
				# 3. Apply the Red Reserved Mask
				if c_room.has("reserved"):
					for l_pos in c_room["reserved"]:
						var g_pos = to_global.call(l_pos)
						realizer.reserved_cells[g_pos] = true
						realizer.critical_path_cells[g_pos] = true 
						realizer.core_path_cells[g_pos] = true     
						
				# 4. Cache the explicit Connection Points (Doorways)
				if c_room.has("doorways"):
					for l_pos in c_room["doorways"]:
						global_doorways.append(to_global.call(l_pos))
						
				# 5. Tag the node
				node.custom_data["_grid_center"] = grid_pos
				node.custom_data["_custom_doorways"] = global_doorways
				node.custom_data["_is_custom_room"] = true
				node.custom_data["_custom_room_id"] = node_id 
				node.custom_data["_custom_room_ref"] = chosen_ref 
				node.custom_data["_custom_room_rot"] = room_rot 
				
				# 6. Build the Data Firewall
				var c_room_dict = realizer.get_meta("custom_room_cells") if realizer.has_meta("custom_room_cells") else {}
				for g_pos in room_cells:
					c_room_dict[g_pos] = node_id
				realizer.set_meta("custom_room_cells", c_room_dict)
				
				metric_custom_rooms += 1
				custom_room_stamped = true
				
		if custom_room_stamped:
			continue # Skip standard shape generation
			
		# --- STANDARD PRESET SHAPE STAMPING ---
		var shape = 0 # 0=Square, 1=Circle, 2=Triangle
		if chosen_ref == "preset_circle": shape = 1
		elif chosen_ref == "preset_triangle": shape = 2
		
		room_data_cache.append({
			"id": node_id, "type": node.type, "pos": grid_pos, "radius": radius,
			"shape": shape, "floor_id": floor_id, "allow_merging": allow_merging,
			"merge_tolerance": merge_tolerance 
		})
		
		# Safe Stamp Helper: Prevents standard rooms from chewing into custom rooms
		var c_room_dict = realizer.get_meta("custom_room_cells") if realizer.has_meta("custom_room_cells") else {}
		var safe_set_cell = func(gx: int, gy: int, id: int):
			var pt = Vector2i(gx, gy)
			if not c_room_dict.has(pt) and not realizer.reserved_cells.has(pt):
				grid.set_cell(gx, gy, id)
		
		# Stamp Base Footprint
		if shape == 1:
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					if dx * dx + dy * dy <= radius * radius:
						safe_set_cell.call(grid_pos.x + dx, grid_pos.y + dy, floor_id)
		elif shape == 2:
			for dy in range(-radius, radius + 1):
				var progress = float(dy + radius) / (radius * 2.0)
				var half_width = int(progress * radius)
				for dx in range(-half_width, half_width + 1):
					safe_set_cell.call(grid_pos.x + dx, grid_pos.y + dy, floor_id)
		else:
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					safe_set_cell.call(grid_pos.x + dx, grid_pos.y + dy, floor_id)
		
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
						
						# Get distance AND exact linear projection (t)
						var projection_data = _dist_to_segment_data(current_point, Vector2(p1), Vector2(p2))
						var d = projection_data["dist"]
						var t = projection_data["t"]
						
						# Perfectly taper the bridge between the two radii!
						var interpolated_radius = lerpf(float(r1.radius), float(r2.radius), t)
						
						if d <= interpolated_radius - 0.5:
							# Apply the firewall shield
							var c_room_dict = realizer.get_meta("custom_room_cells") if realizer.has_meta("custom_room_cells") else {}
							var pt = Vector2i(x, y)
							if not c_room_dict.has(pt) and not realizer.reserved_cells.has(pt):
								grid.set_cell(x, y, r1.floor_id)

	# --- PHASE 3: LOG PROTECTED CELLS ---
	for y in range(grid.height):
		for x in range(grid.width):
			if grid.get_cell(x, y) != TilePalette.VOID_ID:
				realizer.room_cells[Vector2i(x, y)] = true
				
	# --- PHASE 4: LOG DIAGNOSTICS ---
	realizer.set_meta("metric_custom_rooms", metric_custom_rooms)
	realizer.set_meta("metric_rejected_custom_rooms", metric_rejected_custom_rooms)


# --- MATH HELPER ---
# Returns the exact distance AND the projection scalar (t) along the segment
static func _dist_to_segment_data(p: Vector2, v: Vector2, w: Vector2) -> Dictionary:
	var l2 = v.distance_squared_to(w)
	if l2 == 0.0: return {"dist": p.distance_to(v), "t": 0.5}
	
	var t = max(0.0, min(1.0, (p - v).dot(w - v) / l2))
	var projection = v + t * (w - v)
	return {"dist": p.distance_to(projection), "t": t}

static func _rotate_point(pt: Vector2i, rot_idx: int) -> Vector2i:
	match rot_idx % 4:
		1: return Vector2i(-pt.y, pt.x) # 90 deg CW
		2: return Vector2i(-pt.x, -pt.y) # 180 deg
		3: return Vector2i(pt.y, -pt.x) # 270 deg CW
		_: return pt # 0 deg
