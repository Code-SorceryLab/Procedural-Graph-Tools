class_name StrategyBiomeFiller
extends GraphStrategy

func _init() -> void:
	strategy_name = "Biome Flood Fill"
	# Decorator that runs on existing nodes
	reset_on_generate = false 
	rng = RandomNumberGenerator.new()

func get_settings() -> Array[Dictionary]:
	var settings: Array[Dictionary] = super.get_settings()
	
	settings.append({ 
		"name": "use_spatial_fill", 
		"label": "Use Spatial Fill (XY)", 
		"type": TYPE_BOOL, 
		"default": false,
		"hint": "If enabled, biomes ignore corridors and fill based purely on physical distance (Standard Voronoi). If disabled, biomes respect graph topology (BFS)."
	})
	
	# Clear Previous
	settings.append({
		"name": "clear_previous_types",
		"label": "Clear Previous Types",
		"type": TYPE_BOOL,
		"default": true,
		"hint": "Sweeps the graph and resets all nodes to the default type before filling. Turn this off if you are layering multiple Biome Fillers on top of each other."
	})
	
	# Protect Existing Types
	settings.append({
		"name": "protect_existing",
		"label": "Protect Existing Types",
		"type": TYPE_BOOL,
		"default": false,
		"hint": "If enabled, manually painted rooms will not be cleared, and the flood fill will flow around them like rocks in a river."
	})
	
	# Max Expansion Radius
	settings.append({
		"name": "max_expansion_depth",
		"label": "Max Expansion Steps",
		"type": TYPE_INT,
		"default": 0,
		"min": 0,
		"max": 50,
		"hint": "Maximum number of corridors a biome can grow from its seed (0 = Infinite). Rooms further away remain untouched, creating neutral wilderness zones. (Topological Mode Only)"
	})
	
	# Seed Placement Strategy
	settings.append({
		"name": "evenly_space_seeds",
		"label": "Evenly Space Seeds",
		"type": TYPE_BOOL,
		"default": true,
		"hint": "If enabled, seeds are placed as far away from each other as possible for perfect coverage. If disabled, seeds are placed completely at random and may clump together."
	})
	
	settings.append({ 
		"name": "btn_biome_palette", "label": "Configure Biome Palette...", 
		"type": TYPE_NIL, "hint": "button" 
	})
	
	return settings

func get_palette_schema() -> Array[Dictionary]:
	var schema: Array[Dictionary] = []
	
	schema.append({ 
		"name": "seed_count", "label": "Number of Biome Seeds", "type": TYPE_INT, 
		"default": 5, "min": 1, "max": 100 
	})
	schema.append({ "name": "sep_biomes", "type": TYPE_NIL, "hint": "separator" })
	
	var node_cats = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE]
	for key in node_cats:
		# 1. The Enable Toggle
		schema.append({
			"name": "use_biome_" + key,
			"label": node_cats[key]["name"],
			"type": TYPE_BOOL,
			"default": false,
			"color": node_cats[key]["color"] 
		})
		
		# 2. The Growth Speed Slider
		schema.append({
			"name": "speed_biome_" + key,
			"label": "   └─ Growth Speed", # Indented visually!
			"type": TYPE_INT,
			"default": 1,
			"min": 1,
			"max": 5
		})
		
	return schema

func execute(recorder: GraphRecorder, params: Dictionary) -> void:
	var raw_seed = params.get("strategy_seed", "")
	if raw_seed != "":
		my_seed = SeedUtils.hash_seed(raw_seed)
		rng.seed = my_seed
	else:
		rng.randomize() 
		my_seed = rng.seed

	if recorder.nodes.is_empty():
		return

	# 1. Gather Allowed Biomes from UI
	var allowed_biomes: Array[String] = []
	var node_cats = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE]
	for key in node_cats:
		if params.get("use_biome_" + key, false):
			allowed_biomes.append(key)
			
	if allowed_biomes.is_empty():
		push_warning("Biome Filler: No biomes selected! Aborting.")
		return

	var seed_count = params.get("seed_count", 5)
	var use_spatial = params.get("use_spatial_fill", false) 
	var evenly_space = params.get("evenly_space_seeds", true)
	var max_depth = params.get("max_expansion_depth", 0)
	var clear_previous = params.get("clear_previous_types", true)
	var protect_existing = params.get("protect_existing", false) # [NEW] Read mask toggle
	
	# --- PHASE 1: Masking & Initial State ---
	var final_types = {}
	var assigned_types = {} # [MOVED UP] Pre-load protected nodes into the claimed list
	var initial_type_counts = {}
	
	for id in recorder.nodes:
		var original_type = recorder.nodes[id].type
		initial_type_counts[original_type] = initial_type_counts.get(original_type, 0) + 1
		
		# Does this node have a custom type, and are we protecting it?
		var is_protected = protect_existing and original_type != "empty"
		
		if is_protected:
			final_types[id] = original_type
			assigned_types[id] = original_type # Claim it immediately! BFS will bounce off this.
		elif clear_previous:
			final_types[id] = "empty"
		else:
			final_types[id] = original_type
			
	print("\n--- BIOME FILLER DEBUG ---")
	print("[1] Initial State: ", initial_type_counts)
	print("[1] Protected Nodes Count: ", assigned_types.size())

	# 2. Pick Starting Seeds (Deterministically)
	var all_nodes = recorder.nodes.keys()
	all_nodes.sort() 
	
	# Filter the pool so we don't drop seeds on top of protected rooms!
	var valid_seed_nodes = []
	for id in all_nodes:
		if not assigned_types.has(id):
			valid_seed_nodes.append(id)
			
	var actual_seed_count = min(seed_count, valid_seed_nodes.size())
	var seeds = []

	if not evenly_space:
		var pool = valid_seed_nodes.duplicate()
		for i in range(pool.size() - 1, 0, -1):
			var j = rng.randi() % (i + 1)
			var temp = pool[i]
			pool[i] = pool[j]
			pool[j] = temp
		seeds = pool.slice(0, actual_seed_count)
	else:
		if actual_seed_count > 0:
			var pool = valid_seed_nodes.duplicate()
			var first_idx = rng.randi() % pool.size()
			seeds.append(pool[first_idx])
			
			while seeds.size() < actual_seed_count:
				var max_min_dist = -1.0
				var best_candidate = ""
				
				# Iterate only over valid empty rooms
				for candidate_id in valid_seed_nodes:
					if seeds.has(candidate_id): continue
					var candidate_node = recorder.nodes[candidate_id] as NodeData
					var min_dist_to_seed = INF
					
					for s_id in seeds:
						var s_node = recorder.nodes[s_id] as NodeData
						var dist = candidate_node.position.distance_squared_to(s_node.position)
						if dist < min_dist_to_seed: min_dist_to_seed = dist
							
					if min_dist_to_seed > max_min_dist:
						max_min_dist = min_dist_to_seed
						best_candidate = candidate_id
				seeds.append(best_candidate)

	# --- [NEW] PRE-COMPUTE BIOME SPEEDS ---
	var biome_speeds = {}
	var max_speed = 1
	for b in allowed_biomes:
		var s = params.get("speed_biome_" + b, 1)
		biome_speeds[b] = s
		if s > max_speed: max_speed = s

	# 3. Assign Initial Types to Seeds
	var depths = {}
	var frontiers = {} # [NEW] Instead of one queue, every biome gets its own frontier!
	for b in allowed_biomes:
		frontiers[b] = []
	
	var biome_pool = allowed_biomes.duplicate()
	for i in range(biome_pool.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = biome_pool[i]
		biome_pool[i] = biome_pool[j]
		biome_pool[j] = temp

	for i in range(seeds.size()):
		var s_id = seeds[i]
		var b_type = biome_pool[i % biome_pool.size()] 
		assigned_types[s_id] = b_type
		final_types[s_id] = b_type
		depths[s_id] = 0
		frontiers[b_type].append(s_id) # [NEW] Add to this biome's specific queue

	# --- 4. THE FILLING ALGORITHMS ---
	if not use_spatial:
		# Mode A: Topological (Multi-Phase Graph Voronoi)
		var any_progress = true
		while any_progress:
			any_progress = false
			
			# Each "Round" is divided into phases. 
			# Speed 1 biomes only move in Phase 1. Speed 3 biomes move in Phase 1, 2, and 3!
			for phase in range(1, max_speed + 1):
				var next_frontiers = {}
				for b in allowed_biomes:
					next_frontiers[b] = []
					
				for b in allowed_biomes:
					if biome_speeds[b] < phase:
						# Biome is too slow to move this phase. Carry its frontier over unchanged.
						next_frontiers[b].append_array(frontiers[b])
						continue
						
					# Biome is fast enough to expand during this phase!
					for current in frontiers[b]:
						var current_depth = depths[current]
						
						if max_depth > 0 and current_depth >= max_depth:
							continue # Reached max radius, stop branching
							
						var neighbors = recorder.get_neighbors(current)
						neighbors.sort()
						for i in range(neighbors.size() - 1, 0, -1):
							var j = rng.randi() % (i + 1)
							var temp = neighbors[i]
							neighbors[i] = neighbors[j]
							neighbors[j] = temp
							
						for neighbor in neighbors:
							if not assigned_types.has(neighbor):
								assigned_types[neighbor] = b
								final_types[neighbor] = b
								depths[neighbor] = current_depth + 1
								next_frontiers[b].append(neighbor)
								any_progress = true
								
				frontiers = next_frontiers # Commit phase updates
	else:
		# Mode B: Spatial (Weighted Euclidean Voronoi)
		var max_physical_dist_sq = INF
		if max_depth > 0:
			max_physical_dist_sq = pow(max_depth * 150.0, 2)
			
		for id in recorder.nodes:
			if assigned_types.has(id): continue 
			
			var node = recorder.nodes[id] as NodeData
			var min_effective_dist = INF
			var closest_seed = ""
			
			for s_id in seeds:
				var s_type = assigned_types[s_id]
				var s_node = recorder.nodes[s_id] as NodeData
				var s_speed = float(biome_speeds[s_type])
				
				# Base physical distance
				var true_dist = node.position.distance_squared_to(s_node.position)
				
				# Aggressive biomes project their influence further by dividing the distance
				var effective_dist = true_dist / (s_speed * s_speed)
				
				if effective_dist < min_effective_dist:
					min_effective_dist = effective_dist
					closest_seed = s_id
					
			if closest_seed != "":
				var winning_s_node = recorder.nodes[closest_seed] as NodeData
				var true_dist = node.position.distance_squared_to(winning_s_node.position)
				
				# We check max_radius against the TRUE distance, not the effective distance
				if true_dist <= max_physical_dist_sq:
					assigned_types[id] = assigned_types[closest_seed]
					final_types[id] = assigned_types[closest_seed]

	# --- PHASE 2: Commit Changes ---
	var wipe_count = 0
	var paint_count = 0
	var skip_count = 0
	
	for id in final_types:
		if recorder.nodes[id].type != final_types[id]:
			if final_types[id] == "empty":
				wipe_count += 1
			else:
				paint_count += 1
			recorder.set_node_type(id, final_types[id])
		else:
			skip_count += 1
			
	print("[2] Commands -> Wiped: ", wipe_count, " | Painted: ", paint_count, " | Skipped: ", skip_count)
	print("---------------------------\n")
