class_name AgentNavigator
extends RefCounted

# --- ENUMS (Must match UI Dropdown Indices) ---
enum Algo {
	RANDOM = 0,
	BFS = 1,
	DFS = 2,
	ASTAR = 3,
	DIJKSTRA = 4
}

# ==============================================================================
# 1. PUBLIC API
# ==============================================================================

# 1. Used by the Agent to Move (Returns Node ID)
static func get_next_step(current_id: String, target_id: String, algo_id: int, graph: Graph) -> String:
	var strategy = _get_strategy(algo_id)
	if not strategy: return ""
	
	# Execute Strategy
	# (Note: Random walker will return a path of [current, next, ...])
	var path = strategy.find_path(graph, current_id, target_id)
	
	# Return immediate next step
	if path.size() > 1: 
		return path[1]
	
	return ""

# 2. Used by the Editor/Inspector to Draw Lines (Returns Array of IDs)
static func get_projected_path(current_id: String, target_id: String, algo_id: int, graph: Graph, options: Dictionary = {}) -> Array[String]:
	var strategy = _get_strategy(algo_id)
	if not strategy: return []
	
	# Inject runtime options (e.g. Heuristic weights)
	if strategy.has_method("set_options"):
		strategy.set_options(options)
		
	return strategy.find_path(graph, current_id, target_id)

# ==============================================================================
# 2. FACTORY
# ==============================================================================

static func _get_strategy(algo_id: int) -> PathfindingStrategy:
	match algo_id:
		Algo.RANDOM:   return PathfinderRandom.new()
		Algo.BFS:      return PathfinderBFS.new()
		Algo.DFS:      return PathfinderDFS.new()
		Algo.ASTAR:    return PathfinderAStar.new(1.0) 
		Algo.DIJKSTRA: return PathfinderDijkstra.new() 
		_:             return null

# ==============================================================================
# 3. SAFETY & PHYSICS (The Maze Logic Core)
# ==============================================================================

# Centralized check for Zone restrictions (Terrain, Walls, etc.)
# Used by both Pathfinders AND Maze Generators to validate connections.
static func can_enter_node(graph: Graph, node_id: String) -> bool:
	if not graph.zones: return true
	
	for zone in graph.zones:
		# Only check collision for Geographical zones (Terrain/Walls)
		if zone.zone_type == GraphZone.ZoneType.GEOGRAPHICAL:
			
			if zone.contains_node(node_id):
				# If explicitly blocked (Wall), deny entry.
				if not zone.is_traversable:
					return false
					
				# Note: High cost zones (Mud) return TRUE here, 
				# but 'get_traversal_cost' returns a high number.
				
	return true

# Helper to standardize cost calculation across algorithms
static func get_traversal_cost(graph: Graph, from_id: String, to_id: String) -> float:
	# 1. Base Edge Weight
	var cost = graph.get_edge_weight(from_id, to_id)
	
	# 2. Zone Penalties (e.g. Mud)
	# This queries the graph to see if 'to_id' is in a zone with 'traversal_cost > 1.0'
	var zone_multiplier = graph.get_node_traversal_multiplier(to_id)
	
	return cost * zone_multiplier

# ==============================================================================
# 4. SHARED HELPERS
# ==============================================================================

# Reconstructs the entire path array [Start, A, B, ... End]
static func reconstruct_full_path(parent_map: Dictionary, end: String) -> Array[String]:
	var path: Array[String] = []
	var curr = end
	
	# Backtrack from end to start
	while curr != null:
		path.append(curr)
		curr = parent_map.get(curr) # Returns null if key missing (Start node)
	
	path.reverse() # Flip to be Start -> End
	return path
