class_name SemanticBiomeFill extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Biome Flood Fill"
	category = Category.SEMANTIC

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "use_spatial", "label": "Use Spatial Fill (XY)", "type": TYPE_BOOL, "default": false, "hint_text": "If false, respects graph topology (corridors). If true, strictly uses physical distance." },
		{ "name": "clear_previous", "label": "Clear Previous Types", "type": TYPE_BOOL, "default": true },
		{ "name": "protect_existing", "label": "Protect Painted Rooms", "type": TYPE_BOOL, "default": false },
		{ "name": "max_depth", "label": "Max Expansion Steps", "type": TYPE_INT, "default": 0, "min": 0, "max": 50, "hint_text": "0 = Infinite. Limits how far a biome can grow." },
		{ "name": "evenly_space", "label": "Evenly Space Seeds", "type": TYPE_BOOL, "default": true },
		{ "name": "sep_biomes", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "btn_biome_palette", "label": "Configure Biome Palette...", "type": TYPE_NIL, "hint": "button" }
	])
	return s

func get_palette_schema() -> Array[Dictionary]:
	var schema: Array[Dictionary] = []
	schema.append({ "name": "seed_count", "label": "Number of Seeds", "type": TYPE_INT, "default": 5, "min": 1, "max": 100 })
	schema.append({ "name": "sep_biomes_pop", "type": TYPE_NIL, "hint": "separator" })
	
	if SemanticRegistry and SemanticRegistry.categories.has(SemanticRegistry.TARGET_NODE):
		var node_cats = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE]
		for key in node_cats:
			schema.append({ "name": "use_biome_" + key, "label": node_cats[key]["name"], "type": TYPE_BOOL, "default": false, "color": node_cats[key]["color"] })
			schema.append({ "name": "speed_" + key, "label": "  └─ Growth Speed", "type": TYPE_INT, "default": 1, "min": 1, "max": 5 })
			
	return schema

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	if recorder.nodes.is_empty(): return
	
	# Gather allowed biomes from local settings
	var allowed_biomes: Array[String] = []
	var node_cats = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE]
	for key in node_cats:
		if local_settings.get("use_biome_" + key, false): allowed_biomes.append(key)
			
	if allowed_biomes.is_empty(): return
	
	var seed_count = local_settings.get("seed_count", 5)
	var use_spatial = local_settings.get("use_spatial", false) 
	var evenly_space = local_settings.get("evenly_space", true)
	var max_depth = local_settings.get("max_depth", 0)
	var clear_previous = local_settings.get("clear_previous", true)
	var protect_existing = local_settings.get("protect_existing", false)
	
	# --- 1. MASKING & INITIAL STATE ---
	var assigned_types = {} 
	
	for id in recorder.nodes:
		var t = recorder.nodes[id].type
		if protect_existing and t != "empty":
			assigned_types[id] = t
		elif clear_previous:
			recorder.set_node_type(id, "empty")
			
	# --- 2. PICK SEEDS ---
	var valid_seed_nodes = []
	var all_nodes = recorder.nodes.keys()
	all_nodes.sort() 
	
	for id in all_nodes:
		if not assigned_types.has(id): valid_seed_nodes.append(id)
			
	var actual_seed_count = min(seed_count, valid_seed_nodes.size())
	var seeds = []

	if not evenly_space:
		SeedUtils.shuffle(valid_seed_nodes, rng)
		seeds = valid_seed_nodes.slice(0, actual_seed_count)
	elif actual_seed_count > 0:
		seeds.append(valid_seed_nodes[rng.randi() % valid_seed_nodes.size()])
		while seeds.size() < actual_seed_count:
			var max_min_dist = -1.0
			var best_cand = ""
			for c_id in valid_seed_nodes:
				if seeds.has(c_id): continue
				var min_d = INF
				var c_pos = recorder.get_node_pos(c_id)
				for s_id in seeds:
					var d = c_pos.distance_squared_to(recorder.get_node_pos(s_id))
					if d < min_d: min_d = d
				if min_d > max_min_dist:
					max_min_dist = min_d
					best_cand = c_id
			seeds.append(best_cand)

	# --- 3. ASSIGN SEEDS ---
	var depths = {}
	var frontiers = {} 
	for b in allowed_biomes: frontiers[b] = []
	
	var biome_pool = allowed_biomes.duplicate()
	SeedUtils.shuffle(biome_pool, rng)
	
	for i in range(seeds.size()):
		var s_id = seeds[i]
		var b_type = biome_pool[i % biome_pool.size()] 
		assigned_types[s_id] = b_type
		recorder.set_node_type(s_id, b_type)
		depths[s_id] = 0
		frontiers[b_type].append(s_id)

	# --- 4. FLOOD FILL ---
	if not use_spatial:
		# Topological BFS
		var max_speed = 1
		for b in allowed_biomes:
			if local_settings.get("speed_" + b, 1) > max_speed:
				max_speed = local_settings.get("speed_" + b, 1)
				
		var any_progress = true
		while any_progress:
			any_progress = false
			for phase in range(1, max_speed + 1):
				var next_frontiers = {}
				for b in allowed_biomes: next_frontiers[b] = []
					
				for b in allowed_biomes:
					if local_settings.get("speed_" + b, 1) < phase:
						next_frontiers[b].append_array(frontiers[b])
						continue
						
					for current in frontiers[b]:
						var current_depth = depths[current]
						if max_depth > 0 and current_depth >= max_depth: continue 
							
						var neighbors = recorder.get_neighbors(current)
						SeedUtils.shuffle(neighbors, rng)
						for neighbor in neighbors:
							if not assigned_types.has(neighbor):
								assigned_types[neighbor] = b
								recorder.set_node_type(neighbor, b)
								depths[neighbor] = current_depth + 1
								next_frontiers[b].append(neighbor)
								any_progress = true
				frontiers = next_frontiers 
	else:
		# Spatial Voronoi
		var max_dist_sq = INF
		if max_depth > 0: max_dist_sq = pow(max_depth * 150.0, 2)
			
		for id in recorder.nodes:
			if assigned_types.has(id): continue 
			var min_eff_dist = INF
			var closest_seed = ""
			
			for s_id in seeds:
				var s_type = assigned_types[s_id]
				var s_speed = float(local_settings.get("speed_" + s_type, 1))
				var true_dist = recorder.get_node_pos(id).distance_squared_to(recorder.get_node_pos(s_id))
				var eff_dist = true_dist / (s_speed * s_speed)
				
				if eff_dist < min_eff_dist:
					min_eff_dist = eff_dist
					closest_seed = s_id
					
			if closest_seed != "":
				var true_dist = recorder.get_node_pos(id).distance_squared_to(recorder.get_node_pos(closest_seed))
				if true_dist <= max_dist_sq:
					assigned_types[id] = assigned_types[closest_seed]
					recorder.set_node_type(id, assigned_types[closest_seed])
