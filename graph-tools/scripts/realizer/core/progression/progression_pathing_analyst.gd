class_name ProgressionPathingAnalyst
extends RefCounted

static func analyze_paths(realizer: GraphRealizer, params: Dictionary, map_data: Dictionary, rng: RandomNumberGenerator, emit: Callable = Callable()) -> Dictionary:
	var regions = map_data["regions"]
	var region_adj = map_data["region_adj"]
	var grid = realizer.grid
	
	if regions.is_empty(): 
		return {}

	# --- 1. Find the Largest Connected Component ---
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
			
	var valid_regions = largest_component
	if valid_regions.is_empty(): valid_regions = regions.keys()

	# --- 2. Resolve Start and End Points ---
	var pref_start = params.get("progression_preferred_start", "Any")
	var pref_end = params.get("progression_preferred_end", "Any")
	
	var get_r_biomes = func(r_id):
		var b_dict = {}
		for pos in regions[r_id]:
			var cid = grid.get_cell(pos.x, pos.y)
			if realizer.floor_to_semantic.has(cid): b_dict[realizer.floor_to_semantic[cid]] = true
		return b_dict

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
			
	var end_candidates = valid_regions.filter(func(r): return r != start_region)
	var end_region = -1
	var end_tag = "Fallback (Random)"
	
	if end_candidates.is_empty():
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
			
	spawn_marker([start_region], "start_point", "Player Spawn", regions, realizer, rng, start_tag)
	if end_region != -1: spawn_marker([end_region], "end_point", "Dungeon Exit", regions, realizer, rng, end_tag)
	
	if emit.is_valid(): emit.call("Solver: Placed Objectives")

	# --- 3. Build Depth Map & Spine ---
	var region_depth = {}
	var depth_queue = [start_region]
	region_depth[start_region] = 0
	
	while not depth_queue.is_empty():
		var r = depth_queue.pop_front()
		for neighbor in region_adj[r]:
			if not region_depth.has(neighbor):
				region_depth[neighbor] = region_depth[r] + 1
				depth_queue.append(neighbor)

	var spine_path = _find_spine_path(start_region, end_region, region_adj)
	var spine_regions = {}
	for r in spine_path: spine_regions[r] = true

	return {
		"valid_regions": valid_regions,
		"start_region": start_region,
		"end_region": end_region,
		"region_depth": region_depth,
		"spine_path": spine_path,
		"spine_regions": spine_regions
	}

# Shared Utility for PathingAnalyst and Locker
static func spawn_marker(valid_region_ids: Array, e_type: String, subtype: String, regions: Dictionary, realizer: GraphRealizer, rng: RandomNumberGenerator, placement_method: String = "default") -> bool:
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
			"placement_method": placement_method
		}
		realizer.reserved_cells[chosen] = true
		return true
	return false

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
