class_name WallGenerator
extends RefCounted

# [FIXED] Now takes 'realizer' instead of 'grid'
static func generate(realizer: GraphRealizer, default_wall_id: int, semantic_wall_map: Dictionary = {}) -> void:
	var grid = realizer.grid
	var walls_to_build: Dictionary = {} 
	
	var valid_floors = {}
	for id in grid.palette._definitions:
		if grid.palette.get_data(id).get("walkable", false):
			valid_floors[id] = true
			
	# Pass 1: Scan for Void cells touching Floor cells
	for y in range(grid.height):
		for x in range(grid.width):
			var pos = Vector2i(x, y)
			
			if grid.get_cell(x, y) == TilePalette.VOID_ID:
				
				# --- [NEW] IMMUNITY CHECK ---
				# NEVER place a wall on a coordinate that belongs to a corridor!
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
					
	# Pass 2: Stamp the walls
	for pos in walls_to_build:
		grid.set_cell(pos.x, pos.y, walls_to_build[pos])
