class_name EntityScatterer
extends RefCounted

static func scatter(graph: Graph, realizer: GraphRealizer, params: Dictionary) -> void:
	var grid = realizer.grid
	var biome_overrides = params.get("biomes", {})
	
	var master_seed = SeedUtils.hash_seed(str(params.get("realizer_seed", "default")) + "_scatter")
	var rng = RandomNumberGenerator.new()

	var valid_floors = {}
	for id in grid.palette._definitions:
		if grid.palette.get_data(id).get("walkable", false):
			valid_floors[id] = true

	# --- (KEEP THE ENTIRE REACHABLE CELLS FLOOD-FILL BLOCK EXACTLY AS IT IS) ---
	var reachable_cells = {}
	var queue: Array[Vector2i] = []
	for cp in realizer.critical_path_cells:
		queue.append(cp); reachable_cells[cp] = true
	for node_id in graph.nodes:
		var center = graph.nodes[node_id].custom_data.get("_grid_center", Vector2i.ZERO)
		if center != Vector2i.ZERO and not realizer.reserved_cells.has(center) and valid_floors.has(grid.get_cell(center.x, center.y)):
			if not reachable_cells.has(center):
				queue.append(center); reachable_cells[center] = true
	var head = 0
	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var curr = queue[head]; head += 1
		for d in dirs:
			var neighbor = curr + d
			if not reachable_cells.has(neighbor) and grid.in_bounds_vec(neighbor):
				if not realizer.reserved_cells.has(neighbor) and valid_floors.has(grid.get_cell(neighbor.x, neighbor.y)):
					reachable_cells[neighbor] = true; queue.append(neighbor)
	# -------------------------------------------------------------------------

	for node_id in graph.nodes:
		var node = graph.nodes[node_id]
		var center = node.custom_data.get("_grid_center", Vector2i.ZERO)
		if center == Vector2i.ZERO: continue
		
		var target_floor_id = grid.get_cell(center.x, center.y)
		if not valid_floors.has(target_floor_id):
			target_floor_id = realizer.floor_id 

		var effective_params = params
		if biome_overrides.has(node.type) and biome_overrides[node.type].get("override_enabled", false):
			effective_params = params.duplicate()
			effective_params.merge(biome_overrides[node.type], true)

		var density = float(effective_params.get("scatter_density", 0.0))
		if density <= 0.001: continue
		
		var min_dist = int(effective_params.get("scatter_min_dist", 0))
		var max_dist = int(effective_params.get("scatter_max_dist", 99))
		var sym_mode = int(effective_params.get("scatter_symmetry", 0)) # <--- [NEW]
		
		var max_r = int(effective_params.get("room_radius_max", 4)) + 2 
		if node.custom_data.has("room_radius"): max_r = int(node.custom_data["room_radius"]) + 2

		rng.seed = SeedUtils.hash_seed(str(master_seed) + "_" + str(node_id))
		var rect = Rect2i(center.x - max_r, center.y - max_r, max_r * 2 + 1, max_r * 2 + 1)
		
		var processed_cells = {}
		
		# --- SCATTER LOOP ---
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var pos = Vector2i(x, y)
				if processed_cells.has(pos): continue # Skip if already processed via symmetry
				
				# Generate Symmetry Group
				var group = [pos]
				var dx = pos.x - center.x
				var dy = pos.y - center.y
				if sym_mode == 1: group.append(Vector2i(center.x - dx, pos.y))
				elif sym_mode == 2: group.append(Vector2i(pos.x, center.y - dy))
				elif sym_mode == 3: group.append(Vector2i(center.x - dx, center.y - dy))
				elif sym_mode == 4:
					group.append(Vector2i(center.x - dx, pos.y))
					group.append(Vector2i(pos.x, center.y - dy))
					group.append(Vector2i(center.x - dx, center.y - dy))
					
				# Mark group as processed to avoid redundant rolls
				for pt in group: processed_cells[pt] = true
				
				# Strict Validation: The entire group MUST be valid
				var group_is_valid = true
				for pt in group:
					if not grid.in_bounds_vec(pt) or grid.entities.has(pt):
						group_is_valid = false; break
					if realizer.critical_path_cells.has(pt) or realizer.reserved_cells.has(pt) or not reachable_cells.has(pt):
						group_is_valid = false; break
					if grid.get_cell(pt.x, pt.y) != target_floor_id:
						group_is_valid = false; break
					var tile_dist = realizer.distance_field.get(pt, 0)
					if tile_dist < min_dist or tile_dist > max_dist:
						group_is_valid = false; break
						
				if not group_is_valid: continue

				# Roll once for the whole group!
				if rng.randf() < density:
					for pt in group:
						grid.entities[pt] = {
							"type": "generic_entity",
							"source_node": node_id
						}
