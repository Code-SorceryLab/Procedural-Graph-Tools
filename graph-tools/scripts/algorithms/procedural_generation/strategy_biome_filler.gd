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
		"name": "seed_count", "label": "Number of Biomes", "type": TYPE_INT, "default": 5, "min": 1, "max": 100,
		"hint": "How many starting seeds to drop into the graph before expanding."
	})
	
	settings.append({ "name": "sep_biomes", "type": TYPE_NIL, "hint": "separator" })
	
	# Dynamically generate a toggle for EVERY semantic node type!
	var node_cats = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE]
	for key in node_cats:
		settings.append({
			"name": "use_biome_" + key,
			"label": "Allow: " + node_cats[key]["name"],
			"type": TYPE_BOOL,
			"default": false # Default to false so the user actively curates the palette
		})
		
	return settings

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

	# 2. Pick Starting Seeds (Deterministically)
	var all_nodes = recorder.nodes.keys()
	all_nodes.sort() # Must sort first! Godot Dictionary key order is NOT deterministic.
	
	# Custom deterministic shuffle
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
	
	# Deterministically shuffle the biome palette so it varies per run
	var biome_pool = allowed_biomes.duplicate()
	for i in range(biome_pool.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = biome_pool[i]
		biome_pool[i] = biome_pool[j]
		biome_pool[j] = temp

	for i in range(seeds.size()):
		var s_id = seeds[i]
		# Cycle through the randomized palette (allows 10 seeds using 3 biomes)
		var b_type = biome_pool[i % biome_pool.size()] 
		assigned_types[s_id] = b_type
		queue.append(s_id)

	# 4. Multi-Source Breadth-First Search (Graph Voronoi Expansion)
	while not queue.is_empty():
		var current = queue.pop_front()
		var current_type = assigned_types[current]

		# Get neighbors and sort them for deterministic behavior
		var neighbors = recorder.get_neighbors(current)
		neighbors.sort()
		
		# Shuffle neighbor processing order so the biome borders look organic 
		# instead of expanding in perfect geometric diamonds!
		for i in range(neighbors.size() - 1, 0, -1):
			var j = rng.randi() % (i + 1)
			var temp = neighbors[i]
			neighbors[i] = neighbors[j]
			neighbors[j] = temp

		for neighbor in neighbors:
			if not assigned_types.has(neighbor):
				assigned_types[neighbor] = current_type
				queue.append(neighbor)

	# 5. Commit Changes to the Graph
	for id in assigned_types:
		if recorder.nodes[id].type != assigned_types[id]:
			recorder.set_node_type(id, assigned_types[id])
