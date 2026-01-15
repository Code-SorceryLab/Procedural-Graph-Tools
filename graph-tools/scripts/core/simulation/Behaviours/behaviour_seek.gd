class_name BehaviorSeek
extends AgentBehavior

# We keep the 'algo' override in case we want to force a specific behavior
# to ignore the agent's preference (e.g. a "Drunk" status effect forcing Random Walk).
var _algo_override: int = -1

func _init(algo_idx: int = -1) -> void:
	_algo_override = algo_idx

func step(agent: AgentWalker, graph: Graph, _context: Dictionary = {}) -> void:
	var target = agent.target_node_id
	
	# 1. Check Victory
	if target == "" or target == agent.current_node_id:
		agent.is_finished = true
		return

	# 2. Get Next Step (Using the new AgentWalker Memory)
	# The agent checks its cache. If empty/stale, it asks the Navigator.
	var next_node = agent.get_next_move_step(graph)
	
	if next_node == "":
		return # No path found

	# 3. SAFETY CHECK (Constraint Logic)
	if AgentNavigator.is_move_safe(graph, next_node):
		# A. SUCCESS
		agent.move_to_node(next_node, graph)
		agent.commit_move(next_node) # CRITICAL: Tells memory "We made it, forget this node."
	else:
		# B. FAILURE (Blocked)
		
		# [NEW] If our plan failed, the plan is bad. Clear the memory.
		# This forces a full repath next frame.
		agent._current_path_cache.clear()
		
		if agent.use_forward_checking:
			# SMART MODE: "I see a wall. I wait."
			pass 
		else:
			# DUMB MODE: "Ouch."
			agent.last_bump_pos = graph.get_node_pos(next_node)
