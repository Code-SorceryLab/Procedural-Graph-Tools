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
	# 1. Clear any existing placeholders (useful if you reload the scene)
	for child in tool_container.get_children():
		child.queue_free()
	tool_buttons.clear()
	
	# 2. Get a sorted list of tools
	# We sort the keys to ensure buttons appear in Enum order (0, 1, 2...)
	# regardless of how they are hashed in the Dictionary.
	var sorted_ids = GraphSettings.TOOL_DATA.keys()
	sorted_ids.sort() 
	
	# 3. Instantiate Buttons
	for tool_id in sorted_ids:
		var btn = TOOL_BUTTON_SCENE.instantiate()
		
		# CRITICAL: We must set the ID *before* adding to the tree, 
		# so the button's _ready() function sees the correct ID.
		btn.tool_id = tool_id
		
		tool_container.add_child(btn)
		tool_buttons.append(btn)
		
		# Connect the signal
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
