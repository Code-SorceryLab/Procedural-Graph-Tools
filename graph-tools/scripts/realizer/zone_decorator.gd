class_name ZoneDecorator
extends RefCounted

static func decorate(realizer: GraphRealizer, params: Dictionary) -> void:
	var grid = realizer.grid
	var interactions = ConfigManager.load_biome_interactions()
	
	if not interactions.has("global_default"):
		interactions["global_default"] = { "path_style": 0, "seam_style": 1 }

	var cells_to_void = {}
	var entities_to_spawn = {} 

	# Load the custom room firewall
	var c_rooms = realizer.get_meta("custom_room_cells") if realizer.has_meta("custom_room_cells") else {}

	for y in range(grid.height):
		for x in range(grid.width):
			var p1 = Vector2i(x, y)
			var id1 = grid.get_cell(p1.x, p1.y)
			
			if id1 == TilePalette.VOID_ID: continue
			# Skip walls entirely!
			if not grid.palette.get_data(id1).get("walkable", false): continue
			
			var biome1 = realizer.floor_to_semantic.get(id1, "default")
			var is_path_p1 = realizer.critical_path_cells.has(p1)
			
			# [FIXED] Use an empty string "" instead of -1 for the default ID!
			var cr1_id = c_rooms.get(p1, "")
			
			var wants_to_void = false
			var wants_door = false
			var wants_fringe = false

			var neighbors = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
			
			for dir in neighbors:
				var p2 = p1 + dir
				if not grid.in_bounds_vec(p2): continue
				
				var id2 = grid.get_cell(p2.x, p2.y)
				if id2 == TilePalette.VOID_ID: continue
				# Skip walls entirely
				if not grid.palette.get_data(id2).get("walkable", false): continue
				
				# [FIXED] Use an empty string ""
				var cr2_id = c_rooms.get(p2, "")
				
				# --- IMMUNITY 1: Same Custom Room ---
				if cr1_id != "" and cr1_id == cr2_id: continue
				
				var biome2 = realizer.floor_to_semantic.get(id2, "default")
				if biome1 == biome2: continue # Same biome, no seam
				
				var arr = [biome1, biome2]
				arr.sort()
				var pair_key = arr[0] + "|" + arr[1]
				var rule = interactions.get(pair_key, interactions["global_default"])
				
				var is_path_p2 = realizer.critical_path_cells.has(p2)
				
				# --- 2. PATH CROSSING ---
				if is_path_p1 or is_path_p2:
					var p_style = rule.get("path_style", 0)
					if p_style == 1: # Door + Walls
						if is_path_p1 and is_path_p2:
							wants_door = true
						elif not is_path_p1 and is_path_p2:
							# IMMUNITY 2: NEVER void a cell inside a Custom Room!
							if cr1_id == "":
								wants_to_void = true
								
					elif p_style == 2: # Decorated
						if is_path_p1 and is_path_p2:
							wants_fringe = true
							
				# --- 3. GENERAL BOUNDARY ---
				else:
					var s_style = rule.get("seam_style", 1)
					if s_style == 1: # Walled
						# IMMUNITY 3: NEVER void a cell inside a Custom Room!
						if cr1_id == "":
							wants_to_void = true
					elif s_style == 2: # Decorated
						wants_fringe = true
			
			# --- 4. APPLY FLAGS TO CURRENT TILE ---
			if wants_to_void and not is_path_p1:
				cells_to_void[p1] = true
			elif wants_door and is_path_p1:
				entities_to_spawn[p1] = {"type": "door"}
			elif wants_fringe and not wants_to_void:
				entities_to_spawn[p1] = {"type": "fringe"}

	# --- 5. MODIFY THE GRID ---
	for pos in cells_to_void:
		grid.set_cell(pos.x, pos.y, TilePalette.VOID_ID)
		realizer.critical_path_cells.erase(pos)

	for pos in entities_to_spawn:
		if not cells_to_void.has(pos):
			grid.entities[pos] = entities_to_spawn[pos]
