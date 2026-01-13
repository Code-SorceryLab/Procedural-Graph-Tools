class_name SettingsUIBuilder
extends RefCounted

# [NEW] Helper to wipe a container clean
static func clear_ui(container: Control) -> void:
	if not container: return
	for child in container.get_children():
		child.queue_free()

# Generates UI controls inside 'container' based on 'settings_list'.
static func build_ui(settings_list: Array, container: Control, _tooltip_map: Dictionary = {}) -> Dictionary:
	# [CHANGE] Use the helper to ensure consistent clearing
	clear_ui(container)
	
	var active_inputs = {}
	
	for setting in settings_list:
		var key = setting["name"]
		var type = setting["type"]
		var default = setting.get("default", 0)
		var hint_text = setting.get("hint", "")
		var hint_string = setting.get("hint_string", "")
		var options_str = setting.get("options", "")
		var is_mixed = setting.get("mixed", false)
		
		# Create Row
		var row = HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		container.add_child(row)
		
		# 1. LABEL
		if hint_text != "action":
			var label = Label.new()
			label.text = setting.get("label", key.capitalize())
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL 
			label.size_flags_stretch_ratio = 0.4 
			
			if hint_text != "" and hint_text != "enum" and hint_text != "read_only":
				label.tooltip_text = hint_text
				label.mouse_filter = Control.MOUSE_FILTER_STOP
			
			if is_mixed:
				label.modulate = Color(1, 1, 1, 0.7)
				
			row.add_child(label) 
		
		# 2. CONTROL
		var control: Control
		
		if options_str != "":
			var opt = OptionButton.new()
			var items = options_str.split(",")
			for i in range(items.size()):
				opt.add_item(items[i].strip_edges(), i)
			
			if is_mixed:
				opt.add_separator()
				opt.add_item("-- Mixed --", -1)
				opt.selected = opt.item_count - 1
			else:
				opt.selected = int(default)
				
			control = opt
			
		else:
			if hint_text == "action" or hint_text == "button":
				var btn = Button.new()
				btn.text = setting.get("label", "Action")
				
				if "Delete" in btn.text or "Clear" in btn.text:
					btn.modulate = Color(1, 0.5, 0.5)
				elif "Add" in btn.text: 
					btn.modulate = Color(0.6, 1.0, 0.6) 
					
				control = btn
			
			elif setting.get("hint") == "separator":
				var sep = HSeparator.new()
				sep.add_theme_constant_override("separation", 30) 
				sep.modulate = Color(1, 1, 1, 0.5)
				container.add_child(sep)
				continue 
			
			else:
				match type:
					TYPE_INT:
						if hint_text == "enum":
							var opt = OptionButton.new()
							var items = hint_string.split(",")
							for i in range(items.size()):
								opt.add_item(items[i].strip_edges(), i)
							
							if is_mixed:
								opt.add_separator()
								opt.add_item("-- Mixed --", -1)
								opt.selected = opt.item_count - 1
							else:
								opt.selected = int(default)
							control = opt
						else:
							var spin = SpinBox.new()
							spin.min_value = setting.get("min", -99999)
							spin.max_value = setting.get("max", 99999)
							spin.step = 1.0
							spin.value = default
							if is_mixed: spin.suffix = " (Mixed)"
							control = spin
							
					TYPE_FLOAT:
						var spin = SpinBox.new()
						spin.min_value = setting.get("min", -99999)
						spin.max_value = setting.get("max", 99999)
						spin.step = setting.get("step", 0.1)
						spin.value = default
						if is_mixed: spin.suffix = " (Mixed)"
						control = spin
					
					TYPE_BOOL:
						var chk = CheckBox.new()
						chk.text = "Enabled"
						if is_mixed:
							chk.text = "Mixed"
							chk.modulate = Color(1, 1, 1, 0.5)
						chk.button_pressed = bool(default)
						control = chk
					
					TYPE_STRING:
						if hint_text == "read_only":
							var info_label = Label.new()
							info_label.text = str(default)
							info_label.modulate = Color(0.8, 0.8, 0.8)
							control = info_label
						else:
							var line_edit = LineEdit.new()
							if is_mixed:
								line_edit.text = ""
								line_edit.placeholder_text = "(Mixed Values)"
							else:
								line_edit.text = str(default)
								line_edit.placeholder_text = hint_string
							control = line_edit

					TYPE_VECTOR2:
						var hbox = HBoxContainer.new()
						var spin_x = SpinBox.new()
						var spin_y = SpinBox.new()
						spin_x.min_value = -99999; spin_x.max_value = 99999
						spin_y.min_value = -99999; spin_y.max_value = 99999
						spin_x.step = setting.get("step", 1.0)
						spin_y.step = setting.get("step", 1.0)
						spin_x.prefix = "X:"
						spin_y.prefix = "Y:"
						spin_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						spin_y.size_flags_horizontal = Control.SIZE_EXPAND_FILL
						if default is Vector2:
							spin_x.value = default.x
							spin_y.value = default.y
						
						if is_mixed:
							spin_x.modulate = Color(1,1,1,0.5)
							spin_y.modulate = Color(1,1,1,0.5)
							
						hbox.add_child(spin_x)
						hbox.add_child(spin_y)
						control = hbox
						
					# [NEW] TYPE_COLOR Support
					TYPE_COLOR:
						var picker = ColorPickerButton.new()
						picker.custom_minimum_size.x = 40
						if default is Color:
							picker.color = default
						control = picker
		
		if control:
			if hint_text != "" and hint_text != "enum" and hint_text != "action" and hint_text != "read_only":
				control.tooltip_text = hint_text
			
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			control.size_flags_stretch_ratio = 0.6 
			row.add_child(control) 
			
			if hint_text != "read_only":
				active_inputs[key] = control
			
	return active_inputs

static func collect_params(active_inputs: Dictionary) -> Dictionary:
	var params = {}
	for key in active_inputs:
		var control = active_inputs[key]
		if control is SpinBox: params[key] = control.value
		elif control is CheckBox: params[key] = control.button_pressed
		elif control is OptionButton: params[key] = control.selected
		elif control is LineEdit: params[key] = control.text 
		elif control is ColorPickerButton: params[key] = control.color # [NEW]
		elif control is HBoxContainer:
			var spin_x = control.get_child(0) as SpinBox
			var spin_y = control.get_child(1) as SpinBox
			params[key] = Vector2(spin_x.value, spin_y.value)
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
		elif control is ColorPickerButton: # [NEW]
			control.color_changed.connect(func(val): callback.call(key, val))
		elif control is HBoxContainer:
			var spin_x = control.get_child(0)
			var spin_y = control.get_child(1)
			spin_x.value_changed.connect(func(val): callback.call(key, Vector2(val, spin_y.value)))
			spin_y.value_changed.connect(func(val): callback.call(key, Vector2(spin_x.value, val)))
		elif control is Button:
			control.pressed.connect(func(): callback.call(key, true))

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
