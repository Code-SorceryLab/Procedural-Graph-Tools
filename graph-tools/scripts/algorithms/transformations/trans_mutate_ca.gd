class_name MutateCA extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Cellular Automata"
	category = Category.TOPOLOGY

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "fill_percent", "label": "Initial Fill (%)", "type": TYPE_INT, "default": 55, "min": 10, "max": 100, "hint_text": "Randomly deletes nodes before simulating. (100% = solid block)" },
		{ "name": "iterations", "label": "Smoothing Passes", "type": TYPE_INT, "default": 4, "min": 0, "max": 10 },
		{ "name": "carve_only", "label": "Carve Only (No Births)", "type": TYPE_BOOL, "default": true, "hint_text": "If true, nodes can only be destroyed, never created. Keeps the outer silhouette of the graph intact." }
	])
	return s

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	if recorder.nodes.is_empty(): return
	
	var fill_prob = local_settings.get("fill_percent", 55) / 100.0
	var steps = local_settings.get("iterations", 4)
	var carve_only = local_settings.get("carve_only", true)
	var spacing = GraphSettings.GRID_SPACING
	
	# 1. Map existing graph to a spatial grid
	var grid = {}
	var original_nodes = {}
	var min_p = Vector2i(INF, INF)
	var max_p = Vector2i(-INF, -INF)
	
	for id in recorder.nodes:
		var pos = recorder.get_node_pos(id)
		var grid_pos = Vector2i(round(pos.x / spacing.x), round(pos.y / spacing.y))
		
		# Apply Initial Noise
		var is_alive = rng.randf() < fill_prob
		grid[grid_pos] = is_alive
		original_nodes[grid_pos] = id
		
		min_p.x = min(min_p.x, grid_pos.x); min_p.y = min(min_p.y, grid_pos.y)
		max_p.x = max(max_p.x, grid_pos.x); max_p.y = max(max_p.y, grid_pos.y)

	# 2. Simulation Loop
	for iter in range(steps):
		var next_grid = {}
		
		# If carving only, we only evaluate cells that originally existed.
		# Otherwise, we evaluate the entire bounding box to allow growth into empty space!
		var eval_min = min_p if not carve_only else Vector2i.ZERO
		var eval_max = max_p if not carve_only else Vector2i.ZERO
		
		var cells_to_eval = original_nodes.keys()
		if not carve_only:
			cells_to_eval.clear()
			for x in range(min_p.x - 1, max_p.x + 2):
				for y in range(min_p.y - 1, max_p.y + 2):
					cells_to_eval.append(Vector2i(x, y))
					
		for pos in cells_to_eval:
			var neighbors = 0
			for i in range(-1, 2):
				for j in range(-1, 2):
					if i == 0 and j == 0: continue
					var n_pos = pos + Vector2i(i, j)
					
					# Walls/Bounds count as alive
					if carve_only and not original_nodes.has(n_pos):
						neighbors += 1 
					elif grid.get(n_pos, false):
						neighbors += 1
						
			var was_alive = grid.get(pos, false)
			# Standard Cave Rule: Survive >= 4, Birth >= 5
			if was_alive: next_grid[pos] = (neighbors >= 4)
			elif not carve_only: next_grid[pos] = (neighbors >= 5)
			else: next_grid[pos] = false
			
		grid = next_grid

	# 3. Apply Diff to Sandbox
	for pos in grid:
		var is_alive = grid[pos]
		var id = original_nodes.get(pos, "")
		
		if id != "" and not is_alive:
			recorder.remove_node(id) # Died!
		elif id == "" and is_alive:
			# Birthed! Create a new node
			var new_id = "ca_born_%d_%d" % [pos.x, pos.y]
			var w_pos = Vector2(pos.x * spacing.x, pos.y * spacing.y)
			recorder.add_node(new_id, w_pos)
			original_nodes[pos] = new_id
			
			# Connect to existing adjacent orthogonal neighbors
			for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				if grid.get(pos + d, false) and original_nodes.has(pos + d):
					recorder.add_edge(new_id, original_nodes[pos + d])
