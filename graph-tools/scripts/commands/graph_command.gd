class_name GraphCommand
extends RefCounted

# The graph this command operates on
var _graph: Graph

func _init(graph: Graph) -> void:
	_graph = graph

# The logic to perform the action
func execute() -> void:
	pass

# The logic to REVERSE the action perfectly
func undo() -> void:
	pass

# Optional: For UI (e.g., "Undo Add Node")
func get_name() -> String:
	return "Command"
