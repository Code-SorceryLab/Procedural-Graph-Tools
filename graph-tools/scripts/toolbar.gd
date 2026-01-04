# toolbar.gd
extends PanelContainer
class_name Toolbar

# Signal emitted when tool changes
signal tool_changed(tool_id: int, tool_name: String)



var current_tool: int = GraphSettings.Tool.SELECT
var tool_buttons: Array[ToolButton] = []

@onready var tool_container: VBoxContainer = $ToolContainer

func _ready() -> void:
	# Collect all tool buttons
	for child in tool_container.get_children():
		if child is ToolButton:
			tool_buttons.append(child)
			child.pressed.connect(_on_tool_button_pressed.bind(child.tool_id))
	
	# Set initial active tool
	set_active_tool(GraphSettings.Tool.SELECT)

func _on_tool_button_pressed(tool_id: int) -> void:
	# Deselect all other buttons
	for button in tool_buttons:
		if button.tool_id != tool_id:
			button.set_active(false)
	
	# Update current tool
	current_tool = tool_id
	tool_changed.emit(tool_id, _get_tool_name(tool_id))
	
	# Print for debugging (remove later)
	print("Tool changed to: ", _get_tool_name(tool_id))

func set_active_tool(tool_id: int) -> void:
	# Find and activate the corresponding button
	for button in tool_buttons:
		if button.tool_id == tool_id:
			button.set_active(true)
			current_tool = tool_id
			tool_changed.emit(tool_id, _get_tool_name(tool_id))
		else:
			button.set_active(false)

func _get_tool_name(tool_id: int) -> String:
	match tool_id:
		GraphSettings.Tool.SELECT: return "Select"
		GraphSettings.Tool.ADD_NODE: return "Add Node"
		GraphSettings.Tool.CONNECT: return "Connect"
		GraphSettings.Tool.DELETE: return "Delete"
		GraphSettings.Tool.RECTANGLE: return "Rectangle Select"
		GraphSettings.Tool.MEASURE: return "Measure"
		GraphSettings.Tool.PAN: return "Pan"
		_: return "Unknown"

func _input(event: InputEvent) -> void:
	# Handle keyboard shortcuts for tools
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_V:
				set_active_tool(GraphSettings.Tool.SELECT)
				get_viewport().set_input_as_handled()
			KEY_N:
				set_active_tool(GraphSettings.Tool.ADD_NODE)
				get_viewport().set_input_as_handled()
			KEY_C:
				set_active_tool(GraphSettings.Tool.CONNECT)
				get_viewport().set_input_as_handled()
			KEY_X:
				set_active_tool(GraphSettings.Tool.DELETE)
				get_viewport().set_input_as_handled()
			KEY_R:
				set_active_tool(GraphSettings.Tool.RECTANGLE)
				get_viewport().set_input_as_handled()
			KEY_M:
				set_active_tool(GraphSettings.Tool.MEASURE)
				get_viewport().set_input_as_handled()
