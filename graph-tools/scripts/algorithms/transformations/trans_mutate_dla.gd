class_name MutateDLA extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Diffusion Aggregation"
	category = Category.TOPOLOGY # Attach to existing, or grow from center!

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "particles", "type": TYPE_INT, "default": 100, "min": 10, "max": 2000 },
		{ "name": "use_box", "label": "Spawn from Box", "type": TYPE_BOOL, "default": false },
		{ "name": "gravity_bias", "type": TYPE_FLOAT, "default": 0.2, "min": 0.0, "max": 0.8, "step": 0.05 }
	])
	return s

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	
	var target_count = local_settings.get("particles", 100)
	var use_box = local_settings.get("use_box", false)
	var gravity = float(local_settings.get("gravity_bias", 0.2))
	var spacing = GraphSettings.GRID_SPACING
	var max_extents = Vector2(spacing.x, spacing.y) * 2.0
	
	# Calculate bounds of whatever ALREADY exists in the graph
	if not recorder.nodes.is_empty():
		var min_pos = Vector2(INF, INF)
		var max_pos = Vector2(-INF, -INF)
		for id in recorder.nodes:
			var p = recorder.get_node_pos(id)
			if p.x < min_pos.x: min_pos.x = p.x
			if p.y < min_pos.y: min_pos.y = p.y
			if p.x > max_pos.x: max_pos.x = p.x
			if p.y > max_pos.y: max_pos.y = p.y
			
		max_extents.x = max(abs(min_pos.x), abs(max_pos.x))
		max_extents.y = max(abs(min_pos.y), abs(max_pos.y))
	
	var local_batch: Dictionary = {} 
	
	# If graph is totally empty, seed the center!
	if recorder.nodes.is_empty():
		_add_node_hybrid(recorder, local_batch, Vector2i(0,0), spacing)
		
	# Populate local_batch with existing nodes so DLA collides with them
	for id in recorder.nodes:
		var pos = recorder.get_node_pos(id)
		var grid_pos = Vector2i(round(pos.x / spacing.x), round(pos.y / spacing.y))
		local_batch[grid_pos] = id

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
			var side = rng.randi() % 4
			var off_x = rng.randf_range(-current_spawn_extents.x, current_spawn_extents.x)
			var off_y = rng.randf_range(-current_spawn_extents.y, current_spawn_extents.y)
			match side:
				0: walker_pos = Vector2(off_x, -current_spawn_extents.y)
				1: walker_pos = Vector2(off_x, current_spawn_extents.y) 
				2: walker_pos = Vector2(-current_spawn_extents.x, off_y)
				3: walker_pos = Vector2(current_spawn_extents.x, off_y) 
		else:
			var angle = rng.randf() * TAU
			walker_pos = Vector2(cos(angle) * current_spawn_extents.x, sin(angle) * current_spawn_extents.y)
			
		var current_grid_pos = Vector2i(round(walker_pos.x / spacing.x), round(walker_pos.y / spacing.y))
		var walking = true
		var steps = 0
		
		while walking and steps < 1000:
			steps += 1
			
			var neighbor_id = ""
			var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
			for d in dirs:
				if local_batch.has(current_grid_pos + d):
					neighbor_id = local_batch[current_grid_pos + d]
					break
			
			if neighbor_id != "":
				_add_node_hybrid(recorder, local_batch, current_grid_pos, spacing)
				var my_id = local_batch[current_grid_pos]
				
				recorder.add_edge(my_id, neighbor_id)
				
				var w_pos = Vector2(current_grid_pos.x * spacing.x, current_grid_pos.y * spacing.y)
				max_extents.x = max(max_extents.x, abs(w_pos.x))
				max_extents.y = max(max_extents.y, abs(w_pos.y))
				
				added_count += 1
				walking = false
			else:
				if rng.randf() < gravity:
					var diff = -current_grid_pos 
					if abs(diff.x) > abs(diff.y): current_grid_pos.x += sign(diff.x)
					else: current_grid_pos.y += sign(diff.y)
				else:
					current_grid_pos += SeedUtils.pick_random(dirs, rng)
					
				var w_x = float(current_grid_pos.x) * spacing.x
				var w_y = float(current_grid_pos.y) * spacing.y
				if abs(w_x) > (current_spawn_extents.x + 200) or abs(w_y) > (current_spawn_extents.y + 200):
					walking = false

func _vec_to_id(v: Vector2i) -> String:
	return "dla:%d:%d" % [v.x, v.y]

func _add_node_hybrid(recorder: GraphRecorder, local_batch: Dictionary, grid_pos: Vector2i, spacing: Vector2) -> void:
	var id = _vec_to_id(grid_pos)
	if not local_batch.has(grid_pos):
		var world_pos = Vector2(grid_pos.x * spacing.x, grid_pos.y * spacing.y)
		recorder.add_node(id, world_pos)
		local_batch[grid_pos] = id
