class_name EdgeRouter
extends RefCounted

static func route(graph: Graph, realizer: GraphRealizer, default_floor_id: int, params: Dictionary) -> void:
	var grid = realizer.grid
	var biome_overrides = params.get("biomes", {})
	
	# Load Custom Room Firewall
	var c_room_cells = realizer.get_meta("custom_room_cells") if realizer.has_meta("custom_room_cells") else {}
	
	# --- DETERMINISTIC ROUTING SEED ---
	var master_seed_input = params.get("realizer_seed", "default_realizer")
	var master_seed_hash = SeedUtils.hash_seed(str(master_seed_input) + "_routing")
	var rng = RandomNumberGenerator.new()
	
	var astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, grid.width, grid.height)
	astar.cell_size = Vector2i(1, 1)
	astar.update()
	
	var valid_floors = {}
	for id in grid.palette._definitions:
		if grid.palette.get_data(id).get("walkable", false):
			valid_floors[id] = true
	
	# Set Weights using the Semantic valid_floors check
	for y in range(grid.height):
		for x in range(grid.width):
			var pos = Vector2i(x, y)
			if valid_floors.has(grid.get_cell(x, y)):
				astar.set_point_weight_scale(pos, 1.0)
			else:
				astar.set_point_weight_scale(pos, 3.0) 
				
	var processed_edges = {}
	
	# --- GEOMETRIC L-PATH HELPERS ---
	var build_l_path = func(start: Vector2i, corner: Vector2i, end: Vector2i) -> Array[Vector2i]:
		var res: Array[Vector2i] = []
		var cur = start
		while cur != corner:
			res.append(cur)
			cur.x += sign(corner.x - cur.x)
			cur.y += sign(corner.y - cur.y)
		while cur != end:
			res.append(cur)
			cur.x += sign(end.x - cur.x)
			cur.y += sign(end.y - cur.y)
		res.append(end)
		return res
		
	var get_path_cost = func(p_array: Array[Vector2i]) -> float:
		var cost = 0.0
		for p in p_array:
			if grid.in_bounds_vec(p): cost += astar.get_point_weight_scale(p)
			else: cost += 999.0
		return cost
	
	for key in graph.edge_store:
		var edge = graph.edge_store[key]
		
		var pair = [edge.u, edge.v]
		pair.sort()
		if processed_edges.has(pair): continue
		processed_edges[pair] = true
		
		var node_u = graph.nodes[edge.u]
		var node_v = graph.nodes[edge.v]
		
		# --- SMART ENDPOINT RESOLUTION ---
		var get_pts = func(n: NodeData) -> Array:
			# If it's a Custom Room, expose its specific doorways!
			if n.custom_data.get("_is_custom_room", false):
				var doors = n.custom_data.get("_custom_doorways", [])
				if doors.size() > 0: return doors
			# Otherwise, fallback to the center point
			return [n.custom_data.get("_grid_center", Vector2i.ZERO)]
			
		var u_pts = get_pts.call(node_u)
		var v_pts = get_pts.call(node_v)
		
		var start_pos = u_pts[0]
		var end_pos = v_pts[0]
		var min_d = start_pos.distance_squared_to(end_pos)
		
		# Evaluate every doorway combination and pick the shortest bridge!
		for up in u_pts:
			for vp in v_pts:
				var d = up.distance_squared_to(vp)
				if d < min_d:
					min_d = d
					start_pos = up
					end_pos = vp
					
		if start_pos == Vector2i.ZERO or end_pos == Vector2i.ZERO: continue 
		
		# Firewall-protected param merge
		var effective_params = params.duplicate()
		if biome_overrides.has(node_u.type):
			effective_params.merge(biome_overrides[node_u.type], true)
			
		var corridor_thickness = effective_params.get("corridor_thickness", 1)
		var allow_diagonals = effective_params.get("allow_diagonal_corridors", false)
		var routing_mode = effective_params.get("routing_mode", 0) # <--- Fetch Routing Mode
		
		# Override diagonals if we are forcing strict orthogonal L-paths
		if routing_mode == 1:
			allow_diagonals = false
			
		if allow_diagonals:
			astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
			astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
			astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
		else:
			astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
			astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
			astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
			
		# --- DETERMINE PATH GEOMETRY ---
		var path: Array[Vector2i] = []
		
		if routing_mode == 1:
			# Deterministic dice roll for this specific edge
			rng.seed = SeedUtils.hash_seed(str(master_seed_hash) + "_" + str(pair[0]) + "_" + str(pair[1]))
			
			# Calculate the two possible 90-degree corner points
			var c1 = Vector2i(end_pos.x, start_pos.y)
			var c2 = Vector2i(start_pos.x, end_pos.y)
			
			var p1 = build_l_path.call(start_pos, c1, end_pos)
			var p2 = build_l_path.call(start_pos, c2, end_pos)
			
			var cost1 = get_path_cost.call(p1)
			var cost2 = get_path_cost.call(p2)
			
			# Pick the cheaper path to avoid needlessly crashing through thick walls/voids!
			# If equal, add a tiny noise fraction so the map doesn't look artificially biased to one axis
			if cost1 + rng.randf_range(-0.1, 0.1) < cost2:
				path = p1
			else:
				path = p2
		else:
			# Standard A* Organic Path
			path = astar.get_id_path(start_pos, end_pos)
			
		if path.is_empty(): continue
		
		# --- COLOR RESOLUTION (Blend Source and Target Colors) ---
		var floor_id_u = default_floor_id
		if node_u.type != "" and realizer.semantic_floor_ids.has(node_u.type):
			floor_id_u = realizer.semantic_floor_ids[node_u.type]
			
		var floor_id_v = default_floor_id
		if node_v.type != "" and realizer.semantic_floor_ids.has(node_v.type):
			floor_id_v = realizer.semantic_floor_ids[node_v.type]

		var path_midpoint = path.size() / 2.0
		var prev_point = path[0] if path.size() > 0 else Vector2i.ZERO 
		
		var get_smart_floor_id = func(p: Vector2i, default_id: int) -> int:
			for dy in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if dx == 0 and dy == 0: continue
					var n_pos = Vector2i(p.x + dx, p.y + dy)
					
					if grid.in_bounds_vec(n_pos) and realizer.room_cells.has(n_pos):
						var nid = grid.get_cell(n_pos.x, n_pos.y)
						if valid_floors.has(nid):
							return nid
			return default_id
		
		# --- 3. STAMP THE PATH ---
		for i in range(path.size()):
			var point = path[i]
			var active_floor_id = floor_id_u if i < path_midpoint else floor_id_v
			
			# Visually hand off the path to the Custom Room
			# If the point is inside the custom room, let the internal "Reserved" mask 
			# handle the pink overlay. Do not double-draw it!
			if not c_room_cells.has(point):
				realizer.core_path_cells[point] = true 
			
			# --- DIAGONAL PINCH FIX ---
			if allow_diagonals and corridor_thickness == 1 and i > 0:
				var dx = abs(point.x - prev_point.x)
				var dy = abs(point.y - prev_point.y)
				if dx == 1 and dy == 1:
					var corner_p = Vector2i(point.x, prev_point.y)
					
					# Shield the corner from breaching a Custom Room wall
					if not c_room_cells.has(corner_p):
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
						
						# --- IMMUNITY SHIELD ---
						# If the expanded thickness hits a Custom Room, block it!
						# This prevents 3-wide hallways from melting custom walls, while 
						# still allowing the 1-wide core point to hit the doorway.
						if c_room_cells.has(p) and p != point:
							continue
							
						realizer.critical_path_cells[p] = true 
						
						if grid.get_cell(p.x, p.y) == TilePalette.VOID_ID:
							var smart_id = get_smart_floor_id.call(p, active_floor_id)
							grid.set_cell(p.x, p.y, smart_id)
						astar.set_point_weight_scale(p, 1.0)
						
			prev_point = point
