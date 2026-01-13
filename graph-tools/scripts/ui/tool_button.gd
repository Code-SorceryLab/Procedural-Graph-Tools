extends Button
class_name ToolButton

@export var tool_id: GraphSettings.Tool 

# Reference to the TextureRect we just made
@onready var icon_rect: TextureRect = $Icon

func _ready() -> void:
	toggle_mode = true
	focus_mode = Control.FOCUS_NONE
	
	# 1. GET DATA
	var name_str = GraphSettings.get_tool_name(tool_id)
	var key_str = GraphSettings.get_shortcut_string(tool_id)
	var icon_tex = GraphSettings.get_tool_icon(tool_id)
	
	# --- DIAGNOSTIC PRINT (Remove after fixing) ---
	#print("DEBUG ToolButton [", tool_id, "]:")
	#print(" > Name: '", name_str, "'")
	#print(" > Key: '", key_str, "'")
	# ---------------------------------------------
	
	# 2. SETUP ICON
	if icon_tex and icon_rect:
		icon_rect.texture = icon_tex
	
	# 3. SETUP TOOLTIP
	var tooltip = name_str
	
	# We suspect key_str might be literally "((unset))"
	if key_str != "" and key_str != "((unset))": 
		tooltip += " (%s)" % key_str
		
	self.tooltip_text = tooltip
	
	# 4. REMOVE TEXT (Just in case the button property has text)
	text = "" 
	
	# 5. VISUALS
	# Set a base color (optional, or handle via Theme)
	modulate = Color(0.8, 0.8, 0.8, 1.0)
	
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)

func set_active(active: bool) -> void:
	button_pressed = active
	if active:
		# Active State: Bright White + maybe a Theme variation
		modulate = Color(1.0, 1.0, 1.0, 1.0) 
		icon_rect.modulate = Color(1.0, 1.0, 1.0, 1.0)
	else:
		# Inactive State: Dimmed
		modulate = Color(0.7, 0.7, 0.7, 1.0)
		icon_rect.modulate = Color(0.9, 0.9, 0.9, 1.0)

func _on_pressed() -> void:
	pass

func _on_mouse_entered() -> void:
	pass
