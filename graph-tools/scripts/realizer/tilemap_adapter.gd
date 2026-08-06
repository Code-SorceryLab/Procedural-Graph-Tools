class_name TileMapAdapter
extends RefCounted

static func apply_to_layer(grid: GridData, layer: TileMapLayer, tile_mapping: Dictionary) -> void:
	layer.clear()
	
	for y in range(grid.height):
		for x in range(grid.width):
			var cell_id = grid.get_cell(x, y)
			
			if cell_id == TilePalette.VOID_ID:
				continue
				
			if tile_mapping.has(cell_id):
				var mapping = tile_mapping[cell_id]
				var source_id = int(mapping.get("source_id", 0))
				var raw_atlas = mapping.get("atlas_coords", Vector2i.ZERO)
				
				# [CRITICAL FIX] Guarantee strict Vector2i so C++ doesn't silently reject it
				var atlas_coords = Vector2i(int(raw_atlas.x), int(raw_atlas.y))
				
				layer.set_cell(Vector2i(x, y), source_id, atlas_coords)
			else:
				push_warning("TileMapAdapter: Missing visual mapping for Tile ID %d" % cell_id)
