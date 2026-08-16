class_name EntityScatterer
extends RefCounted

static func scatter(graph: Graph, realizer: GraphRealizer, params: Dictionary) -> void:
	var grid = realizer.grid
	var biome_overrides = params.get("biomes", {})
	
	# Extract all active scatter sets (now just Name and Color data)
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

	# Tracks how many times a Set has spawned across the entire biome/map
	var global_spawn_tracker = {}
	
	var node_ids = graph.nodes.keys().duplicate()
	var node_rng = RandomNumberGenerator.new()
	node_rng.seed = master_seed
	var shuffled_nodes = []
	
	# Pre-count how many rooms exist per biome for distribution math!
	var biome_node_counts = {}
	
	while node_ids.size() > 0:
		var n_id = node_ids.pop_at(node_rng.randi() % node_ids.size())
		shuffled_nodes.append(n_id)
		var n_type = graph.nodes[n_id].type
		biome_node_counts[n_type] = biome_node_counts.get(n_type, 0) + 1
		
	var global_nodes_remaining = shuffled_nodes.size()

	# Iterate through the shuffled rooms
	for node_id in shuffled_nodes:
		var node = graph.nodes[node_id]
		var center = node.custom_data.get("_grid_center", Vector2i.ZERO)
		if center == Vector2i.ZERO: continue
		
		var target_floor_id = grid.get_cell(center.x, center.y)
		if not valid_floors.has(target_floor_id):
			target_floor_id = realizer.floor_id 

		# --- [FIXED] SELECTIVE OVERRIDE MATH ---
		var effective_params = params
		var is_scatter_overridden = false
		
		if biome_overrides.has(node.type):
			effective_params = params.duplicate()
			effective_params.merge(biome_overrides[node.type], true)
			# Even if we merged Shape rules, we only isolate the cap tracker if Scatter is checked!
			is_scatter_overridden = biome_overrides[node.type].get("override_scatter", false)

		var active_sets = []
		for s_key in all_scatter_sets:
			var mode = int(effective_params.get("scatter_mode_" + s_key, 0))
			var density = float(effective_params.get("scatter_density_" + s_key, 0.05))
			var qty = int(effective_params.get("scatter_qty_" + s_key, 1))
			
			if (mode == 0 and density > 0.001) or (mode == 1 and qty > 0):
				var set_data = all_scatter_sets[s_key].duplicate()
				set_data["key"] = s_key
				set_data["spawn_mode"] = mode
				set_data["local_density"] = density
				set_data["local_qty"] = qty
				set_data["quantity_scope"] = int(effective_params.get("scatter_scope_" + s_key, 0))
				set_data["min_dist"] = int(effective_params.get("scatter_min_dist_" + s_key, 0))
				set_data["max_dist"] = int(effective_params.get("scatter_max_dist_" + s_key, 99))
				set_data["symmetry"] = int(effective_params.get("scatter_symmetry_" + s_key, 0))
				set_data["clump_chance"] = float(effective_params.get("scatter_clump_chance_" + s_key, 0.0))
				set_data["max_clump_size"] = int(effective_params.get("scatter_max_clump_" + s_key, 3))
				
				# [FIXED] Tracker uses the specific scatter flag!
				set_data["tracker_key"] = s_key + ("_" + node.type if is_scatter_overridden else "_global")
				
				active_sets.append(set_data)

		if active_sets.is_empty(): continue

		rng.seed = SeedUtils.hash_seed(str(master_seed) + "_" + str(node_id))
		var max_r = int(node.custom_data.get("room_radius", effective_params.get("room_radius_max", 4))) + 2 
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

		# --- PROCESS EACH SCATTER SET ---
		for current_set in active_sets:
			var mode = current_set.get("spawn_mode", 0)
			var scope = current_set.get("quantity_scope", 0) 
			var min_dist = int(current_set.get("min_dist", 0))
			var max_dist = int(current_set.get("max_dist", 99))
			var sym_mode = int(current_set.get("symmetry", 0)) 
			var clump_chance = float(current_set.get("clump_chance", 0.0))
			var max_clump_size = int(current_set.get("max_clump_size", 3))
			
			var available_placements = []
			for pt in room_valid_placements:
				if not grid.entities.has(pt): available_placements.append(pt)
				
			if available_placements.is_empty(): continue
			
			var qty_needed = current_set["local_qty"]
			var local_room_cap = qty_needed # Default for Per-Room scope
			
			# Deduct spawns that already occurred in previous rooms
			if mode == 1 and scope == 1: 
				var already_spawned = global_spawn_tracker.get(current_set["tracker_key"], 0)
				qty_needed -= already_spawned
				if qty_needed <= 0: continue # This Biome/Map has reached its cap!
				
				# Distribute the remaining quota across the remaining rooms
				var nodes_left = biome_node_counts[node.type] if is_scatter_overridden else global_nodes_remaining
				local_room_cap = ceil(float(qty_needed) / float(max(1, nodes_left)))
				
			if mode == 1:
				available_placements.shuffle()
				
			var successful_spawns = 0
			var processed_anchors = {}

			# Actually attempt to spawn them
			for pos in available_placements:
				if mode == 1 and successful_spawns >= local_room_cap: break
				
				if mode == 0 and rng.randf() >= current_set["local_density"]: continue
				if processed_anchors.has(pos): continue
				
				var tile_dist = realizer.distance_field.get(pos, 0)
				if tile_dist < min_dist or tile_dist > max_dist: continue

				var group = _get_symmetry_group(pos, center, sym_mode)
				
				var group_is_valid = true
				for member in group:
					var pt = member["pos"]
					processed_anchors[pt] = true
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
				
				var actually_spawned = false
				for member in group:
					for offset in clump_offsets:
						var trans_offset = _transform_offset(offset, member["flip_x"], member["flip_y"])
						var final_pt = member["pos"] + trans_offset
						
						if grid.in_bounds_vec(final_pt) and not grid.entities.has(final_pt):
							if grid.get_cell(final_pt.x, final_pt.y) == target_floor_id:
								if not realizer.critical_path_cells.has(final_pt) and not realizer.reserved_cells.has(final_pt) and reachable_cells.has(final_pt):
									
									grid.entities[final_pt] = {
										"type": "scatter_set",
										"set_id": current_set["key"],
										"name": current_set.get("name", "Unknown Set"),
										"color": current_set.get("color", Color.WHITE),
										"source_node": node_id
									}
									actually_spawned = true
									room_valid_placements.erase(final_pt)
									
				if actually_spawned:
					successful_spawns += 1
					
			# Record the successful spawns into the global tracker
			if mode == 1 and scope == 1 and successful_spawns > 0:
				var t_key = current_set["tracker_key"]
				global_spawn_tracker[t_key] = global_spawn_tracker.get(t_key, 0) + successful_spawns

		# Decrement the available rooms as we leave this node
		biome_node_counts[node.type] -= 1
		global_nodes_remaining -= 1

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
