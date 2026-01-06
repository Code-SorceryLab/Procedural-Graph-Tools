class_name CmdSetType
extends GraphCommand

var _id: String
var _old_type: int
var _new_type: int

func _init(graph: Graph, id: String, old_type: int, new_type: int) -> void:
	super(graph)
	_id = id
	_old_type = old_type
	_new_type = new_type

func execute() -> void:
	if _graph.nodes.has(_id):
		_graph.nodes[_id].type = _new_type

func undo() -> void:
	if _graph.nodes.has(_id):
		_graph.nodes[_id].type = _old_type

func get_name() -> String:
	return "Change Node Type"
