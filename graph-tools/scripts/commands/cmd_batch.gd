class_name CmdBatch
extends GraphCommand

var _commands: Array[GraphCommand] = []
var _name: String
# Flag to control camera behavior
var center_on_undo: bool = true

# Update init to accept the flag (Default = true)
func _init(graph: Graph, name: String = "Batch Action", refocus: bool = true) -> void:
	super(graph)
	_name = name
	center_on_undo = refocus

func add_command(cmd: GraphCommand) -> void:
	_commands.append(cmd)

func execute() -> void:
	print("--- BATCH START: '", _name, "' (", _commands.size(), " commands) ---")
	var start_time = Time.get_ticks_msec()
	
	for cmd in _commands:
		cmd.execute()
		
	var duration = Time.get_ticks_msec() - start_time
	print("--- BATCH END: Executed in ", duration, "ms ---")

func undo() -> void:
	print("--- UNDO BATCH: '", _name, "' ---")
	var reversed = _commands.duplicate()
	reversed.reverse()
	for cmd in reversed:
		cmd.undo()

func get_name() -> String:
	return _name

func get_command_count() -> int:
	return _commands.size()
