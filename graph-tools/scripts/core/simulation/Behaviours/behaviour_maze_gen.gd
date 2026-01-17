class_name BehaviorMazeGen
extends AgentBehavior

# --- STATE ---
var _stack: Array[String] = []       
var _my_creations: Dictionary = {}   
var _attempted_moves: Dictionary = {} # Memory
var _backtracking: bool = false      

# --- CONFIG ---
var DISTANCE_CHECK = GraphSettings.GRID_SPACING.x

func enter(agent: AgentWalker, graph: Graph) -> void:
	_stack.clear()
	_my_creations.clear()
	_attempted_moves.clear()
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

	# [NEW] BRANCHING LOGIC
	# We decide WHERE to grow from based on probability.
	# 0.0 = Always Head (Snake), 1.0 = Always Random (Prim's)
	var expansion_source_id = ""
	var is_branching_randomly = false
	
	if agent.branching_probability > 0.0 and randf() < agent.branching_probability:
		# Prim's Style: Pick ANY node in history
		expansion_source_id = _stack.pick_random()
		is_branching_randomly = true
	else:
		# Snake Style: Pick the NEWEST node
		expansion_source_id = _stack.back()

	# Move agent visually to the source (instant warp if branching)
	if agent.current_node_id != expansion_source_id:
		agent.move_to_node(expansion_source_id, graph)

	# 2. SCAN FOR EXPANSION
	# Note: We pass the specific source ID so we blacklist correctly
	var candidates: Array[Vector2] = _get_expansion_candidates(agent, graph, expansion_source_id)
	
	if not candidates.is_empty():
		# --- CASE A: ADVANCE ---
		_backtracking = false
		var target_pos = candidates.pick_random()
		
		var new_id = agent.generate_unique_id(graph)
		graph.add_node(new_id, target_pos)
		if graph.nodes.has(new_id): graph.nodes[new_id].type = agent.my_paint_type
		
		graph.add_edge(expansion_source_id, new_id)
		_my_creations[new_id] = true
		
		agent.move_to_node(new_id, graph)
		_stack.append(new_id)
		
	else:
		# --- CASE B: RETREAT / FAILURE ---
		_backtracking = true
		
		# [NEW] BRANCHING FAILURE HANDLING
		# If we tried to branch randomly and failed, we don't need to "Undo" anything.
		# We just wasted a turn. We stay in the stack and try again next tick.
		if is_branching_randomly:
			# Optional: Remove this node from stack if it's truly fully blocked?
			# For Prim's, usually you remove fully-blocked nodes from the set.
			# _stack.erase(expansion_source_id) 
			return

		# --- STANDARD BACKTRACKING (Snake) ---
		if _stack.size() <= 1:
			agent.is_finished = true 
			return
			
		var dead_end_node = _stack.pop_back()
		var retreat_target = _stack.back() # Retreat to previous
		
		# Memory Logic (Blacklist)
		var failed_pos = graph.get_node_pos(dead_end_node)
		if not _attempted_moves.has(retreat_target):
			_attempted_moves[retreat_target] = []
		_attempted_moves[retreat_target].append(failed_pos)
		
		if _attempted_moves.has(dead_end_node):
			_attempted_moves.erase(dead_end_node)
		
		# Move Agent
		agent.move_to_node(retreat_target, graph)
		
		# [NEW] DESTRUCTIVE VS PERSISTENT TOGGLE
		if agent.destructive_backtrack:
			# SNAKE MODE: Delete the dead end (Visual Undo)
			if _my_creations.has(dead_end_node):
				graph.remove_node(dead_end_node)
				_my_creations.erase(dead_end_node)
		else:
			# MAZE MODE: Keep the dead end, just forget it from the stack.
			pass

# Helper to ensure we have a valid start
func _ensure_anchored(agent: AgentWalker, graph: Graph) -> void:
	if agent.current_node_id != "" and graph.nodes.has(agent.current_node_id):
		if _stack.is_empty(): _stack.append(agent.current_node_id)
		return

	var found_id = graph.get_node_at_position(agent.pos)
	if found_id != "":
		agent.current_node_id = found_id
		_stack.append(found_id)
	else:
		var seed_id = agent.generate_unique_id(graph)
		graph.add_node(seed_id, agent.pos)
		if graph.nodes.has(seed_id): graph.nodes[seed_id].type = agent.my_paint_type
		agent.current_node_id = seed_id
		_stack.append(seed_id)

# Updated Candidate Search with Rectangular Support & FC Toggle
func _get_expansion_candidates(agent: AgentWalker, graph: Graph, source_id: String) -> Array[Vector2]:
	var results: Array[Vector2] = []
	
	# [FIX] Support Rectangular Grids
	var step_vec = Vector2(DISTANCE_CHECK, DISTANCE_CHECK)
	if agent.snap_to_grid and GraphSettings.GRID_SPACING.length_squared() > 0:
		step_vec = GraphSettings.GRID_SPACING
		
	var check_radius = min(step_vec.x, step_vec.y) * 0.4
	var current_pos = graph.get_node_pos(source_id) # Use source_id, not agent.pos
	
	var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	
	# Memory Check
	var blacklist = []
	if _attempted_moves.has(source_id):
		blacklist = _attempted_moves[source_id]
	
	for d in dirs:
		var offset = d * step_vec
		var check_pos = current_pos + offset
		
		# 1. Memory Check
		var is_banned = false
		for bad_pos in blacklist:
			if bad_pos.distance_squared_to(check_pos) < 1.0: 
				is_banned = true
				break
		if is_banned: continue 
		
		# 2. Occupancy Check
		if not _is_space_occupied(check_pos, graph, check_radius, source_id):
			
			# [NEW] 3. Geometric Forward Checking Toggle
			if agent.use_geometric_fc:
				if _will_move_strand_neighbors(check_pos, agent, graph, step_vec, check_radius):
					continue
			
			# [NEW] 4. Zone Constraint Toggle
			if agent.use_zone_constraints:
				# Assuming you have a helper for this, e.g.
				# if not _is_zone_allowed(check_pos, graph): continue
				pass

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

# 2. Update Forward Checking to use Vector Step
func _will_move_strand_neighbors(target_pos: Vector2, agent: AgentWalker, graph: Graph, step_vec: Vector2, radius: float) -> bool:
	var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	
	for d in dirs:
		var offset = d * step_vec
		var neighbor_pos = target_pos + offset
		
		# Check neighbor with safe radius
		if not _is_space_occupied(neighbor_pos, graph, radius):
			var exits = _count_free_exits(neighbor_pos, graph, step_vec, radius)
			if exits <= 1:
				return true 
				
	return false

# 3. Update Exit Counting to use Vector Step
func _count_free_exits(pos: Vector2, graph: Graph, step_vec: Vector2, radius: float) -> int:
	var count = 0
	var dirs = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	
	for d in dirs:
		var check = pos + (d * step_vec)
		if not _is_space_occupied(check, graph, radius):
			count += 1
			
	return count
