class_name CustomRoomDesignerPopup
extends Window

signal confirmed

enum Brush { NONE, FLOOR_GENERIC, WALL_GENERIC, TILE_EXACT_FLOOR, TILE_EXACT_WALL, DOORWAY, ANCHOR, TOGGLE_RESERVED }

var custom_rooms: Dictionary = {}
var _current_room_key: String = ""

# --- UI REFS ---
var _room_dropdown: OptionButton
var _room_name_edit: LineEdit
var _width_spin: SpinBox
var _height_spin: SpinBox
var _brush_dropdown: OptionButton
var _btn_atlas_picker: Button
var _canvas: Control
var _warning_dialog: AcceptDialog # [NEW] Error popup for validation

# --- [NEW] UNUSED DOOR UI ---
var _opt_unused_door: OptionButton
var _btn_unused_atlas: Button
var _lbl_unused_atlas: Label

# --- ATLAS PICKER WINDOW ---
var _picker_window: Window
var _picker_rect: TextureRect
var _selected_atlas: Vector2i = Vector2i.ZERO
var _picking_mode: int = 0 # 0 = Brush, 1 = Unused Door Fallback

# --- STATE ---
var _draw_mask: int = 0 
var _active_brush: Brush = Brush.NONE
var _tileset_tex: Texture2D
var _tile_size: Vector2i = Vector2i(16, 16)
var _zoom: float = 2.0

func _init() -> void:
	title = "Custom Room Designer"
	min_size = Vector2i(900, 650)
	exclusive = true
	close_requested.connect(func(): hide())
	
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	add_child(main_vbox)
	
	_warning_dialog = AcceptDialog.new()
	_warning_dialog.title = "Validation Error"
	add_child(_warning_dialog)
	
	# --- TOP TOOLBAR 1: ROOM CONFIG ---
	var toolbar = HBoxContainer.new()
	main_vbox.add_child(toolbar)
	
	_room_dropdown = OptionButton.new()
	_room_dropdown.custom_minimum_size.x = 150
	_room_dropdown.item_selected.connect(_on_room_selected)
	toolbar.add_child(_room_dropdown)
	
	_room_name_edit = LineEdit.new()
	_room_name_edit.custom_minimum_size.x = 150
	_room_name_edit.placeholder_text = "Rename Room..."
	_room_name_edit.text_submitted.connect(_on_room_renamed)
	toolbar.add_child(_room_name_edit)
	
	var btn_add = Button.new(); btn_add.text = "+ New"; btn_add.pressed.connect(_on_add_room)
	var btn_del = Button.new(); btn_del.text = "Delete"; btn_del.pressed.connect(_on_delete_room)
	toolbar.add_child(btn_add); toolbar.add_child(btn_del)
	toolbar.add_child(VSeparator.new())
	
	var lbl_w = Label.new(); lbl_w.text = "W:"
	_width_spin = SpinBox.new(); _width_spin.min_value = 3; _width_spin.max_value = 50; _width_spin.value = 9
	_width_spin.value_changed.connect(func(v): _update_current_room_size())
	
	var lbl_h = Label.new(); lbl_h.text = "H:"
	_height_spin = SpinBox.new(); _height_spin.min_value = 3; _height_spin.max_value = 50; _height_spin.value = 9
	_height_spin.value_changed.connect(func(v): _update_current_room_size())
	toolbar.add_child(lbl_w); toolbar.add_child(_width_spin)
	toolbar.add_child(lbl_h); toolbar.add_child(_height_spin)
	toolbar.add_child(VSeparator.new())
	
	var btn_zoom_out = Button.new(); btn_zoom_out.text = "Zoom -"
	btn_zoom_out.pressed.connect(func(): _zoom = max(0.5, _zoom - 0.5); _canvas.queue_redraw())
	var btn_zoom_in = Button.new(); btn_zoom_in.text = "Zoom +"
	btn_zoom_in.pressed.connect(func(): _zoom = min(8.0, _zoom + 0.5); _canvas.queue_redraw())
	toolbar.add_child(btn_zoom_out); toolbar.add_child(btn_zoom_in)
	
	# --- [NEW] TOP TOOLBAR 2: UNUSED DOOR CONFIG ---
	var door_toolbar = HBoxContainer.new()
	main_vbox.add_child(door_toolbar)
	
	var lbl_door = Label.new(); lbl_door.text = "Unused Doorway Fallback: "
	door_toolbar.add_child(lbl_door)
	
	_opt_unused_door = OptionButton.new()
	_opt_unused_door.add_item("Leave as Floor", 0)
	_opt_unused_door.add_item("Seal with Biome Wall", 1)
	_opt_unused_door.add_item("Seal with Exact Tile", 2)
	_opt_unused_door.item_selected.connect(_on_unused_door_mode_changed)
	door_toolbar.add_child(_opt_unused_door)
	
	_btn_unused_atlas = Button.new(); _btn_unused_atlas.text = "Pick Fallback Tile"
	_btn_unused_atlas.pressed.connect(func(): _picking_mode = 1; _picker_window.popup_centered())
	door_toolbar.add_child(_btn_unused_atlas)
	
	
	_lbl_unused_atlas = Label.new(); _lbl_unused_atlas.text = "[0, 0]"
	door_toolbar.add_child(_lbl_unused_atlas)
	
	# --- BRUSH TOOLBAR ---
	var brush_toolbar = HBoxContainer.new()
	main_vbox.add_child(brush_toolbar)
	var lbl_brush = Label.new(); lbl_brush.text = "Active Brush (L-Click Paint, R-Click Erase): "
	brush_toolbar.add_child(lbl_brush)
	
	_brush_dropdown = OptionButton.new()
	_brush_dropdown.add_item("Generic Biome Floor", Brush.FLOOR_GENERIC)
	_brush_dropdown.add_item("Generic Biome Wall", Brush.WALL_GENERIC)
	_brush_dropdown.add_item("Exact Floor Tile", Brush.TILE_EXACT_FLOOR)
	_brush_dropdown.add_item("Exact Wall Tile", Brush.TILE_EXACT_WALL)
	_brush_dropdown.add_item("Doorway Marker", Brush.DOORWAY)
	_brush_dropdown.add_item("Center Anchor", Brush.ANCHOR)
	_brush_dropdown.add_item("Toggle Reserved Mask", Brush.TOGGLE_RESERVED)
	_brush_dropdown.item_selected.connect(func(idx): _active_brush = _brush_dropdown.get_item_id(idx) as Brush)
	brush_toolbar.add_child(_brush_dropdown)
	
	_btn_atlas_picker = Button.new()
	_btn_atlas_picker.text = "Pick Brush Tile [0, 0]"
	_btn_atlas_picker.pressed.connect(func(): _picking_mode = 0; _picker_window.popup_centered())
	brush_toolbar.add_child(_btn_atlas_picker)
	
	# --- VISUAL TILE PICKER POPUP ---
	_picker_window = Window.new()
	_picker_window.title = "Pick Atlas Tile"
	_picker_window.min_size = Vector2i(500, 500)
	_picker_window.exclusive = true
	_picker_window.close_requested.connect(func(): _picker_window.hide())
	_picker_window.hide()
	
	var p_scroll = ScrollContainer.new()
	p_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picker_window.add_child(p_scroll)
	
	_picker_rect = TextureRect.new()
	_picker_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_picker_rect.gui_input.connect(_on_picker_gui_input)
	p_scroll.add_child(_picker_rect)
	add_child(_picker_window)
	
	# --- CANVAS ---
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var panel = PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	main_vbox.add_child(scroll)
	
	_canvas = Control.new()
	_canvas.custom_minimum_size = Vector2(2000, 2000)
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST 
	_canvas.gui_input.connect(_on_canvas_gui_input)
	_canvas.draw.connect(_on_canvas_draw)
	panel.add_child(_canvas)
	
	# --- BOTTOM BUTTONS ---
	var bottom = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	main_vbox.add_child(bottom)
	
	var btn_save = Button.new(); btn_save.text = "Validate & Save"; btn_save.pressed.connect(_on_save_pressed)
	var btn_cancel = Button.new(); btn_cancel.text = "Cancel"; btn_cancel.pressed.connect(func(): hide())
	bottom.add_child(btn_cancel); bottom.add_child(btn_save)

# ==============================================================================
# API & STATE MANAGEMENT
# ==============================================================================
func open(texture_path: String, tile_size: Vector2i, existing_rooms: Dictionary) -> void:
	_tile_size = tile_size
	if texture_path != "" and FileAccess.file_exists(texture_path):
		var img = Image.load_from_file(texture_path)
		if img: 
			_tileset_tex = ImageTexture.create_from_image(img)
			_picker_rect.texture = _tileset_tex
	
	custom_rooms = existing_rooms.duplicate(true) 
	if custom_rooms.is_empty():
		_add_new_room_data("New_Room")
		
	_refresh_room_dropdown()
	_active_brush = Brush.FLOOR_GENERIC
	_brush_dropdown.selected = 0
	popup_centered()

func _add_new_room_data(r_name: String) -> void:
	custom_rooms[r_name] = {
		"width": 9, "height": 9,
		"anchor": Vector2i(4, 4),
		"doorways": [],       
		"reserved": [],       
		"floors": {},         
		"walls": {},          
		"exact_floors": {},   
		"exact_walls": {},
		"unused_door_mode": 1, # 0=Floor, 1=Biome Wall, 2=Exact Tile
		"unused_door_atlas": Vector2i.ZERO
	}
	_current_room_key = r_name

func _update_current_room_size() -> void:
	if _current_room_key == "" or not custom_rooms.has(_current_room_key): return
	custom_rooms[_current_room_key]["width"] = int(_width_spin.value)
	custom_rooms[_current_room_key]["height"] = int(_height_spin.value)
	_canvas.queue_redraw()

func _refresh_room_dropdown() -> void:
	_room_dropdown.clear()
	var keys = custom_rooms.keys()
	for i in range(keys.size()):
		_room_dropdown.add_item(keys[i], i)
		if keys[i] == _current_room_key:
			_room_dropdown.selected = i
	
	if keys.size() > 0 and _current_room_key == "":
		_current_room_key = keys[0]
		_room_dropdown.selected = 0
		
	_load_room_to_ui()

func _load_room_to_ui() -> void:
	if not custom_rooms.has(_current_room_key): return
	var r = custom_rooms[_current_room_key]
	_width_spin.set_value_no_signal(r.get("width", 9))
	_height_spin.set_value_no_signal(r.get("height", 9))
	_room_name_edit.text = _current_room_key
	
	# Load Door Rule state
	_opt_unused_door.selected = r.get("unused_door_mode", 1)
	var d_atlas = r.get("unused_door_atlas", Vector2i.ZERO)
	_lbl_unused_atlas.text = "[%d, %d]" % [d_atlas.x, d_atlas.y]
	_btn_unused_atlas.visible = (_opt_unused_door.selected == 2)
	_lbl_unused_atlas.visible = (_opt_unused_door.selected == 2)
	
	_canvas.queue_redraw()

func _on_room_renamed(new_name: String) -> void:
	var safe_name = new_name.strip_edges()
	if safe_name == "" or safe_name == _current_room_key or custom_rooms.has(safe_name):
		_room_name_edit.text = _current_room_key 
		return
		
	custom_rooms[safe_name] = custom_rooms[_current_room_key]
	custom_rooms.erase(_current_room_key)
	_current_room_key = safe_name
	_room_dropdown.set_item_text(_room_dropdown.selected, safe_name)

func _on_unused_door_mode_changed(idx: int) -> void:
	if _current_room_key == "" or not custom_rooms.has(_current_room_key): return
	custom_rooms[_current_room_key]["unused_door_mode"] = idx
	_btn_unused_atlas.visible = (idx == 2)
	_lbl_unused_atlas.visible = (idx == 2)

# ==============================================================================
# VISUAL TILE PICKER
# ==============================================================================
func _on_picker_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var ax = int(event.position.x / _tile_size.x)
		var ay = int(event.position.y / _tile_size.y)
		var picked = Vector2i(ax, ay)
		
		if _picking_mode == 0:
			_selected_atlas = picked
			_btn_atlas_picker.text = "Pick Brush Tile [%d, %d]" % [ax, ay]
		else:
			if _current_room_key != "" and custom_rooms.has(_current_room_key):
				custom_rooms[_current_room_key]["unused_door_atlas"] = picked
				_lbl_unused_atlas.text = "[%d, %d]" % [ax, ay]
				
		_picker_window.hide()

# ==============================================================================
# PAINTING LOGIC
# ==============================================================================
func _on_canvas_gui_input(event: InputEvent) -> void:
	if _current_room_key == "" or not custom_rooms.has(_current_room_key): return
	
	if event is InputEventMouseButton:
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT: _draw_mask = 1
			elif event.button_index == MOUSE_BUTTON_RIGHT: _draw_mask = 2
			_paint_cell(event.position, _draw_mask == 2)
		else:
			_draw_mask = 0
			
	elif event is InputEventMouseMotion and _draw_mask != 0:
		_paint_cell(event.position, _draw_mask == 2)

func _paint_cell(local_pos: Vector2, erase: bool) -> void:
	var cell_px = _tile_size.x * _zoom
	var cx = int(local_pos.x / cell_px)
	var cy = int(local_pos.y / cell_px)
	
	var r = custom_rooms[_current_room_key]
	if cx < 0 or cx >= r["width"] or cy < 0 or cy >= r["height"]: return
	var pos = Vector2i(cx, cy)
	
	if erase:
		if _active_brush == Brush.TOGGLE_RESERVED and r.has("reserved"): r["reserved"].erase(pos)
		elif _active_brush == Brush.DOORWAY and r.has("doorways"): r["doorways"].erase(pos)
		elif _active_brush in [Brush.FLOOR_GENERIC, Brush.WALL_GENERIC, Brush.TILE_EXACT_FLOOR, Brush.TILE_EXACT_WALL]:
			r["floors"].erase(pos); r["walls"].erase(pos)
			if r.has("exact_floors"): r["exact_floors"].erase(pos)
			if r.has("exact_walls"): r["exact_walls"].erase(pos)
		_canvas.queue_redraw()
		return
		
	if _active_brush == Brush.ANCHOR: r["anchor"] = pos
	elif _active_brush == Brush.TOGGLE_RESERVED:
		if not r.has("reserved"): r["reserved"] = []
		if not r["reserved"].has(pos): r["reserved"].append(pos)
	elif _active_brush == Brush.DOORWAY:
		if not r.has("doorways"): r["doorways"] = []
		if not r["doorways"].has(pos): r["doorways"].append(pos)
	elif _active_brush == Brush.FLOOR_GENERIC:
		r["floors"][pos] = true; _clear_base_tiles(r, pos, ["floors"])
	elif _active_brush == Brush.WALL_GENERIC:
		r["walls"][pos] = true; _clear_base_tiles(r, pos, ["walls"])
	elif _active_brush == Brush.TILE_EXACT_FLOOR:
		if not r.has("exact_floors"): r["exact_floors"] = {}
		r["exact_floors"][pos] = _selected_atlas; _clear_base_tiles(r, pos, ["exact_floors"])
	elif _active_brush == Brush.TILE_EXACT_WALL:
		if not r.has("exact_walls"): r["exact_walls"] = {}
		r["exact_walls"][pos] = _selected_atlas; _clear_base_tiles(r, pos, ["exact_walls"])
		
	_canvas.queue_redraw()

func _clear_base_tiles(r: Dictionary, pos: Vector2i, keep_keys: Array) -> void:
	for k in ["floors", "walls", "exact_floors", "exact_walls"]:
		if not keep_keys.has(k) and r.has(k): r[k].erase(pos)

# ==============================================================================
# DRAWING ENGINE
# ==============================================================================
func _on_canvas_draw() -> void:
	if _current_room_key == "" or not custom_rooms.has(_current_room_key): return
	var r = custom_rooms[_current_room_key]
	var w = r.get("width", 9)
	var h = r.get("height", 9)
	var scaled_sz = _tile_size * _zoom
	
	_canvas.draw_rect(Rect2(0, 0, w * scaled_sz.x, h * scaled_sz.y), Color(0.1, 0.1, 0.15))
	for y in range(h + 1): _canvas.draw_line(Vector2(0, y * scaled_sz.y), Vector2(w * scaled_sz.x, y * scaled_sz.y), Color(1, 1, 1, 0.1))
	for x in range(w + 1): _canvas.draw_line(Vector2(x * scaled_sz.x, 0), Vector2(x * scaled_sz.x, h * scaled_sz.y), Color(1, 1, 1, 0.1))

	var draw_rect_at = func(pos: Vector2i, color: Color):
		_canvas.draw_rect(Rect2(pos.x * scaled_sz.x, pos.y * scaled_sz.y, scaled_sz.x, scaled_sz.y), color)

	if r.has("floors"): for pos in r["floors"]: draw_rect_at.call(pos, Color(0.2, 0.5, 0.3, 0.8)) 
	if r.has("walls"): for pos in r["walls"]: draw_rect_at.call(pos, Color(0.4, 0.4, 0.4, 0.8)) 
		
	if r.has("exact_floors") and _tileset_tex:
		for pos in r["exact_floors"]:
			var atlas = r["exact_floors"][pos]
			var src_rect = Rect2(atlas.x * _tile_size.x, atlas.y * _tile_size.y, _tile_size.x, _tile_size.y)
			var dest_rect = Rect2(pos.x * scaled_sz.x, pos.y * scaled_sz.y, scaled_sz.x, scaled_sz.y)
			_canvas.draw_texture_rect_region(_tileset_tex, dest_rect, src_rect)
			
	if r.has("exact_walls") and _tileset_tex:
		for pos in r["exact_walls"]:
			var atlas = r["exact_walls"][pos]
			var src_rect = Rect2(atlas.x * _tile_size.x, atlas.y * _tile_size.y, _tile_size.x, _tile_size.y)
			var dest_rect = Rect2(pos.x * scaled_sz.x, pos.y * scaled_sz.y, scaled_sz.x, scaled_sz.y)
			_canvas.draw_texture_rect_region(_tileset_tex, dest_rect, src_rect)

	if r.has("reserved"):
		for pos in r["reserved"]:
			var p1 = Vector2(pos.x * scaled_sz.x, pos.y * scaled_sz.y)
			var p2 = p1 + Vector2(scaled_sz)
			_canvas.draw_line(p1, p2, Color(1, 0, 0, 0.6), 2.0)
			
	if r.has("doorways"):
		for pos in r["doorways"]: draw_rect_at.call(pos, Color(0.9, 0.2, 0.2, 0.5)) 
			
	if r.has("anchor"):
		var a = r["anchor"]
		var c = Vector2(a.x * scaled_sz.x + (scaled_sz.x/2.0), a.y * scaled_sz.y + (scaled_sz.y/2.0))
		_canvas.draw_circle(c, scaled_sz.x * 0.3, Color.YELLOW)

# ==============================================================================
# SAVE & VALIDATE
# ==============================================================================
func _on_room_selected(idx: int) -> void:
	_current_room_key = _room_dropdown.get_item_text(idx)
	_load_room_to_ui()

func _on_add_room() -> void:
	var new_name = "Room_" + str(custom_rooms.size() + 1)
	_add_new_room_data(new_name)
	_refresh_room_dropdown()

func _on_delete_room() -> void:
	if _current_room_key != "":
		custom_rooms.erase(_current_room_key)
		_current_room_key = ""
		_refresh_room_dropdown()

func _on_save_pressed() -> void:
	# 1. Run strict topological validation on every single room!
	for r_key in custom_rooms:
		if not _validate_room_solvability(custom_rooms[r_key]):
			_warning_dialog.dialog_text = "Validation Failed for room: '" + r_key + "'\n\nAll Doorways must be connected to each other by a continuous path of 'Reserved' tiles!\n\n(Use the Toggle Reserved Mask brush to link them)."
			_warning_dialog.popup_centered()
			return
			
	confirmed.emit()
	hide()

# --- THE BFS SOLVABILITY CHECKER ---
func _validate_room_solvability(r: Dictionary) -> bool:
	var doors = r.get("doorways", [])
	if doors.size() <= 1: return true # 0 or 1 doors are inherently fully connected!
	
	# Build a lookup table of valid walkable nodes (Doors + Reserved Cells)
	var valid_path = {}
	for d in doors: valid_path[d] = true
	if r.has("reserved"):
		for res in r["reserved"]: valid_path[res] = true
		
	# Standard BFS Flood Fill
	var visited = { doors[0]: true }
	var queue = [ doors[0] ]
	
	while queue.size() > 0:
		var curr = queue.pop_front()
		
		# Check 4 Cardinal Directions
		var neighbors = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
		for dir in neighbors:
			var n = curr + dir
			if valid_path.has(n) and not visited.has(n):
				visited[n] = true
				queue.append(n)
				
	# Final Check: Did the flood fill reach every single doorway?
	for d in doors:
		if not visited.has(d): return false
		
	return true
