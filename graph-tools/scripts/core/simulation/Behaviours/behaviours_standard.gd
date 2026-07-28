class_name BehaviorsStandard
extends RefCounted

# ==========================================================
# 1. HOLD (Do Nothing)
# ==========================================================
class Hold extends AgentBehavior:
	func step(_agent: AgentWalker, _graph: Graph, _context: Dictionary = {}) -> void:
		# Do nothing. The agent stands still.
		pass

# ==========================================================
# 2. WANDER (Random Walk)
# ==========================================================
class Wander extends AgentBehavior:
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
		if agent.use_geometric_fc:
			var safe_neighbors: Array[String] = []
			for n_id in neighbors:
				if AgentNavigator.can_enter_node(graph, n_id):
					safe_neighbors.append(n_id)
			
			neighbors = safe_neighbors
			
			if neighbors.is_empty():
				return 

		# --- 2. PICK A TARGET ---
		if neighbors.is_empty(): return
		# [SEED FIX]
		var target_id = SeedUtils.pick_random(neighbors, agent.rng)
		
		# --- 3. EXECUTE MOVE (With Bump Detection) ---
		if AgentNavigator.can_enter_node(graph, target_id):
			# Valid Move -> Use Capability
			var motor = agent.get_capability("Motor") as CapMotor
			if motor:
				motor.move_to_node(target_id, graph)
			else:
				agent.move_to_node(target_id, graph)
				
			_session_path.append(target_id)
		else:
			# Invalid Move -> Record Bump
			var target_pos = graph.get_node_pos(target_id)
			agent.last_bump_pos = target_pos

	# --- Internal Logic ---
	func _pick_next_node(agent: AgentWalker, graph: Graph) -> String:
		# [SEED FIX]
		if agent.branching_probability > 0.0 and agent.rng.randf() < agent.branching_probability and not _session_path.is_empty():
			var candidate = SeedUtils.pick_random(_session_path, agent.rng)
			if not graph.get_neighbors(candidate).is_empty():
				return candidate
				
		var neighbors = graph.get_neighbors(agent.current_node_id)
		if not neighbors.is_empty():
			return SeedUtils.pick_random(neighbors, agent.rng)
			
		if not _session_path.is_empty():
			return SeedUtils.pick_random(_session_path, agent.rng)
			
		var all_nodes = graph.nodes.keys()
		if not all_nodes.is_empty():
			return SeedUtils.pick_random(all_nodes, agent.rng)
			
		return ""

# ==========================================================
# 3. SEEK (Target Pathfinding)
# ==========================================================
class Seek extends AgentBehavior:
	var _algo_override: int = -1
	
	func _init(algo_idx: int = -1) -> void:
		_algo_override = algo_idx
		
	func enter(agent: AgentWalker, _graph: Graph) -> void:
		if _algo_override != -1:
			agent.movement_algo = _algo_override

	func step(agent: AgentWalker, graph: Graph, _context: Dictionary = {}) -> void:
		var target = agent.target_node_id
		if target == "" or target == agent.current_node_id:
			agent.is_finished = true
			return

		var next_node = agent.get_next_move_step(graph)
		if next_node == "":
			return 

		if AgentNavigator.can_enter_node(graph, next_node):
			var motor = agent.get_capability("Motor") as CapMotor
			if motor:
				motor.move_to_node(next_node, graph)
			else:
				agent.move_to_node(next_node, graph)
			agent.commit_move(next_node)
		else:
			agent._current_path_cache.clear()
			if agent.use_geometric_fc:
				pass 
			else:
				agent.last_bump_pos = graph.get_node_pos(next_node)
