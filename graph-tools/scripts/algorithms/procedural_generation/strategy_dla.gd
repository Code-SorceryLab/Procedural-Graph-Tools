class_name StrategyDLA
extends GraphStrategy

func _init() -> void:
	strategy_name = "Diffusion Aggregation"
	reset_on_generate = true
	supports_grow = true
	# [SEED FIX] Initialize the local RNG
	rng = RandomNumberGenerator.new()

func get_settings() -> Array[Dictionary]:
	# [SEED FIX] Inherit the base settings (the Seed Box)
	var settings: Array[Dictionary] = super.get_settings()
	
	settings.append_array([
		{ 
			"name": "particles", 
			"type": TYPE_INT, 
			"default": 100, 
			"min": 10, 
			"max": 2000,
			"hint": GraphSettings.PARAM_TOOLTIPS.dla.particles
		},
		{ 
			"name": "use_box", 
			"type": TYPE_BOOL, 
			"default": false,
			"hint": GraphSettings.PARAM_TOOLTIPS.dla.box_spawn
		},
		{ 
			"name": "gravity_bias", 
			"type": TYPE_FLOAT, 
			"default": 0.2, 
			"min": 0.0, 
			"max": 0.8, 
			"step": 0.05,
			"hint": GraphSettings.PARAM_TOOLTIPS.dla.gravity
		}
	])
	
	return settings

func execute(graph: GraphRecorder, params: Dictionary) -> void:
	# [SEED FIX] Setup Deterministic State for this run
	var raw_seed = params.get("strategy_seed", "")
	if raw_seed != "":
		my_seed = SeedUtils.hash_seed(raw_seed)
		rng.seed = my_seed
	else:
		rng.randomize() 
		my_seed = rng.seed

	var target_count = int(params.get("particles", 100))
	var use_box = params.get("use_box", false)
	var gravity = float(params.get("gravity_bias", 0.2))
	
	# Use Vector Spacing
	var spacing = GraphSettings.GRID_SPACING
	
	# Track independent X/Y extents for Elliptical Spawning
	var max_extents = Vector2(spacing.x, spacing.y) * 2.0
	
	# --- 1. BOUNDS CALCULATION (Fast) ---
	if not graph.nodes.is_empty():
		var stats = graph.get_spatial_stats()
		var bounds = stats["bounds"] as Rect2
		if bounds.has_area():
			var dist_x = max(abs(bounds.position.x), abs(bounds.position.x + bounds.size.x))
			var dist_y = max(abs(bounds.position.y), abs(bounds.position.y + bounds.size.y))
			max_extents.x = dist_x
			max_extents.y = dist_y
	
	var local_batch: Dictionary = {} 
	
	if graph.nodes.is_empty():
		_add_node_hybrid(graph, local_batch, Vector2i(0,0), spacing)
	
	# --- 2. SIMULATION ---
	var added_count = 0
	var safety_break = 0
	var MAX_LOOPS = target_count * 300 
	
	var spawn_buffer = spacing * 4.0
	var current_spawn_extents = max_extents + spawn_buffer
	
	while added_count < target_count:
		safety_break += 1
		if safety_break > MAX_LOOPS: break
		
		if added_count % 10 == 0:
			current_spawn_extents = max_extents + spawn_buffer
		
		var walker_pos = Vector2.ZERO
		
		if use_box:
			# [SEED FIX] Local RNG usage
			var side = rng.randi() % 4
			var off_x = rng.randf_range(-current_spawn_extents.x, current_spawn_extents.x)
			var off_y = rng.randf_range(-current_spawn_extents.y, current_spawn_extents.y)
			
			match side:
				0: walker_pos = Vector2(off_x, -current_spawn_extents.y) # Top
				1: walker_pos = Vector2(off_x, current_spawn_extents.y)  # Bottom
				2: walker_pos = Vector2(-current_spawn_extents.x, off_y) # Left
				3: walker_pos = Vector2(current_spawn_extents.x, off_y)  # Right
		else:
			# [SEED FIX] Local RNG usage
			var angle = rng.randf() * TAU
			walker_pos = Vector2(cos(angle) * current_spawn_extents.x, sin(angle) * current_spawn_extents.y)
			
		var current_grid_pos = Vector2i(round(walker_pos.x / spacing.x), round(walker_pos.y / spacing.y))
		
		var walking = true
		var steps = 0
		var max_steps = 1000 
		
		while walking and steps < max_steps:
			steps += 1
			
			var neighbor_id = _check_local_neighbors(local_batch, current_grid_pos)
			
			if neighbor_id == "":
				var check_pos = Vector2(current_grid_pos.x * spacing.x, current_grid_pos.y * spacing.y)
				var search_r = max(spacing.x, spacing.y) * 1.5
				var candidates = graph.get_nodes_near_position(check_pos, search_r)
				
				for cand_id in candidates:
					var cand_pos = graph.get_node_pos(cand_id)
					var dx = abs(cand_pos.x - check_pos.x)
					var dy = abs(cand_pos.y - check_pos.y)
					
					if dx < (spacing.x * 0.45) and dy < (spacing.y * 0.45):
						neighbor_id = cand_id
						break
			
			if neighbor_id != "":
				_add_node_hybrid(graph, local_batch, current_grid_pos, spacing)
				var my_id = local_batch[current_grid_pos]
				
				graph.add_edge(my_id, neighbor_id)
				
				var w_pos = Vector2(current_grid_pos.x * spacing.x, current_grid_pos.y * spacing.y)
				max_extents.x = max(max_extents.x, abs(w_pos.x))
				max_extents.y = max(max_extents.y, abs(w_pos.y))
				
				added_count += 1
				walking = false
			else:
				# [SEED FIX] Local RNG usage for gravity bias
				if rng.randf() < gravity:
					var diff = -current_grid_pos 
					if abs(diff.x) > abs(diff.y):
						current_grid_pos.x += sign(diff.x)
					else:
						current_grid_pos.y += sign(diff.y)
				else:
					# [SEED FIX] Deterministic array picking
					var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
					current_grid_pos += SeedUtils.pick_random(dirs, rng)
				
				var curr_world_x = float(current_grid_pos.x) * spacing.x
				var curr_world_y = float(current_grid_pos.y) * spacing.y
				
				if abs(curr_world_x) > (current_spawn_extents.x + 200) or abs(curr_world_y) > (current_spawn_extents.y + 200):
					walking = false

	params["out_highlight_nodes"] = local_batch.values()

# --- HELPER FUNCTIONS ---

func _vec_to_id(v: Vector2i) -> String:
	return "dla:%d:%d" % [v.x, v.y]

func _add_node_hybrid(graph: Graph, local_batch: Dictionary, grid_pos: Vector2i, spacing: Vector2) -> void:
	var id = _vec_to_id(grid_pos)
	if not local_batch.has(grid_pos):
		var world_pos = Vector2(grid_pos.x * spacing.x, grid_pos.y * spacing.y)
		graph.add_node(id, world_pos)
		local_batch[grid_pos] = id

func _check_local_neighbors(batch: Dictionary, pos: Vector2i) -> String:
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for d in dirs:
		var n_pos = pos + d
		if batch.has(n_pos):
			return batch[n_pos]
	return ""
