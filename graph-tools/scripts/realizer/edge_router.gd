class_name EdgeRouter
extends RefCounted

static func route(graph: Graph, realizer: GraphRealizer, default_floor_id: int, params: Dictionary) -> void:
	var grid = realizer.grid
	var corridor_radius = params.get("corridor_radius", 0)
	var allow_diagonals = params.get("allow_diagonal_corridors", false)
	
	var astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, grid.width, grid.height)
	astar.cell_size = Vector2i(1, 1)
	
	if allow_diagonals:
		astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	else:
		astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
		astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	
	# [FIX] Pre-cache all valid walkable floor IDs from the semantic palette
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
			
		var path = astar.get_id_path(start_pos, end_pos)
		
		# [OPTIONAL ENHANCEMENT] Check if the edge itself has a semantic type for its corridor floor!
		var edge_floor_id = default_floor_id
		var edge_type = edge.custom.get("type", "")
		# If you register Edge categories to floor IDs later, you can swap edge_floor_id here!

		# Check for the debug toggle
		var debug_routing = params.get("debug_routing", false)

		# 4. Stamp the Path into the GridData
		for point in path:
			if corridor_radius == 0:
				# ONLY paint if it's void, OR if we are forcing the debug pathway visible
				if grid.get_cell(point.x, point.y) == TilePalette.VOID_ID or debug_routing:
					grid.set_cell(point.x, point.y, edge_floor_id)
					
				astar.set_point_weight_scale(point, 1.0) 
			else:
				var rect = Rect2i(point.x - corridor_radius, point.y - corridor_radius, corridor_radius * 2 + 1, corridor_radius * 2 + 1)
				
				# Loop through the thickened area manually so we don't blindly overwrite rooms
				for dy in range(rect.size.y):
					for dx in range(rect.size.x):
						var p = Vector2i(rect.position.x + dx, rect.position.y + dy)
						if grid.in_bounds_vec(p):
							if grid.get_cell(p.x, p.y) == TilePalette.VOID_ID or debug_routing:
								grid.set_cell(p.x, p.y, edge_floor_id)
							astar.set_point_weight_scale(p, 1.0)
