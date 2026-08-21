class_name WallGenerator
extends RefCounted

# [UPDATED] Signature now takes graph and params
static func generate(graph: Graph, realizer: GraphRealizer, params: Dictionary, default_wall_id: int, semantic_wall_map: Dictionary = {}) -> void:
	var grid = realizer.grid
	var walls_to_build: Dictionary = {} 
	
	var custom_rooms = params.get("custom_rooms", {})
	
	# ==========================================================================
	# PASS 0: SEAL UNUSED CUSTOM DOORWAYS
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
				var is_used = false
				
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var check_pos = d_pos + Vector2i(dx, dy)
						
						if realizer.critical_path_cells.has(check_pos):
							# Check if the path belongs to the exterior void/hallways
							if not c_room_cells.has(check_pos) or c_room_cells[check_pos] != node_id:
								is_used = true
								break
					if is_used: break
					
				# --- IF UNUSED, CLEAN UP AND SEAL ---
				if not is_used:
					metric_doors_sealed += 1 # Log the seal
					# 1. Revoke the pathing tags so the pink overlay doesn't jut into the wall
					#    and so it doesn't block adjacent structure placements!
					realizer.critical_path_cells.erase(d_pos)
					realizer.core_path_cells.erase(d_pos)
					realizer.reserved_cells.erase(d_pos)
					
					# 2. Apply the visual seal
					if mode == 1: 
						grid.set_cell(d_pos.x, d_pos.y, b_wall_id)
					elif mode == 2: 
						grid.set_cell_atlas(d_pos.x, d_pos.y, b_wall_id, exact_atlas)
						
					# 3. If it became a wall, remove it from the firewall so 
					#    Zone Decorator knows it is an exterior boundary!
					if mode != 0 and c_room_cells.has(d_pos): 
						c_room_cells.erase(d_pos)
	
	
	realizer.set_meta("metric_doors_sealed", metric_doors_sealed)
	
	# ==========================================================================
	# PASS 1: SCAN FOR VOID CELLS TOUCHING FLOOR CELLS
	# ==========================================================================
	var valid_floors = {}
	for id in grid.palette._definitions:
		if grid.palette.get_data(id).get("walkable", false):
			valid_floors[id] = true
			
	for y in range(grid.height):
		for x in range(grid.width):
			var pos = Vector2i(x, y)
			
			if grid.get_cell(x, y) == TilePalette.VOID_ID:
				
				# --- IMMUNITY CHECK ---
				if realizer.critical_path_cells.has(pos):
					continue
					
				var touches_floor = false
				var adjacent_floor_id = -1
				
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if dx == 0 and dy == 0: continue
						var nx = x + dx
						var ny = y + dy
						
						if grid.in_bounds(nx, ny):
							var neighbor_id = grid.get_cell(nx, ny)
							if valid_floors.has(neighbor_id):
								touches_floor = true
								adjacent_floor_id = neighbor_id
								break
					if touches_floor: break
					
				if touches_floor:
					var chosen_wall_id = default_wall_id
					if semantic_wall_map.has(adjacent_floor_id):
						chosen_wall_id = semantic_wall_map[adjacent_floor_id]
						
					walls_to_build[pos] = chosen_wall_id
					
	# ==========================================================================
	# PASS 2: STAMP THE WALLS
	# ==========================================================================
	for pos in walls_to_build:
		grid.set_cell(pos.x, pos.y, walls_to_build[pos])
