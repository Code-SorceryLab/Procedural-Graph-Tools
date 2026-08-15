class_name ProgressionSolver
extends RefCounted

static func analyze(realizer: GraphRealizer, params: Dictionary, emit: Callable = Callable()) -> void:
	var grid = realizer.grid
	
	var master_seed = SeedUtils.hash_seed(str(params.get("realizer_seed", "default")) + "_progression")
	var rng = RandomNumberGenerator.new()
	rng.seed = master_seed
	
	var valid_floors = {}
	for id in grid.palette._definitions:
		if grid.palette.get_data(id).get("walkable", false):
			valid_floors[id] = true

	# --- 1 & 2. EXTRACT REGIONS & PORTALS ---
	var regions: Dictionary = {}
	var cell_to_region: Dictionary = {}
	var portals: Dictionary = {}
	var portal_connections: Dictionary = {}
	
	var region_counter = 0
	var visited_cells = {}
	var ortho_dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	
	for y in range(grid.height):
		for x in range(grid.width):
			var pos = Vector2i(x, y)
			if visited_cells.has(pos): continue
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
					if not grid.in_bounds_vec(n) or visited_cells.has(n): continue
					if grid.get_cell(n.x, n.y) != cell_id: continue 
					if grid.entities.has(n) and grid.entities[n].get("type") == "door": continue
					
					visited_cells[n] = true
					queue.append(n)
			regions[region_counter] = current_region

	var portal_counter = 0
	var visited_doors = {}
	var eight_way = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1), 
					 Vector2i(1,1), Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1)]
					
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
				
				for d in eight_way:
					var n = curr + d
					if not grid.in_bounds_vec(n) or visited_doors.has(n): continue
					if grid.entities.has(n) and grid.entities[n].get("type") == "door":
						visited_doors[n] = true
						queue.append(n)
			portals[portal_counter] = current_portal

	# --- 3. MAP CONNECTIVITY ---
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
		
		if conn_arr.size() == 2:
			var r1 = conn_arr[0]; var r2 = conn_arr[1]
			if not region_adj[r1].has(r2): region_adj[r1].append(r2)
			if not region_adj[r2].has(r1): region_adj[r2].append(r1)

	if emit.is_valid(): emit.call("Solver: Mapped Region Connectivity")

	# --- 4. START & END POINTS ---
	if regions.is_empty(): return
	
	var possible_starts = regions.keys().filter(func(r): return region_adj[r].size() > 1)
	var start_region = regions.keys()[0]
	if possible_starts.size() > 0: start_region = SeedUtils.pick_random(possible_starts, rng)
		
	var possible_ends = regions.keys().filter(func(r): return region_adj[r].size() == 1 and r != start_region)
	var end_region = -1
	if possible_ends.size() > 0: end_region = SeedUtils.pick_random(possible_ends, rng)
		
	_spawn_marker([start_region], "start_point", "Player Spawn", regions, realizer, rng)
	if end_region != -1: _spawn_marker([end_region], "end_point", "Dungeon Exit", regions, realizer, rng)

	if emit.is_valid(): emit.call("Solver: Placed Objectives")

	# --- BUILD REGION DEPTH MAP & SPINE ---
	var region_depth = {}
	var depth_queue = [start_region]
	region_depth[start_region] = 0
	
	while not depth_queue.is_empty():
		var r = depth_queue.pop_front()
		for neighbor in region_adj[r]:
			if not region_depth.has(neighbor):
				region_depth[neighbor] = region_depth[r] + 1
				depth_queue.append(neighbor)

	# [TRIMMED] Merged spine logic into a single cohesive list
	var spine_path = _find_spine_path(start_region, end_region, region_adj)
	var spine_regions = {}
	for r in spine_path: spine_regions[r] = true


	# --- 5. THE LOCKSMITH (Stateful BFS & Area Dependency) ---
	var locked_portals = [] # Purely metadata for your progression report
	
	if not params.get("progression_enabled", true): return
	if portal_connections.is_empty(): return
	
	var visited_regions = { start_region: true }
	var frontier_portals = []
	var processed_portals = {}
	
	var current_max_area = 0
	var region_to_area = { start_region: 0 }
	var area_map = { 0: [start_region] }
	var area_entry_locks = {}
	
	for p_id in portal_connections:
		if portal_connections[p_id].has(start_region):
			frontier_portals.append({ "p_id": p_id, "source_region": start_region })
			
	var key_colors = ["Red", "Blue", "Green", "Yellow", "Purple", "Cyan", "Orange"]
	var current_tier = 0
	var generated_locks = []
	
	var max_locks = params.get("progression_max_locks", 0) 
	var lock_chance = params.get("progression_lock_chance", 0.4)
	var min_copies = params.get("progression_key_copies_min", 1)
	var max_copies = params.get("progression_key_copies_max", 2)
	var locks_placed = 0

	var main_path_key_stash = params.get("main_path_key_stash", true)

	while frontier_portals.size() > 0:
		var p_idx = rng.randi() % frontier_portals.size()
		var edge = frontier_portals.pop_at(p_idx)
		var p_id = edge["p_id"]
		var source_region = edge["source_region"]
		var current_area_id = region_to_area[source_region]
		
		if processed_portals.has(p_id): continue
		processed_portals[p_id] = true
		
		var conn = portal_connections[p_id]
		var next_region = -1
		for r in conn:
			if r != source_region:
				next_region = r; break
				
		if next_region == -1: continue 
		
		var is_new_region = not visited_regions.has(next_region)
		var is_end_finale = (next_region == end_region and is_new_region)
		
		var lock_it = false
		var forge_new_key = false
		var lock_str = ""
		
		if is_new_region:
			if is_end_finale:
				lock_it = true
				forge_new_key = true
			elif (max_locks == 0 or locks_placed < max_locks) and rng.randf() < lock_chance:
				lock_it = true
				if generated_locks.size() > 0 and rng.randf() < 0.30:
					forge_new_key = false
					lock_str = SeedUtils.pick_random(generated_locks, rng)
				else:
					forge_new_key = true
		else:
			var dest_area_id = region_to_area[next_region]
			if current_area_id != dest_area_id:
				lock_it = true
				forge_new_key = false
				var deeper_area = max(current_area_id, dest_area_id)
				if area_entry_locks.has(deeper_area): lock_str = area_entry_locks[deeper_area]
				elif generated_locks.size() > 0: lock_str = SeedUtils.pick_random(generated_locks, rng)
				else: lock_it = false
			else:
				if (max_locks == 0 or locks_placed < max_locks) and rng.randf() < lock_chance:
					lock_it = true
					if generated_locks.size() > 0: lock_str = SeedUtils.pick_random(generated_locks, rng)
					else: forge_new_key = true

		if lock_it:
			if forge_new_key:
				var can_color = key_colors.size() > 0
				if not can_color or rng.randf() > 0.5:
					var tier_jump = 1
					if rng.randf() < 0.20: tier_jump = 2
					current_tier += tier_jump
					lock_str = "Tier " + str(current_tier)
				else:
					lock_str = key_colors.pop_front()
					
				generated_locks.append(lock_str)
				locks_placed += 1
				
				# --- SPINE AVOIDANCE DROP LOGIC ---
				var num_keys = rng.randi_range(min_copies, max_copies)
				
				# Split the available Area map into Spine and Off-Spine regions
				var preferred_regions = []
				var fallback_regions = []
				for r in area_map[current_area_id]:
					if main_path_key_stash and not spine_regions.has(r): preferred_regions.append(r)
					else: fallback_regions.append(r)
				
				# Track how the key was actually placed for the Report
				var has_branches = preferred_regions.size() > 0
				var spawn_method = "Stashed (Branch)" if (main_path_key_stash and has_branches) else "Main Path (Spine)"
				var valid_spawn_targets = preferred_regions if (main_path_key_stash and has_branches) else fallback_regions
				
				var key_dropped = false
				for i in range(num_keys):
					if _spawn_marker(valid_spawn_targets, "key", lock_str, regions, realizer, rng, spawn_method):
						key_dropped = true
						
				if not key_dropped:
					# Failsafe: The area was completely full, so drop it anywhere we've previously been
					_spawn_marker(visited_regions.keys(), "key", lock_str, regions, realizer, rng, "Fallback (Emergency)")
			
			# Record for the Report Generator
			locked_portals.append({
				"source_region": source_region, "next_region": next_region,
				"lock_str": lock_str, "forge_new_key": forge_new_key
			})

			for pos in portals[p_id]:
				grid.entities[pos]["lock_type"] = lock_str
				
			if emit.is_valid(): emit.call("Solver: Secured Door (" + lock_str + ")")

		if is_new_region:
			visited_regions[next_region] = true
			var assigned_area = current_area_id
			
			if lock_it and forge_new_key:
				current_max_area += 1
				assigned_area = current_max_area
				area_map[assigned_area] = []
				area_entry_locks[assigned_area] = lock_str
				
			region_to_area[next_region] = assigned_area
			area_map[assigned_area].append(next_region)
			
			for new_p_id in portal_connections:
				if not processed_portals.has(new_p_id) and portal_connections[new_p_id].has(next_region):
					frontier_portals.append({ "p_id": new_p_id, "source_region": next_region })

	# --- 6. EXPORT METADATA ---
	var cell_to_area = {}
	for pos in cell_to_region:
		var r_id = cell_to_region[pos]
		if region_to_area.has(r_id):
			cell_to_area[pos] = region_to_area[r_id]
			
	realizer.set_meta("cell_to_area", cell_to_area)
	
	# --- BUILD PROGRESSION REPORT ---
	var progression_report = _build_progression_report(
		start_region, end_region, regions, region_depth, region_adj, spine_path, 
		spine_regions, region_to_area, cell_to_region, locked_portals, grid, realizer
	)
	realizer.set_meta("progression_report", progression_report)

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

# Computes a strict Array representing the shortest path from start to end
static func _find_spine_path(start: int, end: int, adj: Dictionary) -> Array:
	var parent = {}
	var visited = { start: true }
	var queue = [start]
	parent[start] = -1

	while not queue.is_empty():
		var curr = queue.pop_front()
		if curr == end: break
		for neighbor in adj[curr]:
			if not visited.has(neighbor):
				visited[neighbor] = true
				parent[neighbor] = curr
				queue.append(neighbor)

	if not parent.has(end): return []

	var path: Array = []
	var current = end
	while current != -1:
		path.append(current)
		current = parent.get(current, -1)
	path.reverse()
	return path


static func _build_progression_report(
	start_region: int, end_region: int, regions: Dictionary, region_depth: Dictionary, 
	region_adj: Dictionary, spine_path: Array, spine_regions: Dictionary, 
	region_to_area: Dictionary, cell_to_region: Dictionary, locked_portals: Array, 
	grid: GridData, realizer: GraphRealizer
) -> Dictionary:
	var region_list: Array[Dictionary] = []
	for r_id in regions:
		var depth = region_depth.get(r_id, -1)
		var area = region_to_area.get(r_id, -1)
		var on_spine = spine_regions.has(r_id)

		var biome_keys: Dictionary = {}
		for pos in regions[r_id]:
			var cell_id = grid.get_cell(pos.x, pos.y)
			if realizer.floor_to_semantic.has(cell_id):
				biome_keys[realizer.floor_to_semantic[cell_id]] = true

		region_list.append({
			"id": r_id, "depth": depth, "area": area,
			"on_spine": on_spine, "biome_keys": biome_keys.keys()
		})

	# Locks
	var locks_list: Array[Dictionary] = []
	for lock_info in locked_portals:
		locks_list.append({
			"lock_str": lock_info.get("lock_str", ""),
			"source_region": lock_info.get("source_region", -1),
			"dest_region": lock_info.get("next_region", -1),
			"source_depth": region_depth.get(lock_info.get("source_region", -1), -1),
			"dest_depth": region_depth.get(lock_info.get("next_region", -1), -1)
		})

	# Keys
	var keys_list: Array[Dictionary] = []
	for pos in grid.entities:
		var ent = grid.entities[pos]
		if ent.get("type") != "key": continue
			
		var lock_str = ent.get("key_type", "")
		var r_id = cell_to_region.get(pos, -1)
		var depth = region_depth.get(r_id, -1)
		var biome_keys: Dictionary = {}
		if r_id != -1 and regions.has(r_id):
			for c in regions[r_id]:
				var cid = grid.get_cell(c.x, c.y)
				if realizer.floor_to_semantic.has(cid):
					biome_keys[realizer.floor_to_semantic[cid]] = true

		keys_list.append({
			"lock_str": lock_str, "region": r_id, "depth": depth,
			"biome_keys": biome_keys.keys(), "placement_method": ent.get("placement_method", "unknown")
		})

	var max_depth = 0
	for r in region_depth.values(): max_depth = max(max_depth, r)

	var area_count = 0
	for r in region_to_area.values(): area_count = max(area_count, r + 1)

	var stats = {
		"region_count": regions.size(),
		"lock_count": locks_list.size(),
		"key_count": keys_list.size(),
		"max_depth": max_depth,
		"area_count": area_count,
		"spine_length": spine_path.size()
	}

	return {
		"start_region": start_region, "end_region": end_region,
		"spine_path": spine_path, "regions": region_list,
		"locks": locks_list, "keys": keys_list, "stats": stats
	}

# Added the placement_method parameter back!
static func _spawn_marker(valid_region_ids: Array, e_type: String, subtype: String, regions: Dictionary, realizer: GraphRealizer, rng: RandomNumberGenerator, placement_method: String = "default") -> bool:
	var valid_cells = []
	for r_id in valid_region_ids:
		for pos in regions[r_id]:
			if not realizer.reserved_cells.has(pos) and not realizer.critical_path_cells.has(pos) and not realizer.grid.entities.has(pos):
				valid_cells.append(pos)
			
	if valid_cells.size() > 0:
		var chosen = SeedUtils.pick_random(valid_cells, rng)
		realizer.grid.entities[chosen] = {
			"type": e_type,
			"key_type": subtype if e_type == "key" else "",
			"name": subtype + " Key" if e_type == "key" else subtype,
			"placement_method": placement_method #Save it to the entity data
		}
		realizer.reserved_cells[chosen] = true
		return true
		
	return false
