class_name ProgressionSolver
extends RefCounted

# [NEW] Added the emit Callable to the signature
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

	# ==========================================================================
	# 4. START & END POINTS
	# ==========================================================================
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

	# ==========================================================================
	# 5. THE LOCKSMITH (Stateful BFS & Area Dependency)
	# ==========================================================================
	if not params.get("progression_enabled", true): return
	if portal_connections.is_empty(): return
	
	var visited_regions = { start_region: true }
	var frontier_portals = []
	var processed_portals = {}
	
	var current_max_area = 0
	var region_to_area = { start_region: 0 }
	var area_map = { 0: [start_region] }
	var area_entry_locks = {} # [NEW] Tracks exactly which key opened which Area!
	
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
		
		# --- [UPDATED] DECISION TREE WITH SEQUENCE BREAK PREVENTION ---
		if is_new_region:
			# Normal Expansion
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
			# [NEW] Anti-Sequence Break Check!
			var dest_area_id = region_to_area[next_region]
			if current_area_id != dest_area_id:
				# This door bridges two DIFFERENT depth areas. Force a lock!
				lock_it = true
				forge_new_key = false
				
				# Always lock it with the required key of the DEEPEST area
				var deeper_area = max(current_area_id, dest_area_id)
				if area_entry_locks.has(deeper_area):
					lock_str = area_entry_locks[deeper_area]
				elif generated_locks.size() > 0:
					lock_str = SeedUtils.pick_random(generated_locks, rng)
				else:
					lock_it = false # Failsafe
			else:
				# Connects two regions in the SAME area. Just let it be a random loot door or open passage.
				if (max_locks == 0 or locks_placed < max_locks) and rng.randf() < lock_chance:
					lock_it = true
					if generated_locks.size() > 0: lock_str = SeedUtils.pick_random(generated_locks, rng)
					else: forge_new_key = true
					
		# --- APPLY THE LOCK ---
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
				
				var num_keys = rng.randi_range(min_copies, max_copies)
				var key_dropped = false
				for i in range(num_keys):
					if _spawn_marker(area_map[current_area_id], "key", lock_str, regions, realizer, rng):
						key_dropped = true
						
				if not key_dropped:
					_spawn_marker(visited_regions.keys(), "key", lock_str, regions, realizer, rng)

			for pos in portals[p_id]:
				grid.entities[pos]["lock_type"] = lock_str
				
			if emit.is_valid(): emit.call("Solver: Secured Door (" + lock_str + ")")

		# --- EXPAND FRONTIER ---
		if is_new_region:
			visited_regions[next_region] = true
			var assigned_area = current_area_id
			
			if lock_it and forge_new_key:
				current_max_area += 1
				assigned_area = current_max_area
				area_map[assigned_area] = []
				# [NEW] Log exactly which key opens this new depth level!
				area_entry_locks[assigned_area] = lock_str 
				
			region_to_area[next_region] = assigned_area
			area_map[assigned_area].append(next_region)
			
			for new_p_id in portal_connections:
				if not processed_portals.has(new_p_id) and portal_connections[new_p_id].has(next_region):
					frontier_portals.append({ "p_id": new_p_id, "source_region": next_region })
	
	# ==========================================================================
	# 6. EXPORT METADATA
	# ==========================================================================
	var cell_to_area = {}
	for pos in cell_to_region:
		var r_id = cell_to_region[pos]
		if region_to_area.has(r_id):
			cell_to_area[pos] = region_to_area[r_id]
			
	realizer.set_meta("cell_to_area", cell_to_area)


static func _spawn_marker(valid_region_ids: Array, e_type: String, subtype: String, regions: Dictionary, realizer: GraphRealizer, rng: RandomNumberGenerator) -> bool:
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
			"name": subtype + " Key" if e_type == "key" else subtype
		}
		realizer.reserved_cells[chosen] = true
		return true
		
	return false
