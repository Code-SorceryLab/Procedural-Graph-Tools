class_name CmdConnect
extends GraphCommand

var _u: String
var _v: String
var _weight: float

func _init(graph: Graph, u: String, v: String, weight: float = 1.0) -> void:
	super(graph)
	_u = u
	_v = v
	_weight = weight

func execute() -> void:
	# Safety: Ensure nodes exist before connecting
	if _graph.nodes.has(_u) and _graph.nodes.has(_v):
		_graph.add_edge(_u, _v, _weight)

func undo() -> void:
	# Undo is simple removal
	_graph.remove_edge(_u, _v)

func get_name() -> String:
	return "Connect Nodes"
