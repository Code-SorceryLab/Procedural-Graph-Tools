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
				var alt_tile = mapping.get("alternative_tile", 0) 
				
				for pos in typed_coords:
					layer.set_cell(pos, source_id, atlas_coords, alt_tile) 
		else:
			push_warning("TileMapAdapter: Missing visual mapping for Tile ID %d" % cell_id)

	# --- 3. FORCE EXACT ATLAS OVERRIDES ---
	for pos in grid.cell_atlas_overrides:
		var atlas = grid.cell_atlas_overrides[pos]
		var cell_id = grid.get_cell(pos.x, pos.y)
		
		if tile_mapping.has(cell_id):
			var mapping = tile_mapping[cell_id]
			var source_id = mapping.get("source_id", 0)
			var alt_tile = mapping.get("alternative_tile", 0)
			
			var tile_set = layer.tile_set
			var source = tile_set.get_source(source_id) as TileSetAtlasSource
			
			# --- JUST-IN-TIME (JIT) ALTERNATIVE GENERATION ---
			if alt_tile != 0 and source != null and source.has_tile(atlas):
				if not source.has_alternative_tile(atlas, alt_tile):
					# 1. Create the variant in memory!
					source.create_alternative_tile(atlas, alt_tile)
					
					# 2. Fetch the target color from the biome's generic floor tile
					# (Assuming the generic floor has alternative_tile = 0 as its base, 
					# and the biome's requested tint is what we want).
					var generic_floor_coord = mapping.get("atlas_coords", Vector2i.ZERO)
					var target_color = Color.WHITE
					
					# Safely extract the modulate color from the generic floor's TileData
					if source.has_alternative_tile(generic_floor_coord, alt_tile):
						var reference_data = source.get_tile_data(generic_floor_coord, alt_tile)
						if reference_data:
							target_color = reference_data.modulate
					
					# 3. Apply the tint to the custom sprite variant's TileData!
					var new_tile_data = source.get_tile_data(atlas, alt_tile)
					if new_tile_data:
						new_tile_data.modulate = target_color
			
			# 4. Stamp the fully tinted sprite onto the map
			layer.set_cell(pos, source_id, atlas, alt_tile)
