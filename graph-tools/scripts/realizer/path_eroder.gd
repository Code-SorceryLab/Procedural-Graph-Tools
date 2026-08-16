class_name PathEroder
extends RefCounted

static func erode(realizer: GraphRealizer, params: Dictionary) -> void:
	var grid = realizer.grid
	var biome_overrides = params.get("biomes", {})
	
	var noise = FastNoiseLite.new()
	noise.seed = SeedUtils.hash_seed(str(params.get("realizer_seed", "default")) + "_erosion")
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	
	var cells_to_destroy = []
	
	for cell in realizer.critical_path_cells:
		# 1. Protect the 1-tile A* core path (Guarantees the map never breaks)
		if realizer.core_path_cells.has(cell): continue
		# 2. Protect the room interiors
		if realizer.room_cells.has(cell): continue
		
		var floor_id = grid.get_cell(cell.x, cell.y)
		var cat_key = realizer.floor_to_semantic.get(floor_id, "")
		
		# --- BIOME RESOLUTION (Firewall Protected) ---
		var effective_params = params.duplicate()
		if cat_key != "" and biome_overrides.has(cat_key):
			effective_params.merge(biome_overrides[cat_key], true)
			
		var erosion_chance = float(effective_params.get("corridor_erosion", 0.0))
		if erosion_chance <= 0.0: continue
		
		noise.frequency = float(effective_params.get("corridor_erosion_scale", 0.1))
		
		# FastNoise returns -1.0 to 1.0. We map it to 0.0 to 1.0
		var noise_val = (noise.get_noise_2d(cell.x, cell.y) + 1.0) / 2.0
		
		# If the noise value falls below the threshold, it degrades into a wall!
		if noise_val < erosion_chance:
			cells_to_destroy.append(cell)
			
	# Apply destruction
	for cell in cells_to_destroy:
		grid.set_cell(cell.x, cell.y, TilePalette.VOID_ID)
		realizer.critical_path_cells.erase(cell) # Remove from collision mask so entities don't float
