extends PanelContainer
class_name Toolbar

# Signal emitted when the UI button is clicked manually
signal tool_changed(tool_id: int, tool_name: String)

# --- RESOURCES ---
# Make sure this path matches your actual scene location!
const TOOL_BUTTON_SCENE = preload("res://scenes/tool_button.tscn")

# --- STATE ---
var current_tool: int = GraphSettings.Tool.SELECT
var tool_buttons: Array[ToolButton] = []

@onready var tool_container: VBoxContainer = $ToolContainer

func _ready() -> void:
	_generate_buttons()
	
	# Set initial active tool
	set_active_tool(GraphSettings.Tool.SELECT)

func _generate_buttons() -> void:
	for child in tool_container.get_children():
		child.queue_free()
	tool_buttons.clear()
	
	# USE THE NEW LAYOUT ARRAY
	# This ensures the buttons appear exactly in the order you defined in Settings.
	for tool_id in GraphSettings.TOOLBAR_LAYOUT:
		var btn = TOOL_BUTTON_SCENE.instantiate()
		
		btn.tool_id = tool_id
		
		tool_container.add_child(btn)
		tool_buttons.append(btn)
		
		btn.pressed.connect(_on_tool_button_pressed.bind(tool_id))

func _on_tool_button_pressed(tool_id: int) -> void:
	_update_button_visuals(tool_id)
	tool_changed.emit(tool_id, GraphSettings.get_tool_name(tool_id))

# Public API
func set_active_tool(tool_id: int) -> void:
	_update_button_visuals(tool_id)

func _update_button_visuals(tool_id: int) -> void:
	current_tool = tool_id
	
	for button in tool_buttons:
		if button.tool_id == tool_id:
			button.set_active(true)
		else:
			button.set_active(false)
