class_name BehaviorWander
extends AgentBehavior

# Memory of where we have been (for random branching/backtracking)
var _session_path: Array[String] = []

func enter(agent: AgentWalker, _graph: Graph) -> void:
	_session_path.clear()
	if agent.current_node_id != "":
		_session_path.append(agent.current_node_id)

func step(agent: AgentWalker, graph: Graph, _context: Dictionary = {}) -> void:
	# 1. Logic: Pick next node
	var next_id = _pick_next_node(agent, graph)
	
	# 2. Action: Move
	if next_id != "":
		agent.move_to_node(next_id, graph)
		_session_path.append(next_id)

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
