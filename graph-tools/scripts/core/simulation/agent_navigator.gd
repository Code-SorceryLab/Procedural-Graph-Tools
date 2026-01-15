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

# --- PUBLIC API ---

# 1. Used by the Agent to Move (Returns Node ID)
static func get_next_step(current_id: String, target_id: String, algo_id: int, graph: Graph) -> String:
	# 1. Get Strategy
	var strategy = _get_strategy(algo_id)
	if not strategy: return ""
	
	# 2. Execute
	# (For Random, this generates a full winding path instantly)
	var path = strategy.find_path(graph, current_id, target_id)
	
	# 3. Return next step
	if path.size() > 1: 
		return path[1]
	
	return ""

# 2. Used by the Editor to Draw Lines (Returns Array of IDs)
static func get_projected_path(current_id: String, target_id: String, algo_id: int, graph: Graph, options: Dictionary = {}) -> Array[String]:
	var strategy = _get_strategy(algo_id)
	if not strategy: return []
	
	# Inject options if the strategy supports it
	if strategy.has_method("set_options"):
		strategy.set_options(options)
		
	return strategy.find_path(graph, current_id, target_id)

# --- FACTORY ---

static func _get_strategy(algo_id: int) -> PathfindingStrategy:
	match algo_id:
		Algo.RANDOM:
			return PathfinderRandom.new() # [NEW]
		Algo.BFS: 
			return PathfinderBFS.new()
		Algo.DFS: 
			return PathfinderDFS.new()
		Algo.ASTAR: 
			return PathfinderAStar.new(1.0) 
		Algo.DIJKSTRA: 
			return PathfinderDijkstra.new() 
		_: 
			return null

# --- SAFETY CHECKS ---
# (Keep 'is_move_safe' exactly as we fixed it previously - checking 'is_traversable')


# --- ALGORITHMS ---

static func _solve_random(current_id: String, graph: Graph) -> String:
	var neighbors = graph.get_neighbors(current_id)
	if neighbors.is_empty(): return ""
	return neighbors.pick_random()



# --- HELPERS ---

# Reconstructs the entire path array [Start, A, B, ... End]
static func _reconstruct_full_path(parent_map: Dictionary, end: String) -> Array[String]:
	var path: Array[String] = []
	var curr = end
	
	# Backtrack from end to start
	while curr != null:
		path.append(curr)
		curr = parent_map.get(curr) # Returns null if key missing
	
	path.reverse() # Flip to be Start -> End
	return path


# --- SAFETY & PHYSICS ---

# Centralized check for Zone restrictions (Terrain, Walls, etc.)
static func is_move_safe(graph: Graph, target_id: String) -> bool:
	if not graph.zones: return true
	
	for zone in graph.zones:
		# We only collide with GEOGRAPHICAL zones (Terrain/Walls)
		if zone.zone_type == GraphZone.ZoneType.GEOGRAPHICAL:
			
			# Check if we are inside the zone
			if zone.contains_node(target_id):
				
				# [THE FIX] Check Permissions!
				# Only return false if the zone is explicitly marked as "Not Traversable".
				if not zone.is_traversable:
					return false
					
				# If is_traversable is TRUE, we do nothing. 
				# We just keep checking other zones (in case there's an overlapping wall).

	return true
