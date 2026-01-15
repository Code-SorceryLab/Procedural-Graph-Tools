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
	
	# [REFACTOR 1] Use Vector Spacing
	var spacing = GraphSettings.GRID_SPACING
	
	# Track independent X/Y extents for Elliptical Spawning
	# Start with a tiny buffer
	var max_extents = Vector2(spacing.x, spacing.y) * 2.0
	
	# --- 1. BOUNDS CALCULATION (Fast) ---
	# We don't cache the whole graph, just checking bounds for spawn radius.
	if not graph.nodes.is_empty():
		var stats = graph.get_spatial_stats()
		var bounds = stats["bounds"] as Rect2
		if bounds.has_area():
			# Calculate max reach from center (0,0) for both axes
			var dist_x = max(abs(bounds.position.x), abs(bounds.position.x + bounds.size.x))
			var dist_y = max(abs(bounds.position.y), abs(bounds.position.y + bounds.size.y))
			max_extents.x = dist_x
			max_extents.y = dist_y
	
	# Local batch only stores the NEW nodes we create during this run.
	var local_batch: Dictionary = {} 
	
	# Seed center if totally empty
	if graph.nodes.is_empty():
		_add_node_hybrid(graph, local_batch, Vector2i(0,0), spacing)
	
	# --- 2. SIMULATION ---
	var added_count = 0
	var safety_break = 0
	var MAX_LOOPS = target_count * 300 
	
	# Dynamic Spawn Boundary (Vector)
	# We add a buffer relative to the grid spacing
	var spawn_buffer = spacing * 4.0
	var current_spawn_extents = max_extents + spawn_buffer
	
	while added_count < target_count:
		safety_break += 1
		if safety_break > MAX_LOOPS: break
		
		# Grow the spawn ellipse periodically
		if added_count % 10 == 0:
			current_spawn_extents = max_extents + spawn_buffer
		
		var walker_pos = Vector2.ZERO
		
		if use_box:
			# Box Spawn: Scale offsets by our ellipse extents
			var side = randi() % 4
			# We randomize along the 'long' side of the box for the chosen axis
			var off_x = randf_range(-current_spawn_extents.x, current_spawn_extents.x)
			var off_y = randf_range(-current_spawn_extents.y, current_spawn_extents.y)
			
			match side:
				0: walker_pos = Vector2(off_x, -current_spawn_extents.y) # Top
				1: walker_pos = Vector2(off_x, current_spawn_extents.y)  # Bottom
				2: walker_pos = Vector2(-current_spawn_extents.x, off_y) # Left
				3: walker_pos = Vector2(current_spawn_extents.x, off_y)  # Right
		else:
			# [REFACTOR 2] Elliptical Spawn
			var angle = randf() * TAU
			# Multiply unit circle by our X/Y extents
			walker_pos = Vector2(cos(angle) * current_spawn_extents.x, sin(angle) * current_spawn_extents.y)
			
		# Convert World Float -> Grid Integer
		var current_grid_pos = Vector2i(round(walker_pos.x / spacing.x), round(walker_pos.y / spacing.y))
		
		var walking = true
		var steps = 0
		var max_steps = 1000 
		
		while walking and steps < max_steps:
			steps += 1
			
			# A. Check Local Batch (Fast Integer Check)
			var neighbor_id = _check_local_neighbors(local_batch, current_grid_pos)
			
			# B. Check Static Graph (Spatial World Check)
			if neighbor_id == "":
				# Center of the current logical grid cell
				var check_pos = Vector2(current_grid_pos.x * spacing.x, current_grid_pos.y * spacing.y)
				
				# Search radius should be slightly larger than the largest cell dimension to catch diagonals
				var search_r = max(spacing.x, spacing.y) * 1.5
				var candidates = graph.get_nodes_near_position(check_pos, search_r)
				
				for cand_id in candidates:
					var cand_pos = graph.get_node_pos(cand_id)
					var dx = abs(cand_pos.x - check_pos.x)
					var dy = abs(cand_pos.y - check_pos.y)
					
					# [REFACTOR 3] Strict Limit via Axis Checking
					# We only snap if we are strictly inside the cell's ownership area
					if dx < (spacing.x * 0.45) and dy < (spacing.y * 0.45):
						neighbor_id = cand_id
						break
			
			if neighbor_id != "":
				# --- ATTACH ---
				_add_node_hybrid(graph, local_batch, current_grid_pos, spacing)
				var my_id = local_batch[current_grid_pos]
				
				graph.add_edge(my_id, neighbor_id)
				
				# Update Extents for next spawn
				# We calculate world distance from center to update the ellipse bounds
				var w_pos = Vector2(current_grid_pos.x * spacing.x, current_grid_pos.y * spacing.y)
				max_extents.x = max(max_extents.x, abs(w_pos.x))
				max_extents.y = max(max_extents.y, abs(w_pos.y))
				
				added_count += 1
				walking = false
			else:
				# --- WALK ---
				# Gravity Bias Logic (Grid based)
				if randf() < gravity:
					# Move towards (0,0) in grid units
					var diff = -current_grid_pos 
					if abs(diff.x) > abs(diff.y):
						current_grid_pos.x += sign(diff.x)
					else:
						current_grid_pos.y += sign(diff.y)
				else:
					# Random Walk
					var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
					current_grid_pos += dirs.pick_random()
				
				# Bounds Check (Optimization)
				# If we wandered excessively far outside the current spawn bounds, kill the particle
				# We use a loose ellipse check
				var curr_world_x = float(current_grid_pos.x) * spacing.x
				var curr_world_y = float(current_grid_pos.y) * spacing.y
				
				# "Loose" means we allow it to be a bit further than spawn before killing
				if abs(curr_world_x) > (current_spawn_extents.x + 200) or abs(curr_world_y) > (current_spawn_extents.y + 200):
					walking = false

	# 4. Highlight Output
	params["out_highlight_nodes"] = local_batch.values()

# --- HELPER FUNCTIONS ---

func _vec_to_id(v: Vector2i) -> String:
	return "dla:%d:%d" % [v.x, v.y]

func _add_node_hybrid(graph: Graph, local_batch: Dictionary, grid_pos: Vector2i, spacing: Vector2) -> void:
	var id = _vec_to_id(grid_pos)
	if not local_batch.has(grid_pos):
		# [REFACTOR 4] Use vector multiplication for position
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
