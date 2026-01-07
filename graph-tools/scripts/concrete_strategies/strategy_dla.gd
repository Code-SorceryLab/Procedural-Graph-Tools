class_name StrategyDLA
extends GraphStrategy

func _init() -> void:
	strategy_name = "Diffusion Aggregation"
	reset_on_generate = true
	supports_grow = true

func get_settings() -> Array[Dictionary]:
	return [
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
	]

func execute(graph: GraphRecorder, params: Dictionary) -> void:
	var target_count = int(params.get("particles", 100))
	var use_box = params.get("use_box", false)
	var gravity = float(params.get("gravity_bias", 0.2))
	
	var max_radius = 2.0
	var cell_size = GraphSettings.CELL_SIZE
	var strict_limit_sq = (cell_size * 1.05) ** 2
	
	# --- 1. BOUNDS CALCULATION (Fast) ---
	# We don't cache the whole graph, just checking bounds for spawn radius.
	if not graph.nodes.is_empty():
		var stats = graph.get_spatial_stats()
		var bounds = stats["bounds"] as Rect2
		if bounds.has_area():
			var center_dist = max(abs(bounds.position.x), abs(bounds.position.x + bounds.size.x))
			var center_dist_y = max(abs(bounds.position.y), abs(bounds.position.y + bounds.size.y))
			max_radius = max(center_dist, center_dist_y)
	
	# Local batch only stores the NEW nodes we create during this run.
	var local_batch: Dictionary = {} 
	
	# Seed center if totally empty
	if graph.nodes.is_empty():
		_add_node_hybrid(graph, local_batch, Vector2i(0,0), cell_size)
	
	# --- 2. SIMULATION ---
	var added_count = 0
	var safety_break = 0
	var MAX_LOOPS = target_count * 300 
	
	var spawn_r = max_radius + 50.0
	
	while added_count < target_count:
		safety_break += 1
		if safety_break > MAX_LOOPS: break
		
		# Dynamic Radius growth
		if added_count % 10 == 0:
			spawn_r = max_radius + 50.0
		
		var walker_pos = Vector2.ZERO
		
		if use_box:
			var side = randi() % 4
			var offset = randf_range(-spawn_r, spawn_r)
			match side:
				0: walker_pos = Vector2(offset, -spawn_r)
				1: walker_pos = Vector2(offset, spawn_r)
				2: walker_pos = Vector2(-spawn_r, offset)
				3: walker_pos = Vector2(spawn_r, offset)
		else:
			var angle = randf() * TAU
			walker_pos = Vector2(cos(angle), sin(angle)) * spawn_r
			
		var current_grid_pos = Vector2i(round(walker_pos.x / cell_size), round(walker_pos.y / cell_size))
		
		var walking = true
		var steps = 0
		var max_steps = 1000 
		
		while walking and steps < max_steps:
			steps += 1
			
			# 1. Check Local Batch (Fastest)
			var neighbor_id = _check_local_neighbors(local_batch, current_grid_pos)
			
			# 2. Check Static Graph (Spatial Grid)
			# Only check if we didn't hit a new node
			if neighbor_id == "":
				# FIX: We query the CENTER of the current grid cell.
				# This ensures that even if a manual node is off-center, 
				# the spatial grid will find it because we search with a radius > cell_size.
				var check_pos = Vector2(current_grid_pos.x * cell_size, current_grid_pos.y * cell_size)
				
				# We assume the recorder has access to the target graph's spatial query
				# If using the basic GraphRecorder, we might need to expose this.
				var candidates = graph.get_nodes_near_position(check_pos, cell_size * 1.2)
				
				for cand_id in candidates:
					# We consider it a hit if it's within "Snap Distance"
					var cand_pos = graph.get_node_pos(cand_id)
					if check_pos.distance_squared_to(cand_pos) < strict_limit_sq:
						neighbor_id = cand_id
						break
			
			if neighbor_id != "":
				_add_node_hybrid(graph, local_batch, current_grid_pos, cell_size)
				var my_id = local_batch[current_grid_pos]
				
				graph.add_edge(my_id, neighbor_id)
				
				var dist = float(current_grid_pos.length()) * cell_size
				if dist > max_radius: max_radius = dist
				
				added_count += 1
				walking = false
			else:
				# Gravity Bias Logic
				if randf() < gravity:
					var diff = -current_grid_pos 
					if abs(diff.x) > abs(diff.y):
						current_grid_pos.x += sign(diff.x)
					else:
						current_grid_pos.y += sign(diff.y)
				else:
					var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
					current_grid_pos += dirs.pick_random()
				
				var curr_dist = float(current_grid_pos.length()) * cell_size
				if curr_dist > spawn_r + 200.0:
					walking = false

	# 4. Highlight Output
	params["out_highlight_nodes"] = local_batch.values()

# --- HELPER FUNCTIONS ---

func _vec_to_id(v: Vector2i) -> String:
	return "dla:%d:%d" % [v.x, v.y]

func _add_node_hybrid(graph: Graph, local_batch: Dictionary, grid_pos: Vector2i, cell_size: float) -> void:
	var id = _vec_to_id(grid_pos)
	if not local_batch.has(grid_pos):
		var world_pos = Vector2(grid_pos.x * cell_size, grid_pos.y * cell_size)
		graph.add_node(id, world_pos)
		local_batch[grid_pos] = id

func _check_local_neighbors(batch: Dictionary, pos: Vector2i) -> String:
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for d in dirs:
		var n_pos = pos + d
		if batch.has(n_pos):
			return batch[n_pos]
	return ""
