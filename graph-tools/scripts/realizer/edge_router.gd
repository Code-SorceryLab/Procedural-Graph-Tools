class_name EdgeRouter
extends RefCounted

static func route(graph: Graph, realizer: GraphRealizer, default_floor_id: int, params: Dictionary) -> void:
	var grid = realizer.grid
	var biome_overrides = params.get("biomes", {})
	
	var astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, grid.width, grid.height)
	astar.cell_size = Vector2i(1, 1)
	astar.update()
	
	# Pre-cache all valid walkable floor IDs from the semantic palette
	var valid_floors = {}
	for id in grid.palette._definitions:
		if grid.palette.get_data(id).get("walkable", false):
			valid_floors[id] = true
	
	# Set Weights using the Semantic valid_floors check!
	for y in range(grid.height):
		for x in range(grid.width):
			var pos = Vector2i(x, y)
			if valid_floors.has(grid.get_cell(x, y)):
				astar.set_point_weight_scale(pos, 1.0)
			else:
				astar.set_point_weight_scale(pos, 3.0) 
				
	var processed_edges = {}
	
	for key in graph.edge_store:
		var edge = graph.edge_store[key]
		
		var pair = [edge.u, edge.v]
		pair.sort()
		if processed_edges.has(pair): continue
		processed_edges[pair] = true
		
		var node_u = graph.nodes[edge.u]
		var node_v = graph.nodes[edge.v]
		
		var start_pos = node_u.custom_data.get("_grid_center", Vector2i.ZERO)
		var end_pos = node_v.custom_data.get("_grid_center", Vector2i.ZERO)
		if start_pos == Vector2i.ZERO or end_pos == Vector2i.ZERO: continue 
		
		# --- 1. BIOME RESOLUTION (Driven by the Source Node 'u') ---
		var effective_params = params
		if biome_overrides.has(node_u.type) and biome_overrides[node_u.type].get("override_enabled", false):
			effective_params = params.duplicate()
			effective_params.merge(biome_overrides[node_u.type], true)
			
		var corridor_thickness = effective_params.get("corridor_thickness", 1)
		var allow_diagonals = effective_params.get("allow_diagonal_corridors", false)
		
		# Dynamically reconfigure the A* Pathfinder for THIS specific edge
		if allow_diagonals:
			astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
			astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
			astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
		else:
			astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
			astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
			astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
			
		var path = astar.get_id_path(start_pos, end_pos)
		if path.is_empty(): continue
		
		# --- 2. COLOR RESOLUTION (Blend Source and Target Colors) ---
		var floor_id_u = default_floor_id
		if node_u.type != "" and realizer.semantic_floor_ids.has(node_u.type):
			floor_id_u = realizer.semantic_floor_ids[node_u.type]
			
		var floor_id_v = default_floor_id
		if node_v.type != "" and realizer.semantic_floor_ids.has(node_v.type):
			floor_id_v = realizer.semantic_floor_ids[node_v.type]

		var path_midpoint = path.size() / 2.0
		
		# --- 3. STAMP THE PATH ---
		var prev_point = path[0] if path.size() > 0 else Vector2i.ZERO 
		
		# [NEW] Helper to steal the biome of adjacent rooms so corridors seamlessly blend when touching them!
		var get_smart_floor_id = func(p: Vector2i, default_id: int) -> int:
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if dx == 0 and dy == 0: continue
					var n_pos = Vector2i(p.x + dx, p.y + dy)
					
					# Only inherit from actual Rooms to prevent a corridor from dragging one biome forever
					if grid.in_bounds_vec(n_pos) and realizer.room_cells.has(n_pos):
						var nid = grid.get_cell(n_pos.x, n_pos.y)
						if valid_floors.has(nid):
							return nid
			return default_id
		
		for i in range(path.size()):
			var point = path[i]
			var active_floor_id = floor_id_u if i < path_midpoint else floor_id_v
			
			realizer.core_path_cells[point] = true 
			
			# --- DIAGONAL PINCH FIX ---
			if allow_diagonals and corridor_thickness == 1 and i > 0:
				var dx = abs(point.x - prev_point.x)
				var dy = abs(point.y - prev_point.y)
				if dx == 1 and dy == 1:
					var corner_p = Vector2i(point.x, prev_point.y)
					realizer.critical_path_cells[corner_p] = true 
					if grid.get_cell(corner_p.x, corner_p.y) == TilePalette.VOID_ID:
						var smart_id = get_smart_floor_id.call(corner_p, active_floor_id)
						grid.set_cell(corner_p.x, corner_p.y, smart_id)
			# --------------------------------
			
			var offset_start = -int((corridor_thickness - 1) / 2.0)
			var offset_end = offset_start + corridor_thickness
			
			for dy in range(offset_start, offset_end):
				for dx in range(offset_start, offset_end):
					var p = Vector2i(point.x + dx, point.y + dy)
					if grid.in_bounds_vec(p):
						realizer.critical_path_cells[p] = true 
						
						if grid.get_cell(p.x, p.y) == TilePalette.VOID_ID:
							var smart_id = get_smart_floor_id.call(p, active_floor_id)
							grid.set_cell(p.x, p.y, smart_id)
						astar.set_point_weight_scale(p, 1.0)
						
			prev_point = point
