class_name RasterExporter
extends RefCounted

static func export_level(realizer: GraphRealizer, export_path: String, include_metrics: bool = false, active_mapping: Dictionary = {}) -> int:
	var grid = realizer.grid
	if grid == null: 
		push_error("RasterExporter: No GridData provided.")
		return ERR_INVALID_DATA
		
	var data = {
		"meta": {
			"exporter_version": "1.0",
			"grid_width": grid.width,
			"grid_height": grid.height,
			"timestamp": Time.get_datetime_string_from_system()
		},
		"definitions": {},
		"layers": []
	}
	
	# --- Format the dynamic Tile Mapping for JSON (String Keys) ---
	var str_mapping = {}
	
	# [FIX] Loop directly over active_mapping again!
	for k in active_mapping:
		var visual_data = active_mapping[k].duplicate(true)
		
		# Safely convert Vector2i to array for JSON
		if visual_data.has("atlas_coords"):
			var vec = visual_data["atlas_coords"]
			if typeof(vec) == TYPE_VECTOR2I:
				visual_data["atlas_coords"] = [vec.x, vec.y]
				
		str_mapping[str(k)] = visual_data
		
	data["definitions"]["tile_mapping"] = str_mapping
	
	# ==========================================
	# 1. BUNDLE DEFINITIONS
	# ==========================================
	# We pull directly from ConfigManager so the importing engine 
	# knows what the UUIDs mean!
	data["definitions"]["structures"] = ConfigManager.load_structures()
	data["definitions"]["entities"] = ConfigManager.load_scatter_sets() 
	# (Or load_spawn_decks(), depending on where your final entities live)
	
	var biomes = {}
	ConfigManager.load_semantic_data(biomes, {})
	data["definitions"]["biomes"] = biomes
	
	# ==========================================
	# 2. BUNDLE LAYERS
	# ==========================================
	
	# Layer 0: Base Terrain (IntGrid)
	# We copy the packed array directly into a standard array for JSON
	var terrain_data = []
	terrain_data.append_array(grid.cells)
	data["layers"].append({
		"name": "Terrain",
		"type": "IntGrid",
		"data": terrain_data
	})
	
	# Layer 1: Tile Overrides / WFC Variants (Optional)
	if not grid.cell_atlas_overrides.is_empty():
		var atlas_data = []
		atlas_data.resize(grid.width * grid.height)
		atlas_data.fill([-1, -1]) # Default empty
		for pos in grid.cell_atlas_overrides:
			var idx = grid._get_index(pos.x, pos.y)
			var vec = grid.cell_atlas_overrides[pos]
			atlas_data[idx] = [vec.x, vec.y]
			
		data["layers"].append({
			"name": "Tile_Overrides",
			"type": "AtlasGrid",
			"data": atlas_data
		})
		
	# Layer 2 & 3: Instances & Collision
	var instance_list = []
	var collision_data = []
	collision_data.resize(grid.width * grid.height)
	collision_data.fill(0)
	
	# --- 1. Stamp Standard Terrain Walls into the Collision Mask ---
	for idx in range(grid.cells.size()):
		var t_id = grid.cells[idx]
		if t_id > 0:
			var tile_data = grid.palette.get_data(t_id)
			# If the tile is explicitly not walkable (a Wall), mark it as a collision!
			if not tile_data.get("walkable", true):
				collision_data[idx] = 1
	
	# --- 2. Stamp Solid Structures into the Collision Mask ---
	for pos in grid.entities:
		var ent = grid.entities[pos]
		var ent_copy = ent.duplicate(true) 
		ent_copy["x"] = pos.x
		ent_copy["y"] = pos.y
		instance_list.append(ent_copy)
		
		# [FIX] Read the Vector2i/String footprint safely
		if ent.get("type", "") == "structure" and ent.get("is_solid", false):
			if ent.has("footprint_world"):
				for pt in ent["footprint_world"]:
					var cx = 0
					var cy = 0
					
					# Handle both live Vector2i and JSON-parsed String formats gracefully
					if typeof(pt) == TYPE_VECTOR2I or typeof(pt) == TYPE_VECTOR2:
						cx = int(pt.x)
						cy = int(pt.y)
					elif typeof(pt) == TYPE_STRING:
						var clean = pt.replace("(", "").replace(")", "")
						var parts = clean.split(",")
						if parts.size() == 2:
							cx = parts[0].to_int()
							cy = parts[1].to_int()
					
					if grid.in_bounds(cx, cy):
						collision_data[grid._get_index(cx, cy)] = 1
			else:
				var w = ent.get("width", 1)
				var h = ent.get("height", 1)
				for cy in range(pos.y, pos.y + h):
					for cx in range(pos.x, pos.x + w):
						if grid.in_bounds(cx, cy):
							collision_data[grid._get_index(cx, cy)] = 1
	
						
	data["layers"].append({
		"name": "Instances",
		"type": "InstanceList",
		"instances": instance_list
	})
	
	data["layers"].append({
		"name": "Collision_Mask",
		"type": "IntGrid",
		"data": collision_data
	})

	# ==========================================
	# 3. OPTIONAL METRICS
	# ==========================================
	if include_metrics and realizer.has_meta("progression_report"):
		var report = realizer.get_meta("progression_report")
		
		# Clean up the report for JSON (Removing formatting tags if necessary, 
		# or just dumping the raw dictionaries)
		data["metrics"] = {
			"diagnostics": report.get("meta", {}),
			"validation": report.get("analytics", {})
		}

	# ==========================================
	# 4. WRITE TO DISK
	# ==========================================
	var json_str = JSON.stringify(data, "\t")
	var file = FileAccess.open(export_path, FileAccess.WRITE)
	if file:
		file.store_string(json_str)
		file.close()
		return OK
	else:
		push_error("LevelExporter: Failed to write to " + export_path)
		return ERR_FILE_CANT_WRITE
