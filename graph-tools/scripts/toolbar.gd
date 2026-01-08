extends PanelContainer
class_name Toolbar

# Signal emitted when the UI button is clicked manually
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
			
			# REMOVED: Tooltip/Icon logic. 
			# REASON: ToolButton.gd handles this itself in its own _ready() function.
			
	# Set initial active tool
	set_active_tool(GraphSettings.Tool.SELECT)

func _on_tool_button_pressed(tool_id: int) -> void:
	# Update internal UI state
	_update_button_visuals(tool_id)
	
	# Notify the system
	tool_changed.emit(tool_id, GraphSettings.get_tool_name(tool_id))

# Public API: Called by external scripts (like GraphEditor shortcuts)
func set_active_tool(tool_id: int) -> void:
	_update_button_visuals(tool_id)

func _update_button_visuals(tool_id: int) -> void:
	current_tool = tool_id
	
	for button in tool_buttons:
		if button.tool_id == tool_id:
			button.set_active(true)
		else:
			button.set_active(false)
