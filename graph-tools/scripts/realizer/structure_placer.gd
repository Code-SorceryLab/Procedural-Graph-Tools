class_name StructurePlacer
extends RefCounted

static func place(graph: Graph, realizer: GraphRealizer, params: Dictionary) -> void:
	var grid = realizer.grid
	var biome_overrides = params.get("biomes", {})
	var master_seed = SeedUtils.hash_seed(str(params.get("realizer_seed", "default")) + "_structure")
	var rng = RandomNumberGenerator.new()
	
	# Load the custom structures from disk
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
		
		var effective_params = params
		if biome_overrides.has(node.type) and biome_overrides[node.type].get("override_enabled", false):
			effective_params = params.duplicate()
			effective_params.merge(biome_overrides[node.type], true)
			
		if not effective_params.get("spawn_structure", false): continue
		
		# --- 1. DYNAMIC WEIGHT RESOLUTION ---
		var pool = []
		var total_weight = 0
		for key in custom_structures:
			var w = int(effective_params.get("weight_" + key, 0))
			if w > 0:
				pool.append({ "id": key, "weight": w })
				total_weight += w
				
		if total_weight <= 0: continue
		
		# Roll dice
		rng.seed = SeedUtils.hash_seed(str(master_seed) + "_" + str(node_id))
		var roll = rng.randi() % total_weight
		var chosen_id = ""
		var current_w = 0
		for item in pool:
			current_w += item["weight"]
			if roll < current_w:
				chosen_id = item["id"]
				break
				
		var struct_data = custom_structures[chosen_id]
		var raw_footprint: Array = struct_data.get("footprint", [])
		if raw_footprint.is_empty(): continue
		
		var allow_rotation = struct_data.get("allow_rotation", true)
		var face_path = struct_data.get("face_path", true)
		var front_dir = struct_data.get("front_dir", Vector2i.UP)
		
		# Fetch SDF Constraints (Fallback to 0-99 for pure random default)
		var min_dist = struct_data.get("min_dist", 0)
		var max_dist = struct_data.get("max_dist", 99)
		
		# --- 2. SCAN FOR VALID PLACEMENTS ---
		var max_r = int(node.custom_data.get("room_radius", effective_params.get("room_radius_max", 4))) + 2
		var rect = Rect2i(center.x - max_r, center.y - max_r, max_r * 2 + 1, max_r * 2 + 1)
		var valid_placements = []
		
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var test_center = Vector2i(x, y)
				var rots_to_test = [0, 1, 2, 3] if allow_rotation else [0]
				
				for r in rots_to_test:
					var is_valid = true
					for pt in raw_footprint:
						var abs_pt = test_center + _rotate_point(pt, r)
						
						# Collision Checks
						if realizer.critical_path_cells.has(abs_pt) or realizer.reserved_cells.has(abs_pt):
							is_valid = false
							break
						if not valid_floors.has(grid.get_cell(abs_pt.x, abs_pt.y)):
							is_valid = false
							break
							
						# [NEW] Signed Distance Field Check
						# Every tile in the footprint must satisfy the distance constraints!
						var tile_dist = realizer.distance_field.get(abs_pt, 0)
						if tile_dist < min_dist or tile_dist > max_dist:
							is_valid = false
							break
							
					if is_valid:
						valid_placements.append({ "pos": test_center, "rot": r })
						
		if valid_placements.is_empty(): continue
		
		# --- 3. EVALUATE DIRECTION / FACE PATH ---
		if face_path and not realizer.critical_path_cells.is_empty():
			var path_target = _find_nearest_path(center, realizer.critical_path_cells)
			var best_score = -999.0
			var best_placements = []
			
			for p in valid_placements:
				var rotated_front = Vector2(_rotate_point(front_dir, p["rot"])).normalized()
				var to_path = Vector2(path_target - p["pos"]).normalized()
				
				# Dot product scores 1.0 for perfectly aligned, -1.0 for completely backwards
				var score = rotated_front.dot(to_path)
				
				if score > best_score + 0.01:
					best_score = score
					best_placements = [p]
				elif abs(score - best_score) <= 0.01:
					best_placements.append(p)
					
			valid_placements = best_placements
			
		# --- 4. APPLY TO GRID ---
		var chosen = SeedUtils.pick_random(valid_placements, rng)
		var final_footprint = []
		
		# Map all absolute coordinates so we can draw them and reserve them
		for pt in raw_footprint:
			var abs_pt = chosen["pos"] + _rotate_point(pt, chosen["rot"])
			final_footprint.append(abs_pt)
			realizer.reserved_cells[abs_pt] = true
			
		grid.entities[chosen["pos"]] = {
			"type": "structure",
			"source_node": node_id,
			"name": struct_data.get("name", "Custom"),
			"color": struct_data.get("color", Color.CYAN),
			"footprint_world": final_footprint # Pass the absolute footprint to the UI!
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
