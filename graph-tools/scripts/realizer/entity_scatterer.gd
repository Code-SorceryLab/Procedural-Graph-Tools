class_name EntityScatterer
extends RefCounted

static func scatter(graph: Graph, realizer: GraphRealizer, params: Dictionary) -> void:
	var grid = realizer.grid
	var biome_overrides = params.get("biomes", {})
	
	# Unique seed branch specifically for scattering
	var master_seed = SeedUtils.hash_seed(str(params.get("realizer_seed", "default")) + "_scatter")
	var rng = RandomNumberGenerator.new()

	# Pre-cache walkables so we don't spawn on walls or in the void
	var valid_floors = {}
	for id in grid.palette._definitions:
		if grid.palette.get_data(id).get("walkable", false):
			valid_floors[id] = true

	for node_id in graph.nodes:
		var node = graph.nodes[node_id]
		var center = node.custom_data.get("_grid_center", Vector2i.ZERO)
		if center == Vector2i.ZERO: continue

		# --- BIOME RESOLUTION ---
		var effective_params = params
		if biome_overrides.has(node.type) and biome_overrides[node.type].get("override_enabled", false):
			effective_params = params.duplicate()
			effective_params.merge(biome_overrides[node.type], true)

		var density = float(effective_params.get("scatter_density", 0.0))
		if density <= 0.001: continue

		# Calculate a bounding box that safely encompasses the room's footprint
		var max_r = int(effective_params.get("room_radius_max", 4)) + 2 
		if node.custom_data.has("room_radius"):
			max_r = int(node.custom_data["room_radius"]) + 2

		# Deterministic seed per room!
		rng.seed = SeedUtils.hash_seed(str(master_seed) + "_" + str(node_id))

		var rect = Rect2i(center.x - max_r, center.y - max_r, max_r * 2 + 1, max_r * 2 + 1)
		
		# --- SCATTER LOOP ---
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var pos = Vector2i(x, y)
				
				if not grid.in_bounds_vec(pos): continue
				
				# 1. CRITICAL PATH CHECK: Do not block doorways or hallways!
				if realizer.critical_path_cells.has(pos): continue
				
				# 2. TERRAIN CHECK: Must be on a walkable floor tile
				var cell_id = grid.get_cell(x, y)
				if not valid_floors.has(cell_id): continue

				# 3. ROLL THE DICE
				if rng.randf() < density:
					if not grid.entities.has(pos):
						grid.entities[pos] = {
							"type": "generic_entity",
							"source_node": node_id
						}
