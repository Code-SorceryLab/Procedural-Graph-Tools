class_name BehaviorGrow
extends AgentBehavior

func step(agent: AgentWalker, graph: Graph, context: Dictionary = {}) -> void:
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

	# 2. DEFINE CANDIDATES (The 4 Cardinals)
	# We store them as Vectors so we can calculate positions easily
	var potential_moves = [
		Vector2(grid_spacing.x, 0), 
		Vector2(-grid_spacing.x, 0),
		Vector2(0, grid_spacing.y), 
		Vector2(0, -grid_spacing.y)
	]

	# 3. FORWARD CHECKING (Smart Mode)
	# If enabled, filter out directions that would hit a "Closed Zone"
	if agent.use_forward_checking:
		var safe_moves = []
		for move in potential_moves:
			var test_pos = start_point + move
			if _is_position_growable(graph, test_pos, grid_spacing):
				safe_moves.append(move)
		
		# Update list
		potential_moves = safe_moves
		
		# If trapped, stall silently (Smart Agents don't bump)
		if potential_moves.is_empty(): 
			return

	# 4. PICK TARGET
	if potential_moves.is_empty(): return # Safety
	
	var chosen_move = potential_moves.pick_random()
	var target_pos = start_point + chosen_move
	
	# 5. EXECUTE (Spawn or Bump)
	if _is_position_growable(graph, target_pos, grid_spacing):
		# --- SUCCESS: Create Node ---
		
		var new_id = ""
		var existing_id = graph.get_node_at_position(target_pos, -1.0)
		
		if merge_overlaps and not existing_id.is_empty():
			new_id = existing_id
			# Snap to existing node center
			target_pos = graph.get_node_pos(new_id) 
		else:
			new_id = agent.generate_unique_id(graph)
			# Graph.add_node now handles Zone Registration automatically!
			graph.add_node(new_id, target_pos) 
		
		# Link Backwards
		if not agent.current_node_id.is_empty() and graph.nodes.has(agent.current_node_id):
			if agent.current_node_id != new_id:
				graph.add_edge(agent.current_node_id, new_id)
		
		# Move
		agent.move_to_node(new_id, graph)
		
	else:
		# --- FAILURE: Bump Logic ---
		# We tried to grow into a forbidden zone. Visualize it!
		agent.last_bump_pos = target_pos
		
		# Optional Debug
		# print("Grow Bump! Agent %s blocked at %s" % [agent.display_id, target_pos])

# --- HELPER ---
# Checks if a specific coordinate is allowed to have a node
func _is_position_growable(graph: Graph, pos: Vector2, spacing: Vector2) -> bool:
	if not graph.has_method("get_zone_at"): return true
	
	var gx = round(pos.x / spacing.x)
	var gy = round(pos.y / spacing.y)
	
	var zone = graph.get_zone_at(Vector2i(gx, gy))
	if zone:
		# Grow MUST respect the "Building Permit"
		if not zone.allow_new_nodes:
			return false
			
		# It implies we probably shouldn't grow into walls either
		if not zone.is_traversable:
			return false
			
	return true
