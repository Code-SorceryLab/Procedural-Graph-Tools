class_name CmdDeleteNode
extends GraphCommand

# Node State
var _id: String
var _pos: Vector2
var _type: int

# Edges State
# Schema: Array of Dictionaries { "neighbor": String, "weight": float }
var _edges: Array[Dictionary] = []

func _init(graph: Graph, id: String) -> void:
	super(graph)
	_id = id
	
	# 1. CAPTURE DATA (Before destruction)
	# We must read this NOW, because execute() will wipe it out.
	var node_data = _graph.nodes[id]
	_pos = node_data.position
	_type = node_data.type
	
	# 2. CAPTURE EDGES
	# We iterate neighbors to save exactly who we were connected to.
	var neighbors = _graph.get_neighbors(id)
	for n_id in neighbors:
		var w = _graph.get_edge_weight(id, n_id)
		_edges.append({
			"neighbor": n_id,
			"weight": w
		})

func execute() -> void:
	# The Graph's remove_node handles cleaning up the other side of the connections
	_graph.remove_node(_id)

func undo() -> void:
	# 1. Restore the Body (Node)
	# Note: add_node() might reset the type to default, so we fix that next.
	_graph.add_node(_id, _pos)
	
	if _graph.nodes.has(_id):
		_graph.nodes[_id].type = _type
	
	# 2. Restore the Web (Edges)
	for edge in _edges:
		var neighbor = edge["neighbor"]
		var weight = edge["weight"]
		
		# Safety: The neighbor might have been deleted too if this is part of a complex redo.
		# But in a standard Undo stack, the neighbor must exist.
		if _graph.nodes.has(neighbor):
			_graph.add_edge(_id, neighbor, weight)

func get_name() -> String:
	return "Delete Node"
