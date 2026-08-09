class_name TileMapAdapter
extends RefCounted

static func apply_to_layer(grid: GridData, layer: TileMapLayer, tile_mapping: Dictionary) -> void:
	layer.clear()
	
	# 1. Group coordinates by their internal Grid ID
	var cells_by_id: Dictionary = {}
	
	for y in range(grid.height):
		for x in range(grid.width):
			var cell_id = grid.get_cell(x, y)
			if cell_id == TilePalette.VOID_ID:
				continue
				
			if not cells_by_id.has(cell_id):
				cells_by_id[cell_id] = []
			cells_by_id[cell_id].append(Vector2i(x, y))
			
	# 2. Paint the Grid, handling both standard tiles and Terrains!
	for cell_id in cells_by_id:
		var coords: Array = cells_by_id[cell_id]
		
		# Typecast safely for Godot's C++ API
		var typed_coords: Array[Vector2i] = []
		typed_coords.assign(coords)
		
		if tile_mapping.has(cell_id):
			var mapping = tile_mapping[cell_id]
			
			if mapping.get("is_terrain", false):
				# --- AUTOTILING MODE ---
				var t_set = mapping["terrain_set"]
				var t_id = mapping["terrain"]
				# Let Godot calculate all the corners and borders!
				layer.set_cells_terrain_connect(typed_coords, t_set, t_id, true)
			else:
				# --- STATIC TILE MODE ---
				var source_id = mapping.get("source_id", 0)
				var atlas_coords = mapping.get("atlas_coords", Vector2i.ZERO)
				var alt_tile = mapping.get("alternative_tile", 0) # [NEW] Extract the alternative tile ID
				
				for pos in typed_coords:
					# [FIXED] Pass the alt_tile as the 4th argument!
					layer.set_cell(pos, source_id, atlas_coords, alt_tile) 
		else:
			push_warning("TileMapAdapter: Missing visual mapping for Tile ID %d" % cell_id)
