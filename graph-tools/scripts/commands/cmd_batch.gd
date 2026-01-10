class_name CmdBatch
extends GraphCommand

var _commands: Array[GraphCommand] = []
var _name: String
# NEW: Flag to control camera behavior
var center_on_undo: bool = true

# Update init to accept the flag (Default = true)
func _init(graph: Graph, name: String = "Batch Action", refocus: bool = true) -> void:
	super(graph)
	_name = name
	center_on_undo = refocus

func add_command(cmd: GraphCommand) -> void:
	_commands.append(cmd)

func execute() -> void:
	for cmd in _commands:
		cmd.execute()

func undo() -> void:
	var reversed = _commands.duplicate()
	reversed.reverse()
	for cmd in reversed:
		cmd.undo()

func get_name() -> String:
	return _name

func get_command_count() -> int:
	return _commands.size()
