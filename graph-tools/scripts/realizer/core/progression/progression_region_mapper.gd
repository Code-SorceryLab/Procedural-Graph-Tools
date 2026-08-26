class_name ProgressionRegionMapper
extends RefCounted

static func map_regions(realizer: GraphRealizer, emit: Callable = Callable()) -> Dictionary:
	var grid = realizer.grid
	
	var valid_floors = {}
	for id in grid.palette._definitions:
		if grid.palette.get_data(id).get("walkable", false):
			valid_floors[id] = true

	var regions: Dictionary = {}
	var cell_to_region: Dictionary = {}
	var portals: Dictionary = {}
	var portal_connections: Dictionary = {}
	
	# Pre-calculate all solid cells so regions naturally flow around them
	var solid_cells = {}
	for pos in grid.entities:
		var ent = grid.entities[pos]
		if ent.get("type") == "structure" and ent.get("is_solid", true):
			var footprint = ent.get("footprint_world", [])
			for pt in footprint:
				solid_cells[pt] = true
	
	var region_counter = 0
	var visited_cells = {}
	var ortho_dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	
	# --- EXTRACT REGIONS ---
	for y in range(grid.height):
		for x in range(grid.width):
			var pos = Vector2i(x, y)
			if visited_cells.has(pos) or solid_cells.has(pos): continue 
			
			var cell_id = grid.get_cell(x, y)
			if not valid_floors.has(cell_id): continue
			if grid.entities.has(pos) and grid.entities[pos].get("type") == "door": continue 
				
			region_counter += 1
			var current_region = []
			var queue = [pos]
			visited_cells[pos] = true
			
			var head = 0
			while head < queue.size():
				var curr = queue[head]
				head += 1
				current_region.append(curr)
				cell_to_region[curr] = region_counter
				
				for d in ortho_dirs:
					var n = curr + d
					if not grid.in_bounds_vec(n) or visited_cells.has(n) or solid_cells.has(n): continue 
					if not valid_floors.has(grid.get_cell(n.x, n.y)): continue 
					if grid.entities.has(n) and grid.entities[n].get("type") == "door": continue
					
					visited_cells[n] = true
					queue.append(n)
			regions[region_counter] = current_region

	# --- EXTRACT PORTALS ---
	var portal_counter = 0
	var visited_doors = {}
	
	for pos in grid.entities:
		var ent = grid.entities[pos]
		if ent.get("type") == "door" and not visited_doors.has(pos):
			portal_counter += 1
			var current_portal = []
			var queue = [pos]
			visited_doors[pos] = true
			
			var head = 0
			while head < queue.size():
				var curr = queue[head]
				head += 1
				current_portal.append(curr)
				
				for d in ortho_dirs:
					var n = curr + d
					if not grid.in_bounds_vec(n) or visited_doors.has(n): continue
					if grid.entities.has(n) and grid.entities[n].get("type") == "door":
						visited_doors[n] = true
						queue.append(n)
			portals[portal_counter] = current_portal

	# --- MAP CONNECTIVITY ---
	var region_adj = {}
	for r in regions.keys(): region_adj[r] = []
	
	for p_id in portals:
		var connected_regions = {}
		for door_pos in portals[p_id]:
			grid.entities[door_pos]["portal_id"] = p_id 
			for d in ortho_dirs:
				var neighbor = door_pos + d
				if cell_to_region.has(neighbor):
					connected_regions[cell_to_region[neighbor]] = true
		
		var conn_arr = connected_regions.keys()
		portal_connections[p_id] = conn_arr
		
		for i in range(conn_arr.size()):
			for j in range(i + 1, conn_arr.size()):
				var r1 = conn_arr[i]
				var r2 = conn_arr[j]
				if not region_adj[r1].has(r2): region_adj[r1].append(r2)
				if not region_adj[r2].has(r1): region_adj[r2].append(r1)

	if emit.is_valid(): emit.call("Solver: Mapped Region Connectivity")

	return {
		"regions": regions,
		"cell_to_region": cell_to_region,
		"portals": portals,
		"portal_connections": portal_connections,
		"region_adj": region_adj
	}
