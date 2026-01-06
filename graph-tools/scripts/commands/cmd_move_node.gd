class_name CmdMoveNode
extends GraphCommand

var _id: String
var _old_pos: Vector2
var _new_pos: Vector2

func _init(graph: Graph, id: String, old_pos: Vector2, new_pos: Vector2) -> void:
	super(graph)
	_id = id
	_old_pos = old_pos
	_new_pos = new_pos

func execute() -> void:
	# We use the existing graph method which handles the Spatial Grid updates
	_graph.set_node_position(_id, _new_pos)

func undo() -> void:
	_graph.set_node_position(_id, _old_pos)

func get_name() -> String:
	return "Move Node"
