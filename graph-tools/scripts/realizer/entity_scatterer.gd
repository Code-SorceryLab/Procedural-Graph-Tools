class_name EntityScatterer
extends RefCounted

static func scatter(graph: Graph, realizer: GraphRealizer, params: Dictionary) -> void:
	var grid = realizer.grid
	var biome_overrides = params.get("biomes", {})
	
	# Extract all active scatter sets from the master params list
	var all_scatter_sets = ConfigManager.load_scatter_sets()
	if all_scatter_sets.is_empty(): return
	
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

		# Build a localized list of sets and their specific parameters for this room
		var active_sets = []
		for s_key in all_scatter_sets:
			var mode = all_scatter_sets[s_key].get("spawn_mode", 0)
			var density = float(effective_params.get("density_" + s_key, all_scatter_sets[s_key].get("density", 0.0)))
			var qty = int(effective_params.get("fixed_quantity_" + s_key, all_scatter_sets[s_key].get("fixed_quantity", 1)))
			
			if (mode == 0 and density > 0.001) or (mode == 1 and qty > 0):
				var set_data = all_scatter_sets[s_key].duplicate()
				set_data["key"] = s_key
				set_data["local_density"] = density
				set_data["local_qty"] = qty
				active_sets.append(set_data)

		if active_sets.is_empty(): continue

		rng.seed = SeedUtils.hash_seed(str(master_seed) + "_" + str(node_id))
		var max_r = int(node.custom_data.get("room_radius", effective_params.get("room_radius_max", 4))) + 2 
		var rect = Rect2i(center.x - max_r, center.y - max_r, max_r * 2 + 1, max_r * 2 + 1)
		
		# --- SCAN FOR ALL VALID ANCHORS IN THE ROOM ---
		var valid_placements = []
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var pt = Vector2i(x, y)
				if not grid.in_bounds_vec(pt) or grid.entities.has(pt): continue
				if realizer.critical_path_cells.has(pt) or realizer.reserved_cells.has(pt) or not reachable_cells.has(pt): continue
				if grid.get_cell(pt.x, pt.y) != target_floor_id: continue
				valid_placements.append(pt)

		# --- PROCESS EACH SCATTER SET ---
		for current_set in active_sets:
			var mode = current_set.get("spawn_mode", 0)
			var min_dist = int(current_set.get("min_dist", 0))
			var max_dist = int(current_set.get("max_dist", 99))
			var sym_mode = int(current_set.get("symmetry", 0)) 
			var clump_chance = float(current_set.get("clump_chance", 0.0))
			var max_clump_size = int(current_set.get("max_clump_size", 3))
			var set_name = current_set.get("name", "Unknown Set")
			var set_color = current_set.get("color", Color.WHITE)
			
			var processed_anchors = {}
			var anchors_to_evaluate = []
			
			if mode == 1: # FIXED QUANTITY (Pick N random valid tiles)
				var shuffled_placements = valid_placements.duplicate()
				var qty_needed = current_set["local_qty"]
				
				while shuffled_placements.size() > 0 and anchors_to_evaluate.size() < qty_needed:
					var idx = rng.randi() % shuffled_placements.size()
					anchors_to_evaluate.append(shuffled_placements.pop_at(idx))
			else: # DENSITY (Evaluate every valid tile)
				anchors_to_evaluate = valid_placements.duplicate()

			# Actually attempt to spawn them
			for pos in anchors_to_evaluate:
				if processed_anchors.has(pos): continue 
				
				# Evaluate Distance Rules
				var tile_dist = realizer.distance_field.get(pos, 0)
				if tile_dist < min_dist or tile_dist > max_dist: continue

				# Roll Density (Skip if it's Fixed Quantity, since we already picked the exact ones)
				if mode == 0 and rng.randf() >= current_set["local_density"]: 
					continue
					
				var group = _get_symmetry_group(pos, center, sym_mode)
				
				# Strict Validation for Anchors
				var group_is_valid = true
				for member in group:
					var pt = member["pos"]
					processed_anchors[pt] = true # Mark to avoid redundant rolls
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

				# 1. GENERATE THE CLUMP FOOTPRINT
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
				
				# 2. APPLY CLUMP TO ALL SYMMETRIC ANCHORS
				for member in group:
					for offset in clump_offsets:
						var trans_offset = _transform_offset(offset, member["flip_x"], member["flip_y"])
						var final_pt = member["pos"] + trans_offset
						
						if grid.in_bounds_vec(final_pt) and not grid.entities.has(final_pt):
							if grid.get_cell(final_pt.x, final_pt.y) == target_floor_id:
								if not realizer.critical_path_cells.has(final_pt) and not realizer.reserved_cells.has(final_pt) and reachable_cells.has(final_pt):
									grid.entities[final_pt] = {
										"type": "scatter_set",       # [NEW] Differentiates it from generic scatters
										"set_id": current_set["key"],
										"name": set_name,
										"color": set_color,
										"source_node": node_id
									}
									
									# Update valid_placements so future sets don't spawn on top of this one!
									valid_placements.erase(final_pt)

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
