class_name BehaviorSeek
extends AgentBehavior

var _navigator_algo: int = AgentNavigator.Algo.ASTAR

func _init(algo: int = AgentNavigator.Algo.ASTAR) -> void:
	_navigator_algo = algo

func step(agent: AgentWalker, graph: Graph, _context: Dictionary = {}) -> void:
	
	# 1. Check Goal
	if agent.current_node_id == agent.target_node_id:
		return # We arrived. Do nothing.
		
	# 2. Ask the Utility (Navigator) for the path
	# Note: This might return a blocked node if the Navigator ignores Zones.
	var next_node = AgentNavigator.get_next_step(
		agent.current_node_id, 
		agent.target_node_id, 
		_navigator_algo, 
		graph
	)
	
	if next_node == "": return

	# 3. SAFETY CHECK (Constraint Logic)
	if AgentNavigator.is_move_safe(graph, next_node):
		# Success! The path is clear.
		agent.move_to_node(next_node, graph)
	else:
		# The Navigator wants us to go somewhere forbidden.
		
		if agent.use_forward_checking:
			# SMART MODE: "I see a wall there. I refuse to walk into it."
			# Action: Stall silently. (Wait for a valid path)
			pass 
		else:
			# DUMB MODE: "The GPS said go left... BAM."
			# Action: Try, fail, and visualize the impact.
			agent.last_bump_pos = graph.get_node_pos(next_node)
