class_name CmdSetEdgeWeight
extends GraphCommand

var _id_a: String
var _id_b: String
var _old_weight: float
var _new_weight: float

func _init(graph: Graph, id_a: String, id_b: String, new_weight: float) -> void:
	_graph = graph
	_id_a = id_a
	_id_b = id_b
	_new_weight = new_weight
	# Capture current state for Undo
	_old_weight = graph.get_edge_weight(id_a, id_b)

func execute() -> void:
	_graph.set_edge_weight(_id_a, _id_b, _new_weight) 

func undo() -> void:
	_graph.set_edge_weight(_id_a, _id_b, _old_weight)

func get_name() -> String:
	return "Set Edge Weight %s->%s" % [_id_a, _id_b]
