extends GraphStrategy
class_name StrategyDLA

func _init() -> void:
	strategy_name = "Diffusion Aggregation (DLA)"
	required_params = ["particles"]
	toggle_text = "Use Box Spawning"
	toggle_key = "use_box"

func execute(graph: Graph, params: Dictionary) -> void:
	var target_count = params.get("particles", 100)
	var use_box = params.get("use_box", false)
	var append_mode = params.get("append", false)
	
	var max_radius = 2.0 

	# --- 1. BUILD SPATIAL LOOKUP ---
	# This Dictionary maps Vector2i(x,y) -> String(ID)
	# It allows us to find manual nodes ("1", "2") by their grid position.
	var occupied_grid := {}
	
	if not graph.nodes.is_empty():
		for id in graph.nodes:
			var world_pos = graph.get_node_pos(id)
			# Snap world pos to grid pos
			var gx = round(world_pos.x / GraphSettings.CELL_SIZE)
			var gy = round(world_pos.y / GraphSettings.CELL_SIZE)
			var gpos = Vector2i(gx, gy)
			
			occupied_grid[gpos] = id
			
			# Also calc max_radius while we are here
			var dist = gpos.length()
			if use_box:
				dist = max(abs(gpos.x), abs(gpos.y))
			if dist > max_radius:
				max_radius = dist

	# --- 2. SETUP PHASE ---
	if not append_mode:
		graph.nodes.clear()
		occupied_grid.clear() # Clear lookup if resetting
		var center = Vector2i(0, 0)
		_add_grid_node(graph, occupied_grid, center) # Pass lookup
	else:
		if graph.nodes.is_empty():
			var center = Vector2i(0, 0)
			_add_grid_node(graph, occupied_grid, center)

	# --- 3. SIMULATION PHASE ---
	var nodes_to_add = target_count
	if not append_mode:
		nodes_to_add = target_count - 1
		
	var added_so_far = 0
	
	# Safety Counter to prevent infinite loops if spawn is bad
	var safety_break = 0 
	var MAX_LOOPS = 100000 
	
	while added_so_far < nodes_to_add:
		safety_break += 1
		if safety_break > MAX_LOOPS:
			push_error("DLA Emergency Break: Infinite Loop detected.")
			break

		# A. Determine Spawn Position
		var spawn_radius = max_radius + 5.0 
		var particle_pos = Vector2i.ZERO
		
		if use_box:
			var side = randi() % 4
			var offset = randf_range(-spawn_radius, spawn_radius)
			match side:
				0: particle_pos = Vector2i(int(offset), int(-spawn_radius))
				1: particle_pos = Vector2i(int(offset), int(spawn_radius))
				2: particle_pos = Vector2i(int(-spawn_radius), int(offset))
				3: particle_pos = Vector2i(int(spawn_radius), int(offset))
		else:
			var angle = randf() * TAU
			var px = int(cos(angle) * spawn_radius)
			var py = int(sin(angle) * spawn_radius)
			particle_pos = Vector2i(px, py)

		# B. Random Walk Loop
		var walking = true
		while walking:
			# Pass occupied_grid instead of graph
			var neighbor_id = _get_touching_neighbor(occupied_grid, particle_pos)
			
			if neighbor_id != "":
				_add_grid_node(graph, occupied_grid, particle_pos)
				graph.add_edge(_vec_to_id(particle_pos), neighbor_id)
				
				var dist = particle_pos.length()
				if use_box:
					dist = max(abs(particle_pos.x), abs(particle_pos.y))
				
				if dist > max_radius:
					max_radius = dist
				
				added_so_far += 1
				walking = false
			else:
				var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
				particle_pos += dirs.pick_random()
				
				if particle_pos.length() > spawn_radius + 15.0:
					walking = false 

# --- UPDATED HELPERS ---

func _vec_to_id(v: Vector2i) -> String:
	return "%d_%d" % [v.x, v.y]

# Now accepts and updates the 'occupied' lookup
func _add_grid_node(graph: Graph, occupied: Dictionary, grid_pos: Vector2i) -> void:
	var id = _vec_to_id(grid_pos)
	
	# Check lookup, not graph.nodes, to be safe
	if not occupied.has(grid_pos):
		var world_pos = Vector2(grid_pos.x * GraphSettings.CELL_SIZE, grid_pos.y * GraphSettings.CELL_SIZE)
		graph.add_node(id, world_pos)
		occupied[grid_pos] = id # Register new node

# Now checks the lookup dictionary
func _get_touching_neighbor(occupied: Dictionary, pos: Vector2i) -> String:
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for d in dirs:
		var neighbor_pos = pos + d
		if occupied.has(neighbor_pos):
			return occupied[neighbor_pos]
	return ""
