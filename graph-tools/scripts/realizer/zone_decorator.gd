class_name ZoneDecorator
extends RefCounted

static func decorate(realizer: GraphRealizer, params: Dictionary) -> void:
	var grid = realizer.grid
	var interactions = ConfigManager.load_biome_interactions()
	
	if not interactions.has("global_default"):
		interactions["global_default"] = { "path_style": 0, "seam_style": 1 }

	var cells_to_void = {}
	var entities_to_spawn = {} 

	for y in range(grid.height):
		for x in range(grid.width):
			var p1 = Vector2i(x, y)
			var id1 = grid.get_cell(p1.x, p1.y)
			var biome1 = realizer.floor_to_semantic.get(id1, "")

			if biome1 == "": continue # Only evaluate semantic floors

			# Check Right and Down to find unique tile boundaries
			var neighbors = [Vector2i(x + 1, y), Vector2i(x, y + 1)]

			for p2 in neighbors:
				if not grid.in_bounds_vec(p2): continue

				var id2 = grid.get_cell(p2.x, p2.y)
				var biome2 = realizer.floor_to_semantic.get(id2, "")

				if biome2 == "": continue
				if biome1 == biome2: continue # Same biome, no seam

				# --- 1. RESOLVE RULE ---
				var arr = [biome1, biome2]
				arr.sort()
				var pair_key = arr[0] + "|" + arr[1]
				var rule = interactions.get(pair_key, interactions["global_default"])

				var is_path_p1 = realizer.critical_path_cells.has(p1)
				var is_path_p2 = realizer.critical_path_cells.has(p2)

				# --- 2. PATH CROSSING ---
				if is_path_p1 and is_path_p2:
					var p_style = rule.get("path_style", 0)
					if p_style == 1: # Door + Walls
						if not entities_to_spawn.has(p1):
							entities_to_spawn[p1] = {"type": "door"}
					elif p_style == 2: # Decorated
						if not entities_to_spawn.has(p1):
							entities_to_spawn[p1] = {"type": "fringe"}
							
				# --- 3. GENERAL BOUNDARY ---
				else:
					var s_style = rule.get("seam_style", 1)
					if s_style == 1: # Walled
						# Protect paths running parallel to the border! 
						# We only turn the non-path tile into a wall.
						if not is_path_p1:
							cells_to_void[p1] = true
						elif not is_path_p2:
							cells_to_void[p2] = true
					elif s_style == 2: # Decorated
						var target_p = p1 if not is_path_p1 else p2
						if not entities_to_spawn.has(target_p):
							entities_to_spawn[target_p] = {"type": "fringe"}

	# --- 4. APPLY TO GRID ---
	for pos in cells_to_void:
		grid.set_cell(pos.x, pos.y, TilePalette.VOID_ID)
		# Ensure it's removed from collision masks so it physically acts like a void
		realizer.critical_path_cells.erase(pos)

	for pos in entities_to_spawn:
		grid.entities[pos] = entities_to_spawn[pos]
