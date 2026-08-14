class_name StructurePlacer
extends RefCounted

static func place(graph: Graph, realizer: GraphRealizer, params: Dictionary) -> void:
	var grid = realizer.grid
	var biome_overrides = params.get("biomes", {})
	var master_seed = SeedUtils.hash_seed(str(params.get("realizer_seed", "default")) + "_structure")
	var rng = RandomNumberGenerator.new()
	
	var custom_structures = ConfigManager.load_structures()
	if custom_structures.is_empty(): return
	
	var valid_floors = {}
	for id in grid.palette._definitions:
		if grid.palette.get_data(id).get("walkable", false):
			valid_floors[id] = true
			
	for node_id in graph.nodes:
		var node = graph.nodes[node_id]
		var center = node.custom_data.get("_grid_center", Vector2i.ZERO)
		if center == Vector2i.ZERO: continue
		
		var target_floor_id = grid.get_cell(center.x, center.y)
		if not valid_floors.has(target_floor_id):
			target_floor_id = realizer.floor_id 
		
		var effective_params = params
		if biome_overrides.has(node.type) and biome_overrides[node.type].get("override_enabled", false):
			effective_params = params.duplicate()
			effective_params.merge(biome_overrides[node.type], true)
			
		rng.seed = SeedUtils.hash_seed(str(master_seed) + "_" + str(node_id))
		
		var use_density = effective_params.get("structure_use_density", false)
		var sym_mode = int(effective_params.get("structure_symmetry", 0)) # 0=None, 1=X-Axis, 2=Y-Axis, 3=Radial, 4=Quad
		var intents = []
		
		# --- 1. RESOLVE SPAWN INTENTS ---
		if not use_density:
			if not effective_params.get("spawn_structure", false): continue
			var pool = []
			var total_weight = 0
			for key in custom_structures:
				var w = int(effective_params.get("weight_" + key, 0))
				if w > 0:
					pool.append({ "id": key, "weight": w })
					total_weight += w
					
			if total_weight > 0:
				var roll = rng.randi() % total_weight
				var current_w = 0
				for item in pool:
					current_w += item["weight"]
					if roll < current_w:
						intents.append({ "id": item["id"], "is_density": false })
						break
		else:
			for key in custom_structures:
				var d = float(effective_params.get("density_" + key, 0.0))
				if d > 0.001:
					intents.append({ "id": key, "is_density": true, "density": d })
					
			# [FIX 1] DENSITY NORMALIZATION
			# Divides the density by the number of active structures so probability doesn't stack!
			# 6 structures at 0.01 density will share a single 0.01 probability space.
			var intent_count = float(intents.size())
			if intent_count > 0:
				for intent in intents:
					intent["density"] = intent["density"] / intent_count
					
		if intents.is_empty(): continue
		
		# [FIX 2] INTENT SHUFFLING
		# Randomize the evaluation order so the first structure alphabetically 
		# doesn't always steal the center of the room!
		var shuffled_intents = []
		var temp_intents = intents.duplicate()
		while temp_intents.size() > 0:
			var rand_idx = rng.randi() % temp_intents.size()
			shuffled_intents.append(temp_intents.pop_at(rand_idx))
		intents = shuffled_intents
		
		# --- 2. EVALUATE INTENTS ---
		
		# --- 2. EVALUATE INTENTS ---
		for intent in intents:
			var struct_data = custom_structures[intent["id"]]
			var raw_footprint: Array = struct_data.get("footprint", [])
			if raw_footprint.is_empty(): continue
			
			var allow_rotation = struct_data.get("allow_rotation", true)
			var face_path = struct_data.get("face_path", true)
			var front_dir = struct_data.get("front_dir", Vector2i.UP)
			var min_dist = struct_data.get("min_dist", 0)
			var max_dist = struct_data.get("max_dist", 99)
			
			var max_r = int(node.custom_data.get("room_radius", effective_params.get("room_radius_max", 4))) + 2
			var rect = Rect2i(center.x - max_r, center.y - max_r, max_r * 2 + 1, max_r * 2 + 1)
			
			var valid_placements = []
			var placement_lookup = {} # Fast lookup for symmetry validation
			
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
			
			# --- [NEW] SYMMETRY GROUPING ---
			var valid_groups = []
			var processed_sigs = {}
			
			for p in valid_placements:
				var group = _get_symmetry_group(p, center, sym_mode, allow_rotation)
				
				# Generate a unique signature for this group so we don't add the same mirrored pair twice
				var sig_array = []
				for member in group: sig_array.append("%d,%d,%d" % [member["pos"].x, member["pos"].y, member["rot"]])
				sig_array.sort()
				var sig = str(sig_array)
				
				if processed_sigs.has(sig): continue
				processed_sigs[sig] = true
				
				# Strict Check: ALL mirrored positions MUST be valid!
				var group_is_valid = true
				for member in group:
					var m_sig = "%d,%d,%d" % [member["pos"].x, member["pos"].y, member["rot"]]
					if not placement_lookup.has(m_sig):
						group_is_valid = false; break
						
				if group_is_valid:
					valid_groups.append(group)
					
			if valid_groups.is_empty(): continue

			# FACE PATH EVALUATION (Runs against the primary position in the group)
			if face_path and not realizer.critical_path_cells.is_empty():
				var path_target = _find_nearest_path(center, realizer.critical_path_cells)
				var best_score = -999.0
				var best_groups = []
				
				for g in valid_groups:
					var primary = g[0] # Evaluate based on the primary placement
					var rotated_front = Vector2(_rotate_point(front_dir, primary["rot"])).normalized()
					var to_path = Vector2(path_target - primary["pos"]).normalized()
					var score = rotated_front.dot(to_path)
					
					if score > best_score + 0.01:
						best_score = score
						best_groups = [g]
					elif abs(score - best_score) <= 0.01:
						best_groups.append(g)
				valid_groups = best_groups

			# --- 3. APPLY TO GRID ---
			if not intent["is_density"]:
				var chosen_group = SeedUtils.pick_random(valid_groups, rng)
				for placement in chosen_group:
					_stamp_structure(placement, raw_footprint, struct_data, node_id, realizer)
			else:
				var shuffled = valid_groups.duplicate()
				while shuffled.size() > 0:
					var idx = rng.randi() % shuffled.size()
					var current_group = shuffled.pop_at(idx)
					
					# Re-check collision for the entire group dynamically
					var group_clear = true
					for placement in current_group:
						for pt in raw_footprint:
							var abs_pt = placement["pos"] + _rotate_point(pt, placement["rot"])
							if realizer.reserved_cells.has(abs_pt):
								group_clear = false; break
						if not group_clear: break
						
					if group_clear and rng.randf() < intent["density"]:
						for placement in current_group:
							_stamp_structure(placement, raw_footprint, struct_data, node_id, realizer)


# --- [NEW] SYMMETRY MATH HELPERS ---
static func _get_symmetry_group(p: Dictionary, center: Vector2i, mode: int, can_rotate: bool) -> Array:
	var group = [p]
	var dx = p["pos"].x - center.x
	var dy = p["pos"].y - center.y
	
	var r = p["rot"]
	var r_x = (4 - r) % 4 if can_rotate else r       # X-Axis reflection
	var r_y = (6 - r) % 4 if can_rotate else r       # Y-Axis reflection
	var r_p = (r + 2) % 4 if can_rotate else r       # Point reflection
	
	if mode == 1: # X-Axis
		group.append({"pos": Vector2i(center.x - dx, p["pos"].y), "rot": r_x})
	elif mode == 2: # Y-Axis
		group.append({"pos": Vector2i(p["pos"].x, center.y - dy), "rot": r_y})
	elif mode == 3: # Radial/Point
		group.append({"pos": Vector2i(center.x - dx, center.y - dy), "rot": r_p})
	elif mode == 4: # 4-Way Quad
		group.append({"pos": Vector2i(center.x - dx, p["pos"].y), "rot": r_x})
		group.append({"pos": Vector2i(p["pos"].x, center.y - dy), "rot": r_y})
		group.append({"pos": Vector2i(center.x - dx, center.y - dy), "rot": r_p})
		
	return group

# (Keep _stamp_structure, _rotate_point, and _find_nearest_path exactly as they are)
static func _stamp_structure(chosen: Dictionary, raw_footprint: Array, struct_data: Dictionary, node_id: String, realizer: GraphRealizer) -> void:
	var final_footprint = []
	for pt in raw_footprint:
		var abs_pt = chosen["pos"] + _rotate_point(pt, chosen["rot"])
		final_footprint.append(abs_pt)
		realizer.reserved_cells[abs_pt] = true
		
	realizer.grid.entities[chosen["pos"]] = {
		"type": "structure",
		"source_node": node_id,
		"name": struct_data.get("name", "Custom"),
		"color": struct_data.get("color", Color.CYAN),
		"footprint_world": final_footprint
	}

static func _rotate_point(pt: Vector2i, rot_idx: int) -> Vector2i:
	match rot_idx % 4:
		1: return Vector2i(-pt.y, pt.x) # 90 deg CW
		2: return Vector2i(-pt.x, -pt.y) # 180 deg
		3: return Vector2i(pt.y, -pt.x) # 270 deg CW
		_: return pt # 0 deg

static func _find_nearest_path(room_center: Vector2i, path_cells: Dictionary) -> Vector2i:
	var nearest = room_center
	var min_dist = 9999999.0
	for cell in path_cells:
		var dist = Vector2(cell).distance_squared_to(Vector2(room_center))
		if dist < min_dist:
			min_dist = dist
			nearest = cell
	return nearest
