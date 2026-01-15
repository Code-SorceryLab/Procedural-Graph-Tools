class_name BehaviorMazeGen
extends AgentBehavior

# --- STATE ---
var _stack: Array[String] = []       
var _my_creations: Dictionary = {}   
var _backtracking: bool = false      

# [NEW] MEMORY: Track failed positions for active nodes
# Format: { "node_id_A": [Vector2(100,0), Vector2(0,100)] }
var _attempted_moves: Dictionary = {}

# --- CONFIG ---
const DISTANCE_CHECK = 64.0 

func enter(agent: AgentWalker, graph: Graph) -> void:
	_stack.clear()
	_my_creations.clear()
	_attempted_moves.clear() # [NEW] Clear memory
	_backtracking = false
	
	if not graph: return
	_ensure_anchored(agent, graph)

func step(agent: AgentWalker, graph: Graph, _context: Dictionary = {}) -> void:
	if agent.is_finished: return

	# Lazy Init
	if _stack.is_empty():
		_ensure_anchored(agent, graph)
		if _stack.is_empty():
			agent.is_finished = true
			return

	var current_id = agent.current_node_id
	
	# 2. SCAN FOR EXPANSION
	var candidates: Array[Vector2] = _get_expansion_candidates(agent, graph)
	
	if not candidates.is_empty():
		# --- CASE A: ADVANCE ---
		_backtracking = false
		var target_pos = candidates.pick_random()
		
		var new_id = agent.generate_unique_id(graph)
		graph.add_node(new_id, target_pos)
		if graph.nodes.has(new_id): graph.nodes[new_id].type = agent.my_paint_type
		
		graph.add_edge(current_id, new_id)
		_my_creations[new_id] = true
		
		agent.move_to_node(new_id, graph)
		_stack.append(new_id)
		
	else:
		# --- CASE B: RETREAT ---
		_backtracking = true
		
		if _stack.size() <= 1:
			agent.is_finished = true 
			return
			
		var dead_end_node = _stack.pop_back()
		var retreat_target = _stack.back()
		
		# [NEW] MEMORY LOGIC
		# 1. Capture the position we just failed at
		var failed_pos = graph.get_node_pos(dead_end_node)
		
		# 2. Add it to the PARENT'S blacklist (retreat_target)
		if not _attempted_moves.has(retreat_target):
			_attempted_moves[retreat_target] = []
		_attempted_moves[retreat_target].append(failed_pos)
		
		# 3. Clean up the blacklist for the node we are destroying
		# (We are done with dead_end_node, so we don't need to remember its failures)
		if _attempted_moves.has(dead_end_node):
			_attempted_moves.erase(dead_end_node)
		
		# Move Agent
		agent.move_to_node(retreat_target, graph)
		
		# Delete Node (Visual Undo)
		if _my_creations.has(dead_end_node):
			graph.remove_node(dead_end_node)
			_my_creations.erase(dead_end_node)


func _ensure_anchored(agent: AgentWalker, graph: Graph) -> void:
	if agent.current_node_id != "" and graph.nodes.has(agent.current_node_id):
		if _stack.is_empty(): _stack.append(agent.current_node_id)
		return

	var found_id = graph.get_node_at_position(agent.pos)
	if found_id != "":
		print("MazeGen: Snapped to existing node ", found_id)
		agent.current_node_id = found_id
		_stack.append(found_id)
	else:
		var seed_id = agent.generate_unique_id(graph)
		print("MazeGen: Creating SEED at ", agent.pos)
		graph.add_node(seed_id, agent.pos)
		if graph.nodes.has(seed_id): graph.nodes[seed_id].type = agent.my_paint_type
		agent.current_node_id = seed_id
		_stack.append(seed_id)

# Inside _get_expansion_candidates
func _get_expansion_candidates(agent: AgentWalker, graph: Graph) -> Array[Vector2]:
	var results: Array[Vector2] = []
	
	var step_size = DISTANCE_CHECK
	if agent.snap_to_grid and GraphSettings.GRID_SPACING.x > 0:
		step_size = GraphSettings.GRID_SPACING.x
	
	var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	var ignore_id = agent.current_node_id
	
	# Get blacklist from Memory
	var blacklist = []
	if _attempted_moves.has(ignore_id):
		blacklist = _attempted_moves[ignore_id]
	
	for d in dirs:
		var check_pos = agent.pos + (d * step_size)
		
		# 1. Memory Check
		var is_banned = false
		for bad_pos in blacklist:
			if bad_pos.distance_squared_to(check_pos) < 1.0: 
				is_banned = true
				break
		if is_banned: continue 
		
		# 2. Occupancy Check
		if not _is_space_occupied(check_pos, graph, step_size * 0.4, ignore_id):
			
			# [NEW] 3. Forward Checking (Constraint Satisfaction)
			# Only run this if the User requested it (it is computationally heavier)
			if agent.use_forward_checking:
				if _will_move_strand_neighbors(check_pos, agent, graph, step_size):
					# "Pruning the Branch"
					# We treat this as a "Soft Ban". We don't blacklist it permanently 
					# (because failing here might be valid later), we just skip it now.
					continue
			
			results.append(check_pos)
			
	return results

# Inside _is_space_occupied
func _is_space_occupied(pos: Vector2, graph: Graph, radius: float, ignore_id: String = "") -> bool:
	# 1. Spatial Grid Check
	if graph.has_method("get_nodes_near_position"):
		var nearby = graph.get_nodes_near_position(pos, radius)
		
		if not nearby.is_empty():
			# [FIX] STRICT DISTANCE CHECK
			# Spatial Grid often returns "Broad Phase" candidates (Buckets).
			# We must verify they are actually colliding.
			var r2 = radius * radius
			
			for id in nearby:
				if id == ignore_id: continue
				
				# Double check the math
				var npos = graph.get_node_pos(id)
				if pos.distance_squared_to(npos) < r2:
					return true # Real Collision
					
			return false # Candidates found, but none were close enough
			
		return false
		
	# 2. Brute Force Fallback
	var r2 = radius * radius
	for nid in graph.nodes:
		if nid == ignore_id: continue 
		var npos = graph.get_node_pos(nid)
		if pos.distance_squared_to(npos) < r2:
			return true
			
	return false

# Checks if occupying 'target_pos' would isolate any adjacent empty node
func _will_move_strand_neighbors(target_pos: Vector2, agent: AgentWalker, graph: Graph, step_size: float) -> bool:
	var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	
	# 1. Look at neighbors of the target
	for d in dirs:
		var neighbor_pos = target_pos + (d * step_size)
		
		# We only care about EMPTY neighbors. 
		# If it's already occupied/wall, we can't hurt it further.
		# Note: We use 0.4 radius to be strict.
		if not _is_space_occupied(neighbor_pos, graph, step_size * 0.4):
			
			# 2. "Forward Check": Count exits for this neighbor
			var exits = _count_free_exits(neighbor_pos, graph, step_size)
			
			# 3. The Logic:
			# If the neighbor currently has 1 exit, that exit MUST be 'target_pos' (where we want to go).
			# If we occupy 'target_pos', that neighbor drops to 0 exits. It becomes a "Dead Cell".
			if exits <= 1:
				return true # We are about to strangle this neighbor.
				
	return false

func _count_free_exits(pos: Vector2, graph: Graph, step_size: float) -> int:
	var count = 0
	var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	
	for d in dirs:
		var check = pos + (d * step_size)
		# It's an exit if it's NOT occupied
		if not _is_space_occupied(check, graph, step_size * 0.4):
			count += 1
			
	return count
