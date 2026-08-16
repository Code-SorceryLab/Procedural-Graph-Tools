class_name CellularSmoother
extends RefCounted

static func smooth(realizer: GraphRealizer, default_floor_id: int, params: Dictionary) -> void:
	var grid = realizer.grid
	var biomes = params.get("biomes", {})
	
	# 1. Build a fast lookup table for CA rules per Semantic Floor ID
	var rule_map = {}
	var max_global_iterations = params.get("ca_iterations", 0)
	
	# Base rule (Default Floor)
	rule_map[default_floor_id] = {
		"iter": max_global_iterations,
		"survive": params.get("ca_survive_min", 4),
		"birth": params.get("ca_birth_min", 5)
	}
	
	# Biome rules (Semantic Floors)
	for type_key in realizer.semantic_floor_ids:
		var f_id = realizer.semantic_floor_ids[type_key]
		var b = biomes.get(type_key, {}) # Safely get the biome dict if it passed the firewall
		
		# Because of the firewall, if "ca_iterations" isn't in 'b', 
		# we know the user disabled the Routing override for this biome!
		var b_iter = b.get("ca_iterations", params.get("ca_iterations", 0))
		
		rule_map[f_id] = {
			"iter": b_iter,
			"survive": b.get("ca_survive_min", params.get("ca_survive_min", 4)),
			"birth": b.get("ca_birth_min", params.get("ca_birth_min", 5))
		}
		
		# Elevate the global loop count if this biome needs more passes!
		if b_iter > max_global_iterations:
			max_global_iterations = b_iter
			
	if max_global_iterations <= 0: return
	
	# Pre-cache all valid floor IDs (anything marked as walkable)
	var valid_floors = {}
	for id in grid.palette._definitions:
		if grid.palette.get_data(id).get("walkable", false):
			valid_floors[id] = true
	
	# 2. Run the Masked CA Loop
	for i in range(max_global_iterations):
		var new_cells = grid.cells.duplicate()
		
		for y in range(grid.height):
			for x in range(grid.width):
				var pos = Vector2i(x, y)
				
				# --- IMMUNITY CHECK ---
				if realizer.critical_path_cells.has(pos):
					continue
					
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
				
				if was_floor:
					# --- EROSION ---
					var rules = rule_map.get(current_id, rule_map[default_floor_id])
					
					if i < rules["iter"]:
						if neighbors < rules["survive"]:
							new_cells[idx] = TilePalette.VOID_ID
				else:
					# --- BIRTH ---
					if neighbors > 0:
						var best_id = default_floor_id
						var counts = {}
						var max_count = 0
						
						for f_id in neighbor_floors:
							counts[f_id] = counts.get(f_id, 0) + 1
							if counts[f_id] > max_count:
								max_count = counts[f_id]
								best_id = f_id
								
						var rules = rule_map.get(best_id, rule_map[default_floor_id])
						
						if i < rules["iter"]:
							if neighbors >= rules["birth"]:
								new_cells[idx] = best_id # Inherit semantic type!
								
		# Apply the simulated step back to the master grid
		grid.cells = new_cells
