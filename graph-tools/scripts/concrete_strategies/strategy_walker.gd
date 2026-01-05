class_name StrategyWalker
extends GraphStrategy

# Walker memory to track state between "Grow" clicks
# Schema: { "id": int, "pos": Vector2, "current_node_id": String, "step_count": int }
var _walkers: Array[Dictionary] = []

func _init() -> void:
	strategy_name = "Random Walker"
	reset_on_generate = true

# --- NEW DYNAMIC UI ---
func get_settings() -> Array[Dictionary]:
	return [
		{ "name": "steps", "type": TYPE_INT, "default": 50, "min": 1, "max": 500 },
		# The new feature: "Branch Randomly"
		{ "name": "branch_randomly", "type": TYPE_BOOL, "default": false }
	]

func execute(graph: Graph, params: Dictionary) -> void:
	var steps = int(params.get("steps", 50))
	var branch_randomly = params.get("branch_randomly", false)
	var append_mode = params.get("append", false)
	var merge_overlaps = params.get("merge_overlaps", true)
	
	# 1. Handle Reset vs Append
	if not append_mode:
		# If we are Generating fresh, we must clear memory
		# (Unless we specifically want to 'add walkers' to an existing map, 
		# but usually Generate means New)
		# NOTE: logic depends on Controller calling clear_graph(). 
		# We just clear our internal walker memory.
		_walkers.clear()

	# 2. Handle Branching Logic (The "Safety" Check)
	# If we are appending AND we want to branch randomly, we pick a new start point.
	if append_mode and branch_randomly and not graph.nodes.is_empty():
		# Reset the walker's position to a random existing node
		var keys = graph.nodes.keys()
		var random_id = keys[randi() % keys.size()]
		var random_pos = graph.get_node_pos(random_id)
		
		# Update the FIRST walker (or create a new one if you want multi-agent later)
		if _walkers.is_empty():
			_walkers.append({ "id": 0, "pos": random_pos, "current_node_id": random_id, "step_count": 0 })
		else:
			# Teleport existing walker to the branch point
			_walkers[0].pos = random_pos
			_walkers[0].current_node_id = random_id
			# We don't reset step_count so IDs remain unique (walk:0:51, etc)

	# 3. Ensure Default State
	if _walkers.is_empty():
		# If graph has nodes (e.g. Grid), start at a random one? 
		# Or default to 0,0. Let's default to 0,0 for deterministic starts.
		_walkers.append({
			"id": 0,
			"pos": Vector2(0, 0),
			"current_node_id": "",
			"step_count": 0
		})

	# 4. Simulation Loop
	for i in range(steps):
		for w in _walkers:
			_step_walker(graph, w, merge_overlaps)

func _step_walker(graph: Graph, walker: Dictionary, merge_overlaps: bool) -> void:
	# Direction Logic
	var dir_idx = randi() % 4
	var step_vector = Vector2.ZERO
	match dir_idx:
		0: step_vector = Vector2(GraphSettings.CELL_SIZE, 0)
		1: step_vector = Vector2(-GraphSettings.CELL_SIZE, 0)
		2: step_vector = Vector2(0, GraphSettings.CELL_SIZE)
		3: step_vector = Vector2(0, -GraphSettings.CELL_SIZE)
		
	var target_pos = walker.pos + step_vector
	walker.step_count += 1
	var current_id = ""
	
	# Collision Logic
	var existing_id = graph.get_node_at_position(target_pos, 1.0)
	
	if merge_overlaps and not existing_id.is_empty():
		current_id = existing_id
	else:
		current_id = "walk:%d:%d" % [walker.id, walker.step_count]
		# Ensure uniqueness if we looped back to same spot/step
		while graph.nodes.has(current_id):
			walker.step_count += 1
			current_id = "walk:%d:%d" % [walker.id, walker.step_count]
		graph.add_node(current_id, target_pos)
	
	# Connect
	if not walker.current_node_id.is_empty():
		if walker.current_node_id != current_id:
			graph.add_edge(walker.current_node_id, current_id)
			
	# Update State
	walker.pos = target_pos
	walker.current_node_id = current_id
