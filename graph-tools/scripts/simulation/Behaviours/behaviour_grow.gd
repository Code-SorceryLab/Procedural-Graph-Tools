class_name BehaviorGrow
extends AgentBehavior

# Note: We don't need 'context' anymore for grid spacing!
func step(agent: AgentWalker, graph: Graph, context: Dictionary = {}) -> void:
	# 1. Get Global Settings directly
	var grid_spacing = GraphSettings.GRID_SPACING
	
	# We still accept overrides from context if provided (optional flexibility)
	# but default to the global static value.
	var merge_overlaps = context.get("merge_overlaps", true)
	
	# 2. Determine Start Position
	if agent.current_node_id == "":
		var under_feet = graph.get_node_at_position(agent.pos, -1.0)
		if not under_feet.is_empty(): 
			agent.current_node_id = under_feet

	var start_point = agent.pos
	if agent.snap_to_grid: 
		start_point = agent.pos.snapped(grid_spacing)

	# 3. Calculate Target Position (Random Cardinal Direction)
	var target_pos = start_point + _get_random_cardinal_vector(grid_spacing)
	
	# Check Zone Permissions
	var gx = round(target_pos.x / grid_spacing.x)
	var gy = round(target_pos.y / grid_spacing.y)
	if graph.has_method("get_zone_at"):
		var zone = graph.get_zone_at(Vector2i(gx, gy))
		if zone and not zone.allow_new_nodes: 
			return # Blocked by zone

	# 4. Create or Merge Node
	var new_id = ""
	var existing_id = graph.get_node_at_position(target_pos, -1.0)
	
	if merge_overlaps and not existing_id.is_empty():
		new_id = existing_id
		target_pos = graph.get_node_pos(new_id)
	else:
		new_id = agent.generate_unique_id(graph)
		graph.add_node(new_id, target_pos)
	
	# 5. Link Backwards
	if not agent.current_node_id.is_empty() and graph.nodes.has(agent.current_node_id):
		if agent.current_node_id != new_id:
			var prev_pos = graph.get_node_pos(agent.current_node_id)
			var dist = prev_pos.distance_to(target_pos)
			if dist < grid_spacing.length() * 1.5:
				graph.add_edge(agent.current_node_id, new_id)
	
	# 6. Action: Move
	agent.move_to_node(new_id, graph)

# --- Helper ---
func _get_random_cardinal_vector(scale: Vector2) -> Vector2:
	var dir_idx = randi() % 4
	match dir_idx:
		0: return Vector2(scale.x, 0) 
		1: return Vector2(-scale.x, 0)
		2: return Vector2(0, scale.y) 
		3: return Vector2(0, -scale.y)
	return Vector2.ZERO
