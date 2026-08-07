class_name StrategyBiomeFiller
extends GraphStrategy

func _init() -> void:
	strategy_name = "Biome Flood Fill"
	# Decorator that runs on existing nodes
	reset_on_generate = false 
	rng = RandomNumberGenerator.new()

func get_settings() -> Array[Dictionary]:
	var settings: Array[Dictionary] = super.get_settings()
	
	# The Spatial Toggle (placed directly in the sidebar for easy access)
	settings.append({ 
		"name": "use_spatial_fill", 
		"label": "Use Spatial Fill (XY)", 
		"type": TYPE_BOOL, 
		"default": false,
		"hint": "If enabled, biomes ignore corridors and fill based purely on physical distance (Standard Voronoi). If disabled, biomes respect graph topology (BFS)."
	})
	
	settings.append({ 
		"name": "btn_biome_palette", "label": "Configure Biome Palette...", 
		"type": TYPE_NIL, "hint": "button" 
	})
	
	return settings

# Function to serve the schema specifically to the popup
func get_palette_schema() -> Array[Dictionary]:
	var schema: Array[Dictionary] = []
	
	schema.append({ 
		"name": "seed_count", "label": "Number of Biome Seeds", "type": TYPE_INT, 
		"default": 5, "min": 1, "max": 100 
	})
	schema.append({ "name": "sep_biomes", "type": TYPE_NIL, "hint": "separator" })
	
	# Dynamically generate a toggle for EVERY semantic node type, WITH its color!
	var node_cats = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE]
	for key in node_cats:
		schema.append({
			"name": "use_biome_" + key,
			"label": node_cats[key]["name"],
			"type": TYPE_BOOL,
			"default": false,
			"color": node_cats[key]["color"] # Pass the color to the popup engine!
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
	var use_spatial = params.get("use_spatial_fill", false) # [NEW] Read the toggle

	# 2. Pick Starting Seeds (Deterministically)
	var all_nodes = recorder.nodes.keys()
	all_nodes.sort() 
	
	var pool = all_nodes.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = pool[i]
		pool[i] = pool[j]
		pool[j] = temp

	var actual_seed_count = min(seed_count, pool.size())
	var seeds = pool.slice(0, actual_seed_count)

	# 3. Assign Initial Types to Seeds
	var assigned_types = {}
	var queue = []
	
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
		queue.append(s_id)

	# --- 4. THE FILLING ALGORITHMS ---
	
	if not use_spatial:
		# Mode A: Topological (Graph Voronoi / BFS)
		while not queue.is_empty():
			var current = queue.pop_front()
			var current_type = assigned_types[current]
	
			var neighbors = recorder.get_neighbors(current)
			neighbors.sort()
			
			for i in range(neighbors.size() - 1, 0, -1):
				var j = rng.randi() % (i + 1)
				var temp = neighbors[i]
				neighbors[i] = neighbors[j]
				neighbors[j] = temp
	
			for neighbor in neighbors:
				if not assigned_types.has(neighbor):
					assigned_types[neighbor] = current_type
					queue.append(neighbor)
	else:
		# Mode B: Spatial (Euclidean Voronoi)
		for id in recorder.nodes:
			# Skip the seeds themselves, they are already assigned
			if assigned_types.has(id): continue 
			
			var node = recorder.nodes[id] as NodeData
			var min_dist = INF
			var closest_seed = ""
			
			# Find the physically closest seed in 2D space
			for s_id in seeds:
				var s_node = recorder.nodes[s_id] as NodeData
				var dist = node.position.distance_squared_to(s_node.position)
				
				if dist < min_dist:
					min_dist = dist
					closest_seed = s_id
					
			if closest_seed != "":
				assigned_types[id] = assigned_types[closest_seed]

	# 5. Commit Changes to the Graph
	for id in assigned_types:
		if recorder.nodes[id].type != assigned_types[id]:
			recorder.set_node_type(id, assigned_types[id])
