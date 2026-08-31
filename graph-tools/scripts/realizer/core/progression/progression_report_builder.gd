class_name ProgressionReportBuilder
extends RefCounted

static func build_and_export(realizer: GraphRealizer, params: Dictionary, map_data: Dictionary, path_data: Dictionary, locker_data: Dictionary) -> void:
	if path_data.is_empty(): return
	
	var grid = realizer.grid
	var valid_regions = path_data["valid_regions"]
	var regions = map_data["regions"]
	var region_adj = map_data["region_adj"]
	var cell_to_region = map_data["cell_to_region"]
	var region_depth = path_data["region_depth"]
	var region_to_area = locker_data.get("region_to_area", {})
	var spine_regions = path_data["spine_regions"]
	var locked_portals = locker_data.get("locked_portals", [])
	
	var region_list: Array[Dictionary] = []
	for r_id in valid_regions:
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

	# --- TOPOLOGY & METRIC MATH ---
	var leaves = []
	var corridors = []
	var hubs = []
	
	for r_id in valid_regions:
		var deg = region_adj[r_id].size()
		if deg == 1: leaves.append(r_id)
		elif deg == 2: corridors.append(r_id)
		elif deg >= 3: hubs.append(r_id)
		
	var multi_way_doors = []
	var portal_connections = map_data["portal_connections"]
	for p_id in portal_connections:
		var conn = portal_connections[p_id]
		var valid_conns = []
		for c in conn:
			if valid_regions.has(c): valid_conns.append(c)
		if valid_conns.size() > 2:
			multi_way_doors.append({ "portal_id": p_id, "regions": valid_conns })
		
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
	
	var active_regions = { path_data["start_region"]: true, path_data["end_region"]: true }
	for l in locks_list: 
		active_regions[l["source_region"]] = true
		active_regions[l["dest_region"]] = true 
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
		"multi_way_doors": multi_way_doors,
		"empty_regions": empty_regions,
		"avg_backtrack": avg_backtrack,
		"lock_count": locks_list.size(),
		"key_count": keys_list.size(),
		"max_depth": max_depth,
		"area_count": area_count,
		"spine_length": path_data["spine_path"].size(),
		"start_method": start_method,
		"end_method": end_method
	}

	# --- EXPORT METADATA TO REALIZER ---
	var cell_to_area = {}
	for pos in cell_to_region:
		var r_id = cell_to_region[pos]
		if region_to_area.has(r_id): cell_to_area[pos] = region_to_area[r_id]
			
	var leaf_regions_export = {}
	for r in regions:
		if region_adj[r].size() == 1:
			leaf_regions_export[r] = true
	
	realizer.set_meta("progression_map_data", map_data)
	realizer.set_meta("leaf_regions", leaf_regions_export)
	realizer.set_meta("cell_to_area", cell_to_area)
	realizer.set_meta("cell_to_region", cell_to_region)
	realizer.set_meta("vault_regions", locker_data.get("vault_regions", {}))
	
	var progression_report = {
		"start_region": path_data["start_region"], "end_region": path_data["end_region"],
		"spine_path": path_data["spine_path"], "regions": region_list,
		"locks": locks_list, "keys": keys_list, "stats": stats,
		"region_adj": region_adj,
		"critical_locks": locker_data.get("critical_locks", []),
		"vault_locks": locker_data.get("vault_locks", []),
		"settings": {
			"lock_chance": params.get("progression_lock_chance", 0.4),
			"max_locks": params.get("progression_max_locks", 0),
			"max_vaults": params.get("progression_max_vaults", 2),
			"style_ratio": params.get("progression_style_ratio", 0.5),
			"shortcut_min": params.get("progression_shortcut_min", 0),
			"shortcut_max": params.get("progression_shortcut_max", 2),
			"seq_break_limit": params.get("progression_sequence_break_limit", 2),
			"main_path_stash": params.get("main_path_key_stash", true),
			"non_terminal_vaults": params.get("progression_non_terminal_vaults", false)
		}
	}
	
	realizer.set_meta("progression_report", progression_report)
