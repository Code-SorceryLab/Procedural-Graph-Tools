class_name StrategyWalker
extends GraphStrategy

# Walker memory to track state between "Grow" clicks
# Schema: { "id": int, "pos": Vector2, "current_node_id": String, "step_count": int }
var _walkers: Array[Dictionary] = []

func _init() -> void:
	strategy_name = "Random Walker"
	reset_on_generate = true

func get_settings() -> Array[Dictionary]:
	return [
		{ "name": "steps", "type": TYPE_INT, "default": 50, "min": 1, "max": 500 },
		{ "name": "branch_randomly", "type": TYPE_BOOL, "default": false }
	]

func execute(graph: Graph, params: Dictionary) -> void:
	var steps = int(params.get("steps", 50))
	var branch_randomly = params.get("branch_randomly", false)
	var append_mode = params.get("append", false)
	var merge_overlaps = params.get("merge_overlaps", true)
	
	# 1. HANDLE RESET
	if not append_mode:
		_walkers.clear()

	# 2. VALIDATE MEMORY (The Crash Fix)
	# Check if our walkers are "lost" (holding references to deleted nodes)
	for w in _walkers:
		if w.current_node_id != "" and not graph.nodes.has(w.current_node_id):
			# The node we were standing on is gone! 
			# We must reset this walker's anchor.
			w.current_node_id = ""
	
	# 3. BRANCHING / RESPAWN LOGIC
	# If we want to branch randomly, OR if we are lost (current_node_id is empty), 
	# we need to pick a new spot.
	var need_respawn = (append_mode and branch_randomly)
	
	# Also respawn if we have a walker but it's disconnected from reality
	if not _walkers.is_empty() and _walkers[0].current_node_id == "":
		need_respawn = true

	if need_respawn:
		if not graph.nodes.is_empty():
			# Teleport to a random existing node
			var keys = graph.nodes.keys()
			var random_id = keys[randi() % keys.size()]
			var random_pos = graph.get_node_pos(random_id)
			
			if _walkers.is_empty():
				_walkers.append({ "id": 0, "pos": random_pos, "current_node_id": random_id, "step_count": 0 })
			else:
				_walkers[0].pos = random_pos
				_walkers[0].current_node_id = random_id
		else:
			# Graph is empty, reset to center
			if _walkers.is_empty():
				_walkers.append({ "id": 0, "pos": Vector2.ZERO, "current_node_id": "", "step_count": 0 })
			else:
				_walkers[0].pos = Vector2.ZERO
				_walkers[0].current_node_id = ""

	# 4. INITIALIZE DEFAULT (If totally empty)
	if _walkers.is_empty():
		_walkers.append({
			"id": 0,
			"pos": Vector2(0, 0),
			"current_node_id": "",
			"step_count": 0
		})

	# 5. SIMULATION LOOP
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
		while graph.nodes.has(current_id):
			walker.step_count += 1
			current_id = "walk:%d:%d" % [walker.id, walker.step_count]
		graph.add_node(current_id, target_pos)
	
	# Connect to Previous
	if not walker.current_node_id.is_empty():
		# SAFETY CHECK: Only connect if the previous node actually exists
		if graph.nodes.has(walker.current_node_id):
			if walker.current_node_id != current_id:
				graph.add_edge(walker.current_node_id, current_id)
		else:
			# If we somehow got here with a dead ID, ignore the edge but keep moving.
			pass
			
	# Update State
	walker.pos = target_pos
	walker.current_node_id = current_id
