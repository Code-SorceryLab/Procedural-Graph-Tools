class_name BehaviorGrow
extends AgentBehavior

func step(agent: AgentWalker, graph: Graph, context: Dictionary = {}) -> void:
	var builder = agent.get_capability("Builder") as CapBuilder
	var motor = agent.get_capability("Motor") as CapMotor
	if not builder or not motor: return

	var grid_spacing = GraphSettings.GRID_SPACING
	var merge_overlaps = context.get("merge_overlaps", true)
	
	if agent.current_node_id == "":
		var under = graph.get_node_at_position(agent.pos, -1.0)
		if not under.is_empty(): agent.current_node_id = under

	# --- BRANCHING LOGIC ---
	if agent.branching_probability > 0.0 and agent.rng.randf() < agent.branching_probability:
		if not agent.history.is_empty():
			# Pick a historical node and log the backtrack into history
			var past_entry = SeedUtils.pick_random(agent.history, agent.rng)
			var branch_node_id = past_entry.get("node", agent.current_node_id)
			if graph.nodes.has(branch_node_id) and branch_node_id != agent.current_node_id:
				motor.move_to_node(branch_node_id, graph)

	var start_point = agent.pos
	if agent.snap_to_grid: 
		start_point = agent.pos.snapped(grid_spacing)

	var potential_moves = [
		Vector2(grid_spacing.x, 0), 
		Vector2(-grid_spacing.x, 0),
		Vector2(0, grid_spacing.y), 
		Vector2(0, -grid_spacing.y)
	]

	if agent.use_geometric_fc:
		var safe_moves = []
		for move in potential_moves:
			var test_pos = start_point + move
			if builder.can_build_at(graph, test_pos, grid_spacing):
				safe_moves.append(move)
		potential_moves = safe_moves

	if potential_moves.is_empty(): return 
	
	var chosen_move = SeedUtils.pick_random(potential_moves, agent.rng)
	var target_pos = start_point + chosen_move
	
	# 5. EXECUTE (Spawn or Bump)
	if builder.can_build_at(graph, target_pos, grid_spacing):
		var new_id = builder.build_and_link(graph, target_pos, merge_overlaps)
		# [FIX] Log the new node placement correctly!
		motor.move_to_node(new_id, graph)
	else:
		agent.last_bump_pos = target_pos
