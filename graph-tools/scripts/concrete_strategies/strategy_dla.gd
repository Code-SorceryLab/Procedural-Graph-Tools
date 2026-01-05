class_name StrategyDLA
extends GraphStrategy

func _init() -> void:
	strategy_name = "Diffusion Aggregation"
	# "particles" is the main input, "toggle" is handled by the generic UI
	required_params = ["particles"]
	toggle_text = "Use Box Spawning"
	toggle_key = "use_box"
	
	# DLA is a Generator, so by default it wants a clean slate.
	# The Controller handles clearing the graph if 'Generate' is clicked.
	# If 'Grow' is clicked, the Controller skips the clear, allowing 'append'.
	reset_on_generate = true 

func execute(graph: Graph, params: Dictionary) -> void:
	var target_count = params.get("particles", 100)
	var use_box = params.get("use_box", false)
	# Note: We rely on graph state for 'append', but we can check the flag if needed.
	
	var max_radius = 2.0 

	# --- 1. BUILD SPATIAL LOOKUP ---
	# Map Vector2i(x,y) -> String(ID)
	# This is crucial for "Grow" mode: we need to know where existing nodes are.
	var occupied_grid := {}
	
	if not graph.nodes.is_empty():
		for id in graph.nodes:
			var world_pos = graph.nodes[id].position
			# Snap world pos to grid pos
			var gx = round(world_pos.x / GraphSettings.CELL_SIZE)
			var gy = round(world_pos.y / GraphSettings.CELL_SIZE)
			var gpos = Vector2i(gx, gy)
			
			occupied_grid[gpos] = id
			
			# Recalculate max_radius so we spawn outside the existing blob
			var dist = float(gpos.length()) # Use float cast for safety
			if use_box:
				dist = float(max(abs(gpos.x), abs(gpos.y)))
			if dist > max_radius:
				max_radius = dist

	# --- 2. SEEDING PHASE ---
	# If the graph is empty (because Controller cleared it), plant the seed.
	if graph.nodes.is_empty():
		var center = Vector2i(0, 0)
		_add_dla_node(graph, occupied_grid, center)

	# --- 3. SIMULATION PHASE ---
	# We want to ADD 'target_count' new particles.
	# (If we wanted 'total count', we would subtract graph.nodes.size())
	var nodes_to_add = target_count
	var added_so_far = 0
	
	# Safety Counters
	var safety_break = 0 
	var MAX_LOOPS = nodes_to_add * 200 # Allow some failed walks
	
	while added_so_far < nodes_to_add:
		safety_break += 1
		if safety_break > MAX_LOOPS:
			push_warning("DLA: Max loops reached. Stopping early.")
			break

		# A. Determine Spawn Position
		# Spawn slightly outside the current max radius
		var spawn_radius = max_radius + 5.0 
		var particle_pos = Vector2i.ZERO
		
		if use_box:
			# Box Logic (Preserved)
			var side = randi() % 4
			var offset = randf_range(-spawn_radius, spawn_radius)
			match side:
				0: particle_pos = Vector2i(int(offset), int(-spawn_radius)) # Top edge
				1: particle_pos = Vector2i(int(offset), int(spawn_radius))  # Bottom edge
				2: particle_pos = Vector2i(int(-spawn_radius), int(offset)) # Left edge
				3: particle_pos = Vector2i(int(spawn_radius), int(offset))  # Right edge
		else:
			# Circle Logic (Standard)
			var angle = randf() * TAU
			var px = int(cos(angle) * spawn_radius)
			var py = int(sin(angle) * spawn_radius)
			particle_pos = Vector2i(px, py)

		# B. Random Walk Loop
		var walking = true
		var step_limit = 500 # Prevent single particle wandering forever
		var steps = 0
		
		while walking and steps < step_limit:
			steps += 1
			
			# Check for neighbors BEFORE moving (Sticky behavior)
			var neighbor_id = _get_touching_neighbor(occupied_grid, particle_pos)
			
			if neighbor_id != "":
				# HIT! Attach here.
				_add_dla_node(graph, occupied_grid, particle_pos)
				var new_id = occupied_grid[particle_pos]
				
				# Connect to the neighbor we hit
				graph.add_edge(new_id, neighbor_id)
				
				# Update Radius
				var dist = float(particle_pos.length())
				if use_box:
					dist = float(max(abs(particle_pos.x), abs(particle_pos.y)))
				
				if dist > max_radius:
					max_radius = dist
				
				added_so_far += 1
				walking = false
			else:
				# NO HIT. Move randomly.
				var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
				particle_pos += dirs.pick_random()
				
				# Optimization: Kill if it wandered too far away (Despawn)
				if use_box:
					if max(abs(particle_pos.x), abs(particle_pos.y)) > spawn_radius + 10.0:
						walking = false
				else:
					if particle_pos.length() > spawn_radius + 10.0:
						walking = false

# --- HELPER FUNCTIONS ---

# Generate Namespaced ID: dla:x:y
# This ensures DLA nodes don't collide with 'grid:x:y' or 'man:x' unless intended
func _vec_to_id(v: Vector2i) -> String:
	return "dla:%d:%d" % [v.x, v.y]

# Add node to Graph AND update local lookup
func _add_dla_node(graph: Graph, occupied: Dictionary, grid_pos: Vector2i) -> void:
	var id = _vec_to_id(grid_pos)
	
	# Check lookup to prevent duplicates
	if not occupied.has(grid_pos):
		var world_pos = Vector2(grid_pos.x * GraphSettings.CELL_SIZE, grid_pos.y * GraphSettings.CELL_SIZE)
		
		# NOTE: We use add_node directly. 
		# Since DLA grows into empty space, we don't usually need "Merge Overlaps" logic here.
		graph.add_node(id, world_pos)
		occupied[grid_pos] = id 

# Check adjacent cells for any existing node
func _get_touching_neighbor(occupied: Dictionary, pos: Vector2i) -> String:
	var dirs = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for d in dirs:
		var neighbor_pos = pos + d
		if occupied.has(neighbor_pos):
			return occupied[neighbor_pos]
	return ""
