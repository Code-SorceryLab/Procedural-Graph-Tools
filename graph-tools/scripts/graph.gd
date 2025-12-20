extends Resource
class_name Graph




# 1. Export the main dictionary
# Godot will now save dictionaries containing the external 'NodeData' resource perfectly.
@export var nodes: Dictionary = {}

# --- Node Management ---

func add_node(id: String, pos: Vector2 = Vector2.ZERO) -> void:
	if not nodes.has(id):
		nodes[id] = NodeData.new(pos)

func remove_node(id: String) -> void:
	if not nodes.has(id):
		return
	
	# Remove connections pointing TO this node
	for other_id: String in nodes:
		var other_node: NodeData = nodes[other_id]
		if other_node.connections.has(id):
			other_node.connections.erase(id)

	nodes.erase(id)

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

# --- Pathfinding (A*) ---

# RENAMED: 'get_path' is reserved by Resource, so we use 'get_astar_path'
func get_astar_path(start_id: String, end_id: String) -> Array[String]:
	if not nodes.has(start_id) or not nodes.has(end_id):
		return []

	var open_set: Dictionary = { start_id: true }
	var came_from: Dictionary = {}
	
	var g_score: Dictionary = {} 
	var f_score: Dictionary = {} 

	g_score[start_id] = 0.0
	f_score[start_id] = _heuristic(start_id, end_id)

	while not open_set.is_empty():
		var current: String = ""
		var lowest_f: float = INF
		
		for id: String in open_set:
			var score: float = f_score.get(id, INF)
			if score < lowest_f:
				lowest_f = score
				current = id
		
		if current == end_id:
			return _reconstruct_path(came_from, current)

		open_set.erase(current)

		var current_node: NodeData = nodes[current]
		for neighbor: String in current_node.connections:
			var tentative_g: float = g_score.get(current, INF) + current_node.connections[neighbor]
			
			if tentative_g < g_score.get(neighbor, INF):
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g
				f_score[neighbor] = tentative_g + _heuristic(neighbor, end_id)
				if not open_set.has(neighbor):
					open_set[neighbor] = true

	return [] 

func _heuristic(a: String, b: String) -> float:
	return nodes[a].position.distance_to(nodes[b].position)

func _reconstruct_path(came_from: Dictionary, current: String) -> Array[String]:
	var path: Array[String] = [current]
	while came_from.has(current):
		current = came_from[current]
		path.push_front(current)
	return path
