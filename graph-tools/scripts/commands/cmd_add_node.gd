class_name CmdAddNode
extends GraphCommand

var _id: String
var _pos: Vector2

func _init(graph: Graph, id: String, pos: Vector2) -> void:
	super(graph)
	_id = id
	_pos = pos

func execute() -> void:
	# Check prevents errors during Redo if logic gets messy
	if not _graph.nodes.has(_id):
		_graph.add_node(_id, _pos)

func undo() -> void:
	if _graph.nodes.has(_id):
		_graph.remove_node(_id)

func get_name() -> String:
	return "Add Node"
