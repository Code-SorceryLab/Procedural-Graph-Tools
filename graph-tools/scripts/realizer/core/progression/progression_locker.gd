class_name ProgressionLocker
extends RefCounted

static func distribute_locks(realizer: GraphRealizer, params: Dictionary, map_data: Dictionary, path_data: Dictionary, rng: RandomNumberGenerator, emit: Callable = Callable()) -> Dictionary:
	var locked_portals = [] 
	
	if not params.get("progression_enabled", true) or path_data.is_empty() or map_data["portal_connections"].is_empty(): 
		return {"locked_portals": [], "critical_locks": [], "vault_locks": [], "vault_regions": {}, "region_to_area": {}}
		
	var grid = realizer.grid
	var regions = map_data["regions"]
	var region_adj = map_data["region_adj"]
	var portals = map_data["portals"]
	var portal_connections = map_data["portal_connections"]
	
	var start_region = path_data["start_region"]
	var end_region = path_data["end_region"]
	var spine_regions = path_data["spine_regions"]
	
	# --- [NEW] FETCH THE ARCHIVES ---
	var archived_keys = map_data.get("archived_keys", [])
	var archived_locks = map_data.get("archived_locks", {})
	var newly_dropped_replacements = {}
	
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
	
	# --- [NEW] PRUNE EXISTING COLORS ---
	# Remove any surviving colors from the pool so we don't generate duplicate doors!
	for p_id in archived_locks:
		var c = archived_locks[p_id]
		if color_pool.has(c): color_pool.erase(c)
		
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
	var vault_regions = {} 
	
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
		
		if is_leaf and not visited_regions.has(next_region) and not is_spine and not is_end_finale:
			unvisited_leaves -= 1
		
		if not is_end_finale and not is_spine and vaults_placed < max_vaults:
			if is_leaf:
				is_vault = true
				vault_tag = "Standard Leaf"
			elif allow_non_term_vaults: 
				is_vault = true
				vault_tag = "Non-Terminal Branch"
			elif not allow_non_term_vaults and unvisited_leaves < (max_vaults - vaults_placed):
				is_vault = true
				vault_tag = "Fallback (Non-Terminal)"
				
		var empty_stash_spots = []
		var empty_branches = []
		for r in accessible_regions:
			if not regions_with_keys.has(r):
				empty_stash_spots.append(r)
				if main_path_key_stash and not spine_regions.has(r): empty_branches.append(r)
				
		# --- VERIFY VAULT FEASIBILITY ---
		if is_vault and empty_stash_spots.size() == 0 and vault_locks.size() == 0:
			is_vault = false
			vault_tag = ""
				
		var lock_it = false
		var forge_new_key = false
		var lock_str = ""
		
		# --- [NEW] ARCHIVE OVERRIDE ---
		var existing_lock = archived_locks.get(p_id, "")
		
		if existing_lock != "":
			lock_it = true
			lock_str = existing_lock
			forge_new_key = false # Do not pull a new color/tier!
			
		elif is_end_finale:
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
			var needs_key_drop = false
			
			if existing_lock != "":
				# --- RESTORATION MODE ---
				placement_tag = "Restored Vault" if is_vault else "Restored Critical"
				
				if is_vault and not vault_locks.has(lock_str): vault_locks.append(lock_str)
				elif not is_vault and not critical_locks.has(lock_str): critical_locks.append(lock_str)
				
				if not safe_regions_for_lock.has(lock_str):
					safe_regions_for_lock[lock_str] = accessible_regions.duplicate()
					
				# 1. Did the Main Key Survive?
				var key_survived = false
				for k in archived_keys:
					if k["lock_str"] == lock_str and not "Shortcut" in k["placement_method"]:
						key_survived = true
						if k["region"] != -1: regions_with_keys[k["region"]] = true
						break
						
				# 2. If it died, and we haven't already replaced it, Forge a Replacement!
				if not key_survived and not newly_dropped_replacements.has(lock_str):
					needs_key_drop = true
					newly_dropped_replacements[lock_str] = true
					placement_tag += " (Replacement Key)"
					
			elif forge_new_key:
				# --- STANDARD NEW KEY MODE ---
				if rng.randf() < key_style_ratio and color_pool.size() > 0:
					lock_str = color_pool.pop_front()
				else:
					var tier_jump = 1
					if rng.randf() < 0.20: tier_jump = 2
					current_tier += tier_jump
					lock_str = "Tier " + str(current_tier)
					
				safe_regions_for_lock[lock_str] = accessible_regions.duplicate()
					
				if is_vault:
					vault_locks.append(lock_str)
					placement_tag = "Optional Vault"
				else:
					critical_locks.append(lock_str)
					
				needs_key_drop = true
				
			# --- THE KEY DROP ---
			if needs_key_drop:
				var target_pool = empty_branches if empty_branches.size() > 0 else empty_stash_spots
				var chosen_region = SeedUtils.pick_random(target_pool, rng)
				
				var key_dropped = false
				if chosen_region != null:
					if ProgressionPathingAnalyst.spawn_marker([chosen_region], "key", lock_str, regions, realizer, rng, placement_tag):
						key_dropped = true
						regions_with_keys[chosen_region] = true
						
				if not key_dropped:
					ProgressionPathingAnalyst.spawn_marker(accessible_regions, "key", lock_str, regions, realizer, rng, placement_tag + " (Emergency)")
					
			if is_vault:
				vaults_placed += 1
				vault_regions[next_region] = true
			else:
				locks_placed += 1
				
			locked_portals.append({
				"source_region": source_region, "next_region": next_region,
				"lock_str": lock_str, "forge_new_key": forge_new_key,
				"vault_tag": vault_tag 
			})

			for pos in portals[p_id]: grid.entities[pos]["lock_type"] = lock_str
			if emit.is_valid(): emit.call("Solver: Secured Door (" + lock_str + ")")

		visited_regions[next_region] = true
		
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
				
				var target_area = current_room_area + rng.randi_range(1, max(1, sequence_break_limit))
				
				var bonus_lock = ""
				if area_entry_locks.has(target_area):
					bonus_lock = area_entry_locks[target_area]
				else:
					bonus_lock = critical_locks[-1] 
					
				var safe_spots = safe_regions_for_lock.get(bonus_lock, [])
				
				if safe_spots.has(bonus_region):
					if ProgressionPathingAnalyst.spawn_marker([bonus_region], "key", bonus_lock, regions, realizer, rng, "Shortcut"):
						regions_with_keys[bonus_region] = true
				else:
					var fallback_empty = []
					for r in safe_spots:
						if not regions_with_keys.has(r): fallback_empty.append(r)
						
					if fallback_empty.size() > 0:
						var fallback_reg = SeedUtils.pick_random(fallback_empty, rng)
						if ProgressionPathingAnalyst.spawn_marker([fallback_reg], "key", bonus_lock, regions, realizer, rng, "Shortcut (Adjusted)"):
							regions_with_keys[fallback_reg] = true
					elif safe_spots.size() > 0:
						ProgressionPathingAnalyst.spawn_marker(safe_spots, "key", bonus_lock, regions, realizer, rng, "Shortcut (Shared Room)")

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

	return {
		"locked_portals": locked_portals,
		"critical_locks": critical_locks,
		"vault_locks": vault_locks,
		"vault_regions": vault_regions,
		"region_to_area": region_to_area
	}
