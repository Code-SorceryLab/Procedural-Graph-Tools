class_name AlgorithmSettingsPopup
extends AcceptDialog

# Signal sent back when user clicks "OK"
# Returns the modified dictionary of settings
signal settings_confirmed(new_settings: Dictionary)

# UI References
var _content_container: VBoxContainer
var _inputs: Dictionary = {} # Map "setting_name" -> Control Node
var _current_schema: Array[Dictionary] = []
var _working_settings: Dictionary = {}

func _init() -> void:
	title = "Configuration" # Default title
	initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	size = Vector2(350, 250)
	unresizable = false
	
	# 1. Scroll Container (Handles tall lists of settings)
	var scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# Use generic anchors to fill the AcceptDialog's content area
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	
	# 2. Content Container (VBox)
	_content_container = VBoxContainer.new()
	_content_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Add a small margin for aesthetics
	_content_container.add_theme_constant_override("separation", 10)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_child(_content_container)
	scroll.add_child(margin)
	
	# 3. Signals
	confirmed.connect(_on_confirmed)

# --- PUBLIC API ---

# Call this to open the window
# p_title: Custom window title (e.g. "A* Settings", "Maze Generator Settings")
# schema: Array of dictionaries defining the controls
# current_values: Dictionary of current values to populate inputs
func open_settings(p_title: String, schema: Array[Dictionary], current_values: Dictionary) -> void:
	title = p_title
	_current_schema = schema
	_working_settings = current_values.duplicate()
	_inputs.clear()
	
	# Clear old UI
	for child in _content_container.get_children():
		child.queue_free()
		
	# Build new UI
	if schema.is_empty():
		var lbl = Label.new()
		lbl.text = "No configurable settings available."
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.modulate = Color(1, 1, 1, 0.5)
		_content_container.add_child(lbl)
	else:
		for def in schema:
			_create_control_row(def)
			
	popup()

# --- INTERNAL BUILDER ---

func _create_control_row(def: Dictionary) -> void:
	var row = HBoxContainer.new()
	_content_container.add_child(row)
	
	# 1. Label
	var lbl = Label.new()
	lbl.text = def.get("label", def.name).capitalize()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if def.has("hint"):
		lbl.tooltip_text = def.hint
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	row.add_child(lbl)
	
	# 2. Input Control
	var key = def.name
	# Use default from schema if current value is missing
	var val = _working_settings.get(key, def.get("default"))
	var control: Control
	
	match def.type:
		TYPE_BOOL:
			control = CheckButton.new()
			control.button_pressed = bool(val)
			control.text = "On" if bool(val) else "Off"
			control.toggled.connect(func(s): control.text = "On" if s else "Off")
			
		TYPE_INT:
			control = SpinBox.new()
			control.min_value = def.get("min", 0)
			control.max_value = def.get("max", 9999)
			control.value = int(val)
			control.rounded = true
			
		TYPE_FLOAT:
			control = SpinBox.new()
			control.min_value = def.get("min", 0.0)
			control.max_value = def.get("max", 10.0)
			control.step = def.get("step", 0.1)
			control.value = float(val)
			
		TYPE_STRING:
			control = LineEdit.new()
			control.text = str(val)
			control.custom_minimum_size.x = 120
			
	if control:
		control.size_flags_horizontal = Control.SIZE_SHRINK_END
		if def.has("hint"): control.tooltip_text = def.hint
		row.add_child(control)
		_inputs[key] = control

# --- CONFIRMATION ---

func _on_confirmed() -> void:
	var final_settings = {}
	
	# Read values back from controls
	for def in _current_schema:
		var key = def.name
		var control = _inputs.get(key)
		if not control: continue
		
		match def.type:
			TYPE_BOOL: final_settings[key] = control.button_pressed
			TYPE_INT: final_settings[key] = int(control.value)
			TYPE_FLOAT: final_settings[key] = float(control.value)
			TYPE_STRING: final_settings[key] = control.text
			
	settings_confirmed.emit(final_settings)
