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

	# ==========================================================================
	# GLOBAL REACHABILITY MAP (Flood Fill)
	# ==========================================================================
	# We flood-fill exactly once from the critical paths to find all unblocked tiles.
	# This completely prevents entities from spawning inside blocked-off rings of structures.
	var reachable_cells = {}
	var queue: Array[Vector2i] = []
	
	# 1. Seed the queue with the guaranteed safe zones (Critical Paths)
	for cp in realizer.critical_path_cells:
		queue.append(cp)
		reachable_cells[cp] = true
		
	# (Failsafe) Also seed room centers in case a room has no paths connected to it
	for node_id in graph.nodes:
		var center = graph.nodes[node_id].custom_data.get("_grid_center", Vector2i.ZERO)
		if center != Vector2i.ZERO and not realizer.reserved_cells.has(center) and valid_floors.has(grid.get_cell(center.x, center.y)):
			if not reachable_cells.has(center):
				queue.append(center)
				reachable_cells[center] = true
				
	# 2. Expand outwards into any valid floor that isn't blocked by a structure
	var head = 0
	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	
	while head < queue.size():
		var curr = queue[head]
		head += 1
		
		for d in dirs:
			var neighbor = curr + d
			if not reachable_cells.has(neighbor) and grid.in_bounds_vec(neighbor):
				if not realizer.reserved_cells.has(neighbor):
					if valid_floors.has(grid.get_cell(neighbor.x, neighbor.y)):
						reachable_cells[neighbor] = true
						queue.append(neighbor)
	# ==========================================================================

	for node_id in graph.nodes:
		var node = graph.nodes[node_id]
		var center = node.custom_data.get("_grid_center", Vector2i.ZERO)
		if center == Vector2i.ZERO: continue
		
		# --- [FIXED] ROBUST BIOME CONTAINMENT ---
		var target_floor_id = grid.get_cell(center.x, center.y)
		if not valid_floors.has(target_floor_id):
			target_floor_id = realizer.floor_id 

		# --- BIOME RESOLUTION ---
		var effective_params = params
		if biome_overrides.has(node.type) and biome_overrides[node.type].get("override_enabled", false):
			effective_params = params.duplicate()
			effective_params.merge(biome_overrides[node.type], true)

		var density = float(effective_params.get("scatter_density", 0.0))
		if density <= 0.001: continue
		
		# [NEW] Distance Field Constraints
		var min_dist = int(effective_params.get("scatter_min_dist", 0))
		var max_dist = int(effective_params.get("scatter_max_dist", 99))

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
				
				# 1. CRITICAL PATH & STRUCTURE CHECK: Do not block doorways or large structures!
				if realizer.critical_path_cells.has(pos) or realizer.reserved_cells.has(pos): 
					continue
					
				# --- [NEW] REACHABILITY CHECK ---
				# If the global BFS didn't reach this tile, it is trapped behind structures.
				if not reachable_cells.has(pos):
					continue
				
				# [FIXED] 2. TERRAIN CHECK: Must strictly be THIS biome's floor tile!
				var cell_id = grid.get_cell(x, y)
				if cell_id != target_floor_id: continue
				
				# 3. DISTANCE FIELD CHECK
				var tile_dist = realizer.distance_field.get(pos, 0)
				if tile_dist < min_dist or tile_dist > max_dist:
					continue

				# 4. ROLL THE DICE
				if rng.randf() < density:
					if not grid.entities.has(pos):
						grid.entities[pos] = {
							"type": "generic_entity",
							"source_node": node_id
						}
