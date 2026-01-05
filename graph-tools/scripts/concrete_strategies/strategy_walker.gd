class_name StrategyWalker
extends GraphStrategy

# Walker memory to track state between "Grow" clicks
# Schema: { "id": int, "pos": Vector2, "current_node_id": String, "step_count": int }
var _walkers: Array[Dictionary] = []

func _init() -> void:
	strategy_name = "Random Walker"
	reset_on_generate = true # Wipes previous work
	# "steps" triggers the first input, "merge_overlaps" is handled by the toggle
	required_params = ["steps", "merge_overlaps"]

func execute(graph: Graph, params: Dictionary) -> void:
	# 1. Parse Parameters
	var width = params.get("width", 500)   # Not used by walker, but good to have
	var height = params.get("height", 500) # Not used
	var steps = params.get("steps", 50)
	var append_mode = params.get("append", false)
	
	# The Collision Policy Toggle
	var merge_overlaps = params.get("merge_overlaps", true)
	
	# 2. Reset or Initialize
	if not append_mode:
		graph.clear()
		_walkers.clear()
		
	# Initialize a default walker if none exist (start at 0,0)
	if _walkers.is_empty():
		_walkers.append({
			"id": 0,
			"pos": Vector2(0, 0),
			"current_node_id": "",
			"step_count": 0
		})
		
	# 3. Simulation Loop
	for i in range(steps):
		for w in _walkers:
			_step_walker(graph, w, merge_overlaps)

func _step_walker(graph: Graph, walker: Dictionary, merge_overlaps: bool) -> void:
	# A. Determine Move Direction (Random Cardinal Step)
	var dir_idx = randi() % 4
	var step_vector = Vector2.ZERO
	match dir_idx:
		0: step_vector = Vector2(GraphSettings.CELL_SIZE, 0)  # Right
		1: step_vector = Vector2(-GraphSettings.CELL_SIZE, 0) # Left
		2: step_vector = Vector2(0, GraphSettings.CELL_SIZE)  # Down
		3: step_vector = Vector2(0, -GraphSettings.CELL_SIZE) # Up
		
	var target_pos = walker.pos + step_vector
	var current_id = ""
	
	# Increment step count for ID provenance
	walker.step_count += 1
	
	# B. COLLISION POLICY CHECK
	# Query the Graph/SpatialGrid for a node at this EXACT position (1.0 tolerance)
	var existing_id = graph.get_node_at_position(target_pos, 1.0)
	
	if merge_overlaps and not existing_id.is_empty():
		# REUSE: The node exists, and we are allowed to merge.
		# We don't create a new node, we just reference the old one.
		current_id = existing_id
	else:
		# CREATE: Make a new node with a deterministic ID.
		# Schema: walk : walker_id : step_number
		# Example: walk:0:55
		current_id = "walk:%d:%d" % [walker.id, walker.step_count]
		
		# Edge case: If "Force New" is on, and we somehow step on the exact same spot 
		# twice in the same generation run (e.g. step 5 and step 7 are same pos),
		# we need to ensure the ID is unique.
		# The step_count handles this naturally (walk:0:5 vs walk:0:7).
		
		graph.add_node(current_id, target_pos)
	
	# C. Connect to Previous Step
	if not walker.current_node_id.is_empty():
		# Prevent self-loops (connecting A to A)
		if walker.current_node_id != current_id:
			# Check if edge already exists to avoid duplication overhead
			# (Graph.add_edge usually handles this safely, but good to be explicit)
			graph.add_edge(walker.current_node_id, current_id)
			
	# D. Update Walker Memory
	walker.pos = target_pos
	walker.current_node_id = current_id
