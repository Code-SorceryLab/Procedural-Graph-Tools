class_name WallGenerator
extends RefCounted

static func generate(graph: Graph, realizer: GraphRealizer, params: Dictionary, default_wall_id: int, semantic_wall_map: Dictionary = {}) -> void:
	var grid = realizer.grid
	var custom_rooms = params.get("custom_rooms", {})
	
	# ==========================================================================
	# PASS 0: SEAL UNUSED CUSTOM DOORWAYS (Graph-level, already fast)
	# ==========================================================================
	var c_room_cells = realizer.get_meta("custom_room_cells") if realizer.has_meta("custom_room_cells") else {}
	var metric_doors_sealed = 0
	
	for node_id in graph.nodes:
		var node = graph.nodes[node_id]
		if node.custom_data.get("_is_custom_room", false):
			var doors = node.custom_data.get("_custom_doorways", [])
			var ref = node.custom_data.get("_custom_room_ref", "")
			
			if not custom_rooms.has(ref): continue
			
			var c_room = custom_rooms[ref]
			var mode = c_room.get("unused_door_mode", 1)
			var exact_atlas = c_room.get("unused_door_atlas", Vector2i.ZERO)
			
			var f_id = realizer.semantic_floor_ids.get(node.type, -1)
			var b_wall_id = semantic_wall_map.get(f_id, default_wall_id)
			
			for d_pos in doors:
				# --- MASK CHECK ---
				if params.has("regen_dirty_rect") and not params["regen_dirty_rect"].has_point(d_pos):
					continue
					
				var is_used = false
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var check_pos = d_pos + Vector2i(dx, dy)
						if realizer.critical_path_cells.has(check_pos):
							if not c_room_cells.has(check_pos) or c_room_cells[check_pos] != node_id:
								is_used = true
								break
					if is_used: break
					
				# --- IF UNUSED, CLEAN UP AND SEAL ---
				if not is_used:
					metric_doors_sealed += 1 
					realizer.critical_path_cells.erase(d_pos)
					realizer.core_path_cells.erase(d_pos)
					realizer.reserved_cells.erase(d_pos)
					
					if mode == 1: 
						grid.set_cell(d_pos.x, d_pos.y, b_wall_id)
					elif mode == 2: 
						grid.set_cell_atlas(d_pos.x, d_pos.y, b_wall_id, exact_atlas)
						
					if mode != 0 and c_room_cells.has(d_pos): 
						c_room_cells.erase(d_pos)
	
	realizer.set_meta("metric_doors_sealed", metric_doors_sealed)
	
	# ==========================================================================
	# PASS 1: HIGH-PERFORMANCE IN-PLACE WALL STAMPING
	# ==========================================================================
	var width = grid.width
	var height = grid.height
	var total_cells = width * height
	
	# 1. Find Max ID for flat arrays
	var max_id = 0
	for id in grid.palette._definitions:
		if id > max_id: max_id = id
		
	# 2. Precompute Floor Boolean Mask
	var is_floor = PackedByteArray()
	is_floor.resize(max_id + 1)
	is_floor.fill(0)
	for id in grid.palette._definitions:
		if grid.palette.get_data(id).get("walkable", false):
			is_floor[id] = 1
			
	# 3. Precompute Semantic Wall Mappings
	var floor_to_wall = PackedInt32Array()
	floor_to_wall.resize(max_id + 1)
	floor_to_wall.fill(default_wall_id)
	for f_id in semantic_wall_map:
		if f_id <= max_id:
			floor_to_wall[f_id] = semantic_wall_map[f_id]
			
	# 4. Flatten Critical Path Immunity Mask
	var is_critical = PackedByteArray()
	is_critical.resize(total_cells)
	is_critical.fill(0)
	for pos in realizer.critical_path_cells:
		var idx = pos.y * width + pos.x
		if idx >= 0 and idx < total_cells:
			is_critical[idx] = 1
			
	# --- REGENERATION MASK ---
	# Pad by 1 tile to safely skip in_bounds checks inside the loop
	var search_rect = params.get("regen_dirty_rect", Rect2i(0, 0, width, height))
	var start_x = max(1, search_rect.position.x)
	var end_x = min(width - 1, search_rect.position.x + search_rect.size.x)
	var start_y = max(1, search_rect.position.y)
	var end_y = min(height - 1, search_rect.position.y + search_rect.size.y)
	
	var n_offsets = PackedInt32Array([-width - 1, -width, -width + 1, -1, 1, width - 1, width, width + 1])
	var cells = grid.cells # Direct reference to C++ memory
	var VOID_ID = TilePalette.VOID_ID
	
	# Loop through the grid
	for y in range(start_y, end_y):
		var idx = y * width + start_x
		for x in range(start_x, end_x):
			
			# If it's a void tile and NOT immune...
			if cells[idx] == VOID_ID and is_critical[idx] == 0:
				var chosen_wall = -1
				
				# Fast unrolled neighbor search
				for off in n_offsets:
					var n_id = cells[idx + off]
					
					# If the neighbor is a FLOOR tile, we build a wall!
					if n_id >= 0 and n_id <= max_id and is_floor[n_id] == 1:
						chosen_wall = floor_to_wall[n_id]
						break
						
				# Mutate the grid memory completely in-place!
				if chosen_wall != -1:
					cells[idx] = chosen_wall
					
			idx += 1
