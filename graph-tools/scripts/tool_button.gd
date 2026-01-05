extends Button
class_name ToolButton

# 1. The ONLY thing you set in the Inspector.
# Using the type 'GraphSettings.Tool' creates a dropdown menu automatically!
@export var tool_id: GraphSettings.Tool 

# (Removed: export var tool_name)
# (Removed: export var shortcut_key)

func _ready() -> void:
	# 2. Fetch everything dynamically
	var name_str = GraphSettings.get_tool_name(tool_id)
	var key_str = GraphSettings.get_shortcut_string(tool_id)
	
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	
	# 3. Build Label: "Paint (P)"
	var display_text = name_str
	if key_str != "":
		display_text += " (%s)" % key_str
		
	if has_node("Content/Label"):
		$Content/Label.text = display_text
	else:
		text = display_text

	# 4. Build Tooltip
	tooltip_text = name_str
	if key_str != "":
		tooltip_text += " (Shortcut: %s)" % key_str
	
	# Visual Init
	modulate = Color(0.8, 0.8, 0.8, 1.0)
	
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)

# ... (rest of the visual logic remains the same) ...

func _on_pressed() -> void:
	pass

func _on_mouse_entered() -> void:
	pass

func set_active(active: bool) -> void:
	button_pressed = active
	if active:
		modulate = Color(1.0, 1.0, 1.0, 1.0) # White (Active)
	else:
		modulate = Color(0.8, 0.8, 0.8, 1.0) # Gray (Inactive)
