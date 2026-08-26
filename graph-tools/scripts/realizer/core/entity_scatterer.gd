class_name EntityScatterer
extends RefCounted

static func scatter(graph: Graph, realizer: GraphRealizer, params: Dictionary, shopping_lists: Dictionary) -> void:
	var grid = realizer.grid
	var all_scatter_sets = ConfigManager.load_scatter_sets()
	if all_scatter_sets.is_empty() or shopping_lists.is_empty(): return
	
	var master_seed = SeedUtils.hash_seed(str(params.get("realizer_seed", "default")) + "_scatter")
	var rng = RandomNumberGenerator.new()

	var valid_floors = {}
	for id in grid.palette._definitions:
		if grid.palette.get_data(id).get("walkable", false):
			valid_floors[id] = true

	# --- REACHABLE CELLS FLOOD-FILL BLOCK ---
	var reachable_cells = {}
	var queue: Array[Vector2i] = []
	for cp in realizer.critical_path_cells:
		queue.append(cp); reachable_cells[cp] = true
	for node_id in graph.nodes:
		var center = graph.nodes[node_id].custom_data.get("_grid_center", Vector2i.ZERO)
		if center != Vector2i.ZERO and not realizer.reserved_cells.has(center) and valid_floors.has(grid.get_cell(center.x, center.y)):
			if not reachable_cells.has(center):
				queue.append(center); reachable_cells[center] = true
	var head = 0
	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var curr = queue[head]; head += 1
		for d in dirs:
			var neighbor = curr + d
			if not reachable_cells.has(neighbor) and grid.in_bounds_vec(neighbor):
				if not realizer.reserved_cells.has(neighbor) and valid_floors.has(grid.get_cell(neighbor.x, neighbor.y)):
					reachable_cells[neighbor] = true; queue.append(neighbor)
	# -------------------------------------------------------------------------
	
	var node_ids = graph.nodes.keys().duplicate()
	var node_rng = RandomNumberGenerator.new()
	node_rng.seed = master_seed
	var shuffled_nodes = []
	
	while node_ids.size() > 0:
		shuffled_nodes.append(node_ids.pop_at(node_rng.randi() % node_ids.size()))
		
	# --- REGENERATION MASK ---
	var target_nodes = params.get("regen_target_nodes", [])
	var is_regen = target_nodes.size() > 0
		
	# Iterate through the shuffled rooms
	for node_id in shuffled_nodes:
		# --- MASK CHECK ---
		if is_regen and not target_nodes.has(node_id):
			continue
			
		var node = graph.nodes[node_id]
		var center = node.custom_data.get("_grid_center", Vector2i.ZERO)
		if center == Vector2i.ZERO: continue
		
		var target_floor_id = grid.get_cell(center.x, center.y)
		if not valid_floors.has(target_floor_id):
			target_floor_id = realizer.floor_id 

		# ======================================================================
		# [NEW] PRE-PASS: STAMP EXPLICIT CUSTOM ROOM ENTITIES
		# ======================================================================
		if node.custom_data.get("_is_custom_room", false):
			var ref = node.custom_data.get("_custom_room_ref", "")
			var custom_rooms = params.get("custom_rooms", {})
			if custom_rooms.has(ref):
				var c_room = custom_rooms[ref]
				var anchor = c_room.get("anchor", Vector2i.ZERO)
				var placed = c_room.get("placed_entities", [])
				
				for p_item in placed:
					var e_id = p_item["id"]
					if all_scatter_sets.has(e_id):
						var e_data = all_scatter_sets[e_id]
						var room_rot = node.custom_data.get("_custom_room_rot", 0) # [NEW]
						
						# [UPDATED] Pivot the entity's position around the rotated anchor
						var rel_pos = p_item["pos"] - anchor
						var g_pos = center + _rotate_point(rel_pos, room_rot)
						
						if grid.in_bounds_vec(g_pos) and not grid.entities.has(g_pos):
							grid.entities[g_pos] = {
								"type": "scatter_set",
								"set_id": e_id,
								"name": e_data.get("name", "Unknown Set"),
								"color": e_data.get("color", Color.WHITE),
								"source_node": node_id,
								
								"texture_path": e_data.get("texture_path", ""),
								"texture_offset": e_data.get("texture_offset", Vector2.ZERO),
								"texture_scale": e_data.get("texture_scale", Vector2.ONE),
								"texture_filter": e_data.get("texture_filter", 0),
								"rot": 0 
							}
		# ======================================================================

		# --- FETCH SHOPPING LIST ---
		var room_list = shopping_lists.get(node_id, [])
		var intents = []
		for item in room_list:
			if item["type"] == "scatter" and all_scatter_sets.has(item["ref_id"]):
				intents.append(item)
				
		if intents.is_empty(): continue

		rng.seed = SeedUtils.hash_seed(str(master_seed) + "_" + str(node_id))
		var max_r = int(node.custom_data.get("room_radius", params.get("room_radius_max", 4))) + 2 
		var rect = Rect2i(center.x - max_r, center.y - max_r, max_r * 2 + 1, max_r * 2 + 1)
		
		# --- PRE-CALCULATE ALL VALID ANCHORS IN THE ROOM ---
		var room_valid_placements = []
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var pt = Vector2i(x, y)
				if not grid.in_bounds_vec(pt): continue
				if realizer.critical_path_cells.has(pt) or realizer.reserved_cells.has(pt) or not reachable_cells.has(pt): continue
				if grid.get_cell(pt.x, pt.y) != target_floor_id: continue
				room_valid_placements.append(pt)

		# --- PROCESS EACH INTENT ---
		for item in intents:
			var ref_id = item["ref_id"]
			var current_set = all_scatter_sets[ref_id]
			
			# Pull placement constraints directly from the Shopping List item!
			var min_dist = item.get("min_dist", 0)
			var max_dist = item.get("max_dist", 99)
			var sym_mode = item.get("symmetry", 0) 
			var clump_chance = item.get("clump_chance", 0.0)
			var max_clump_size = item.get("clump_max", 3)
			
			var available_placements = []
			for pt in room_valid_placements:
				if not grid.entities.has(pt): available_placements.append(pt)
				
			if available_placements.is_empty(): continue
			
			# Shuffle so we pick a random valid anchor!
			available_placements.shuffle()
			var actually_spawned = false

			# Actually attempt to spawn ONE instance (or clump) of this item
			for pos in available_placements:
				if actually_spawned: break # Move on to the next item on the shopping list!
				
				var tile_dist = realizer.distance_field.get(pos, 0)
				if tile_dist < min_dist or tile_dist > max_dist: continue

				var group = _get_symmetry_group(pos, center, sym_mode)
				
				var group_is_valid = true
				for member in group:
					var pt = member["pos"]
					if not grid.in_bounds_vec(pt) or grid.entities.has(pt):
						group_is_valid = false; break
					if realizer.critical_path_cells.has(pt) or realizer.reserved_cells.has(pt) or not reachable_cells.has(pt):
						group_is_valid = false; break
					if grid.get_cell(pt.x, pt.y) != target_floor_id:
						group_is_valid = false; break
					var m_dist = realizer.distance_field.get(pt, 0)
					if m_dist < min_dist or m_dist > max_dist:
						group_is_valid = false; break
						
				if not group_is_valid: continue

				var current_clump_size = 1
				if rng.randf() < clump_chance:
					current_clump_size = rng.randi_range(2, max(2, max_clump_size))

				var clump_offsets = [Vector2i.ZERO]
				if current_clump_size > 1:
					var edge_tiles = [Vector2i.ZERO]
					var possible_dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
					
					while clump_offsets.size() < current_clump_size:
						var grow_base = SeedUtils.pick_random(edge_tiles, rng)
						var d = possible_dirs[rng.randi() % 4]
						var new_tile = grow_base + d
						if not clump_offsets.has(new_tile):
							clump_offsets.append(new_tile)
							edge_tiles.append(new_tile)
				
				for member in group:
					for offset in clump_offsets:
						var trans_offset = _transform_offset(offset, member["flip_x"], member["flip_y"])
						var final_pt = member["pos"] + trans_offset
						
						if grid.in_bounds_vec(final_pt) and not grid.entities.has(final_pt):
							if grid.get_cell(final_pt.x, final_pt.y) == target_floor_id:
								if not realizer.critical_path_cells.has(final_pt) and not realizer.reserved_cells.has(final_pt) and reachable_cells.has(final_pt):
									
									grid.entities[final_pt] = {
										"type": "scatter_set",
										"set_id": ref_id,
										"name": current_set.get("name", "Unknown Set"),
										"color": current_set.get("color", Color.WHITE),
										"source_node": node_id,
										
										# --- SPRITE DATA FOR THE REALIZER ---
										"texture_path": current_set.get("texture_path", ""),
										"texture_offset": current_set.get("texture_offset", Vector2.ZERO),
										"texture_scale": current_set.get("texture_scale", Vector2.ONE),
										"texture_filter": current_set.get("texture_filter", 0),
										"rot": 0 
									}
									actually_spawned = true
									# Remove it from valid placements so other items can't spawn here
									room_valid_placements.erase(final_pt)
									


# --- SYMMETRY MATH HELPERS ---
static func _get_symmetry_group(pos: Vector2i, center: Vector2i, mode: int) -> Array:
	var group = [{"pos": pos, "flip_x": false, "flip_y": false}]
	var dx = pos.x - center.x
	var dy = pos.y - center.y
	
	if mode == 1: # X-Axis
		group.append({"pos": Vector2i(center.x - dx, pos.y), "flip_x": true, "flip_y": false})
	elif mode == 2: # Y-Axis
		group.append({"pos": Vector2i(pos.x, center.y - dy), "flip_x": false, "flip_y": true})
	elif mode == 3: # Radial/Point
		group.append({"pos": Vector2i(center.x - dx, center.y - dy), "flip_x": true, "flip_y": true})
	elif mode == 4: # 4-Way Quad
		group.append({"pos": Vector2i(center.x - dx, pos.y), "flip_x": true, "flip_y": false})
		group.append({"pos": Vector2i(pos.x, center.y - dy), "flip_x": false, "flip_y": true})
		group.append({"pos": Vector2i(center.x - dx, center.y - dy), "flip_x": true, "flip_y": true})
		
	return group

static func _transform_offset(offset: Vector2i, flip_x: bool, flip_y: bool) -> Vector2i:
	return Vector2i(-offset.x if flip_x else offset.x, -offset.y if flip_y else offset.y)

static func _rotate_point(pt: Vector2i, rot_idx: int) -> Vector2i:
	match rot_idx % 4:
		1: return Vector2i(-pt.y, pt.x) # 90 deg CW
		2: return Vector2i(-pt.x, -pt.y) # 180 deg
		3: return Vector2i(pt.y, -pt.x) # 270 deg CW
		_: return pt # 0 deg
