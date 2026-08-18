class_name ScatterDesignerPopup
extends ConfirmationDialog

var scatter_sets: Dictionary = {}
var _current_key: String = ""
var _active_inputs: Dictionary = {}
var _texture_cache: Dictionary = {}

var _item_list: ItemList
var _dynamic_container: VBoxContainer
var _sprite_ui_container: VBoxContainer
var _btn_add: Button
var _btn_dup: Button
var _btn_del: Button

# --- SPRITE UI REFS ---
var _file_dialog: FileDialog
var _lbl_sprite_path: Label
var _spin_offset_x: SpinBox
var _spin_offset_y: SpinBox
var _spin_scale_x: SpinBox
var _spin_scale_y: SpinBox
var _opt_filter: OptionButton

# --- CANVAS REFS ---
var canvas: Control
var zoom_level: float = 2.0
var tile_size: float = 32.0

func _init() -> void:
	title = "Scatter Sets Designer"
	size = Vector2i(950, 600)
	transient = true
	exclusive = true
	
	var hbox = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(hbox)
	
	# ==========================================================================
	# LEFT PANEL (List & Actions)
	# ==========================================================================
	var left_vbox = VBoxContainer.new()
	left_vbox.custom_minimum_size.x = 220
	hbox.add_child(left_vbox)
	
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
	
	# ==========================================================================
	# MIDDLE PANEL (Dynamic Settings & Sprite UI)
	# ==========================================================================
	var mid_scroll = ScrollContainer.new()
	mid_scroll.custom_minimum_size.x = 280
	mid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(mid_scroll)
	
	var mid_margin = MarginContainer.new()
	mid_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_margin.add_theme_constant_override("margin_top", 10)
	mid_margin.add_theme_constant_override("margin_left", 15)
	mid_margin.add_theme_constant_override("margin_right", 15)
	mid_margin.add_theme_constant_override("margin_bottom", 10)
	mid_scroll.add_child(mid_margin)
	
	var mid_vbox = VBoxContainer.new()
	mid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_margin.add_child(mid_vbox)
	
	# Container 1: The Dynamic UI (Wiped by SettingsUIBuilder)
	_dynamic_container = VBoxContainer.new()
	mid_vbox.add_child(_dynamic_container)
	
	# Container 2: The Static Sprite UI (Never wiped, prevents duplication bugs!)
	_sprite_ui_container = VBoxContainer.new()
	_sprite_ui_container.visible = false
	mid_vbox.add_child(_sprite_ui_container)
	
	_sprite_ui_container.add_child(HSeparator.new())
	
	var lbl_sprite = Label.new()
	lbl_sprite.text = "Visual Sprite Mapping"
	lbl_sprite.modulate = Color(0.6, 1.0, 0.6)
	_sprite_ui_container.add_child(lbl_sprite)
	
	var box_sprite_btns = HBoxContainer.new()
	var btn_load_sprite = Button.new()
	btn_load_sprite.text = "Load Image..."
	btn_load_sprite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_load_sprite.pressed.connect(func(): _file_dialog.popup_centered())
	box_sprite_btns.add_child(btn_load_sprite)
	
	var btn_clear_sprite = Button.new()
	btn_clear_sprite.text = "Clear"
	btn_clear_sprite.pressed.connect(func(): 
		if _current_key != "":
			scatter_sets[_current_key]["texture_path"] = ""
			_lbl_sprite_path.text = "No Sprite Loaded"
			canvas.queue_redraw()
	)
	box_sprite_btns.add_child(btn_clear_sprite)
	_sprite_ui_container.add_child(box_sprite_btns)
	
	_lbl_sprite_path = Label.new()
	_lbl_sprite_path.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lbl_sprite_path.add_theme_font_size_override("font_size", 10)
	_lbl_sprite_path.modulate = Color(0.6, 0.6, 0.6)
	_sprite_ui_container.add_child(_lbl_sprite_path)
	
	var box_offset = HBoxContainer.new()
	var lbl_off = Label.new()
	lbl_off.text = "Offset (Tiles):"
	box_offset.add_child(lbl_off)
	
	_spin_offset_x = _create_spinbox(-10, 10, 0.1)
	_spin_offset_y = _create_spinbox(-10, 10, 0.1)
	_spin_offset_x.value_changed.connect(func(v): 
		if _current_key != "":
			scatter_sets[_current_key]["texture_offset"] = Vector2(v, scatter_sets[_current_key].get("texture_offset", Vector2.ZERO).y)
			canvas.queue_redraw()
	)
	_spin_offset_y.value_changed.connect(func(v): 
		if _current_key != "":
			scatter_sets[_current_key]["texture_offset"] = Vector2(scatter_sets[_current_key].get("texture_offset", Vector2.ZERO).x, v)
			canvas.queue_redraw()
	)
	box_offset.add_child(_spin_offset_x)
	box_offset.add_child(_spin_offset_y)
	_sprite_ui_container.add_child(box_offset)
	
	var box_scale = HBoxContainer.new()
	var lbl_scale = Label.new()
	lbl_scale.text = "Scale Mult:"
	box_scale.add_child(lbl_scale)
	
	_spin_scale_x = _create_spinbox(0.1, 10, 0.1)
	_spin_scale_y = _create_spinbox(0.1, 10, 0.1)
	_spin_scale_x.value_changed.connect(func(v): 
		if _current_key != "":
			scatter_sets[_current_key]["texture_scale"] = Vector2(v, scatter_sets[_current_key].get("texture_scale", Vector2.ONE).y)
			canvas.queue_redraw()
	)
	_spin_scale_y.value_changed.connect(func(v): 
		if _current_key != "":
			scatter_sets[_current_key]["texture_scale"] = Vector2(scatter_sets[_current_key].get("texture_scale", Vector2.ONE).x, v)
			canvas.queue_redraw()
	)
	box_scale.add_child(_spin_scale_x)
	box_scale.add_child(_spin_scale_y)
	_sprite_ui_container.add_child(box_scale)
	
	_opt_filter = OptionButton.new()
	_opt_filter.add_item("Filter: Nearest (Pixel Art)", 0)
	_opt_filter.add_item("Filter: Linear (Smooth)", 1)
	_opt_filter.item_selected.connect(func(idx): 
		if _current_key != "":
			scatter_sets[_current_key]["texture_filter"] = idx
			canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if idx == 0 else CanvasItem.TEXTURE_FILTER_LINEAR
			canvas.queue_redraw()
	)
	_sprite_ui_container.add_child(_opt_filter)

	_file_dialog = FileDialog.new()
	_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_file_dialog.add_filter("*.png, *.jpg, *.jpeg", "Image Files")
	_file_dialog.size = Vector2i(600, 400)
	_file_dialog.file_selected.connect(_on_file_selected)
	add_child(_file_dialog)

	# ==========================================================================
	# RIGHT PANEL (Canvas)
	# ==========================================================================
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(right_panel)
	
	var top_tools = HBoxContainer.new()
	right_panel.add_child(top_tools)
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_tools.add_child(spacer)
	
	var btn_zoom_out = Button.new()
	btn_zoom_out.text = " - Zoom "
	btn_zoom_out.pressed.connect(func(): zoom_level = max(0.5, zoom_level - 0.25); canvas.queue_redraw())
	top_tools.add_child(btn_zoom_out)
	
	var btn_zoom_in = Button.new()
	btn_zoom_in.text = " + Zoom "
	btn_zoom_in.pressed.connect(func(): zoom_level = min(4.0, zoom_level + 0.25); canvas.queue_redraw())
	top_tools.add_child(btn_zoom_in)
	
	var canvas_bg = ColorRect.new()
	canvas_bg.color = Color(0.1, 0.1, 0.12)
	canvas_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_bg.clip_contents = true
	right_panel.add_child(canvas_bg)
	
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas_bg.add_child(canvas)
	canvas.draw.connect(_on_canvas_draw)

func _create_spinbox(min_v: float, max_v: float, step: float) -> SpinBox:
	var sb = SpinBox.new()
	sb.min_value = min_v
	sb.max_value = max_v
	sb.step = step
	sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return sb

# ==============================================================================
# LIFECYCLE & DATA
# ==============================================================================
func open() -> void:
	scatter_sets = ConfigManager.load_scatter_sets().duplicate(true)
	_current_key = ""
	_texture_cache.clear()
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
		
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(s_color)
		var tex = ImageTexture.create_from_image(img)
		
		_item_list.add_item(s_name, tex)
		_item_list.set_item_metadata(i, key)
		
		if key == _current_key:
			selected_idx = i
			
	if keys.is_empty():
		SettingsUIBuilder.clear_ui(_dynamic_container)
		_sprite_ui_container.visible = false
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
	
	# Legacy migration safety
	if not current_vals.has("texture_path"): current_vals["texture_path"] = ""
	if not current_vals.has("texture_offset"): current_vals["texture_offset"] = Vector2.ZERO
	if not current_vals.has("texture_scale"): current_vals["texture_scale"] = Vector2.ONE
	if not current_vals.has("texture_filter"): current_vals["texture_filter"] = 0
	
	var schema = [
		{ "name": "name", "label": "Scatter Set Name", "type": TYPE_STRING, "default": current_vals.get("name", "New Set") },
		{ "name": "color", "label": "Editor Entity Color", "type": TYPE_COLOR, "default": current_vals.get("color", Color.WHITE) }
	]
	
	# Render the dynamic portion into its dedicated container!
	_active_inputs = SettingsUIBuilder.render_dynamic_section(_dynamic_container, schema, _on_setting_changed)
	
	# Update the static Sprite UI values without firing signals
	_sprite_ui_container.visible = true
	
	var tex_path = current_vals.get("texture_path", "No Sprite Loaded")
	_lbl_sprite_path.text = tex_path if tex_path != "" else "No Sprite Loaded"
	
	var off = current_vals.get("texture_offset", Vector2.ZERO)
	_spin_offset_x.set_value_no_signal(off.x)
	_spin_offset_y.set_value_no_signal(off.y)
	
	var sc = current_vals.get("texture_scale", Vector2.ONE)
	_spin_scale_x.set_value_no_signal(sc.x)
	_spin_scale_y.set_value_no_signal(sc.y)
	
	var t_filter = current_vals.get("texture_filter", 0)
	_opt_filter.select(t_filter)
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if t_filter == 0 else CanvasItem.TEXTURE_FILTER_LINEAR
	
	canvas.queue_redraw()

func _on_file_selected(path: String) -> void:
	if _current_key == "": return
	var cached_path = ConfigManager.import_sprite(path)
	if cached_path != "":
		scatter_sets[_current_key]["texture_path"] = cached_path
		if _lbl_sprite_path:
			_lbl_sprite_path.text = cached_path
		if _texture_cache.has(_current_key):
			_texture_cache.erase(_current_key)
		canvas.queue_redraw()

func _get_cached_texture(s_id: String, path: String) -> Texture2D:
	if _texture_cache.has(s_id): return _texture_cache[s_id]
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(path)
		if img:
			var tex = ImageTexture.create_from_image(img)
			_texture_cache[s_id] = tex
			return tex
	return null

func _on_setting_changed(key: String, value: Variant) -> void:
	if _current_key == "": return
	scatter_sets[_current_key][key] = value
	
	if key == "name" or key == "color":
		var idx = _item_list.get_selected_items()[0]
		_item_list.set_item_text(idx, scatter_sets[_current_key].get("name", "Unnamed"))
		if key == "color": 
			_populate_list()
			canvas.queue_redraw()

func _on_add_pressed() -> void:
	var new_id = "set_" + str(hash(Time.get_ticks_usec()))
	scatter_sets[new_id] = {
		"name": "New Scatter Set", 
		"color": Color(0.8, 0.8, 0.2),
		"texture_path": "",
		"texture_offset": Vector2.ZERO,
		"texture_scale": Vector2.ONE,
		"texture_filter": 0
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

# ==============================================================================
# CANVAS DRAWING
# ==============================================================================
func _on_canvas_draw() -> void:
	var center = canvas.size / 2.0
	var actual_ts = tile_size * zoom_level
	
	canvas.draw_line(Vector2(center.x, 0), Vector2(center.x, canvas.size.y), Color(0.4, 0.4, 0.4, 0.8), 2.0)
	canvas.draw_line(Vector2(0, center.y), Vector2(canvas.size.x, center.y), Color(0.4, 0.4, 0.4, 0.8), 2.0)
	
	var grid_color = Color(1, 1, 1, 0.1)
	var steps_x = int((canvas.size.x / 2.0) / actual_ts) + 1
	var steps_y = int((canvas.size.y / 2.0) / actual_ts) + 1
	
	for i in range(-steps_x, steps_x + 1):
		var px = center.x + (i * actual_ts)
		canvas.draw_line(Vector2(px, 0), Vector2(px, canvas.size.y), grid_color, 1.0)
	for i in range(-steps_y, steps_y + 1):
		var py = center.y + (i * actual_ts)
		canvas.draw_line(Vector2(0, py), Vector2(canvas.size.x, py), grid_color, 1.0)
		
	if _current_key != "" and scatter_sets.has(_current_key):
		var struct = scatter_sets[_current_key]
		var color = struct.get("color", Color.WHITE)
		color.a = 0.5 # Make the footprint slightly transparent to see the grid/sprite
		
		# Draw a single 1x1 tile as the "Scatter Footprint" in the exact center
		var footprint_pos = Vector2(center.x - (actual_ts / 2.0), center.y - (actual_ts / 2.0))
		var rect = Rect2(footprint_pos, Vector2(actual_ts, actual_ts))
		
		canvas.draw_rect(rect, color)
		canvas.draw_rect(rect, Color.WHITE, false, 2.0)
		
		# Draw the normalized Sprite
		var tex_path = struct.get("texture_path", "")
		if tex_path != "":
			var tex = _get_cached_texture(_current_key, tex_path)
			if tex:
				var t_offset = struct.get("texture_offset", Vector2.ZERO)
				var t_scale = struct.get("texture_scale", Vector2.ONE)
				
				# Normalize so (1,1) scale = exactly 1 tile size, matching the realizer mathematically!
				var normalized_size = Vector2(actual_ts * t_scale.x, actual_ts * t_scale.y)
				var draw_pos = center - (normalized_size / 2.0) + (t_offset * actual_ts)
				
				canvas.draw_texture_rect(tex, Rect2(draw_pos, normalized_size), false)
