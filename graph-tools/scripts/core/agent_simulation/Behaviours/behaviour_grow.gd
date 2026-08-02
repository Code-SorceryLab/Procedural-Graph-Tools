class_name BehaviorGrow
extends AgentBehavior

func step(agent: AgentWalker, graph: Graph, context: Dictionary = {}) -> void:
	# 0. Grab Capabilities
	var builder = agent.get_capability("Builder") as CapBuilder
	var motor = agent.get_capability("Motor") as CapMotor
	if not builder or not motor: return

	# 1. Setup
	var grid_spacing = GraphSettings.GRID_SPACING
	var merge_overlaps = context.get("merge_overlaps", true)
	
	# Snap logic
	if agent.current_node_id == "":
		var under = graph.get_node_at_position(agent.pos, -1.0)
		if not under.is_empty(): agent.current_node_id = under

	var start_point = agent.pos
	if agent.snap_to_grid: 
		start_point = agent.pos.snapped(grid_spacing)

	# 2. DEFINE CANDIDATES
	var potential_moves = [
		Vector2(grid_spacing.x, 0), 
		Vector2(-grid_spacing.x, 0),
		Vector2(0, grid_spacing.y), 
		Vector2(0, -grid_spacing.y)
	]

	# 3. FORWARD CHECKING (Smart Mode)
	if agent.use_geometric_fc:
		var safe_moves = []
		for move in potential_moves:
			var test_pos = start_point + move
			if builder.can_build_at(graph, test_pos, grid_spacing):
				safe_moves.append(move)
		
		potential_moves = safe_moves
		if potential_moves.is_empty(): return

	# 4. PICK TARGET
	if potential_moves.is_empty(): return 
	
	# [SEED FIX] Replaced array.pick_random()
	var chosen_move = SeedUtils.pick_random(potential_moves, agent.rng)
	var target_pos = start_point + chosen_move
	
	# 5. EXECUTE (Spawn or Bump)
	if builder.can_build_at(graph, target_pos, grid_spacing):
		var new_id = builder.build_and_link(graph, target_pos, merge_overlaps)
		var final_pos = graph.get_node_pos(new_id) if merge_overlaps else target_pos
		motor.warp(final_pos, new_id) 
		agent.step_count += 1
		agent.history.append({ "node": new_id, "step": agent.step_count })
	else:
		agent.last_bump_pos = target_pos
