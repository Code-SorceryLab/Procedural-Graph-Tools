class_name CmdDisconnect
extends GraphCommand

var _u: String
var _v: String
var _old_weight: float
var _old_data: Dictionary # Snapshot of the edge's semantic data
var _was_directed: bool

func _init(graph: Graph, u: String, v: String, weight: float, directed: bool = false) -> void:
	super(graph)
	_u = u
	_v = v
	_old_weight = weight
	_was_directed = directed
	
	# Capture the semantic data from the Canonical Edge Store
	var key = _graph.get_edge_key(u, v)
	if _graph.edge_store.has(key):
		_old_data = _graph.edge_store[key].custom.duplicate(true)
	else:
		_old_data = {}

func execute() -> void:
	_graph.remove_edge(_u, _v, _was_directed)

func undo() -> void:
	# Restore the edge with the exact weight and data it had before
	if _graph.nodes.has(_u) and _graph.nodes.has(_v):
		_graph.add_edge(_u, _v, _old_weight, _was_directed, _old_data)

func get_name() -> String:
	return "Disconnect Nodes"
