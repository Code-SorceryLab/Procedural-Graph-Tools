class_name TexturalWFCPass
extends RefCounted

static func apply(realizer: GraphRealizer, params: Dictionary, emit: Callable = Callable()) -> void:
	var grid = realizer.grid
	var biomes = params.get("biomes", {})
	var patterns = params.get("tile_wfc_patterns", {})
	
	if patterns.is_empty(): return
	
	# --- DETERMINISTIC SEED SETUP ---
	var master_seed = params.get("realizer_seed", "default")
	var rng = RandomNumberGenerator.new()
	rng.seed = SeedUtils.hash_seed(str(master_seed) + "_textural_wfc")
	
	var wfc_tasks = {} 
	var c_room_cells = realizer.get_meta("custom_room_cells") if realizer.has_meta("custom_room_cells") else {}
	
	# 1. Group all valid floor cells by their Biome's WFC Palette
	for y in range(grid.height):
		for x in range(grid.width):
			var pos = Vector2i(x, y)
			var cell_id = grid.get_cell(x, y)
			if cell_id == TilePalette.VOID_ID: continue
			
			var cat_key = ""
			if realizer.floor_to_semantic.has(cell_id):
				cat_key = realizer.floor_to_semantic[cell_id]
			else: continue 
			
			var b_data = biomes.get(cat_key, {})
			var palette_ref = b_data.get("wfc_palette_ref", "")
			
			if palette_ref != "" and patterns.has(palette_ref):
				if not wfc_tasks.has(palette_ref): wfc_tasks[palette_ref] = []
				wfc_tasks[palette_ref].append(pos)
				
	# --- Fetch contradiction metric ---
	var metric_wfc_contradictions = realizer.get_meta("metric_wfc_contradictions") if realizer.has_meta("metric_wfc_contradictions") else 0
	
	# 2. Run the 1x1 Overlapping Solver for each territory!
	for palette_ref in wfc_tasks:
		var t_total_start = Time.get_ticks_usec()
		var target_cells = wfc_tasks[palette_ref]
		var p_data = patterns[palette_ref]
		var n_size = p_data.get("n_size", 3)

		var valid_targets = {}
		for pos in target_cells: valid_targets[pos] = true

		# --- PREPARE VARIABLES ---
		var is_seamless = p_data.get("seamless", false)
		var base_fill_mode = p_data.get("base_fill", 1)
		var wall_aware = p_data.get("wall_aware", true)
		var allow_rots = p_data.get("rotations", false)
		var allow_refs = p_data.get("reflections", false)

		var t_extract_start = Time.get_ticks_usec()
		var modules = WFCPatternExtractor.extract(
			p_data.get("sample_grid", {}),
			p_data.get("width", 10), p_data.get("height", 10),
			n_size, is_seamless, base_fill_mode, allow_rots, allow_refs
		)
		var t_extract_end = Time.get_ticks_usec()
		print("[WFC Timer] Palette %s | Extract: %d us" % [palette_ref, t_extract_end - t_extract_start])

		

		# --- FIXED WALL CONSTRAINTS ---
		var expanded_sockets = {}
		var fixed_pixels = {}

		for pos in target_cells:
			for dy in range(-n_size + 1, 1):
				for dx in range(-n_size + 1, 1):
					expanded_sockets[pos + Vector2i(dx, dy)] = true

		if wall_aware:
			for s_pos in expanded_sockets:
				for dy in range(n_size):
					for dx in range(n_size):
						var world_pt = s_pos + Vector2i(dx, dy)
						if not valid_targets.has(world_pt):
							fixed_pixels[world_pt] = WFCPatternExtractor.CELL_BOUNDARY

		# --- DEBUG: Coverage before solve ---
		print("[WFC Debug] Palette %s | Interior cells: %d | Expanded sockets: %d" % [
			palette_ref, target_cells.size(), expanded_sockets.size()
		])

		var t_solve_start = Time.get_ticks_usec()
		var payload = WFCSolver.resolve(expanded_sockets.keys(), rng, modules, 1, fixed_pixels)
		var t_solve_end = Time.get_ticks_usec()
		print("[WFC Timer] Palette %s | Solve: %d us" % [palette_ref, t_solve_end - t_solve_start])
		
		
		# --- DEBUG: Coverage after solve ---
		var generated_exact = 0
		if payload.has("exact_floors"):
			generated_exact = payload["exact_floors"].size()
		print("[WFC Debug] Palette %s | Generated exact cells: %d" % [palette_ref, generated_exact])
		
		# 3. Stamp the resulting exact atlas tiles onto the floor!
		var stamped_cells = {}
		if payload.has("exact_floors"):
			for pt in payload["exact_floors"]:
				if not valid_targets.has(pt):
					continue
				if c_room_cells.has(pt) and grid.cell_atlas_overrides.has(pt):
					continue

				var atlas_coord = payload["exact_floors"][pt]
				if atlas_coord.x < 0 or atlas_coord.y < 0:
					continue

				grid.set_cell_atlas(pt.x, pt.y, grid.get_cell(pt.x, pt.y), atlas_coord)
				stamped_cells[pt] = true

		# Fill any remaining valid interior cells with the fallback tile if needed
		if stamped_cells.size() < target_cells.size():
			if p_data.get("fallback_mode", 0) == 1:
				var f_atlas = p_data.get("fallback_atlas", Vector2i.ZERO)
				for pt in target_cells:
					if stamped_cells.has(pt):
						continue
					if c_room_cells.has(pt) and grid.cell_atlas_overrides.has(pt):
						continue
					grid.set_cell_atlas(pt.x, pt.y, grid.get_cell(pt.x, pt.y), f_atlas)
			# Mode 0: leave base floor as is
			var fallback_used = 0
			for pt in target_cells:
				if not stamped_cells.has(pt) and not (c_room_cells.has(pt) and grid.cell_atlas_overrides.has(pt)):
					fallback_used += 1
			print("[WFC Debug] Palette %s | Fallback cells: %d" % [palette_ref, fallback_used])
					
		print("[WFC Timer] Palette %s | Total: %d us" % [palette_ref, Time.get_ticks_usec() - t_total_start])
		if emit.is_valid():
		# Snapshot the current state under a region-specific name
			emit.call("Textural WFC: " + palette_ref)
	
	realizer.set_meta("metric_wfc_contradictions", metric_wfc_contradictions)
