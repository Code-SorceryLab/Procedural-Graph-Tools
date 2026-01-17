class_name SettingsUIBuilder
extends RefCounted

# ==============================================================================
# 1. PUBLIC API - BUILDERS
# ==============================================================================

# [NEW] Helper to create a unified Collapsible Header + Container
# [CHANGED] Helper to create a unified Collapsible Header + Container
# Now uses a distinct blue style to differentiate it from action buttons.
static func create_collapsible_section(parent: Control, title: String, start_expanded: bool = true) -> VBoxContainer:
	var btn = Button.new()
	btn.text = ("v " if start_expanded else "> ") + title
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	# --- STYLE CHANGES ---
	# 1. Remove 'flat = true' so it has a background bar.
	# btn.flat = true 
	
	# 2. Tint the background button itself to a neutral slate blue.
	# Using self_modulate affects the button background texture without tinting the child text.
	btn.self_modulate = Color(0.25, 0.35, 0.5) 
	
	# 3. Ensure text is bright white for contrast against the blue.
	btn.add_theme_color_override("font_color", Color.WHITE)
	# Add hover/pressed overrides to maintain the white text styling
	btn.add_theme_color_override("font_hover_color", Color(0.9, 0.9, 0.9))
	btn.add_theme_color_override("font_pressed_color", Color(0.8, 0.8, 0.8))
	# ---------------------

	parent.add_child(btn)
	
	var container = VBoxContainer.new()
	container.visible = start_expanded
	# Add indentation
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_child(container)
	parent.add_child(margin)
	
	# Toggle Logic
	btn.pressed.connect(func():
		var is_vis = !container.visible
		container.visible = is_vis
		btn.text = ("v " if is_vis else "> ") + title
	)
	
	return container

# Generates UI controls inside 'container' based on 'settings_list'.
static func build_ui(settings_list: Array, container: Control) -> Dictionary:
	clear_ui(container)
	var active_inputs = {}
	
	for setting in settings_list:
		var key = setting["name"]
		var type = setting["type"]
		var hint = setting.get("hint", "")
		
		# 1. SEPARATORS
		if hint == "separator":
			_create_separator(container)
			continue
			
		# 2. ACTIONS / BUTTONS (No Row Layout)
		if hint == "action" or hint == "button":
			var btn = _create_action_button(setting, container)
			active_inputs[key] = btn
			continue
			
		# 3. STANDARD CONTROLS (Row Layout)
		var row_control = null
		
		# Decide which control to build based on Type or Hint
		if setting.get("options", "") != "" or hint == "enum":
			row_control = _create_dropdown(setting)
		elif hint == "read_only":
			row_control = _create_read_only_label(setting)
		else:
			match type:
				TYPE_INT, TYPE_FLOAT: row_control = _create_number(setting)
				TYPE_BOOL:            row_control = _create_checkbox(setting)
				TYPE_STRING:          row_control = _create_line_edit(setting)
				TYPE_VECTOR2:         row_control = _create_vector2(setting)
				TYPE_COLOR:           row_control = _create_color_picker(setting)
		
		# 4. WRAP IN ROW
		if row_control:
			_create_standard_row(container, setting, row_control)
			active_inputs[key] = row_control
			
	return active_inputs

# Renders a schema into a specific container, handling safe cleanup
static func render_dynamic_section(container: Control, schema: Array, callback: Callable) -> Dictionary:
	var content_box = container.get_node_or_null("ContentBox")
	
	# Safe Cleanup Check (If queued for deletion, ignore it)
	if content_box and content_box.is_queued_for_deletion():
		content_box.name = "ContentBox_Trash" 
		content_box = null
	
	if not content_box:
		content_box = VBoxContainer.new()
		content_box.name = "ContentBox"
		content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		container.add_child(content_box)
	
	var inputs = build_ui(schema, content_box)
	connect_live_updates(inputs, callback)
	return inputs

static func clear_ui(container: Control) -> void:
	if not container: return
	for child in container.get_children():
		child.queue_free()

# ==============================================================================
# 2. INTERNAL COMPONENT FACTORIES
# ==============================================================================

static func _create_standard_row(parent: Control, setting: Dictionary, control: Control) -> void:
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(row)
	
	var label = Label.new()
	label.text = setting.get("label", setting["name"].capitalize())
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL 
	label.size_flags_stretch_ratio = 0.4 
	
	var tooltip = setting.get("hint_text", "") # Standard property is often "hint_text"
	if tooltip == "": tooltip = setting.get("hint", "") # Fallback
	
	if tooltip != "":
		label.tooltip_text = tooltip
		label.mouse_filter = Control.MOUSE_FILTER_STOP
	
	if setting.get("mixed", false):
		label.modulate = Color(1, 1, 1, 0.7)
		
	row.add_child(label)
	
	# Configure Control Layout
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_stretch_ratio = 0.6
	row.add_child(control)

static func _create_separator(parent: Control) -> void:
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 20) 
	sep.modulate = Color(1, 1, 1, 0.5)
	parent.add_child(sep)

static func _create_action_button(setting: Dictionary, parent: Control) -> Button:
	var btn = Button.new()
	var label = setting.get("label", "Action")
	btn.text = label
	
	if "Delete" in label or "Clear" in label:
		btn.modulate = Color(1, 0.5, 0.5)
	elif "Add" in label: 
		btn.modulate = Color(0.6, 1.0, 0.6)
		
	parent.add_child(btn)
	return btn

static func _create_number(setting: Dictionary) -> SpinBox:
	var spin = SpinBox.new()
	spin.min_value = setting.get("min", -99999)
	spin.max_value = setting.get("max", 99999)
	spin.step = setting.get("step", 1.0 if setting["type"] == TYPE_INT else 0.1)
	spin.value = setting.get("default", 0)
	
	if setting.get("mixed", false):
		spin.suffix = "(Mixed)"
		spin.modulate = Color(1, 1, 1, 0.5)
		
	return spin

static func _create_checkbox(setting: Dictionary) -> CheckBox:
	var chk = CheckBox.new()
	chk.text = "Enabled"
	chk.button_pressed = bool(setting.get("default", false))
	
	if setting.get("mixed", false):
		chk.text = "Mixed"
		chk.modulate = Color(1, 1, 1, 0.5)
		
	return chk

static func _create_line_edit(setting: Dictionary) -> LineEdit:
	var field = LineEdit.new()
	var is_mixed = setting.get("mixed", false)
	
	if is_mixed:
		field.placeholder_text = "(Mixed Values)"
		field.text = ""
	else:
		field.text = str(setting.get("default", ""))
		field.placeholder_text = setting.get("hint_string", "")
		
	return field

static func _create_dropdown(setting: Dictionary) -> OptionButton:
	var opt = OptionButton.new()
	var options = []
	
	# Source A: Explicit options string "A,B,C"
	if setting.get("options", "") != "":
		var str_opts = setting["options"].split(",")
		for s in str_opts: options.append(s.strip_edges())
	# Source B: Hint String (Standard Godot enum hint)
	elif setting.get("hint_string", "") != "":
		var str_opts = setting["hint_string"].split(",")
		for s in str_opts: options.append(s.strip_edges())
		
	for i in range(options.size()):
		opt.add_item(options[i], i)
		
	if setting.get("mixed", false):
		opt.add_separator()
		opt.add_item("-- Mixed --", -1)
		opt.selected = opt.item_count - 1
	else:
		opt.selected = int(setting.get("default", 0))
		
	return opt

static func _create_vector2(setting: Dictionary) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	var def_val = setting.get("default", Vector2.ZERO)
	var is_mixed = setting.get("mixed", false)
	
	var spin_x = SpinBox.new()
	var spin_y = SpinBox.new()
	
	# Setup Spins
	for s in [spin_x, spin_y]:
		s.min_value = -99999; s.max_value = 99999
		s.step = setting.get("step", 1.0)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if is_mixed: s.modulate = Color(1,1,1,0.5)
			
	spin_x.prefix = "X:"; spin_x.value = def_val.x
	spin_y.prefix = "Y:"; spin_y.value = def_val.y
	
	hbox.add_child(spin_x)
	hbox.add_child(spin_y)
	return hbox

static func _create_color_picker(setting: Dictionary) -> ColorPickerButton:
	var picker = ColorPickerButton.new()
	picker.custom_minimum_size.x = 40
	picker.color = setting.get("default", Color.WHITE)
	return picker

static func _create_read_only_label(setting: Dictionary) -> Label:
	var lbl = Label.new()
	lbl.text = str(setting.get("default", ""))
	lbl.modulate = Color(0.8, 0.8, 0.8)
	return lbl

# ==============================================================================
# 3. WIRING & UTILS
# ==============================================================================

static func collect_params(active_inputs: Dictionary) -> Dictionary:
	var params = {}
	for key in active_inputs:
		var control = active_inputs[key]
		if control is SpinBox: params[key] = control.value
		elif control is CheckBox: params[key] = control.button_pressed
		elif control is OptionButton: params[key] = control.selected
		elif control is LineEdit: params[key] = control.text 
		elif control is ColorPickerButton: params[key] = control.color
		elif control is HBoxContainer:
			# Vector2 Logic
			var sx = control.get_child(0) as SpinBox
			var sy = control.get_child(1) as SpinBox
			if sx and sy: params[key] = Vector2(sx.value, sy.value)
	return params

static func connect_live_updates(active_inputs: Dictionary, callback: Callable) -> void:
	for key in active_inputs:
		var control = active_inputs[key]
		
		if control is SpinBox:
			control.value_changed.connect(func(val): callback.call(key, val))
		elif control is CheckBox:
			control.toggled.connect(func(val): callback.call(key, val))
		elif control is OptionButton:
			control.item_selected.connect(func(val): callback.call(key, val))
		elif control is LineEdit:
			control.text_changed.connect(func(val): callback.call(key, val))
		elif control is ColorPickerButton:
			control.color_changed.connect(func(val): callback.call(key, val))
		elif control is Button:
			control.pressed.connect(func(): callback.call(key, true))
		elif control is HBoxContainer:
			# Vector2
			var sx = control.get_child(0)
			var sy = control.get_child(1)
			sx.value_changed.connect(func(val): callback.call(key, Vector2(val, sy.value)))
			sy.value_changed.connect(func(val): callback.call(key, Vector2(sx.value, val)))

# --- REUSABLE COMPONENT LOGIC ---
static func sync_picker_button(active_inputs: Dictionary, btn_key: String, label_prefix: String, value: Variant) -> void:
	if active_inputs.has(btn_key):
		var btn = active_inputs[btn_key] as Button
		if btn:
			if str(value) == "":
				btn.text = "Pick %s (Random/None)" % label_prefix
				btn.modulate = Color.WHITE
			else:
				btn.text = "%s: %s" % [label_prefix, value]
				btn.modulate = Color(0.7, 1.0, 0.7)
