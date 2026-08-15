class_name ScatterDesignerPopup
extends ConfirmationDialog

var scatter_sets: Dictionary = {}
var _current_key: String = ""
var _active_inputs: Dictionary = {}

var _item_list: ItemList
var _settings_container: VBoxContainer
var _btn_add: Button
var _btn_dup: Button
var _btn_del: Button

func _init() -> void:
	title = "Scatter Sets Designer"
	min_size = Vector2(750, 550)
	transient = true
	exclusive = true
	
	var split = HSplitContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 220 # Width of the left panel
	add_child(split)
	
	# --- LEFT PANEL (List & Actions) ---
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left_vbox)
	
	_item_list = ItemList.new()
	_item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_item_list.item_selected.connect(_on_list_selected)
	left_vbox.add_child(_item_list)
	
	var btn_hbox = HBoxContainer.new()
	left_vbox.add_child(btn_hbox)
	
	_btn_add = Button.new()
	_btn_add.text = "Add"
	_btn_add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_add.pressed.connect(_on_add_pressed)
	btn_hbox.add_child(_btn_add)
	
	_btn_dup = Button.new()
	_btn_dup.text = "Dup"
	_btn_dup.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_dup.pressed.connect(_on_duplicate_pressed)
	btn_hbox.add_child(_btn_dup)
	
	_btn_del = Button.new()
	_btn_del.text = "Del"
	_btn_del.modulate = Color(1.0, 0.5, 0.5)
	_btn_del.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_del.pressed.connect(_on_delete_pressed)
	btn_hbox.add_child(_btn_del)
	
	# --- RIGHT PANEL (Dynamic Settings) ---
	var right_scroll = ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(right_scroll)
	
	var right_margin = MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_top", 10)
	right_margin.add_theme_constant_override("margin_left", 15)
	right_margin.add_theme_constant_override("margin_right", 15)
	right_margin.add_theme_constant_override("margin_bottom", 10)
	right_scroll.add_child(right_margin)
	
	_settings_container = VBoxContainer.new()
	_settings_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.add_child(_settings_container)

func open() -> void:
	scatter_sets = ConfigManager.load_scatter_sets().duplicate(true)
	_current_key = ""
	_populate_list()
	popup_centered()

func _populate_list() -> void:
	_item_list.clear()
	var keys = scatter_sets.keys()
	var selected_idx = -1
	
	for i in range(keys.size()):
		var key = keys[i]
		var s_data = scatter_sets[key]
		var s_name = s_data.get("name", "Unnamed Set")
		var s_color = s_data.get("color", Color.WHITE)
		
		# Create a little color square icon!
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(s_color)
		var tex = ImageTexture.create_from_image(img)
		
		_item_list.add_item(s_name, tex)
		_item_list.set_item_metadata(i, key)
		
		if key == _current_key:
			selected_idx = i
			
	if keys.is_empty():
		SettingsUIBuilder.clear_ui(_settings_container)
		_btn_dup.disabled = true
		_btn_del.disabled = true
	else:
		_btn_dup.disabled = false
		_btn_del.disabled = false
		if selected_idx >= 0:
			_item_list.select(selected_idx)
			_on_list_selected(selected_idx)
		else:
			_item_list.select(0)
			_on_list_selected(0)

func _on_list_selected(index: int) -> void:
	_current_key = _item_list.get_item_metadata(index)
	_build_right_panel()

func _build_right_panel() -> void:
	if _current_key == "" or not scatter_sets.has(_current_key): return
	var current_vals = scatter_sets[_current_key]
	
	var schema = [
		{ "name": "name", "label": "Scatter Set Name", "type": TYPE_STRING, "default": current_vals.get("name", "New Set") },
		{ "name": "color", "label": "Editor Entity Color", "type": TYPE_COLOR, "default": current_vals.get("color", Color.WHITE) },
		{ "name": "sep_1", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "spawn_mode", "label": "Spawn Mode", "type": TYPE_INT, "default": current_vals.get("spawn_mode", 0), "hint": "enum", "hint_string": "Density (Organic %),Fixed Quantity (Cap)" },
		{ "name": "density", "label": "Spawn Density %", "type": TYPE_FLOAT, "default": current_vals.get("density", 0.05), "min": 0.0, "max": 1.0, "step": 0.001 },
		{ "name": "fixed_quantity", "label": "Fixed Spawn Quantity", "type": TYPE_INT, "default": current_vals.get("fixed_quantity", 1), "min": 1, "max": 999 },
		{ "name": "sep_2", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "min_dist", "label": "Min Wall Distance", "type": TYPE_INT, "default": current_vals.get("min_dist", 0), "min": 0, "max": 20 },
		{ "name": "max_dist", "label": "Max Wall Distance", "type": TYPE_INT, "default": current_vals.get("max_dist", 99), "min": 1, "max": 99 },
		{ "name": "symmetry", "label": "Symmetry Clumping", "type": TYPE_INT, "default": current_vals.get("symmetry", 0), "hint": "enum", "hint_string": "None,X-Axis (Left/Right),Y-Axis (Top/Bottom),Radial (Point),4-Way" },
		{ "name": "sep_3", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "clump_chance", "label": "Organic Clump Chance", "type": TYPE_FLOAT, "default": current_vals.get("clump_chance", 0.0), "min": 0.0, "max": 1.0, "step": 0.05 },
		{ "name": "max_clump_size", "label": "Max Clump Size", "type": TYPE_INT, "default": current_vals.get("max_clump_size", 3), "min": 2, "max": 25 }
	]
	
	_active_inputs = SettingsUIBuilder.render_dynamic_section(_settings_container, schema, _on_setting_changed)
	_update_field_visibility()

func _on_setting_changed(key: String, value: Variant) -> void:
	if _current_key == "": return
	scatter_sets[_current_key][key] = value
	
	# If name or color changes, redraw the left list so the text/icon updates instantly
	if key == "name" or key == "color":
		var idx = _item_list.get_selected_items()[0]
		_item_list.set_item_text(idx, scatter_sets[_current_key].get("name", "Unnamed"))
		if key == "color": _populate_list()
		
	# If spawn mode changes, we should dim out the irrelevant setting!
	if key == "spawn_mode":
		_update_field_visibility()

# Dims Density if Fixed is selected, and vice versa!
func _update_field_visibility() -> void:
	var mode = scatter_sets[_current_key].get("spawn_mode", 0)
	if _active_inputs.has("density"):
		_active_inputs["density"].get_parent().modulate = Color(1,1,1, 1.0 if mode == 0 else 0.3)
	if _active_inputs.has("fixed_quantity"):
		_active_inputs["fixed_quantity"].get_parent().modulate = Color(1,1,1, 1.0 if mode == 1 else 0.3)

func _on_add_pressed() -> void:
	var new_id = "set_" + str(hash(Time.get_ticks_usec()))
	scatter_sets[new_id] = {
		"name": "New Scatter Set", "color": Color(0.8, 0.8, 0.2), "spawn_mode": 0,
		"density": 0.05, "fixed_quantity": 3, "min_dist": 0, "max_dist": 99,
		"symmetry": 0, "clump_chance": 0.0, "max_clump_size": 3
	}
	_current_key = new_id
	_populate_list()

func _on_duplicate_pressed() -> void:
	if _current_key == "" or not scatter_sets.has(_current_key): return
	var new_id = "set_" + str(hash(Time.get_ticks_usec()))
	var dup_data = scatter_sets[_current_key].duplicate(true)
	dup_data["name"] = dup_data["name"] + " (Copy)"
	scatter_sets[new_id] = dup_data
	_current_key = new_id
	_populate_list()

func _on_delete_pressed() -> void:
	if _current_key == "": return
	scatter_sets.erase(_current_key)
	_current_key = ""
	_populate_list()
