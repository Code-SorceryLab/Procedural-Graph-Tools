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
	# VIP BYPASS: EXPLICIT NODE ASSIGNMENTS
	# ==========================================================================
	var explicit_start_region = -1
	var explicit_end_region = -1
	var explicit_start_node_id = "" 
	var explicit_end_node_id = ""   
	
	# Robustly map Node IDs to Region IDs using raw physical footprint intersections
	var node_to_region = {}
	for cell in realizer.cell_to_nodes:
		if cell_to_region.has(cell):
			var r_id = cell_to_region[cell]
			for n_id in realizer.cell_to_nodes[cell]:
				if not node_to_region.has(n_id):
					node_to_region[n_id] = r_id
					
	# Scan the graph for the explicit flags
	for n_id in graph.nodes:
		var c_data = graph.nodes[n_id].custom_data
		if c_data.get("is_forced_start", false):
			explicit_start_node_id = n_id 
			if node_to_region.has(n_id): 
				explicit_start_region = node_to_region[n_id]
				
		if c_data.get("is_forced_end", false):
			explicit_end_node_id = n_id   
			if node_to_region.has(n_id): 
				explicit_end_region = node_to_region[n_id]
			
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
	
	print("[DEBUG PATHING] explicit_start_node_id = ", explicit_start_node_id)
	print("[DEBUG PATHING] existing_start_pos = ", existing_start_pos)
	print("[DEBUG PATHING] recovered_start_region = ", recovered_start_region)
	
	if explicit_start_region != -1 and is_region_spawnable.call(explicit_start_region):
		# 0. VIP BYPASS: User explicitly assigned this node!
		print("[DEBUG PATHING] Branch 0: Explicit Assignment -> ", explicit_start_node_id)
		start_region = explicit_start_region
		start_tag = "Explicit Editor Assignment"
		final_start_node_id = explicit_start_node_id 
		need_spawn_start = true
		
		# [CRITICAL FIX] If the user explicitly assigned a new node, we MUST delete any old entity that survived!
		if existing_start_pos != Vector2i(-1, -1):
			print("[DEBUG PATHING] Erasing old preserved spawn point at ", existing_start_pos)
			grid.entities.erase(existing_start_pos)
			
	elif existing_start_pos != Vector2i(-1, -1) and cell_to_region.has(existing_start_pos):
		# 1. GROUND TRUTH: The entity safely survived the blast radius!
		print("[DEBUG PATHING] Branch 1: Preserved Spawn -> Region ", cell_to_region[existing_start_pos])
		start_region = cell_to_region[existing_start_pos]
		start_tag = "Preserved Spawn"
		need_spawn_start = false
		
	elif recovered_start_region != -1 and valid_regions.has(recovered_start_region) and is_region_spawnable.call(recovered_start_region):
		# 2. RECOVERY: The entity was vaporized, but we found the new room built in its place!
		print("[DEBUG PATHING] Branch 2: Recovered Spawn -> Region ", recovered_start_region)
		start_region = recovered_start_region
		start_tag = "Recovered Spawn"
		need_spawn_start = true
		
	else:
		# 3. FALLBACK: Pick a new room from SPAWNABLE regions!
		print("[DEBUG PATHING] Branch 3: Fallback Search")
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
				
	print("[DEBUG PATHING] Final Start Region: ", start_region, " | Need Spawn: ", need_spawn_start)
			
	# ==========================================================================
	# END REGION
	# ==========================================================================
	var end_candidates = spawnable_regions.filter(func(r): return r != start_region)
	var end_region = -1
	var end_tag = "Fallback (Random)"
	var need_spawn_end = true
	var final_end_node_id = "" 
	
	print("[DEBUG PATHING] explicit_end_node_id = ", explicit_end_node_id)
	
	if explicit_end_region != -1 and is_region_spawnable.call(explicit_end_region) and (explicit_end_region != start_region or valid_regions.size() == 1):
		# 0. VIP BYPASS: User explicitly assigned this node!
		print("[DEBUG PATHING] Branch 0: Explicit End Assignment -> ", explicit_end_node_id)
		end_region = explicit_end_region
		end_tag = "Explicit Editor Assignment"
		final_end_node_id = explicit_end_node_id 
		need_spawn_end = true
		
		# [CRITICAL FIX] Erase old entity if we are explicitly re-assigning it
		if existing_end_pos != Vector2i(-1, -1):
			print("[DEBUG PATHING] Erasing old preserved exit point at ", existing_end_pos)
			grid.entities.erase(existing_end_pos)
			
	elif existing_end_pos != Vector2i(-1, -1) and cell_to_region.has(existing_end_pos) and (cell_to_region[existing_end_pos] != start_region or valid_regions.size() == 1):
		print("[DEBUG PATHING] Branch 1: Preserved Exit -> Region ", cell_to_region[existing_end_pos])
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
		print("[DEBUG PATHING] spawn_marker(Start) Success: ", s_success)
		
	if need_spawn_end and end_region != -1: 
		var e_success = spawn_marker([end_region], "end_point", "Dungeon Exit", regions, realizer, rng, end_tag, "", final_end_node_id)
		print("[DEBUG PATHING] spawn_marker(End) Success: ", e_success)
	
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
		# --- STRICT MODE: Guaranteed Reachability Search ---
		# 1. Find all critical path cells that belong to this node
		var node_critical_cells = []
		var all_node_cells = []
		
		var fetch_node_cells = func(n_id: String):
			node_critical_cells.clear()
			all_node_cells.clear()
			for pos in realizer.cell_to_nodes.keys():
				if realizer.cell_to_nodes[pos].has(n_id):
					all_node_cells.append(pos)
					if realizer.critical_path_cells.has(pos):
						node_critical_cells.append(pos)
		
		# Initial fetch for the target node
		fetch_node_cells.call(strict_node_id)
					
		# 2. Rescue Operation (If severed from critical path)
		if node_critical_cells.is_empty():
			print("[WARNING] Strict Node '", strict_node_id, "' is severed from the critical path!")
			
			var rescued = false
			# Do a fast BFS on the abstract graph to find the closest living neighbor!
			var visited_nodes = { strict_node_id: true }
			# We pass the graph reference via an assumption that it's accessible, but it's cleaner
			# to use the `realizer.graph_ref` if we stashed it, OR we can just rely on `cell_to_nodes` 
			# to find a neighbor physically.
			
			# Let's find neighbors by checking `cell_to_edges` which tells us what nodes connect here!
			var search_queue = []
			
			# We need access to the graph to do this cleanly.
			# Since spawn_marker doesn't receive `graph`, we will use a purely physical search 
			# based on the cell_to_nodes dictionary! We find ANY node that has critical cells.
			
			print("[RESCUE] Scanning map for the closest valid topological replacement...")
			var fallback_node = ""
			var min_dist = INF
			
			# Find the physical center of the dead room
			var dead_center = Vector2i.ZERO
			if all_node_cells.size() > 0:
				for p in all_node_cells: dead_center += p
				dead_center /= all_node_cells.size()
			
			# Find the node that HAS critical path cells that is physically closest to our dead room
			var candidate_nodes = {}
			for pos in realizer.critical_path_cells.keys():
				if realizer.cell_to_nodes.has(pos):
					for n_id in realizer.cell_to_nodes[pos].keys():
						candidate_nodes[n_id] = true
						
			for n_id in candidate_nodes.keys():
				var center = Vector2i.ZERO
				var count = 0
				for pos in realizer.cell_to_nodes.keys():
					if realizer.cell_to_nodes[pos].has(n_id):
						center += pos
						count += 1
				if count > 0:
					center /= count
					var d = Vector2(dead_center).distance_squared_to(Vector2(center))
					if d < min_dist:
						min_dist = d
						fallback_node = n_id
						
			if fallback_node != "":
				print("[RESCUE] Successfully hijacked Start/End point. Redirecting to neighbor: ", fallback_node)
				strict_node_id = fallback_node
				fetch_node_cells.call(strict_node_id)
				rescued = true
				
			if not rescued:
				print("[ERROR] Rescue failed! No valid nodes found. Falling back to Region search.")
				strict_node_id = "" # Clear it to trigger the standard fallback block
			
		# 3. Flood-fill outward from the critical path (Only runs if we have critical cells!)
		if strict_node_id != "":
			var solvable_chunk = {}
			var queue = node_critical_cells.duplicate()
			for c in queue: solvable_chunk[c] = true
				
			var ortho = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
			var allowed_floor_lookup = {}
			for pos in all_node_cells:
				var cell_id = grid.get_cell(pos.x, pos.y)
				if cell_id != realizer.wall_id and not realizer.semantic_wall_map.values().has(cell_id):
					if not realizer.reserved_cells.has(pos) and not grid.entities.has(pos):
						allowed_floor_lookup[pos] = true
			
			while queue.size() > 0:
				var curr = queue.pop_front()
				for d in ortho:
					var n = curr + d
					if allowed_floor_lookup.has(n) and not solvable_chunk.has(n):
						solvable_chunk[n] = true
						queue.append(n)
						
			# 4. Filter for 'pure' cells
			for pos in solvable_chunk.keys():
				if not realizer.critical_path_cells.has(pos): 
					if realizer.cell_to_nodes[pos].size() == 1:
						valid_cells.append(pos)
						
			if valid_cells.is_empty():
				for pos in solvable_chunk.keys():
					if not realizer.critical_path_cells.has(pos):
						valid_cells.append(pos)
						
	# --- STANDARD MODE: Use Region Safe Chunks ---
	if strict_node_id == "":
		for r_id in valid_region_ids:
			if not regions.has(r_id): continue
				
			var safe_chunk = _get_safe_cells_for_region(r_id, regions, realizer)
			for pos in safe_chunk:
				if not realizer.critical_path_cells.has(pos) and not grid.entities.has(pos):
					valid_cells.append(pos)
				
	# --- EXECUTE PLACEMENT ---
	if valid_cells.size() > 0:
		valid_cells.sort_custom(func(a, b): return a.x < b.x if a.x != b.x else a.y < b.y)
		var chosen = SeedUtils.pick_random(valid_cells, rng)
		
		grid.entities[chosen] = {
			"type": e_type,
			"key_type": subtype if e_type == "key" else "",
			"name": display_name if display_name != "" else (subtype + " Key" if e_type == "key" else subtype),
			"placement_method": placement_method
		}
		realizer.reserved_cells[chosen] = true
		return true
		
	print("[WARNING] spawn_marker failed entirely! No valid cells found.")
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
