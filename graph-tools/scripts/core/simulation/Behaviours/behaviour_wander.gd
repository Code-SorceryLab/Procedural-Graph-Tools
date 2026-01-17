class_name BehaviorWander
extends AgentBehavior

# Memory of where we have been (for random branching/backtracking)
var _session_path: Array[String] = []

func enter(agent: AgentWalker, _graph: Graph) -> void:
	_session_path.clear()
	if agent.current_node_id != "":
		_session_path.append(agent.current_node_id)

func step(agent: AgentWalker, graph: Graph, _context: Dictionary = {}) -> void:
	var current_id = agent.current_node_id
	var neighbors = graph.get_neighbors(current_id)
	
	if neighbors.is_empty(): 
		return

	# --- 1. SMART MODE: FORWARD CHECKING ---
	# If the toggle is ON, we filter the list BEFORE picking.
	if agent.use_forward_checking:
		var safe_neighbors: Array[String] = []
		for n_id in neighbors:
			if AgentNavigator.can_enter_node(graph, n_id):
				safe_neighbors.append(n_id)
		
		# Replace the full list with the filtered list
		neighbors = safe_neighbors
		
		# If the list is empty now, we are trapped. 
		# We simply return (wait), effectively "stalling" without a bump visual.
		if neighbors.is_empty():
			return 

	# --- 2. PICK A TARGET ---
	# Pick a random option from whatever is left in our list
	# (If Smart Mode was off, this is still the full list of neighbors)
	if neighbors.is_empty(): return
	var target_id = neighbors.pick_random()
	
	# --- 3. EXECUTE MOVE (With Bump Detection) ---
	if AgentNavigator.can_enter_node(graph, target_id):
		# Success! The move is valid.
		agent.move_to_node(target_id, graph)
	else:
		# Failure! We tried to enter a forbidden zone.
		# This only happens if 'use_forward_checking' is FALSE.
		
		# 1. Calculate where we hit the wall
		var target_pos = graph.get_node_pos(target_id)
		
		# 2. Record the bump (This triggers the Red Line in GraphRenderer)
		agent.last_bump_pos = target_pos
		# [DEBUG PRINT]
		print("BUMP! Agent %s hit wall at %s" % [agent.display_id, target_pos])

# --- Internal Logic (Preserved from old BehaviorPaint) ---
func _pick_next_node(agent: AgentWalker, graph: Graph) -> String:
	
	# A. Try to branch backwards (Teleport to previous spot)
	if agent.branch_randomly and randf() < 0.2 and not _session_path.is_empty():
		var candidate = _session_path.pick_random()
		# Only jump there if it still has neighbors (isn't isolated)
		if not graph.get_neighbors(candidate).is_empty():
			return candidate
			
	# B. Random Walk from here
	var neighbors = graph.get_neighbors(agent.current_node_id)
	if not neighbors.is_empty():
		return neighbors.pick_random()
		
	# C. Stuck? Teleport to random spot in history
	if not _session_path.is_empty():
		return _session_path.pick_random()
		
	# D. Total Desperation (Jump to random node in world)
	var all_nodes = graph.nodes.keys()
	if not all_nodes.is_empty():
		return all_nodes.pick_random()
		
	return ""
	
