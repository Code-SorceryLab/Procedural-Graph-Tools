class_name CmdDeleteNode
extends GraphCommand

# Node State
var _id: String
var _pos: Vector2
var _type: int

# Edges State
var _edges: Array[Dictionary] = []

# [FIX] Safety flag to prevent crashes if logic gets out of sync
var _is_valid: bool = false

func _init(graph: Graph, id: String) -> void:
	super(graph)
	_id = id
	
	# [FIX] Check existence immediately
	if not _graph.nodes.has(id):
		# This usually happens if Simulation Logic tries to delete a node
		# that was already removed via Undo. We abort gracefully.
		_is_valid = false
		return

	_is_valid = true
	
	# 1. CAPTURE DATA (Safe now)
	var node_data = _graph.nodes[id]
	_pos = node_data.position
	_type = node_data.type
	
	# 2. CAPTURE EDGES
	var neighbors = _graph.get_neighbors(id)
	for n_id in neighbors:
		var w = _graph.get_edge_weight(id, n_id)
		_edges.append({
			"neighbor": n_id,
			"weight": w
		})

func execute() -> void:
	# [FIX] Guard check
	if not _is_valid: return
	if not _graph.nodes.has(_id): return 
	
	_graph.remove_node(_id)

func undo() -> void:
	# [FIX] Guard check
	if not _is_valid: return
		
	# 1. Restore the Body (Node)
	_graph.add_node(_id, _pos)
	
	if _graph.nodes.has(_id):
		_graph.nodes[_id].type = _type
	
	# 2. Restore the Web (Edges)
	for edge in _edges:
		var neighbor = edge["neighbor"]
		var weight = edge["weight"]
		
		# Safety check: Neighbor must exist to reconnect
		if _graph.nodes.has(neighbor):
			_graph.add_edge(_id, neighbor, weight)

func get_name() -> String:
	return "Delete Node"
