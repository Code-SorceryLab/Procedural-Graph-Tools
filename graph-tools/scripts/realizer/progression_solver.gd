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
	
	# [NEW] Pre-calculate all solid cells so regions naturally flow around them!
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
	
	for y in range(grid.height):
		for x in range(grid.width):
			var pos = Vector2i(x, y)
			if visited_cells.has(pos): continue
			if solid_cells.has(pos): continue # <--- Ignore solid structures entirely!
			
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
					if solid_cells.has(n): continue 
					
					# --- [FIXED] THE SHATTER BUG ---
					# We MUST check if the cell is ANY valid floor, not just the identical cell_id!
					# Otherwise, rooms with multiple floor textures shatter into disconnected micro-regions.
					if not valid_floors.has(grid.get_cell(n.x, n.y)): continue 
					
					if grid.entities.has(n) and grid.entities[n].get("type") == "door": continue
					
					visited_cells[n] = true
					queue.append(n)
			regions[region_counter] = current_region

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
				
				for d in ortho_dirs: # <-- Switched to ortho_dirs
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
		
		# [FIXED] Combinatorial Adjacency!
		# Safely links all regions touching this portal, eliminating the strict size==2 rejection bug.
		for i in range(conn_arr.size()):
			for j in range(i + 1, conn_arr.size()):
				var r1 = conn_arr[i]
				var r2 = conn_arr[j]
				if not region_adj[r1].has(r2): region_adj[r1].append(r2)
				if not region_adj[r2].has(r1): region_adj[r2].append(r1)

	if emit.is_valid(): emit.call("Solver: Mapped Region Connectivity")

	# --- 4. START & END POINTS (Connected Component Floodfill) ---
	if regions.is_empty(): return
	
	# 1. Find the Largest Connected Component
	var visited_components = {}
	var largest_component = []
	
	for r_id in regions.keys():
		if visited_components.has(r_id): continue
		
		var current_comp = []
		var queue = [r_id]
		visited_components[r_id] = true
		
		while queue.size() > 0:
			var curr = queue.pop_front()
			current_comp.append(curr)
			for neighbor in region_adj.get(curr, []):
				if not visited_components.has(neighbor):
					visited_components[neighbor] = true
					queue.append(neighbor)
					
		if current_comp.size() > largest_component.size():
			largest_component = current_comp
			
	# The valid pool is now strictly the largest contiguous graph of rooms!
	var valid_regions = largest_component
	if valid_regions.is_empty(): valid_regions = regions.keys() # Absolute failsafe

	var pref_start = params.get("progression_preferred_start", "Any")
	var pref_end = params.get("progression_preferred_end", "Any")
	
	var get_r_biomes = func(r_id):
		var b_dict = {}
		for pos in regions[r_id]:
			var cid = grid.get_cell(pos.x, pos.y)
			if realizer.floor_to_semantic.has(cid): b_dict[realizer.floor_to_semantic[cid]] = true
		return b_dict

	# START REGION
	var start_region = -1
	var start_tag = "Fallback (Random)"
	
	if pref_start != "Any":
		var matches = valid_regions.filter(func(r): return get_r_biomes.call(r).has(pref_start))
		if matches.size() > 0:
			start_region = SeedUtils.pick_random(matches, rng)
			start_tag = "Preferred Biome"
			
	if start_region == -1: 
		var multi_door = valid_regions.filter(func(r): return region_adj[r].size() > 1)
		if multi_door.size() > 0:
			start_region = SeedUtils.pick_random(multi_door, rng)
			start_tag = "Fallback (Multi-Door)"
		else:
			start_region = SeedUtils.pick_random(valid_regions, rng)
			start_tag = "Fallback (Leaf)"
			
	# END REGION
	var end_candidates = valid_regions.filter(func(r): return r != start_region)
	var end_region = -1
	var end_tag = "Fallback (Random)"
	
	if end_candidates.is_empty():
		# [FIXED] Single-Room Graph! Safely put the End Point in the Start Room.
		end_region = start_region
		end_tag = "Fallback (Single Room Graph)"
	else:
		if pref_end != "Any":
			var leaf_matches = end_candidates.filter(func(r): return region_adj[r].size() == 1 and get_r_biomes.call(r).has(pref_end))
			if leaf_matches.size() > 0:
				end_region = SeedUtils.pick_random(leaf_matches, rng)
				end_tag = "Preferred Leaf"
			else:
				var cycle_matches = end_candidates.filter(func(r): return get_r_biomes.call(r).has(pref_end))
				if cycle_matches.size() > 0:
					end_region = SeedUtils.pick_random(cycle_matches, rng)
					end_tag = "Preferred Cycle Node"
					
		if end_region == -1:
			var leaves = end_candidates.filter(func(r): return region_adj[r].size() == 1)
			if leaves.size() > 0:
				end_region = SeedUtils.pick_random(leaves, rng)
				end_tag = "Fallback Leaf"
			else:
				end_region = SeedUtils.pick_random(end_candidates, rng)
				end_tag = "Fallback Cycle Node"
			
	_spawn_marker([start_region], "start_point", "Player Spawn", regions, realizer, rng, start_tag)
	
	# _spawn_marker natively reserves the cell, so even if start and end are in the same room, 
	# they will be placed on different physical tiles!
	if end_region != -1: _spawn_marker([end_region], "end_point", "Dungeon Exit", regions, realizer, rng, end_tag)
	
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


	# --- 5. THE LOCKSMITH (Advanced Metroidvania Simulator) ---
	var locked_portals = [] 
	
	if not params.get("progression_enabled", true): return
	if portal_connections.is_empty(): return
	
	var accessible_regions = [start_region]
	var visited_regions = { start_region: true }
	var frontier_edges = []
	var processed_portals = {}
	var regions_with_keys = {} 
	
	var current_max_area = 0
	var region_to_area = { start_region: 0 }
	var area_entry_locks = {}
	var safe_regions_for_lock = {}
	var region_prereqs = { start_region: [] }
	
	var populate_frontier = func(r_id):
		for p_id in portal_connections:
			if processed_portals.has(p_id): continue
			if portal_connections[p_id].has(r_id):
				var dest = -1
				for c in portal_connections[p_id]:
					if c != r_id: dest = c; break
				if dest != -1:
					frontier_edges.append({ "p_id": p_id, "source": r_id, "dest": dest })

	populate_frontier.call(start_region)
	
	# --- PARAMETERS & CONFIG ---
	var max_locks = params.get("progression_max_locks", 0) 
	var lock_chance = params.get("progression_lock_chance", 0.4)
	var max_vaults = params.get("progression_max_vaults", 2)
	var key_style_ratio = params.get("progression_style_ratio", 0.5)
	var shortcut_min = params.get("progression_shortcut_min", 0)
	var shortcut_max = params.get("progression_shortcut_max", 2)
	var sequence_break_limit = params.get("progression_sequence_break_limit", 2)
	var main_path_key_stash = params.get("main_path_key_stash", true)
	var allow_non_term_vaults = params.get("progression_non_terminal_vaults", false)
	
	# --- MASTER COLOR POOL ---
	var master_colors = [
		"AliceBlue", "AntiqueWhite", "Aqua", "Aquamarine", "Azure", "Beige", "Bisque", "BlanchedAlmond", "Blue", "BlueViolet",
		"Brown", "Burlywood", "CadetBlue", "Chartreuse", "Chocolate", "Coral", "CornflowerBlue", "Cornsilk", "Crimson", "Cyan",
		"DarkBlue", "DarkCyan", "DarkGoldenrod", "DarkGray", "DarkGreen", "DarkKhaki", "DarkMagenta", "DarkOliveGreen", "DarkOrange", "DarkOrchid",
		"DarkRed", "DarkSalmon", "DarkSeaGreen", "DarkSlateBlue", "DarkSlateGray", "DarkTurquoise", "DarkViolet", "DeepPink", "DeepSkyBlue", "DimGray",
		"DodgerBlue", "Firebrick", "FloralWhite", "ForestGreen", "Fuchsia", "Gainsboro", "GhostWhite", "Gold", "Goldenrod", "Gray",
		"Green", "GreenYellow", "Honeydew", "HotPink", "IndianRed", "Indigo", "Ivory", "Khaki", "Lavender", "LavenderBlush",
		"LawnGreen", "LemonChiffon", "LightBlue", "LightCoral", "LightCyan", "LightGoldenrod", "LightGray", "LightGreen", "LightPink", "LightSalmon",
		"LightSeaGreen", "LightSkyBlue", "LightSlateGray", "LightSteelBlue", "LightYellow", "Lime", "LimeGreen", "Linen", "Magenta", "Maroon",
		"MediumAquamarine", "MediumBlue", "MediumOrchid", "MediumPurple", "MediumSeaGreen", "MediumSlateBlue", "MediumSpringGreen", "MediumTurquoise", "MediumVioletRed", "MidnightBlue",
		"MintCream", "MistyRose", "Moccasin", "NavajoWhite", "NavyBlue", "OldLace", "Olive", "OliveDrab", "Orange", "OrangeRed",
		"Orchid", "PaleGoldenrod", "PaleGreen", "PaleTurquoise", "PaleVioletRed", "PapayaWhip", "PeachPuff", "Peru", "Pink", "Plum",
		"PowderBlue", "Purple", "RebeccaPurple", "Red", "RosyBrown", "RoyalBlue", "SaddleBrown", "Salmon", "SandyBrown", "SeaGreen",
		"Seashell", "Sienna", "Silver", "SkyBlue", "SlateBlue", "SlateGray", "Snow", "SpringGreen", "SteelBlue", "Tan",
		"Teal", "Thistle", "Tomato", "Turquoise", "Violet", "WebGray", "WebGreen", "WebMaroon", "WebPurple", "Wheat", "White", "Yellow", "YellowGreen"
	]
	
	var color_pool = master_colors.duplicate()
	for i in range(color_pool.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = color_pool[i]
		color_pool[i] = color_pool[j]
		color_pool[j] = temp
		
	var current_tier = 0
	var critical_locks = []
	var vault_locks = []
	var locks_placed = 0
	var vaults_placed = 0
	var vault_regions = {} # Track which regions become vaults
	# --- LEAF TRACKING FOR VAULT FALLBACKS ---
	var unvisited_leaves = 0
	for r in regions:
		if region_adj[r].size() == 1 and not spine_regions.has(r) and r != start_region and r != end_region:
			unvisited_leaves += 1

	while frontier_edges.size() > 0:
		var e_idx = rng.randi() % frontier_edges.size()
		var edge = frontier_edges[e_idx]
		
		if edge["dest"] == end_region and frontier_edges.size() > 1:
			var found_other = false
			for i in range(frontier_edges.size()):
				if frontier_edges[i]["dest"] != end_region:
					e_idx = i
					edge = frontier_edges[i]
					found_other = true
					break
					
		frontier_edges.remove_at(e_idx)
		
		var p_id = edge["p_id"]
		var source_region = edge["source"]
		var next_region = edge["dest"]
		
		if processed_portals.has(p_id): continue
		processed_portals[p_id] = true
		
		# --- SHORTCUT SYNCHRONIZATION ---
		if visited_regions.has(next_region):
			var area_source = region_to_area.get(source_region, 0)
			var area_dest = region_to_area.get(next_region, 0)
			
			if area_source != area_dest:
				var deeper_area = max(area_source, area_dest)
				if area_entry_locks.has(deeper_area):
					var sync_lock = area_entry_locks[deeper_area]
					locked_portals.append({
						"source_region": source_region, "next_region": next_region,
						"lock_str": sync_lock, "forge_new_key": false
					})
					for pos in portals[p_id]: grid.entities[pos]["lock_type"] = sync_lock
					if emit.is_valid(): emit.call("Solver: Synced Shortcut Door (" + sync_lock + ")")
			continue
		
		var is_end_finale = (next_region == end_region)
		var is_leaf = (region_adj[next_region].size() == 1)
		var is_spine = spine_regions.has(next_region)
		var is_vault = false
		var vault_tag = ""
		
		# Decrement leaf tracker if this is our first time visiting this valid leaf
		if is_leaf and not visited_regions.has(next_region) and not is_spine and not is_end_finale:
			unvisited_leaves -= 1
		
		if not is_end_finale and not is_spine and vaults_placed < max_vaults:
			if is_leaf:
				is_vault = true
				vault_tag = "Standard Leaf"
			elif allow_non_term_vaults: # If allowed, instantly claims the branch
				is_vault = true
				vault_tag = "Non-Terminal Branch"
			elif not allow_non_term_vaults and unvisited_leaves < (max_vaults - vaults_placed):
				# [FIXED] Zero RNG! Mathematically forces a fallback ONLY if out of leaves.
				is_vault = true
				vault_tag = "Fallback (Non-Terminal)"
				
		var empty_stash_spots = []
		var empty_branches = []
		for r in accessible_regions:
			if not regions_with_keys.has(r):
				empty_stash_spots.append(r)
				if main_path_key_stash and not spine_regions.has(r): empty_branches.append(r)
				
		# --- VERIFY VAULT FEASIBILITY ---
		# If we want to make a vault, we MUST have a place to put its key, or an existing vault key to reuse!
		# If we don't, we must revoke the vault status so the branch doesn't silently truncate.
		if is_vault and empty_stash_spots.size() == 0 and vault_locks.size() == 0:
			is_vault = false
			vault_tag = ""
				
		var lock_it = false
		var forge_new_key = false
		var lock_str = ""
		
		# --- FORK LOGIC ---
		if is_end_finale:
			lock_it = true
			forge_new_key = false
			if critical_locks.size() > 0: lock_str = critical_locks[-1] 
			else: forge_new_key = true 
				
		elif is_vault:
			lock_it = true
			if empty_stash_spots.size() > 0: forge_new_key = true 
			else:
				forge_new_key = false
				lock_str = SeedUtils.pick_random(vault_locks, rng)
				
		elif (max_locks == 0 or locks_placed < max_locks) and rng.randf() < lock_chance:
			lock_it = true
			if empty_stash_spots.size() > 0: forge_new_key = true 
			else:
				forge_new_key = false
				if critical_locks.size() > 0: lock_str = SeedUtils.pick_random(critical_locks, rng)
				else: lock_it = false
					
		if lock_it:
			var placement_tag = "Critical Progression"
			
			if forge_new_key:
				# Style Ratio Roll
				if rng.randf() < key_style_ratio and color_pool.size() > 0:
					lock_str = color_pool.pop_front()
				else:
					var tier_jump = 1
					if rng.randf() < 0.20: tier_jump = 2
					current_tier += tier_jump
					lock_str = "Tier " + str(current_tier)
					
				# --- DEPENDENCY SNAPSHOT ---
				# At the exact millisecond this lock is born, the current accessible_regions
				# are guaranteed to be reachable WITHOUT this key!
				safe_regions_for_lock[lock_str] = accessible_regions.duplicate()
					
				if is_vault:
					vault_locks.append(lock_str)
					vaults_placed += 1
					placement_tag = "Optional Vault"
					vault_regions[next_region] = true # Tag the region
				else:
					critical_locks.append(lock_str)
					locks_placed += 1
					
				var target_pool = empty_branches if empty_branches.size() > 0 else empty_stash_spots
				var chosen_region = SeedUtils.pick_random(target_pool, rng)
				
				var key_dropped = false
				if chosen_region != null:
					if _spawn_marker([chosen_region], "key", lock_str, regions, realizer, rng, placement_tag):
						key_dropped = true
						regions_with_keys[chosen_region] = true
						
				if not key_dropped:
					_spawn_marker(accessible_regions, "key", lock_str, regions, realizer, rng, "Fallback (Emergency)")
						
			locked_portals.append({
				"source_region": source_region, "next_region": next_region,
				"lock_str": lock_str, "forge_new_key": forge_new_key,
				"vault_tag": vault_tag # Export the placement context
			})

			for pos in portals[p_id]: grid.entities[pos]["lock_type"] = lock_str
			if emit.is_valid(): emit.call("Solver: Secured Door (" + lock_str + ")")

		# --- SIMULATE UNLOCKING ---
		visited_regions[next_region] = true
		
		# Inherit prerequisites, and add the new lock if one was just placed
		var prereqs = region_prereqs.get(source_region, []).duplicate()
		if lock_it and lock_str != "":
			if not prereqs.has(lock_str): prereqs.append(lock_str)
		region_prereqs[next_region] = prereqs
		
		var assigned_area = region_to_area[source_region]
		if lock_it and forge_new_key and not is_vault: 
			current_max_area += 1
			assigned_area = current_max_area
			area_entry_locks[assigned_area] = lock_str
			
		region_to_area[next_region] = assigned_area
		
		# [FIXED] Prevent the BFS from "leaking" out the backdoors of terminal nodes!
		if not is_vault and not is_end_finale:
			accessible_regions.append(next_region)
			populate_frontier.call(next_region)
		
	# --- CONTROLLED SEQUENCE BREAKS (Shortcuts) ---
	var num_shortcuts = rng.randi_range(shortcut_min, shortcut_max)
	if num_shortcuts > 0 and critical_locks.size() > 0:
		for i in range(num_shortcuts):
			var empty_spots = []
			for r in accessible_regions:
				if not regions_with_keys.has(r): empty_spots.append(r)
				
			if empty_spots.size() > 0:
				var bonus_region = SeedUtils.pick_random(empty_spots, rng)
				var current_room_area = region_to_area.get(bonus_region, 0)
				
				# Advance Area ID by the Break Limit
				var target_area = current_room_area + rng.randi_range(1, max(1, sequence_break_limit))
				
				var bonus_lock = ""
				if area_entry_locks.has(target_area):
					bonus_lock = area_entry_locks[target_area]
				else:
					bonus_lock = critical_locks[-1] 
					
				# --- [NEW] STRICT DEPENDENCY CHECK ---
				# Ensure the chosen bonus_region is actually safe for this lock!
				var safe_spots = safe_regions_for_lock.get(bonus_lock, [])
				
				if safe_spots.has(bonus_region):
					if _spawn_marker([bonus_region], "key", bonus_lock, regions, realizer, rng, "Shortcut"):
						regions_with_keys[bonus_region] = true
				else:
					# The intended room was downstream of the lock! Fallback to a guaranteed safe room.
					var fallback_empty = []
					for r in safe_spots:
						if not regions_with_keys.has(r): fallback_empty.append(r)
						
					if fallback_empty.size() > 0:
						var fallback_reg = SeedUtils.pick_random(fallback_empty, rng)
						if _spawn_marker([fallback_reg], "key", bonus_lock, regions, realizer, rng, "Shortcut (Adjusted)"):
							regions_with_keys[fallback_reg] = true
					elif safe_spots.size() > 0:
						_spawn_marker(safe_spots, "key", bonus_lock, regions, realizer, rng, "Shortcut (Shared Room)")

	# --- CLEANUP: ASSIGN REMAINING ROOMS ---
	for r_id in regions:
		if not region_to_area.has(r_id):
			var assigned = false
			if region_adj.has(r_id):
				for neighbor in region_adj[r_id]:
					if region_to_area.has(neighbor):
						region_to_area[r_id] = region_to_area[neighbor]
						assigned = true; break
			if not assigned: region_to_area[r_id] = 0

	# --- 6. EXPORT METADATA ---
	var cell_to_area = {}
	for pos in cell_to_region:
		var r_id = cell_to_region[pos]
		if region_to_area.has(r_id): cell_to_area[pos] = region_to_area[r_id]
			
	# --- EXPORT LEAVES ---
	var leaf_regions_export = {}
	for r in regions:
		if region_adj[r].size() == 1:
			leaf_regions_export[r] = true
	realizer.set_meta("leaf_regions", leaf_regions_export)
			
	realizer.set_meta("cell_to_area", cell_to_area)
	realizer.set_meta("cell_to_region", cell_to_region)
	realizer.set_meta("vault_regions", vault_regions)
	
	# --- BUILD PROGRESSION REPORT ---
	var progression_report = _build_progression_report(
		start_region, end_region, valid_regions, regions, region_depth, region_adj, spine_path, 
		spine_regions, region_to_area, cell_to_region, locked_portals, grid, realizer
	)
	
	progression_report["critical_locks"] = critical_locks
	progression_report["vault_locks"] = vault_locks
	
	# Package the settings into the report!
	progression_report["settings"] = {
		"lock_chance": lock_chance,
		"max_locks": max_locks,
		"max_vaults": max_vaults,
		"style_ratio": key_style_ratio,
		"shortcut_min": shortcut_min,
		"shortcut_max": shortcut_max,
		"seq_break_limit": sequence_break_limit,
		"main_path_stash": main_path_key_stash,
		"non_terminal_vaults": allow_non_term_vaults
	}
	
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
	start_region: int, end_region: int, valid_regions: Array, regions: Dictionary, region_depth: Dictionary, 
	region_adj: Dictionary, spine_path: Array, spine_regions: Dictionary, 
	region_to_area: Dictionary, cell_to_region: Dictionary, locked_portals: Array, 
	grid: GridData, realizer: GraphRealizer
) -> Dictionary:
	var region_list: Array[Dictionary] = []
	for r_id in valid_regions: # [FIXED] Only list playable regions!
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
			"dest_depth": region_depth.get(lock_info.get("next_region", -1), -1),
			"vault_tag": lock_info.get("vault_tag", "")
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

	var start_method = "Unknown"
	var end_method = "Unknown"
	for pos in grid.entities:
		if grid.entities[pos].get("type") == "start_point": start_method = grid.entities[pos].get("placement_method", "Unknown")
		elif grid.entities[pos].get("type") == "end_point": end_method = grid.entities[pos].get("placement_method", "Unknown")

	# --- NEW TOPOLOGY & METRIC MATH ---
	var leaves = []
	var corridors = []
	var hubs = []
	
	# [FIXED] Collect region IDs instead of raw counts!
	for r_id in valid_regions:
		var deg = region_adj[r_id].size()
		if deg == 1: leaves.append(r_id)
		elif deg == 2: corridors.append(r_id)
		elif deg >= 3: hubs.append(r_id)
		
	var total_backtrack = 0.0
	var backtrack_pairs = 0
	
	for l in locks_list:
		var lock_str = l["lock_str"]
		var lock_depth = l["source_depth"]
		for k in keys_list:
			if k["lock_str"] == lock_str:
				total_backtrack += abs(k["depth"] - lock_depth)
				backtrack_pairs += 1
				break
				
	var avg_backtrack = total_backtrack / max(1.0, float(backtrack_pairs))
	
	# Any region involved in progression logic is marked active
	var active_regions = { start_region: true, end_region: true }
	for l in locks_list: 
		active_regions[l["source_region"]] = true
		active_regions[l["dest_region"]] = true # Automatically flags vault rooms as active!
	for k in keys_list: 
		active_regions[k["region"]] = true
		
	var empty_regions = []
	for r_id in valid_regions:
		if not active_regions.has(r_id):
			empty_regions.append(r_id)

	var stats = {
		"valid_region_count": valid_regions.size(),
		"total_raw_regions": regions.size(),
		"leaves": leaves,
		"corridors": corridors,
		"hubs": hubs,
		"empty_regions": empty_regions,
		"avg_backtrack": avg_backtrack,
		"lock_count": locks_list.size(),
		"key_count": keys_list.size(),
		"max_depth": max_depth,
		"area_count": area_count,
		"spine_length": spine_path.size(),
		"start_method": start_method,
		"end_method": end_method
	}

	return {
		"start_region": start_region, "end_region": end_region,
		"spine_path": spine_path, "regions": region_list,
		"locks": locks_list, "keys": keys_list, "stats": stats,
		"region_adj": region_adj
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
