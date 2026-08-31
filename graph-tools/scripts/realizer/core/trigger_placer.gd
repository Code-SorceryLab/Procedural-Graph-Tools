class_name TriggerPlacer
extends RefCounted

static func place(graph: Graph, realizer: GraphRealizer, params: Dictionary) -> void:
	var triggers = params.get("regen_triggers", {})
	if triggers.is_empty(): return
	
	var grid = realizer.grid
	var master_seed = SeedUtils.hash_seed(str(params.get("realizer_seed", "default")) + "_triggers")
	var rng = RandomNumberGenerator.new()
	rng.seed = master_seed

	var valid_floors = {}
	for id in grid.palette._definitions:
		if grid.palette.get_data(id).get("walkable", false):
			valid_floors[id] = true
			
	# --- PRE-PASS: Tally existing triggers & find Start ---
	var existing_triggers = {}
	var start_pos = Vector2i(-1, -1)
	for pos in grid.entities:
		var e = grid.entities[pos]
		if e.get("type", "") == "trigger":
			var tid = e.get("trigger_id", "")
			existing_triggers[tid] = existing_triggers.get(tid, 0) + 1
		elif e.get("type", "") == "start_point":
			start_pos = pos
			
	var temporal_state = params.get("temporal_state", {})
	var consumed = temporal_state.get("consumed_triggers", [])
	
	# ==========================================================================
	# REGION MAPPING (The Ground Truth)
	# ==========================================================================
	var map_data = realizer.get_meta("progression_map_data") if realizer.has_meta("progression_map_data") else {}
	# If Progression pass was disabled, dynamically fetch/build the regions!
	if map_data.is_empty():
		map_data = ProgressionRegionMapper.map_regions(realizer)
		
	var regions = map_data.get("regions", {})
	var region_adj = map_data.get("region_adj", {})
	var cell_to_region = map_data.get("cell_to_region", {})
	var depth_map = {} 

	for t_id in triggers:
		if consumed.has(t_id): continue 
		
		var t_data = triggers[t_id]
		var t_globals = t_data.get("global_overrides", {})
		
		if existing_triggers.get(t_id, 0) >= t_data.get("max_instances", 1): continue
		if t_data.get("placement_mode", 1) != 1: continue 
		
		# ======================================================================
		# PRIORITY 1-3: MACRO REGION SELECTION
		# ======================================================================
		var candidate_regions = []
		var exact_node = str(t_globals.get("exact_node_id", ""))
		
		if exact_node != "" and graph.nodes.has(exact_node):
			# PRIORITY 1: Convert Exact Node -> Exact Regions
			candidate_regions = _get_regions_from_nodes([exact_node], realizer, cell_to_region)
		else:
			# PRIORITY 2: Search Area
			var confine = t_globals.get("confine_to_mask", true)
			var mask_nodes = t_data.get("target_nodes", [])
			
			if confine and mask_nodes.size() > 0:
				candidate_regions = _get_regions_from_nodes(mask_nodes, realizer, cell_to_region)
			else:
				candidate_regions = regions.keys()
				
			# PRIORITY 3: Topological Filters
			var pref_biome = str(t_globals.get("pref_biome", "Any"))
			if pref_biome == "0": pref_biome = "Any"
			
			var pref_topo = int(t_globals.get("pref_topology", 0))
			var min_depth = int(t_globals.get("min_depth", 0))
			
			if min_depth > 0 and depth_map.is_empty():
				depth_map = _calculate_region_depths(start_pos, regions, region_adj, cell_to_region)
				
			var filtered_regions = []
			var reject_stats = {"biome": 0, "topo": 0, "depth": 0}
			
			for r_id in candidate_regions:
				# 1. BIOME CHECK (Physical Tiles)
				if pref_biome != "Any":
					var r_biomes = _get_region_biomes(r_id, regions, realizer)
					if not r_biomes.has(pref_biome):
						reject_stats["biome"] += 1
						continue
				
				# 2. TOPOLOGY CHECK (Physical Doorways)
				var doors = region_adj.get(r_id, []).size()
				if pref_topo == 1 and doors > 1: # Leaf Room
					reject_stats["topo"] += 1
					continue
				elif pref_topo == 2 and doors <= 1: # Spine Room
					reject_stats["topo"] += 1
					continue
					
				# 3. DEPTH CHECK
				if min_depth > 0 and depth_map.get(r_id, 0) < min_depth:
					reject_stats["depth"] += 1
					continue
					
				filtered_regions.append(r_id)
				
			if filtered_regions.size() > 0:
				candidate_regions = filtered_regions
			elif candidate_regions.size() > 0:
				print("[TriggerPlacer] Warning: Macro filters eliminated all %d options for '%s'. (Rejected by -> Biome: %d, Topology: %d, Depth: %d). Falling back to broader search area!" % [
					candidate_regions.size(), t_data.get("name", t_id), 
					reject_stats["biome"], reject_stats["topo"], reject_stats["depth"]
				])

		if candidate_regions.is_empty(): 
			print("[TriggerPlacer] Error: Trigger '%s' has zero valid physical regions to spawn in!" % t_data.get("name", t_id))
			continue
		
		# ======================================================================
		# PRIORITY 4: MICRO CELL SELECTION
		# ======================================================================
		var affinity = int(t_globals.get("wall_affinity", 0))
		var require_clear = t_globals.get("require_clearance", true)
		
		var valid_cells = []
		var fallback_cells = [] 
		
		for r_id in candidate_regions:
			# Iterate over the EXACT physical footprint of the room!
			for pt in regions.get(r_id, []):
				if realizer.critical_path_cells.has(pt) or realizer.reserved_cells.has(pt): continue
				
				var cid = grid.get_cell(pt.x, pt.y)
				if not valid_floors.has(cid): continue
				
				fallback_cells.append(pt)
				
				var is_perfect = true
				if require_clear:
					for dy in range(-1, 2):
						for dx in range(-1, 2):
							if dx == 0 and dy == 0: continue
							var n = pt + Vector2i(dx, dy)
							if grid.entities.has(n) or realizer.reserved_cells.has(n):
								is_perfect = false
								
				if is_perfect and affinity == 1: # Wall
					var touching_wall = false
					for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
						var n = pt + d
						if grid.in_bounds_vec(n) and not valid_floors.has(grid.get_cell(n.x, n.y)):
							touching_wall = true; break
					if not touching_wall: is_perfect = false
					
				if is_perfect and affinity == 2: # Center
					if realizer.distance_field.get(pt, 0) < 2: is_perfect = false
					
				if is_perfect:
					valid_cells.append(pt)
						
		var target_pool = valid_cells
		if target_pool.size() == 0 and fallback_cells.size() > 0:
			print("[TriggerPlacer] Warning: Room too cluttered to satisfy Wall/Clearance rules for '%s'. Placing randomly." % t_data.get("name", t_id))
			target_pool = fallback_cells
		
		if target_pool.size() > 0:
			var chosen = SeedUtils.pick_random(target_pool, rng)
			
			grid.entities[chosen] = {
				"type": "trigger",
				"trigger_id": t_id,
				"name": t_data.get("name", "Unknown Trigger"),
				"placement_method": "local"
			}
			realizer.reserved_cells[chosen] = true
			existing_triggers[t_id] = existing_triggers.get(t_id, 0) + 1

# ==============================================================================
# SPATIAL HELPERS
# ==============================================================================

static func _get_regions_from_nodes(node_list: Array, realizer: GraphRealizer, cell_to_region: Dictionary) -> Array:
	var found_regions = {}
	for cell in realizer.cell_to_nodes:
		for n in node_list:
			if realizer.cell_to_nodes[cell].has(n):
				if cell_to_region.has(cell):
					found_regions[cell_to_region[cell]] = true
	return found_regions.keys()

static func _get_region_biomes(r_id: int, regions: Dictionary, realizer: GraphRealizer) -> Dictionary:
	var b_dict = {}
	for pos in regions.get(r_id, []):
		var cid = realizer.grid.get_cell(pos.x, pos.y)
		if realizer.floor_to_semantic.has(cid):
			b_dict[realizer.floor_to_semantic[cid]] = true
	return b_dict

static func _calculate_region_depths(start_pos: Vector2i, regions: Dictionary, region_adj: Dictionary, cell_to_region: Dictionary) -> Dictionary:
	var depth_map = {}
	if regions.is_empty(): return depth_map
	
	var start_r = -1
	if start_pos != Vector2i(-1, -1) and cell_to_region.has(start_pos):
		start_r = cell_to_region[start_pos]
	else:
		start_r = regions.keys()[0] # Fallback
		
	var queue = [start_r]
	depth_map[start_r] = 0
	
	while queue.size() > 0:
		var curr = queue.pop_front()
		var d = depth_map[curr]
		
		for neighbor in region_adj.get(curr, []):
			if not depth_map.has(neighbor):
				depth_map[neighbor] = d + 1
				queue.append(neighbor)
				
	return depth_map
