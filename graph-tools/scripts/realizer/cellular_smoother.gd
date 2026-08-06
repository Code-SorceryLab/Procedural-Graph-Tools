class_name CellularSmoother
extends RefCounted

static func smooth(grid: GridData, default_floor_id: int, params: Dictionary) -> void:
	var iterations = params.get("ca_iterations", 0)
	if iterations <= 0: return
	
	var survive_min = params.get("ca_survive_min", 4)
	var birth_min = params.get("ca_birth_min", 5)
	
	# 1. Pre-cache all valid floor IDs (anything marked as walkable)
	# This allows the CA to seamlessly recognize SCP semantic rooms!
	var valid_floors = {}
	for id in grid.palette._definitions:
		if grid.palette.get_data(id).get("walkable", false):
			valid_floors[id] = true
	
	for i in range(iterations):
		var new_cells = grid.cells.duplicate()
		
		for y in range(grid.height):
			for x in range(grid.width):
				var neighbor_floors: Array[int] = []
				
				# 8-Way Neighbor Count
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						if dx == 0 and dy == 0: continue
						
						var nx = x + dx
						var ny = y + dy
						
						if grid.in_bounds(nx, ny):
							var cell_id = grid.get_cell(nx, ny)
							if valid_floors.has(cell_id):
								neighbor_floors.append(cell_id)
				
				var neighbors = neighbor_floors.size()
				var idx = grid._get_index(x, y)
				var current_id = grid.cells[idx]
				var was_floor = valid_floors.has(current_id)
				
				# Apply the CA Rules
				if was_floor:
					if neighbors < survive_min:
						new_cells[idx] = TilePalette.VOID_ID # Erode
				else:
					if neighbors >= birth_min:
						# 2. SEMANTIC INHERITANCE (Majority Vote)
						# Find the most common floor ID among the neighbors
						var best_id = default_floor_id
						var counts = {}
						var max_count = 0
						
						for f_id in neighbor_floors:
							counts[f_id] = counts.get(f_id, 0) + 1
							if counts[f_id] > max_count:
								max_count = counts[f_id]
								best_id = f_id
								
						# Dilate/Birth using the dominant semantic type!
						new_cells[idx] = best_id
						
		# Apply the simulated step back to the master grid
		grid.cells = new_cells
