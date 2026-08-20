class_name DistributionEngine
extends RefCounted

# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================
static func generate_shopping_lists(graph: Graph, global_decks: Dictionary, overrides: Dictionary, master_seed: String, override_key: String = "spawn_decks") -> Dictionary:
	var shopping_lists = {}
	var rng = RandomNumberGenerator.new()
	rng.seed = SeedUtils.hash_seed(master_seed + "_distribution")
	
	# 1. Initialize shopping lists and group rooms by biome
	var biome_nodes = {}
	for node_id in graph.nodes:
		var n = graph.nodes[node_id]
		if not biome_nodes.has(n.type):
			biome_nodes[n.type] = []
		biome_nodes[n.type].append(node_id)
		shopping_lists[node_id] = []
		
	# 2. Process each biome independently
	for biome in biome_nodes:
		var decks = global_decks
		
		# [UPDATED] Check for the dynamic override_key!
		if overrides.has(biome) and overrides[biome].get("override_enabled", false):
			if overrides[biome].has(override_key):
				decks = overrides[biome][override_key]
				
		if decks.is_empty(): continue
		
		# Find all Root Nodes (Nodes with no parent)
		var roots = []
		for k in decks:
			if decks[k].get("parent_id", "") == "":
				roots.append(decks[k])
				
		var rooms_in_biome = biome_nodes[biome]
		
		# 3. Resolve the Roots
		for root in roots:
			var scope = int(root.get("scope", 0)) # 0 = Per Room, 1 = Per Biome
			var mode = int(root.get("mode", 0))   # 0 = Fixed Quota, 1 = Density
			
			if scope == 1: 
				# --- PER BIOME SCOPE ---
				# Roll the quota once for the entire biome
				var biome_quota = 0
				if mode == 0:
					biome_quota = rng.randi_range(root.get("quota_min", 1), root.get("quota_max", 1))
				else:
					# Estimate tiles across the whole biome for density math
					var est_tiles = rooms_in_biome.size() * 50.0 
					biome_quota = round(est_tiles * root.get("density", 0.1))
					
				# Recursively resolve the tree into a flat array of concrete items
				var resolved_items = _resolve_pool(root, biome_quota, decks, rng)
				
				# Shuffle and distribute the resulting items randomly across the rooms in this biome
				resolved_items.shuffle()
				for item in resolved_items:
					var target_room = SeedUtils.pick_random(rooms_in_biome, rng)
					shopping_lists[target_room].append(item)
					
			else: 
				# --- PER ROOM SCOPE ---
				# Roll the quota independently for each room
				for room_id in rooms_in_biome:
					var room_rng = RandomNumberGenerator.new()
					# Unique seed per room and root combination to guarantee determinism
					room_rng.seed = SeedUtils.hash_seed(master_seed + str(room_id) + root["id"])
					
					var room_quota = 0
					if mode == 0:
						room_quota = room_rng.randi_range(root.get("quota_min", 1), root.get("quota_max", 1))
					else:
						# Calculate rough room area for density
						var radius = graph.nodes[room_id].custom_data.get("room_radius", 4)
						var est_tiles = pow(radius * 2 + 1, 2) * 0.8
						room_quota = round(est_tiles * root.get("density", 0.1))
						
					var resolved_items = _resolve_pool(root, room_quota, decks, room_rng)
					shopping_lists[room_id].append_array(resolved_items)
					
	return shopping_lists

# ==============================================================================
# THE RECURSIVE SOLVER
# ==============================================================================
static func _resolve_pool(node: Dictionary, quota: int, decks: Dictionary, rng: RandomNumberGenerator) -> Array:
	if quota <= 0: return []
	
	# --- BASE CASE: It's a Leaf Node (Structure or Scatter) ---
	var type = node.get("type", "pool")
	if type != "pool":
		if node.get("ref_id", "") == "": return []
		
		# Package the physical placement rules dynamically with the item!
		var item = {
			"type": type,
			"ref_id": node["ref_id"],
			"min_dist": node.get("min_dist", 0),
			"max_dist": node.get("max_dist", 99),
			"symmetry": node.get("symmetry", 0),
			"clump_chance": node.get("clump_chance", 0.0),
			"clump_max": node.get("clump_max", 3)
		}
		
		var results = []
		for i in range(quota): results.append(item.duplicate())
		return results
		
	# --- RECURSIVE CASE: It's a Pool ---
	var children = []
	var total_weight = 0
	
	# Find all children of this pool
	for k in decks:
		if decks[k].get("parent_id", "") == node["id"]:
			var w = decks[k].get("weight", 10)
			children.append({"node": decks[k], "weight": w})
			total_weight += w
			
	if children.is_empty() or total_weight == 0: return []
	
	# 1. The Strict Ratio Math
	var quotas = []
	var allocated = 0
	
	for i in range(children.size()):
		var child_quota = floor(float(quota) * (float(children[i]["weight"]) / float(total_weight)))
		quotas.append(child_quota)
		allocated += child_quota
		
	# 2. The Fractional Remainder Lottery
	var remainder = quota - allocated
	while remainder > 0:
		var roll = rng.randf_range(0, total_weight)
		var cursor = 0
		for i in range(children.size()):
			cursor += children[i]["weight"]
			if roll <= cursor:
				quotas[i] += 1
				break
		remainder -= 1
		
	# 3. Recurse down into the children with their newly assigned quotas
	var final_results = []
	for i in range(children.size()):
		if quotas[i] > 0:
			final_results.append_array(_resolve_pool(children[i]["node"], quotas[i], decks, rng))
			
	return final_results
