class_name CmdConnect
extends GraphCommand

var _u: String
var _v: String
var _weight: float
var _directed: bool

func _init(graph: Graph, u: String, v: String, weight: float = 1.0, directed: bool = false) -> void:
	super(graph)
	_u = u
	_v = v
	_weight = weight
	_directed = directed

func execute() -> void:
	# Safety: Ensure nodes exist before connecting
	if _graph.nodes.has(_u) and _graph.nodes.has(_v):
		_graph.add_edge(_u, _v, _weight, _directed)

func undo() -> void:
	# Undo is simple removal
	_graph.remove_edge(_u, _v, _directed)

func get_name() -> String:
	return "Connect Nodes"
