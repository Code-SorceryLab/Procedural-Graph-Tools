class_name CmdDisconnect
extends GraphCommand

var _u: String
var _v: String
var _old_weight: float

func _init(graph: Graph, u: String, v: String, weight: float) -> void:
	super(graph)
	_u = u
	_v = v
	_old_weight = weight

func execute() -> void:
	_graph.remove_edge(_u, _v)

func undo() -> void:
	# Restore the edge with the exact weight it had before
	if _graph.nodes.has(_u) and _graph.nodes.has(_v):
		_graph.add_edge(_u, _v, _old_weight)

func get_name() -> String:
	return "Disconnect Nodes"
