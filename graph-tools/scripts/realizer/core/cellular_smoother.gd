class_name CellularSmoother
extends RefCounted

static func smooth(realizer: GraphRealizer, default_floor_id: int, params: Dictionary) -> void:
	var grid = realizer.grid
	var biomes = params.get("biomes", {})
	
	# 1. Build the base rule map (Same as before)
	var rule_map = {}
	var max_global_iterations = params.get("ca_iterations", 0)
	
	rule_map[default_floor_id] = {
		"iter": max_global_iterations,
		"survive": params.get("ca_survive_min", 4),
		"birth": params.get("ca_birth_min", 5)
	}
	
	for type_key in realizer.semantic_floor_ids:
		var f_id = realizer.semantic_floor_ids[type_key]
		var b = biomes.get(type_key, {})
		var b_iter = b.get("ca_iterations", params.get("ca_iterations", 0))
		
		rule_map[f_id] = {
			"iter": b_iter,
			"survive": b.get("ca_survive_min", params.get("ca_survive_min", 4)),
			"birth": b.get("ca_birth_min", params.get("ca_birth_min", 5))
		}
		if b_iter > max_global_iterations:
			max_global_iterations = b_iter
			
	if max_global_iterations <= 0: return
	
	# ==========================================================================
	# HIGH-PERFORMANCE PRE-COMPUTATION
	# ==========================================================================
	var width = grid.width
	var height = grid.height
	var total_cells = width * height
	
	# Find Max Tile ID to size our flat lookup arrays
	var max_id = 0
	for id in grid.palette._definitions:
		if id > max_id: max_id = id
		
	# Flat Arrays (Bypasses GDScript Variant & Dictionary overhead)
	var is_floor = PackedByteArray()
	is_floor.resize(max_id + 1)
	is_floor.fill(0)
	
	for id in grid.palette._definitions:
		if grid.palette.get_data(id).get("walkable", false):
			is_floor[id] = 1
			
	var rule_iter = PackedInt32Array()
	var rule_survive = PackedInt32Array()
	var rule_birth = PackedInt32Array()
	rule_iter.resize(max_id + 1)
	rule_survive.resize(max_id + 1)
	rule_birth.resize(max_id + 1)
	
	var d_rule = rule_map[default_floor_id]
	for i in range(max_id + 1):
		var r = rule_map.get(i, d_rule)
		rule_iter[i] = r["iter"]
		rule_survive[i] = r["survive"]
		rule_birth[i] = r["birth"]
		
	# Flatten the Immunity Checks into a 1D Mask array
	var immune = PackedByteArray()
	immune.resize(total_cells)
	immune.fill(0)
	
	for pos in realizer.critical_path_cells:
		var idx = pos.y * width + pos.x
		if idx >= 0 and idx < total_cells: immune[idx] = 1
		
	if realizer.has_meta("custom_room_cells"):
		for pos in realizer.get_meta("custom_room_cells"):
			var idx = pos.y * width + pos.x
			if idx >= 0 and idx < total_cells: immune[idx] = 1

	# ==========================================================================
	# THE CA LOOP
	# ==========================================================================
	# Pad bounds by 1 to skip `in_bounds` checks safely
	var search_rect = params.get("regen_dirty_rect", Rect2i(0, 0, width, height))
	var start_x = max(1, search_rect.position.x)
	var end_x = min(width - 1, search_rect.position.x + search_rect.size.x)
	var start_y = max(1, search_rect.position.y)
	var end_y = min(height - 1, search_rect.position.y + search_rect.size.y)
	
	# Pre-calculated 1D Array offsets for 8-way neighbors
	var n_offsets = PackedInt32Array([-width - 1, -width, -width + 1, -1, 1, width - 1, width, width + 1])
	
	# Pre-allocated Counting Buffers (Kills Garbage Collection completely)
	var counts = PackedInt32Array()
	counts.resize(max_id + 1)
	counts.fill(0)
	var used_ids = PackedInt32Array()
	used_ids.resize(8) 
	
	var old_cells = grid.cells
	var VOID_ID = TilePalette.VOID_ID
	
	for i in range(max_global_iterations):
		var new_cells = old_cells.duplicate()
		
		for y in range(start_y, end_y):
			var idx = y * width + start_x
			for x in range(start_x, end_x):
				
				# Instant O(1) Mask Check (Replaces 2 Dictionary string lookups + Vector2i alloc)
				if immune[idx] == 1:
					idx += 1
					continue
					
				var current_id = old_cells[idx]
				var neighbor_count = 0
				var most_common_id = default_floor_id
				var max_count = 0
				var used_count = 0
				
				# Unrolled Flat neighbor iteration (Replaces in_bounds() and get_cell() calls)
				for off in n_offsets:
					var n_id = old_cells[idx + off]
					
					# Fast filter for floor tiles
					if n_id >= 0 and n_id <= max_id and is_floor[n_id] == 1:
						neighbor_count += 1
						
						# Tally frequencies inline
						counts[n_id] += 1
						if counts[n_id] == 1:
							used_ids[used_count] = n_id
							used_count += 1
							
						if counts[n_id] > max_count:
							max_count = counts[n_id]
							most_common_id = n_id
							
				# Erosion vs Birth checks (Flat array read)
				if current_id >= 0 and current_id <= max_id and is_floor[current_id] == 1:
					if i < rule_iter[current_id] and neighbor_count < rule_survive[current_id]:
						new_cells[idx] = VOID_ID
				else:
					if neighbor_count > 0:
						if i < rule_iter[most_common_id] and neighbor_count >= rule_birth[most_common_id]:
							new_cells[idx] = most_common_id
							
				# Clear only the dirtied elements of the counts array
				for u in range(used_count):
					counts[used_ids[u]] = 0
					
				idx += 1
				
		old_cells = new_cells
		
	grid.cells = old_cells
