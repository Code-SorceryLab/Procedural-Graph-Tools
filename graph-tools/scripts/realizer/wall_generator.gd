class_name WallGenerator
extends RefCounted

# [FIX] Added semantic_wall_map: { floor_id : wall_id }
static func generate(grid: GridData, default_wall_id: int, semantic_wall_map: Dictionary = {}) -> void:
	var walls_to_build: Dictionary = {} # Maps Vector2i(x, y) -> Wall ID to place
	
	# Pre-cache walkables
	var valid_floors = {}
	for id in grid.palette._definitions:
		if grid.palette.get_data(id).get("walkable", false):
			valid_floors[id] = true
	
	# Pass 1: Scan for Void cells touching Floor cells
	for y in range(grid.height):
		for x in range(grid.width):
			if grid.get_cell(x, y) == TilePalette.VOID_ID:
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
					# Semantic Wall check! Does this floor type have a matching wall type?
					var chosen_wall_id = default_wall_id
					if semantic_wall_map.has(adjacent_floor_id):
						chosen_wall_id = semantic_wall_map[adjacent_floor_id]
						
					walls_to_build[Vector2i(x, y)] = chosen_wall_id
					
	# Pass 2: Stamp the walls
	for pos in walls_to_build:
		grid.set_cell(pos.x, pos.y, walls_to_build[pos])
