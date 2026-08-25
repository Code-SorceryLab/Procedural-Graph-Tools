class_name StructureDesignerPopup
extends AcceptDialog

var structures: Dictionary = {}
var current_id: String = ""

# --- UI REFS ---
var item_list: ItemList
var name_edit: LineEdit
var color_picker: ColorPickerButton
var chk_rotate: CheckBox
var chk_face_path: CheckBox
var chk_solid: CheckBox
var opt_front_dir: OptionButton

# Sprite Refs
var lbl_sprite_path: Label
var file_dialog: FileDialog
var spin_offset_x: SpinBox
var spin_offset_y: SpinBox
var spin_scale_x: SpinBox
var spin_scale_y: SpinBox
var opt_filter: OptionButton

var prop_panel: VBoxContainer
var painter: GridCanvasPainter # [NEW] Replaces canvas, zoom, and tile_size!

func _init() -> void:
	title = "Custom Structure Designer"
	size = Vector2i(1000, 700) 
	
	var hbox = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(hbox)
	
	# ==========================================================================
	# LEFT PANEL: LIST & PROPERTIES
	# ==========================================================================
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size.x = 280
	hbox.add_child(left_panel)
	
	var lbl_list = Label.new()
	lbl_list.text = "Saved Structures"
	left_panel.add_child(lbl_list)
	
	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.item_selected.connect(_on_item_selected)
	left_panel.add_child(item_list)
	
	var btn_box = HBoxContainer.new()
	left_panel.add_child(btn_box)
	
	var btn_add = Button.new()
	btn_add.text = " + Add New "
	btn_add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_add.pressed.connect(_add_new_structure)
	btn_box.add_child(btn_add)
	
	var btn_del = Button.new()
	btn_del.text = " - Delete "
	btn_del.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_del.pressed.connect(_delete_current_structure)
	btn_box.add_child(btn_del)
	
	left_panel.add_child(HSeparator.new())
	
	# Properties Inspector
	var prop_scroll = ScrollContainer.new()
	prop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(prop_scroll)
	
	prop_panel = VBoxContainer.new()
	prop_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	prop_panel.visible = false
	prop_scroll.add_child(prop_panel)
	
	var lbl_name = Label.new()
	lbl_name.text = "Structure Name:"
	prop_panel.add_child(lbl_name)
	name_edit = LineEdit.new()
	name_edit.text_changed.connect(func(t): structures[current_id]["name"] = t; _refresh_list())
	prop_panel.add_child(name_edit)
	
	var box_color = HBoxContainer.new()
	var lbl_color = Label.new()
	lbl_color.text = "Display Color:"
	box_color.add_child(lbl_color)
	
	color_picker = ColorPickerButton.new()
	color_picker.custom_minimum_size.x = 40
	color_picker.color_changed.connect(func(c): structures[current_id]["color"] = c; painter.canvas.queue_redraw())
	box_color.add_child(color_picker)
	prop_panel.add_child(box_color)
	
	chk_rotate = CheckBox.new()
	chk_rotate.text = "Allow 90° Rotations"
	chk_rotate.toggled.connect(func(v): structures[current_id]["allow_rotation"] = v)
	prop_panel.add_child(chk_rotate)
	
	chk_face_path = CheckBox.new()
	chk_face_path.text = "Face Critical Path"
	chk_face_path.toggled.connect(func(v): structures[current_id]["face_path"] = v; painter.canvas.queue_redraw())
	prop_panel.add_child(chk_face_path)
	
	chk_solid = CheckBox.new()
	chk_solid.text = "Solid Collision (Blocks Pathing)"
	chk_solid.toggled.connect(func(v): structures[current_id]["is_solid"] = v; painter.canvas.queue_redraw())
	prop_panel.add_child(chk_solid)
	
	opt_front_dir = OptionButton.new()
	opt_front_dir.add_item("Front: UP", 0)
	opt_front_dir.add_item("Front: RIGHT", 1)
	opt_front_dir.add_item("Front: DOWN", 2)
	opt_front_dir.add_item("Front: LEFT", 3)
	opt_front_dir.item_selected.connect(_on_front_dir_selected)
	prop_panel.add_child(opt_front_dir)
	
	prop_panel.add_child(HSeparator.new())
	
	# ==========================================================================
	# SPRITE MAPPING UI
	# ==========================================================================
	var lbl_sprite = Label.new()
	lbl_sprite.text = "Visual Sprite Mapping"
	lbl_sprite.modulate = Color(0.6, 1.0, 0.6)
	prop_panel.add_child(lbl_sprite)
	
	var box_sprite_btns = HBoxContainer.new()
	var btn_load_sprite = Button.new()
	btn_load_sprite.text = "Load Image..."
	btn_load_sprite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_load_sprite.pressed.connect(func(): file_dialog.popup_centered())
	box_sprite_btns.add_child(btn_load_sprite)
	
	var btn_clear_sprite = Button.new()
	btn_clear_sprite.text = "Clear"
	btn_clear_sprite.pressed.connect(func(): structures[current_id]["texture_path"] = ""; painter.canvas.queue_redraw())
	box_sprite_btns.add_child(btn_clear_sprite)
	prop_panel.add_child(box_sprite_btns)
	
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.add_filter("*.png, *.jpg, *.jpeg", "Image Files")
	file_dialog.size = Vector2i(600, 400)
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)
	
	lbl_sprite_path = Label.new()
	lbl_sprite_path.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_sprite_path.add_theme_font_size_override("font_size", 10)
	lbl_sprite_path.modulate = Color(0.6, 0.6, 0.6)
	prop_panel.add_child(lbl_sprite_path)
	
	var box_offset = HBoxContainer.new()
	var lbl_offset = Label.new()
	lbl_offset.text = "Offset (Tiles):"
	box_offset.add_child(lbl_offset)
	
	spin_offset_x = _create_spinbox(-10, 10, 0.1)
	spin_offset_y = _create_spinbox(-10, 10, 0.1)
	spin_offset_x.value_changed.connect(func(v): structures[current_id]["texture_offset"] = Vector2(v, structures[current_id].get("texture_offset", Vector2.ZERO).y); painter.canvas.queue_redraw())
	spin_offset_y.value_changed.connect(func(v): structures[current_id]["texture_offset"] = Vector2(structures[current_id].get("texture_offset", Vector2.ZERO).x, v); painter.canvas.queue_redraw())
	box_offset.add_child(spin_offset_x); box_offset.add_child(spin_offset_y)
	prop_panel.add_child(box_offset)
	
	var box_scale = HBoxContainer.new()
	var lbl_scale = Label.new()
	lbl_scale.text = "Scale Mult:"
	box_scale.add_child(lbl_scale)
	
	spin_scale_x = _create_spinbox(0.1, 10, 0.1)
	spin_scale_y = _create_spinbox(0.1, 10, 0.1)
	spin_scale_x.value_changed.connect(func(v): structures[current_id]["texture_scale"] = Vector2(v, structures[current_id].get("texture_scale", Vector2.ONE).y); painter.canvas.queue_redraw())
	spin_scale_y.value_changed.connect(func(v): structures[current_id]["texture_scale"] = Vector2(structures[current_id].get("texture_scale", Vector2.ONE).x, v); painter.canvas.queue_redraw())
	box_scale.add_child(spin_scale_x); box_scale.add_child(spin_scale_y)
	prop_panel.add_child(box_scale)
	
	opt_filter = OptionButton.new()
	opt_filter.add_item("Filter: Nearest (Pixel Perfect)", 0)
	opt_filter.add_item("Filter: Linear (Smooth)", 1)
	opt_filter.item_selected.connect(func(idx): 
		structures[current_id]["texture_filter"] = idx
		painter.canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if idx == 0 else CanvasItem.TEXTURE_FILTER_LINEAR
		painter.canvas.queue_redraw()
	)
	prop_panel.add_child(opt_filter)

	# ==========================================================================
	# RIGHT PANEL: GRID CANVAS PAINTER
	# ==========================================================================
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(right_panel)
	
	painter = GridCanvasPainter.new()
	painter.origin_mode = GridCanvasPainter.OriginMode.CENTERED
	right_panel.add_child(painter)
	
	painter.cell_painted.connect(_on_cell_painted)
	painter.canvas.draw.connect(_on_canvas_draw)

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
	structures = ConfigManager.load_structures()
	_refresh_list()
	
	if structures.is_empty():
		_add_new_structure()
	else:
		item_list.select(0)
		_on_item_selected(0)
		
	popup_centered()

func _refresh_list() -> void:
	item_list.clear()
	var keys = structures.keys()
	for key in keys:
		var struct = structures[key]
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(struct.get("color", Color.CYAN))
		var tex = ImageTexture.create_from_image(img)
		item_list.add_item(struct["name"], tex)
		item_list.set_item_metadata(item_list.item_count - 1, key)
		if key == current_id:
			item_list.select(item_list.item_count - 1)

func _add_new_structure() -> void:
	var new_id = "struct_" + str(Time.get_unix_time_from_system())
	structures[new_id] = {
		"name": "New Structure",
		"color": Color(0.2, 0.6, 1.0, 0.8),
		"footprint": [Vector2i(0, 0)],
		"allow_rotation": true,
		"face_path": true,
		"is_solid": true,
		"front_dir": Vector2i.UP,
		"texture_path": "",
		"texture_offset": Vector2.ZERO,
		"texture_scale": Vector2(1.0, 1.0),
		"texture_filter": 0
	}
	_refresh_list()
	for i in range(item_list.item_count):
		if item_list.get_item_metadata(i) == new_id:
			item_list.select(i)
			_on_item_selected(i)
			break

func _delete_current_structure() -> void:
	if current_id != "" and structures.has(current_id):
		structures.erase(current_id)
		current_id = ""
		prop_panel.visible = false
		_refresh_list()
		painter.canvas.queue_redraw()

func _on_item_selected(idx: int) -> void:
	current_id = item_list.get_item_metadata(idx)
	var struct = structures[current_id]
	
	# Legacy migration
	if not struct.has("is_solid"): struct["is_solid"] = true
	if not struct.has("texture_path"): struct["texture_path"] = ""
	if not struct.has("texture_offset"): struct["texture_offset"] = Vector2.ZERO
	if not struct.has("texture_scale"): struct["texture_scale"] = Vector2.ONE
	if not struct.has("texture_filter"): struct["texture_filter"] = 0
	
	prop_panel.visible = true
	name_edit.text = struct.get("name", "Unnamed")
	color_picker.color = struct.get("color", Color.CYAN)
	chk_rotate.button_pressed = struct.get("allow_rotation", true)
	chk_face_path.button_pressed = struct.get("face_path", true)
	chk_solid.button_pressed = struct.get("is_solid", true)
	
	var f_dir = struct.get("front_dir", Vector2i.UP)
	if f_dir == Vector2i.UP: opt_front_dir.select(0)
	elif f_dir == Vector2i.RIGHT: opt_front_dir.select(1)
	elif f_dir == Vector2i.DOWN: opt_front_dir.select(2)
	elif f_dir == Vector2i.LEFT: opt_front_dir.select(3)
	
	lbl_sprite_path.text = struct.get("texture_path", "No Sprite Loaded")
	var off = struct.get("texture_offset", Vector2.ZERO)
	spin_offset_x.set_value_no_signal(off.x)
	spin_offset_y.set_value_no_signal(off.y)
	var sc = struct.get("texture_scale", Vector2.ONE)
	spin_scale_x.set_value_no_signal(sc.x)
	spin_scale_y.set_value_no_signal(sc.y)
	
	var t_filter = struct.get("texture_filter", 0)
	opt_filter.select(t_filter)
	painter.canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if t_filter == 0 else CanvasItem.TEXTURE_FILTER_LINEAR
	
	painter.canvas.queue_redraw()

func _on_front_dir_selected(idx: int) -> void:
	var dir = Vector2i.UP
	if idx == 1: dir = Vector2i.RIGHT
	elif idx == 2: dir = Vector2i.DOWN
	elif idx == 3: dir = Vector2i.LEFT
	structures[current_id]["front_dir"] = dir
	painter.canvas.queue_redraw()

func _on_file_selected(path: String) -> void:
	if current_id == "": return
	var cached_path = ConfigManager.import_sprite(path)
	if cached_path != "":
		structures[current_id]["texture_path"] = cached_path
		lbl_sprite_path.text = cached_path
		painter.canvas.queue_redraw()

# ==============================================================================
# PAINTER API USAGE
# ==============================================================================
func _on_cell_painted(coord: Vector2i, is_erase: bool, is_drag: bool) -> void:
	if current_id == "" or not structures.has(current_id): return
	
	var footprint: Array = structures[current_id]["footprint"]
	var typed_footprint: Array[Vector2i] = []
	typed_footprint.assign(footprint)
	
	if not is_erase and not typed_footprint.has(coord): 
		typed_footprint.append(coord)
	elif is_erase and typed_footprint.has(coord): 
		typed_footprint.erase(coord)
		
	structures[current_id]["footprint"] = typed_footprint
	painter.canvas.queue_redraw()

func _on_canvas_draw() -> void:
	if current_id == "" or not structures.has(current_id): return
	var struct = structures[current_id]
	var footprint: Array = struct.get("footprint", [])
	var color = struct.get("color", Color.CYAN)
	
	if not struct.get("is_solid", true): 
		color.a = 0.5
	
	# Draw Footprint
	for coord in footprint:
		painter.draw_cell_rect(coord, color, Color.WHITE, 2.0)
		
	# Draw Global Cached Sprite
	var tex_path = struct.get("texture_path", "")
	if tex_path != "":
		var tex = ConfigManager.get_cached_texture(tex_path)
		if tex:
			painter.draw_normalized_sprite(Vector2i.ZERO, tex, struct.get("texture_offset", Vector2.ZERO), struct.get("texture_scale", Vector2.ONE), 0, 1.0)
			
	# Draw Arrow
	if struct.get("face_path", true) and footprint.size() > 0:
		painter.draw_facing_arrow(Vector2i.ZERO, footprint, struct.get("front_dir", Vector2i.UP), 0, Color.RED)
