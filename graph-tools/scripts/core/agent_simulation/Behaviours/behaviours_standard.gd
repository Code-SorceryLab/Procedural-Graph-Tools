class_name BehaviorsStandard
extends RefCounted

# ==========================================================
# 1. HOLD (Do Nothing)
# ==========================================================
class Hold extends AgentBehavior:
	func step(_agent: AgentWalker, _graph: Graph, _context: Dictionary = {}) -> void:
		# Do nothing. The agent stands still.
		print("agent: stepped")
		pass

# ==========================================================
# 2. WANDER (Random Walk)
# ==========================================================
class Wander extends AgentBehavior:
	var _session_path: Array[String] = []

	func enter(agent: AgentWalker, _graph: Graph) -> void:
		_session_path.clear()
		if agent.current_node_id != "":
			_session_path.append(agent.current_node_id)

	func step(agent: AgentWalker, graph: Graph, _context: Dictionary = {}) -> void:
		var current_id = agent.current_node_id
		var neighbors = graph.get_neighbors(current_id)
		
		# --- DEBUG EXPOSURE ---
		print("[WANDER DEBUG] At '%s' | Found %d outgoing neighbors." % [current_id, neighbors.size()])
		
		if neighbors.is_empty():
			print("[WANDER DEBUG] Dead End! I am trapped.")
			return

		# Bypass external utilities to guarantee safe selection
		var target_id = neighbors[agent.rng.randi() % neighbors.size()]
		print("[WANDER DEBUG] Picked target: '%s'" % target_id)

		if AgentNavigator.can_enter_node(graph, target_id):
			print("[WANDER DEBUG] Move approved! Walking...")
			var motor = agent.get_capability("Motor") as CapMotor
			if motor:
				motor.move_to_node(target_id, graph)
			else:
				agent.move_to_node(target_id, graph)
				
			_session_path.append(target_id)
		else:
			print("[WANDER DEBUG] Move REJECTED by Zone/Geometry constraints!")
			agent.last_bump_pos = graph.get_node_pos(target_id)

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

# ==========================================================
# DIAGNOSTIC SOLVER (Bypasses all rules to find the bug) #The big guns
# ==========================================================
class BehaviorDiagnostic extends AgentBehavior:
	func step(agent: AgentWalker, graph: Graph, _context: Dictionary = {}) -> void:
		print("--- DIAGNOSTIC TICK %d ---" % agent.step_count)
		print("1. Agent Location: ", agent.current_node_id)
		print("2. Sandbox Nodes Size: ", graph.nodes.size())
		print("3. Sandbox Edges Size: ", graph.edge_store.size())
		
		var neighbors = graph.get_neighbors(agent.current_node_id)
		print("4. Adjacency Cache Neighbors: ", neighbors)
		
		# Manually scan the raw edge store just in case the cache is empty
		var manual_neighbors = []
		for key in graph.edge_store:
			if graph.edge_store[key].u == agent.current_node_id:
				manual_neighbors.append(graph.edge_store[key].v)
		print("5. Raw Edge Store Neighbors: ", manual_neighbors)
		
		if manual_neighbors.size() > 0:
			var target = manual_neighbors[0]
			print("6. FORCING move to: ", target)
			agent.get_capability("Motor").move_to_node(target, graph)
		else:
			print("FATAL: This node has absolutely 0 outgoing edges in the Sandbox!")
