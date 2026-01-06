extends Resource
class_name Graph

const PRIORITY_QUEUE = preload("res://scripts/priority_queue.gd")
const SPATIAL_GRID = preload("res://scripts/spatial_grid.gd")

# 1. Export the main dictionary
# Godot will now save dictionaries containing the external 'NodeData' resource perfectly.
@export var nodes: Dictionary = {}

# 2. Spatial partitioning
var _spatial_grid: SpatialGrid = null
var _spatial_grid_dirty: bool = true  # Flag to indicate we need to rebuild
var _node_radius: float = GraphSettings.NODE_RADIUS  # For spatial queries

# --- Node Management (Updated for Spatial Grid) ---

func add_node(id: String, pos: Vector2 = Vector2.ZERO) -> void:
	if not nodes.has(id):
		nodes[id] = NodeData.new(pos)
		
		# Update spatial grid
		_ensure_spatial_grid()
		_spatial_grid.add_node(id, pos, _node_radius)

func remove_node(id: String) -> void:
	if not nodes.has(id):
		return
	
	# Remove from spatial grid first
	if _spatial_grid != null:
		_spatial_grid.remove_node(id)
	
	# Remove connections pointing TO this node
	for other_id: String in nodes:
		var other_node: NodeData = nodes[other_id]
		if other_node.connections.has(id):
			other_node.connections.erase(id)

	nodes.erase(id)

# Add a method to update node position (for dragging)
func set_node_position(id: String, new_pos: Vector2) -> void:
	if nodes.has(id):
		var node_data: NodeData = nodes[id]
		node_data.position = new_pos
		
		# Update spatial grid
		_ensure_spatial_grid()
		_spatial_grid.update_node(id, new_pos, _node_radius)

# --- Edge Management ---

func add_edge(a: String, b: String, weight: float = 1.0, directed: bool = false) -> void:
	if not nodes.has(a) or not nodes.has(b):
		push_error("Graph: Attempted to connect non-existent nodes [%s, %s]" % [a, b])
		return
	
	var node_a: NodeData = nodes[a]
	node_a.connections[b] = weight
	
	if not directed:
		var node_b: NodeData = nodes[b]
		node_b.connections[a] = weight

func remove_edge(a: String, b: String, directed: bool = false) -> void:
	if nodes.has(a):
		nodes[a].connections.erase(b)
	if not directed and nodes.has(b):
		nodes[b].connections.erase(a)

# Clears all connections but keeps the nodes intact.
# Required for MST and other re-wiring strategies.
func clear_edges() -> void:
	for id in nodes:
		# Access the NodeData resource and clear its dictionary
		if nodes[id] is NodeData:
			nodes[id].connections.clear()

func has_edge(a: String, b: String) -> bool:
	if nodes.has(a):
		return nodes[a].connections.has(b)
	return false

# --- Helpers ---

func get_neighbors(id: String) -> Array:
	if nodes.has(id):
		return nodes[id].connections.keys()
	return []

func get_edge_weight(a: String, b: String) -> float:
	if nodes.has(a):
		return nodes[a].connections.get(b, INF)
	return INF

func get_node_pos(id: String) -> Vector2:
	if nodes.has(id):
		return nodes[id].position
	return Vector2.ZERO
	


# --- Spatial Grid Methods ---

# Initialize spatial grid
func _ensure_spatial_grid() -> void:
	if _spatial_grid == null:
		# Cell size should be 2-4 times node radius for good performance
		var cell_size = GraphSettings.NODE_RADIUS * 4
		_spatial_grid = SPATIAL_GRID.new(cell_size)
		_spatial_grid_dirty = true
	
	if _spatial_grid_dirty:
		_rebuild_spatial_grid()

# Rebuild spatial grid from scratch
func _rebuild_spatial_grid() -> void:
	if _spatial_grid == null:
		return
	
	_spatial_grid.clear()
	
	for id in nodes:
		var node_data: NodeData = nodes[id]
		_spatial_grid.add_node(id, node_data.position, _node_radius)
	
	_spatial_grid_dirty = false

# Get nodes near a position (for mouse picking)
func get_nodes_near_position(pos: Vector2, radius: float = -1.0) -> Array[String]:
	if radius < 0:
		radius = _node_radius
	
	_ensure_spatial_grid()
	return _spatial_grid.query_circle(pos, radius)

# Get nodes in a rectangle (for selection boxes, etc.)
func get_nodes_in_rect(rect: Rect2) -> Array[String]:
	# 1. Broad Phase: Get candidates from the Grid (Fast, but imprecise)
	var candidates: Array[String] = []
	if _spatial_grid:
		candidates = _spatial_grid.query_rect(rect)
	else:
		# If no grid, every node is a candidate
		candidates = nodes.keys()
	
	# 2. Narrow Phase: Check exact positions (Precise)
	var result: Array[String] = []
	for id in candidates:
		if not nodes.has(id): continue
		
		var pos = nodes[id].position
		
		# STRICT CHECK: Is the point actually inside the rectangle?
		if rect.has_point(pos):
			result.append(id)
			
	return result

# Find node at exact position (for mouse picking)
func get_node_at_position(pos: Vector2, pick_radius: float = -1.0) -> String:
	if pick_radius < 0:
		pick_radius = _node_radius
	
	var candidates = get_nodes_near_position(pos, pick_radius)
	
	var closest_id: String = ""
	var closest_dist: float = INF
	
	for candidate_id in candidates:
		var candidate_pos = get_node_pos(candidate_id)
		var dist = candidate_pos.distance_to(pos)
		if dist <= pick_radius and dist < closest_dist:
			closest_dist = dist
			closest_id = candidate_id
	
	return closest_id

# Get spatial grid stats for debugging
func get_spatial_stats() -> Dictionary:
	_ensure_spatial_grid()
	return _spatial_grid.get_stats()

# Clear all nodes (update to handle spatial grid)
func clear() -> void:
	nodes.clear()
	if _spatial_grid != null:
		_spatial_grid.clear()
	_spatial_grid_dirty = true

# --- Pathfinding (A*) with Priority Queue ---

func get_astar_path(start_id: String, end_id: String) -> Array[String]:
	if not nodes.has(start_id) or not nodes.has(end_id):
		return []
	
	# Early exit: start and end are the same
	if start_id == end_id:
		return [start_id]
	
	# Initialize data structures
	var open_set = PRIORITY_QUEUE.new()
	var in_open_set: Dictionary = {}  # Track which nodes are in open_set
	var g_score: Dictionary = {}
	var f_score: Dictionary = {}
	var came_from: Dictionary = {}
	
	# Initialize start node
	g_score[start_id] = 0.0
	f_score[start_id] = _heuristic(start_id, end_id)
	open_set.push(start_id, f_score[start_id])
	in_open_set[start_id] = true
	
	while not open_set.is_empty():
		var current = open_set.pop()
		
		# Remove from open set tracking
		if in_open_set.has(current):
			in_open_set.erase(current)
		
		# Found the goal
		if current == end_id:
			return _reconstruct_path(came_from, current)
		
		var current_node: NodeData = nodes[current]
		var current_g = g_score[current]
		
		# Explore neighbors
		for neighbor: String in current_node.connections:
			# Calculate tentative g-score
			var tentative_g = current_g + current_node.connections[neighbor]
			
			# If we found a better path to this neighbor
			if tentative_g < g_score.get(neighbor, INF):
				# Update path
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + _heuristic(neighbor, end_id)
				
				# Add to open set if not already there
				if not in_open_set.has(neighbor):
					open_set.push(neighbor, f_score[neighbor])
					in_open_set[neighbor] = true
				else:
					# Update priority if already in open set
					open_set.update_priority(neighbor, f_score[neighbor])
	
	return []

# OPTIONAL: Add a squared distance heuristic for even better performance
# (avoids sqrt calculation)
func _heuristic_squared(a: String, b: String) -> float:
	var pos_a = nodes[a].position
	var pos_b = nodes[b].position
	return pos_a.distance_squared_to(pos_b)

# Keep the original heuristic for compatibility
func _heuristic(a: String, b: String) -> float:
	return nodes[a].position.distance_to(nodes[b].position)

func _reconstruct_path(came_from: Dictionary, current: String) -> Array[String]:
	var path: Array[String] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path
