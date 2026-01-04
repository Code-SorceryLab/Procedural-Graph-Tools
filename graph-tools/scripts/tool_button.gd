# tool_button.gd
extends Button
class_name ToolButton

@export var tool_name: String = "Tool"
@export var tool_id: int = 0
@export var shortcut_key: String = ""

func _ready() -> void:
	# Set up button properties
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	
	# Set the label text
	$Content/Label.text = tool_name

	# Set up tooltip with shortcut
	tooltip_text = tool_name
	if shortcut_key != "":
		tooltip_text += " (" + shortcut_key + ")"
	self.tooltip_text = tooltip_text
	
	# Connect signals
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)

func _on_pressed() -> void:
	# This will be handled by the parent toolbar
	pass

func _on_mouse_entered() -> void:
	# Optional: Add hover sound or effect
	pass

func set_active(active: bool) -> void:
	button_pressed = active
	# You could add visual feedback here
	if active:
		modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		modulate = Color(0.8, 0.8, 0.8, 1.0)
