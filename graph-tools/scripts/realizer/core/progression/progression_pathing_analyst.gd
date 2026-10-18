class_name ProgressionPathingAnalyst
extends RefCounted

static func analyze_paths(graph: Graph, realizer: GraphRealizer, params: Dictionary, map_data: Dictionary, rng: RandomNumberGenerator, emit: Callable = Callable()) -> Dictionary:
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
	var cell_to_region = map_data.get("cell_to_region", {})
	
	# ==========================================================================
	# VIP BYPASS: EXPLICIT NODE ASSIGNMENTS (INSERT NEW BLOCK HERE)
	# ==========================================================================
	var explicit_start_region = -1
	var explicit_end_region = -1
	var explicit_start_node_id = "" 
	var explicit_end_node_id = ""   
	
	# We need to map the Node ID string back to the numeric Region ID
	var node_to_region = {}
	if realizer.has_meta("custom_room_cells"): 
		var custom_cells = realizer.get_meta("custom_room_cells")
		for cell in custom_cells:
			if cell_to_region.has(cell):
				node_to_region[custom_cells[cell]] = cell_to_region[cell]
	
	# If the standard mapping isn't available, fallback to checking node centers
	if node_to_region.is_empty():
		for n_id in graph.nodes:
			var center = graph.nodes[n_id].custom_data.get("_grid_center", Vector2i(-1, -1))
			if center != Vector2i(-1, -1) and cell_to_region.has(center):
				node_to_region[n_id] = cell_to_region[center]
	
	# Scan the graph for the explicit flags
	for n_id in graph.nodes:
		var c_data = graph.nodes[n_id].custom_data
		if c_data.get("is_forced_start", false):
			explicit_start_node_id = n_id 
			if node_to_region.has(n_id): explicit_start_region = node_to_region[n_id]
				
		if c_data.get("is_forced_end", false):
			explicit_end_node_id = n_id   
			if node_to_region.has(n_id): explicit_end_region = node_to_region[n_id]
			
	# ==========================================================================
	# PHYSICAL GROUND TRUTH & ARCHIVE RECOVERY (YOUR EXISTING CODE CONTINUES HERE)
	# ==========================================================================
	var existing_start_pos = Vector2i(-1, -1)
	var existing_end_pos = Vector2i(-1, -1)
	
	for pos in grid.entities:
		var type = grid.entities[pos].get("type", "")
		if type == "start_point": existing_start_pos = pos
		elif type == "end_point": existing_end_pos = pos

	# If the entity was vaporized by the dirty rect, we recover its old coordinate!
	var archived_start_pos = params.get("_archived_start_pos", Vector2i(-1, -1))
	var archived_end_pos = params.get("_archived_end_pos", Vector2i(-1, -1))

	# Helper to find the nearest surviving Region ID from an old coordinate
	var get_region_from_pos = func(pos: Vector2i) -> int:
		if pos == Vector2i(-1, -1): return -1
		# Spiral search up to 5 tiles away in case the exact pixel became a wall
		for radius in range(6):
			for dy in range(-radius, radius + 1):
				for dx in range(-radius, radius + 1):
					var p = pos + Vector2i(dx, dy)
					if cell_to_region.has(p): return cell_to_region[p]
		return -1

	var recovered_start_region = get_region_from_pos.call(archived_start_pos)
	var recovered_end_region = get_region_from_pos.call(archived_end_pos)

	# Helper: Ensure a region has a safe, contiguous chunk of at least 4 free tiles!
	var is_region_spawnable = func(r_id: int) -> bool:
		var safe_chunk = _get_safe_cells_for_region(r_id, regions, realizer)
		var free_count = 0
		for pos in safe_chunk:
			if not realizer.critical_path_cells.has(pos) and not grid.entities.has(pos):
				free_count += 1
				if free_count >= 4: return true # Requires at least 4 viable placement spots!
		return false

	var spawnable_regions = valid_regions.filter(func(r): return is_region_spawnable.call(r))
	if spawnable_regions.is_empty(): spawnable_regions = valid_regions # Absolute fallback
	
	var get_r_biomes = func(r_id):
		var b_dict = {}
		for pos in regions[r_id]:
			var cid = grid.get_cell(pos.x, pos.y)
			if realizer.floor_to_semantic.has(cid): b_dict[realizer.floor_to_semantic[cid]] = true
		return b_dict

	# ==========================================================================
	# START REGION
	# ==========================================================================
	var start_region = -1
	var start_tag = "Fallback (Random)"
	var need_spawn_start = true
	var final_start_node_id = ""
	
	if explicit_start_region != -1 and is_region_spawnable.call(explicit_start_region):
		# 0. VIP BYPASS: User explicitly assigned this node
		start_region = explicit_start_region
		start_tag = "Explicit Editor Assignment"
		final_start_node_id = explicit_start_node_id # <--- Lock it in
		need_spawn_start = true
	elif existing_start_pos != Vector2i(-1, -1) and cell_to_region.has(existing_start_pos):
		# 1. GROUND TRUTH: The entity safely survived the blast radius!
		start_region = cell_to_region[existing_start_pos]
		start_tag = "Preserved Spawn"
		need_spawn_start = false
	elif recovered_start_region != -1 and valid_regions.has(recovered_start_region) and is_region_spawnable.call(recovered_start_region):
		# 2. RECOVERY: The entity was vaporized, but we found the new room built in its place!
		start_region = recovered_start_region
		start_tag = "Recovered Spawn"
		need_spawn_start = true
	else:
		# 3. FALLBACK: Pick a new room from SPAWNABLE regions!
		if pref_start != "Any":
			var matches = spawnable_regions.filter(func(r): return get_r_biomes.call(r).has(pref_start))
			if matches.size() > 0:
				start_region = SeedUtils.pick_random(matches, rng)
				start_tag = "Preferred Biome"
				
		if start_region == -1: 
			var multi_door = spawnable_regions.filter(func(r): return region_adj[r].size() > 1)
			if multi_door.size() > 0:
				start_region = SeedUtils.pick_random(multi_door, rng)
				start_tag = "Fallback (Multi-Door)"
			else:
				start_region = SeedUtils.pick_random(spawnable_regions, rng)
				start_tag = "Fallback (Leaf)"
			
	# ==========================================================================
	# END REGION
	# ==========================================================================
	var end_candidates = spawnable_regions.filter(func(r): return r != start_region)
	var end_region = -1
	var end_tag = "Fallback (Random)"
	var need_spawn_end = true
	var final_end_node_id = "" # <--- [NEW] Pass this to the spawner
	
	if explicit_end_region != -1 and is_region_spawnable.call(explicit_end_region) and (explicit_end_region != start_region or valid_regions.size() == 1):
		# 0. VIP BYPASS: User explicitly assigned this node!
		end_region = explicit_end_region
		end_tag = "Explicit Editor Assignment"
		final_end_node_id = explicit_end_node_id # <--- Lock it in
		need_spawn_end = true
	elif existing_end_pos != Vector2i(-1, -1) and cell_to_region.has(existing_end_pos) and (cell_to_region[existing_end_pos] != start_region or valid_regions.size() == 1):
		end_region = cell_to_region[existing_end_pos]
		end_tag = "Preserved Exit"
		need_spawn_end = false
	elif recovered_end_region != -1 and valid_regions.has(recovered_end_region) and is_region_spawnable.call(recovered_end_region) and (recovered_end_region != start_region or valid_regions.size() == 1):
		end_region = recovered_end_region
		end_tag = "Recovered Exit"
		need_spawn_end = true
	elif end_candidates.is_empty():
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
			
	# --- EXECUTIONS ---
	if need_spawn_start: 
		var s_success = spawn_marker([start_region], "start_point", "Player Spawn", regions, realizer, rng, start_tag, "", final_start_node_id)
		
	if need_spawn_end and end_region != -1: 
		var e_success = spawn_marker([end_region], "end_point", "Dungeon Exit", regions, realizer, rng, end_tag, "", final_end_node_id)
	
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
static func spawn_marker(valid_region_ids: Array, e_type: String, subtype: String, regions: Dictionary, realizer: GraphRealizer, rng: RandomNumberGenerator, placement_method: String = "default", display_name: String = "", strict_node_id: String = "") -> bool:
	var valid_cells = []
	var grid = realizer.grid
	
	if strict_node_id != "":
		# --- STRICT MODE: Bypass Region flood-fill and search the Node's exact footprint! ---
		for pos in realizer.cell_to_nodes.keys():
			# Check if this cell belongs to our explicit node
			if realizer.cell_to_nodes[pos].has(strict_node_id):
				# Must be a floor tile, not a wall
				var cell_id = grid.get_cell(pos.x, pos.y)
				if cell_id == realizer.wall_id or (realizer.semantic_wall_map.values().has(cell_id)):
					continue
					
				# Must not be reserved or occupied
				if not realizer.reserved_cells.has(pos) and not realizer.critical_path_cells.has(pos) and not grid.entities.has(pos):
					valid_cells.append(pos)
					
		# Optional: Filter out 'bridge' cells (cells owned by multiple nodes) to force it deep inside the room
		var pure_cells = valid_cells.filter(func(p): return realizer.cell_to_nodes[p].size() == 1)
		if pure_cells.size() > 0:
			valid_cells = pure_cells
			
	else:
		# --- STANDARD MODE: Use Region Safe Chunks ---
		for r_id in valid_region_ids:
			if not regions.has(r_id): continue
				
			var safe_chunk = _get_safe_cells_for_region(r_id, regions, realizer)
			for pos in safe_chunk:
				if not realizer.critical_path_cells.has(pos) and not grid.entities.has(pos):
					valid_cells.append(pos)
				
	# --- EXECUTE PLACEMENT ---
	if valid_cells.size() > 0:
		var chosen = SeedUtils.pick_random(valid_cells, rng)
		grid.entities[chosen] = {
			"type": e_type,
			"key_type": subtype if e_type == "key" else "",
			"name": display_name if display_name != "" else (subtype + " Key" if e_type == "key" else subtype),
			"placement_method": placement_method
		}
		realizer.reserved_cells[chosen] = true
		return true
		
	# Fallback Debug Print
	if strict_node_id != "":
		print("[WARNING] spawn_marker failed! strict_node_id '", strict_node_id, "' has no valid spawnable floor tiles left!")
		
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

static func _get_safe_cells_for_region(r_id: int, regions: Dictionary, realizer: GraphRealizer) -> Array:
	var reg_cells = regions.get(r_id, [])
	var unblocked = {}
	for pos in reg_cells:
		if not realizer.reserved_cells.has(pos):
			unblocked[pos] = true
			
	if unblocked.is_empty(): return []
	
	var visited = {}
	var largest_chunk = []
	var ortho = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	
	for start_pos in unblocked:
		if visited.has(start_pos): continue
		
		var current_chunk = []
		var queue = [start_pos]
		visited[start_pos] = true
		
		while queue.size() > 0:
			var curr = queue.pop_front()
			current_chunk.append(curr)
			
			for d in ortho:
				var n = curr + d
				if unblocked.has(n) and not visited.has(n):
					# Treat doors as solid walls to prevent crossing into other regions!
					if realizer.grid.entities.has(n) and realizer.grid.entities[n].get("type") == "door":
						continue
					visited[n] = true
					queue.append(n)
					
		if current_chunk.size() > largest_chunk.size():
			largest_chunk = current_chunk
			
	return largest_chunk
