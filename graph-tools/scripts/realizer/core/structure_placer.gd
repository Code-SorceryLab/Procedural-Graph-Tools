class_name StructurePlacer
extends RefCounted

static func place(graph: Graph, realizer: GraphRealizer, params: Dictionary, shopping_lists: Dictionary) -> void:
	var grid = realizer.grid
	# (We no longer load biome_overrides here, the DistributionEngine handled it!)
	var master_seed = SeedUtils.hash_seed(str(params.get("realizer_seed", "default")) + "_structure")
	var rng = RandomNumberGenerator.new()
	
	var custom_structures = ConfigManager.load_structures()
	if custom_structures.is_empty() or shopping_lists.is_empty(): return
	
	var valid_floors = {}
	for id in grid.palette._definitions:
		if grid.palette.get_data(id).get("walkable", false):
			valid_floors[id] = true
			
	var node_ids = graph.nodes.keys().duplicate()
	var node_rng = RandomNumberGenerator.new()
	node_rng.seed = master_seed
	var shuffled_nodes = []
	
	while node_ids.size() > 0:
		shuffled_nodes.append(node_ids.pop_at(node_rng.randi() % node_ids.size()))
			
	for node_id in shuffled_nodes:
		var node = graph.nodes[node_id]
		var center = node.custom_data.get("_grid_center", Vector2i.ZERO)
		if center == Vector2i.ZERO: continue
		
		var target_floor_id = grid.get_cell(center.x, center.y)
		if not valid_floors.has(target_floor_id):
			target_floor_id = realizer.floor_id 
			
		# ======================================================================
		# PRE-PASS: STAMP EXPLICIT CUSTOM ROOM STRUCTURES
		# ======================================================================
		if node.custom_data.get("_is_custom_room", false):
			var ref = node.custom_data.get("_custom_room_ref", "")
			var custom_rooms = params.get("custom_rooms", {})
			if custom_rooms.has(ref):
				var c_room = custom_rooms[ref]
				var anchor = c_room.get("anchor", Vector2i.ZERO)
				var placed = c_room.get("placed_structures", [])
				
				for p_item in placed:
					var s_id = p_item["id"]
					if custom_structures.has(s_id):
						var s_data = custom_structures[s_id]
						var room_rot = node.custom_data.get("_custom_room_rot", 0)
						
						# [UPDATED] Pivot the structure's position around the rotated anchor
						var rel_pos = p_item["pos"] - anchor
						var g_pos = center + _rotate_point(rel_pos, room_rot)
						
						# [UPDATED] Combine the structure's base rotation with the room's rotation!
						var final_rot = (p_item["rot"] + room_rot) % 4
						var chosen = { "pos": g_pos, "rot": final_rot }
						
						var raw_footprint = s_data.get("footprint", [])
						_stamp_structure(chosen, raw_footprint, s_data, node_id, realizer)
		# ======================================================================
		
		# --- FETCH SHOPPING LIST ---
		var room_list = shopping_lists.get(node_id, [])
		var intents = []
		for item in room_list:
			if item["type"] == "structure" and custom_structures.has(item["ref_id"]):
				intents.append(item)
				
		if intents.is_empty(): continue
		
		rng.seed = SeedUtils.hash_seed(str(master_seed) + "_" + str(node_id))
		
		# --- EVALUATE INTENTS ---
		for item in intents:
			var key = item["ref_id"]
			var struct_data = custom_structures[key]
			var raw_footprint: Array = struct_data.get("footprint", [])
			if raw_footprint.is_empty(): continue
			
			var allow_rotation = struct_data.get("allow_rotation", true)
			var face_path = struct_data.get("face_path", true)
			var front_dir = struct_data.get("front_dir", Vector2i.UP)
			
			# Pull placement constraints directly from the Shopping List item
			var min_dist = item.get("min_dist", 0)
			var max_dist = item.get("max_dist", 99)
			var sym_mode = item.get("symmetry", 0)
			
			var max_r = int(node.custom_data.get("room_radius", params.get("room_radius_max", 4))) + 2
			var rect = Rect2i(center.x - max_r, center.y - max_r, max_r * 2 + 1, max_r * 2 + 1)
			
			# --- LOCAL PATH CACHE ---
			# Drastically optimizes math by only checking paths near this specific room
			var local_paths = []
			for cell in realizer.critical_path_cells:
				if abs(cell.x - center.x) <= max_r + 10 and abs(cell.y - center.y) <= max_r + 10:
					local_paths.append(Vector2(cell))
			if local_paths.is_empty() and not realizer.critical_path_cells.is_empty():
				local_paths.append(Vector2(realizer.critical_path_cells.keys()[0])) # Fallback
			
			var valid_placements = []
			var placement_lookup = {}
			
			# SCAN FOR VALID PLACEMENTS
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					var test_center = Vector2i(x, y)
					var rots_to_test = [0, 1, 2, 3] if allow_rotation else [0]
					
					for r in rots_to_test:
						var is_valid = true
						for pt in raw_footprint:
							var abs_pt = test_center + _rotate_point(pt, r)
							
							if realizer.critical_path_cells.has(abs_pt) or realizer.reserved_cells.has(abs_pt):
								is_valid = false; break
							if grid.get_cell(abs_pt.x, abs_pt.y) != target_floor_id:
								is_valid = false; break
							var tile_dist = realizer.distance_field.get(abs_pt, 0)
							if tile_dist < min_dist or tile_dist > max_dist:
								is_valid = false; break
								
						if is_valid:
							var placement = { "pos": test_center, "rot": r }
							valid_placements.append(placement)
							placement_lookup["%d,%d,%d" % [test_center.x, test_center.y, r]] = placement
							
			if valid_placements.is_empty(): continue
			
			# --- SYMMETRY GROUPING ---
			var valid_groups = []
			var processed_sigs = {}
			
			for p in valid_placements:
				var group = _get_symmetry_group(p, center, sym_mode, allow_rotation)
				var sig_array = []
				for member in group: sig_array.append("%d,%d,%d" % [member["pos"].x, member["pos"].y, member["rot"]])
				sig_array.sort()
				var sig = str(sig_array)
				
				if processed_sigs.has(sig): continue
				processed_sigs[sig] = true
				
				var group_is_valid = true
				var group_footprint_cells = {} # Tracks tiles claimed by this specific group
				
				for member in group:
					var m_sig = "%d,%d,%d" % [member["pos"].x, member["pos"].y, member["rot"]]
					if not placement_lookup.has(m_sig):
						group_is_valid = false; break
						
					# Internal Collision Check
					# Prevent members of the same symmetry group from overlapping each other
					for pt in raw_footprint:
						var abs_pt = member["pos"] + _rotate_point(pt, member["rot"])
						if group_footprint_cells.has(abs_pt):
							group_is_valid = false
							break
						group_footprint_cells[abs_pt] = true
						
					if not group_is_valid: break
						
				if group_is_valid:
					valid_groups.append(group)
					
			if valid_groups.is_empty(): continue

			# FACE PATH EVALUATION
			if face_path and not local_paths.is_empty():
				var best_score = -999.0
				var best_groups = []
				
				for g in valid_groups:
					var group_score = 0.0
					
					for member in g:
						# 1. Find the true physical center of THIS specific structure
						var member_center = Vector2.ZERO
						for pt in raw_footprint:
							member_center += Vector2(member["pos"] + _rotate_point(pt, member["rot"]))
						member_center /= max(1.0, float(raw_footprint.size()))
						
						# 2. Find the path tile closest to THIS structure (not the room center)
						var min_struct_dist = 999999.0
						var closest_path = member_center
						for path_pt in local_paths:
							var d = path_pt.distance_squared_to(member_center)
							if d < min_struct_dist:
								min_struct_dist = d
								closest_path = path_pt
								
						# 3. Calculate dot product score
						var to_path = (closest_path - member_center).normalized()
						if to_path != Vector2.ZERO:
							var rotated_front = Vector2(_rotate_point(front_dir, member["rot"])).normalized()
							group_score += rotated_front.dot(to_path)
							
					# Average the score across all symmetry members in the group
					group_score /= max(1.0, float(g.size()))
					
					if group_score > best_score + 0.01:
						best_score = group_score
						best_groups = [g]
					elif abs(group_score - best_score) <= 0.01:
						best_groups.append(g)
						
				valid_groups = best_groups

			# --- 3. APPLY TO GRID ---
			var chosen_group = SeedUtils.pick_random(valid_groups, rng)
			var group_size = chosen_group.size()
			
			
			
			var group_clear = true
			for placement in chosen_group:
				for pt in raw_footprint:
					var abs_pt = placement["pos"] + _rotate_point(pt, placement["rot"])
					if realizer.reserved_cells.has(abs_pt):
						group_clear = false; break
				if not group_clear: break
				
			if group_clear:
				for placement in chosen_group:
					_stamp_structure(placement, raw_footprint, struct_data, node_id, realizer)
					
				


# --- HELPERS ---

static func _get_symmetry_group(p: Dictionary, center: Vector2i, mode: int, can_rotate: bool) -> Array:
	var group = [p]
	var dx = p["pos"].x - center.x
	var dy = p["pos"].y - center.y
	
	var r = p["rot"]
	var r_x = (4 - r) % 4 if can_rotate else r
	var r_y = (6 - r) % 4 if can_rotate else r
	var r_p = (r + 2) % 4 if can_rotate else r
	
	if mode == 1: group.append({"pos": Vector2i(center.x - dx, p["pos"].y), "rot": r_x})
	elif mode == 2: group.append({"pos": Vector2i(p["pos"].x, center.y - dy), "rot": r_y})
	elif mode == 3: group.append({"pos": Vector2i(center.x - dx, center.y - dy), "rot": r_p})
	elif mode == 4:
		group.append({"pos": Vector2i(center.x - dx, p["pos"].y), "rot": r_x})
		group.append({"pos": Vector2i(p["pos"].x, center.y - dy), "rot": r_y})
		group.append({"pos": Vector2i(center.x - dx, center.y - dy), "rot": r_p})
	return group

static func _stamp_structure(chosen: Dictionary, raw_footprint: Array, struct_data: Dictionary, node_id: String, realizer: GraphRealizer) -> void:
	var final_footprint = []
	for pt in raw_footprint:
		var abs_pt = chosen["pos"] + _rotate_point(pt, chosen["rot"])
		final_footprint.append(abs_pt)
		realizer.reserved_cells[abs_pt] = true # Non-solid structures still reserve cells so entities don't stack inside them!
		
	realizer.grid.entities[chosen["pos"]] = {
		"type": "structure",
		"source_node": node_id,
		"name": struct_data.get("name", "Custom"),
		"color": struct_data.get("color", Color.CYAN),
		"footprint_world": final_footprint,
		"is_solid": struct_data.get("is_solid", true),
		
		# --- SPRITE & ROTATION DATA ---
		"rot": chosen.get("rot", 0), 
		"texture_path": struct_data.get("texture_path", ""),
		"texture_offset": struct_data.get("texture_offset", Vector2.ZERO),
		"texture_scale": struct_data.get("texture_scale", Vector2.ONE),
		"texture_filter": struct_data.get("texture_filter", 0)
	}

static func _rotate_point(pt: Vector2i, rot_idx: int) -> Vector2i:
	match rot_idx % 4:
		1: return Vector2i(-pt.y, pt.x) # 90 deg CW
		2: return Vector2i(-pt.x, -pt.y) # 180 deg
		3: return Vector2i(pt.y, -pt.x) # 270 deg CW
		_: return pt # 0 deg
