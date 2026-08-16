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
			
	# --- GLOBAL TRACKERS ---
	var global_struct_tracker = {} # Tracks individual structures
	var global_biome_tracker = {}  # Tracks total structures per biome
	
	var node_ids = graph.nodes.keys().duplicate()
	var node_rng = RandomNumberGenerator.new()
	node_rng.seed = master_seed
	var shuffled_nodes = []
	var biome_node_counts = {}
	
	while node_ids.size() > 0:
		var n_id = node_ids.pop_at(node_rng.randi() % node_ids.size())
		shuffled_nodes.append(n_id)
		var n_type = graph.nodes[n_id].type
		biome_node_counts[n_type] = biome_node_counts.get(n_type, 0) + 1
		
	var global_nodes_remaining = shuffled_nodes.size()
			
	for node_id in shuffled_nodes:
		var node = graph.nodes[node_id]
		var center = node.custom_data.get("_grid_center", Vector2i.ZERO)
		if center == Vector2i.ZERO: 
			_decrement_trackers(node.type, biome_node_counts, global_nodes_remaining)
			continue
		
		var target_floor_id = grid.get_cell(center.x, center.y)
		if not valid_floors.has(target_floor_id):
			target_floor_id = realizer.floor_id 
		
		var effective_params = params.duplicate()
		var is_overridden = false
		if biome_overrides.has(node.type):
			effective_params.merge(biome_overrides[node.type], true)
			is_overridden = biome_overrides[node.type].get("override_structures", false)
			
		if not effective_params.get("spawn_structure", false):
			_decrement_trackers(node.type, biome_node_counts, global_nodes_remaining)
			continue
			
		rng.seed = SeedUtils.hash_seed(str(master_seed) + "_" + str(node_id))
		
		# --- CAPS & LIMITS ---
		var master_per_room = int(effective_params.get("master_struct_per_room", 1))
		var master_per_biome = int(effective_params.get("master_struct_per_biome", 0))
		var biome_tracker_key = node.type if is_overridden else "global"
		var nodes_left = biome_node_counts[node.type] if is_overridden else global_nodes_remaining
		
		# CIRCUIT BREAKER 1: Have we hit the biome-wide Master Cap?
		if master_per_biome > 0 and global_biome_tracker.get(biome_tracker_key, 0) >= master_per_biome:
			_decrement_trackers(node.type, biome_node_counts, global_nodes_remaining)
			continue
		
		var use_density = effective_params.get("structure_use_density", false)
		
		var force_pool = []
		var rng_pool = []
		var total_weight = 0
		
		# --- BUILD THE DECK ---
		for key in custom_structures:
			var tracker_key = key + "_" + biome_tracker_key
			var spawned = global_struct_tracker.get(tracker_key, 0)
			
			# CIRCUIT BREAKER 2: Individual Structure Max Cap
			var max_s = int(effective_params.get("struct_max_spawns_" + key, 0))
			if max_s > 0 and spawned >= max_s: continue 
			
			# CIRCUIT BREAKER 3: Guaranteed Minimums
			var min_s = int(effective_params.get("struct_min_spawns_" + key, 0))
			var needed = min_s - spawned
			
			if needed > 0 and needed >= nodes_left:
				force_pool.append(key) # Must spawn NOW to fulfill minimum quota
			else:
				if use_density:
					var d = float(effective_params.get("density_" + key, 0.0))
					if d > 0.001: rng_pool.append({"id": key, "density": d})
				else:
					var w = int(effective_params.get("weight_" + key, 0))
					if w > 0: 
						rng_pool.append({"id": key, "weight": w})
						total_weight += w

		var intents = []
		
		# 1. Fill slots with Forced Minimums first
		for key in force_pool:
			if intents.size() >= master_per_room: break
			intents.append(key)
			
		var remaining_slots = master_per_room - intents.size()
		
		# 2. Fill remaining slots organically
		if remaining_slots > 0:
			if use_density:
				var valid_rng_pool = []
				for item in rng_pool:
					if rng.randf() < item["density"]: valid_rng_pool.append(item["id"])
				valid_rng_pool.shuffle()
				
				for key in valid_rng_pool:
					if intents.size() >= master_per_room: break
					intents.append(key)
			else:
				for i in range(remaining_slots):
					if total_weight <= 0: break
					var roll = rng.randi() % total_weight
					var current_w = 0
					var chosen_idx = -1
					for j in range(rng_pool.size()):
						current_w += rng_pool[j]["weight"]
						if roll < current_w:
							chosen_idx = j
							break
					if chosen_idx >= 0:
						var chosen_item = rng_pool[chosen_idx]
						intents.append(chosen_item["id"])
						total_weight -= chosen_item["weight"]
						rng_pool.remove_at(chosen_idx)
						
		if intents.is_empty(): 
			_decrement_trackers(node.type, biome_node_counts, global_nodes_remaining)
			continue
			
		intents.shuffle()
		
		# --- 2. EVALUATE INTENTS ---
		for key in intents:
			var struct_data = custom_structures[key]
			var raw_footprint: Array = struct_data.get("footprint", [])
			if raw_footprint.is_empty(): continue
			
			var allow_rotation = struct_data.get("allow_rotation", true)
			var face_path = struct_data.get("face_path", true)
			var front_dir = struct_data.get("front_dir", Vector2i.UP)
			var min_dist = int(effective_params.get("struct_min_dist_" + key, 0))
			var max_dist = int(effective_params.get("struct_max_dist_" + key, 99))
			
			# Fetch symmetry on a PER STRUCTURE basis
			var sym_mode = int(effective_params.get("struct_symmetry_" + key, 0))
			
			var max_r = int(node.custom_data.get("room_radius", effective_params.get("room_radius_max", 4))) + 2
			var rect = Rect2i(center.x - max_r, center.y - max_r, max_r * 2 + 1, max_r * 2 + 1)
			
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
				for member in group:
					var m_sig = "%d,%d,%d" % [member["pos"].x, member["pos"].y, member["rot"]]
					if not placement_lookup.has(m_sig):
						group_is_valid = false; break
						
				if group_is_valid:
					valid_groups.append(group)
					
			if valid_groups.is_empty(): continue

			# FACE PATH EVALUATION
			if face_path and not realizer.critical_path_cells.is_empty():
				var path_target = _find_nearest_path(center, realizer.critical_path_cells)
				var best_score = -999.0
				var best_groups = []
				
				for g in valid_groups:
					var primary = g[0]
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
			var chosen_group = SeedUtils.pick_random(valid_groups, rng)
			var group_size = chosen_group.size()
			
			# [NEW] Cap Verification - Ensure the symmetrical burst fits the remaining quota!
			var t_key = key + "_" + biome_tracker_key
			var current_struct_count = global_struct_tracker.get(t_key, 0)
			var current_biome_count = global_biome_tracker.get(biome_tracker_key, 0)
			
			var max_s = int(effective_params.get("struct_max_spawns_" + key, 0))
			if max_s > 0 and current_struct_count + group_size > max_s: continue # Bursts over the structure cap!
			if master_per_biome > 0 and current_biome_count + group_size > master_per_biome: continue # Bursts over the biome cap!
			
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
					
				# [FIXED] Record the ENTIRE group size to the trackers!
				global_struct_tracker[t_key] = current_struct_count + group_size
				global_biome_tracker[biome_tracker_key] = current_biome_count + group_size

		_decrement_trackers(node.type, biome_node_counts, global_nodes_remaining)


# --- HELPERS ---
static func _decrement_trackers(n_type: String, biome_node_counts: Dictionary, global_nodes_remaining: int) -> void:
	biome_node_counts[n_type] -= 1
	global_nodes_remaining -= 1

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
		"is_solid": struct_data.get("is_solid", true) # Inject the solid flag!
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
