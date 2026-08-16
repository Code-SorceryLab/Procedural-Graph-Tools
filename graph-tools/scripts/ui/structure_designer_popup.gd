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
var chk_solid: CheckBox # [NEW]
var opt_front_dir: OptionButton
var prop_panel: VBoxContainer

var canvas: Control
var zoom_level: float = 1.0
var tile_size: float = 32.0

func _init() -> void:
	title = "Custom Structure Designer"
	size = Vector2i(900, 600)
	
	var hbox = HBoxContainer.new()
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(hbox)
	
	# ==========================================================================
	# LEFT PANEL: LIST & PROPERTIES
	# ==========================================================================
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size.x = 250
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
	prop_panel = VBoxContainer.new()
	prop_panel.visible = false
	left_panel.add_child(prop_panel)
	
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
	color_picker.color_changed.connect(func(c): structures[current_id]["color"] = c; canvas.queue_redraw())
	box_color.add_child(color_picker)
	prop_panel.add_child(box_color)
	
	chk_rotate = CheckBox.new()
	chk_rotate.text = "Allow 90° Rotations"
	chk_rotate.toggled.connect(func(v): structures[current_id]["allow_rotation"] = v)
	prop_panel.add_child(chk_rotate)
	
	chk_face_path = CheckBox.new()
	chk_face_path.text = "Face Critical Path"
	chk_face_path.toggled.connect(func(v): structures[current_id]["face_path"] = v; canvas.queue_redraw())
	prop_panel.add_child(chk_face_path)
	
	# [NEW] Solid Checkbox
	chk_solid = CheckBox.new()
	chk_solid.text = "Solid Collision (Blocks Pathing)"
	chk_solid.toggled.connect(func(v): structures[current_id]["is_solid"] = v)
	prop_panel.add_child(chk_solid)
	
	opt_front_dir = OptionButton.new()
	opt_front_dir.add_item("Front: UP", 0)
	opt_front_dir.add_item("Front: RIGHT", 1)
	opt_front_dir.add_item("Front: DOWN", 2)
	opt_front_dir.add_item("Front: LEFT", 3)
	opt_front_dir.item_selected.connect(_on_front_dir_selected)
	prop_panel.add_child(opt_front_dir)
	
	# ==========================================================================
	# RIGHT PANEL: CANVAS
	# ==========================================================================
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(right_panel)
	
	var top_tools = HBoxContainer.new()
	right_panel.add_child(top_tools)
	
	var lbl_help = Label.new()
	lbl_help.text = " Left Click: Draw   |   Right Click: Erase"
	lbl_help.modulate = Color(1, 1, 1, 0.6)
	top_tools.add_child(lbl_help)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_tools.add_child(spacer)
	
	var btn_zoom_out = Button.new()
	btn_zoom_out.text = " - Zoom "
	btn_zoom_out.pressed.connect(func(): zoom_level = max(0.5, zoom_level - 0.25); canvas.queue_redraw())
	top_tools.add_child(btn_zoom_out)
	
	var btn_zoom_in = Button.new()
	btn_zoom_in.text = " + Zoom "
	btn_zoom_in.pressed.connect(func(): zoom_level = min(3.0, zoom_level + 0.25); canvas.queue_redraw())
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
	canvas.gui_input.connect(_on_canvas_input)

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
		"is_solid": true, # [NEW]
		"front_dir": Vector2i.UP
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
		canvas.queue_redraw()

func _on_item_selected(idx: int) -> void:
	current_id = item_list.get_item_metadata(idx)
	var struct = structures[current_id]
	
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
	
	canvas.queue_redraw()

func _on_front_dir_selected(idx: int) -> void:
	var dir = Vector2i.UP
	if idx == 1: dir = Vector2i.RIGHT
	elif idx == 2: dir = Vector2i.DOWN
	elif idx == 3: dir = Vector2i.LEFT
	
	structures[current_id]["front_dir"] = dir
	canvas.queue_redraw()

# ==============================================================================
# CANVAS DRAWING & LOGIC
# ==============================================================================
func _get_grid_center() -> Vector2:
	return canvas.size / 2.0

func _get_coord_from_mouse(mouse_pos: Vector2) -> Vector2i:
	var center = _get_grid_center()
	var offset = mouse_pos - center
	var actual_tile_size = tile_size * zoom_level
	var gx = floor(offset.x / actual_tile_size)
	var gy = floor(offset.y / actual_tile_size)
	return Vector2i(gx, gy)

func _on_canvas_input(event: InputEvent) -> void:
	if current_id == "" or not structures.has(current_id): return
	
	var is_add = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) or \
				 (event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0)
				 
	var is_remove = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed) or \
					(event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0)
					
	if is_add or is_remove:
		var coord = _get_coord_from_mouse(event.position)
		var footprint: Array = structures[current_id]["footprint"]
		
		var typed_footprint: Array[Vector2i] = []
		typed_footprint.assign(footprint)
		
		if is_add and not typed_footprint.has(coord):
			typed_footprint.append(coord)
		elif is_remove and typed_footprint.has(coord):
			typed_footprint.erase(coord)
			
		structures[current_id]["footprint"] = typed_footprint
		canvas.queue_redraw()

func _on_canvas_draw() -> void:
	var center = _get_grid_center()
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
		
	if current_id != "" and structures.has(current_id):
		var struct = structures[current_id]
		var footprint: Array = struct.get("footprint", [])
		var color = struct.get("color", Color.CYAN)
		
		# [NEW] Visually differentiate non-solid structures by making them semi-transparent in the editor
		var is_solid = struct.get("is_solid", true)
		if not is_solid: color.a = 0.5
		
		for coord in footprint:
			var px = center.x + (coord.x * actual_ts)
			var py = center.y + (coord.y * actual_ts)
			var rect = Rect2(px, py, actual_ts, actual_ts)
			
			canvas.draw_rect(rect, color)
			canvas.draw_rect(rect, Color.WHITE, false, 2.0)
			
		if struct.get("face_path", true) and footprint.size() > 0:
			var front_dir = struct.get("front_dir", Vector2i.UP)
			
			var min_coord = footprint[0]
			var max_coord = footprint[0]
			for c in footprint:
				if c.x < min_coord.x: min_coord.x = c.x
				if c.y < min_coord.y: min_coord.y = c.y
				if c.x > max_coord.x: max_coord.x = c.x
				if c.y > max_coord.y: max_coord.y = c.y
				
			var arrow_start = Vector2.ZERO
			var arrow_end = Vector2.ZERO
			
			var center_x = center.x + ((min_coord.x + max_coord.x + 1) / 2.0) * actual_ts
			var center_y = center.y + ((min_coord.y + max_coord.y + 1) / 2.0) * actual_ts
			
			if front_dir == Vector2i.UP:
				arrow_start = Vector2(center_x, center.y + (min_coord.y * actual_ts))
				arrow_end = arrow_start + Vector2(0, -actual_ts)
			elif front_dir == Vector2i.DOWN:
				arrow_start = Vector2(center_x, center.y + ((max_coord.y + 1) * actual_ts))
				arrow_end = arrow_start + Vector2(0, actual_ts)
			elif front_dir == Vector2i.LEFT:
				arrow_start = Vector2(center.x + (min_coord.x * actual_ts), center_y)
				arrow_end = arrow_start + Vector2(-actual_ts, 0)
			elif front_dir == Vector2i.RIGHT:
				arrow_start = Vector2(center.x + ((max_coord.x + 1) * actual_ts), center_y)
				arrow_end = arrow_start + Vector2(actual_ts, 0)
				
			_draw_arrow(arrow_start, arrow_end, Color.RED)

func _draw_arrow(start: Vector2, end: Vector2, color: Color) -> void:
	canvas.draw_line(start, end, color, 4.0)
	var dir = (end - start).normalized()
	var right = dir.rotated(PI * 0.75) * 15.0
	var left = dir.rotated(-PI * 0.75) * 15.0
	canvas.draw_line(end, end + right, color, 4.0)
	canvas.draw_line(end, end + left, color, 4.0)
