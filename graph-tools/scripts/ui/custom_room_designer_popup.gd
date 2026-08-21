class_name CustomRoomDesignerPopup
extends Window

signal confirmed

enum Brush { NONE, FLOOR_GENERIC, WALL_GENERIC, TILE_EXACT_FLOOR, TILE_EXACT_WALL, DOORWAY, ANCHOR, TOGGLE_RESERVED, PLACE_STRUCTURE, PLACE_ENTITY }

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
var _warning_dialog: AcceptDialog # Error popup for validation
var _struct_toolbar: HBoxContainer # Group container
var _opt_structure: OptionButton
var _btn_rotate_struct: Button
var _opt_entity: OptionButton 
var _lbl_struct: Label 
var _lbl_ent: Label

# --- UNUSED DOOR UI ---
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
var _texture_cache: Dictionary = {}
var _zoom: float = 2.0
var _available_structures: Dictionary = {}
var _available_entities: Dictionary = {} 
var _current_struct_id: String = ""
var _current_struct_rot: int = 0
var _mouse_grid_pos: Vector2i = Vector2i.ZERO # Tracks hover for ghost preview


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
	
	# --- TOP TOOLBAR 2: UNUSED DOOR CONFIG ---
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
	_brush_dropdown.add_item("Place Structure", Brush.PLACE_STRUCTURE)
	_brush_dropdown.add_item("Place Entity", Brush.PLACE_ENTITY)
	_brush_dropdown.item_selected.connect(func(idx): _active_brush = _brush_dropdown.get_item_id(idx) as Brush; _update_brush_ui())
	brush_toolbar.add_child(_brush_dropdown)
	
	_btn_atlas_picker = Button.new()
	_btn_atlas_picker.text = "Pick Brush Tile [0, 0]"
	_btn_atlas_picker.pressed.connect(func(): _picking_mode = 0; _picker_window.popup_centered())
	brush_toolbar.add_child(_btn_atlas_picker)
	
	# --- STRUCTURE TOOLBAR ---
	_struct_toolbar = HBoxContainer.new()
	_struct_toolbar.visible = false
	main_vbox.add_child(_struct_toolbar)
	
	_lbl_struct = Label.new(); _lbl_struct.text = "Select Structure: "
	_struct_toolbar.add_child(_lbl_struct)
	
	_opt_structure = OptionButton.new()
	_opt_structure.item_selected.connect(func(idx): 
		_current_struct_id = _opt_structure.get_item_metadata(idx)
		_canvas.queue_redraw()
	)
	_struct_toolbar.add_child(_opt_structure)
	
	_btn_rotate_struct = Button.new()
	_btn_rotate_struct.text = "Rotate 90° (R)"
	_btn_rotate_struct.pressed.connect(func():
		_current_struct_rot = (_current_struct_rot + 1) % 4
		_canvas.queue_redraw()
	)
	_struct_toolbar.add_child(_btn_rotate_struct)
	
	_lbl_ent = Label.new(); _lbl_ent.text = "  Select Entity: "
	_struct_toolbar.add_child(_lbl_ent)
	
	_opt_entity = OptionButton.new()
	_opt_entity.item_selected.connect(func(idx): _canvas.queue_redraw())
	_struct_toolbar.add_child(_opt_entity)
	
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
func open(texture_path: String, tile_size: Vector2i, existing_rooms: Dictionary, available_structs: Dictionary, available_ents: Dictionary) -> void:
	_tile_size = tile_size
	_available_structures = available_structs
	_available_entities = available_ents
	
	if texture_path != "" and FileAccess.file_exists(texture_path):
		var img = Image.load_from_file(texture_path)
		if img: 
			_tileset_tex = ImageTexture.create_from_image(img)
			_picker_rect.texture = _tileset_tex
	
	custom_rooms = existing_rooms.duplicate(true) 
	if custom_rooms.is_empty():
		_add_new_room_data("New_Room")
		
	_refresh_room_dropdown()
	_refresh_structure_dropdown()
	_refresh_entity_dropdown()
	_active_brush = Brush.FLOOR_GENERIC
	_brush_dropdown.selected = 0
	_update_brush_ui()
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
		"placed_structures": [], # Array of { "id": String, "pos": Vector2i, "rot": int }
		"unused_door_mode": 1, 
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

func _refresh_structure_dropdown() -> void:
	_opt_structure.clear()
	var keys = _available_structures.keys()
	for i in range(keys.size()):
		var s_data = _available_structures[keys[i]]
		_opt_structure.add_item(s_data.get("name", "Unnamed"), i)
		_opt_structure.set_item_metadata(i, keys[i])
		
	if keys.size() > 0:
		_current_struct_id = keys[0]
		_opt_structure.selected = 0

func _refresh_entity_dropdown() -> void:
	_opt_entity.clear()
	var keys = _available_entities.keys()
	for i in range(keys.size()):
		_opt_entity.add_item(_available_entities[keys[i]].get("name", "Unnamed"), i)
		_opt_entity.set_item_metadata(i, keys[i])

func _update_brush_ui() -> void:
	var is_struct = (_active_brush == Brush.PLACE_STRUCTURE)
	var is_ent = (_active_brush == Brush.PLACE_ENTITY)
	
	_struct_toolbar.visible = is_struct or is_ent
	_lbl_struct.visible = is_struct
	_opt_structure.visible = is_struct
	_btn_rotate_struct.visible = is_struct
	
	_lbl_ent.visible = is_ent
	_opt_entity.visible = is_ent
	
	_btn_atlas_picker.visible = (_active_brush in [Brush.TILE_EXACT_FLOOR, Brush.TILE_EXACT_WALL])

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
	
	# Track hover for ghost preview
	if event is InputEventMouseMotion:
		var cell_px = _tile_size.x * _zoom
		_mouse_grid_pos = Vector2i(int(event.position.x / cell_px), int(event.position.y / cell_px))
		
		# Redraw for both Structures AND Entities
		if _active_brush in [Brush.PLACE_STRUCTURE, Brush.PLACE_ENTITY]: 
			_canvas.queue_redraw()
		
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if _active_brush == Brush.PLACE_STRUCTURE:
			_current_struct_rot = (_current_struct_rot + 1) % 4
			_canvas.queue_redraw()
			
	if event is InputEventMouseButton:
		# Handle Scroll Wheel Rotation
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			return
			
		# Restrict painting to strict Left/Right clicks
		if event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
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
		if _active_brush == Brush.PLACE_STRUCTURE and r.has("placed_structures"):
			# Find and delete any structure anchored at this exact spot
			for i in range(r["placed_structures"].size() - 1, -1, -1):
				if r["placed_structures"][i]["pos"] == pos:
					r["placed_structures"].remove_at(i)
					
		elif _active_brush == Brush.PLACE_ENTITY and r.has("placed_entities"):
			for i in range(r["placed_entities"].size() - 1, -1, -1):
				if r["placed_entities"][i]["pos"] == pos:
					r["placed_entities"].remove_at(i)
					
		elif _active_brush == Brush.TOGGLE_RESERVED and r.has("reserved"): r["reserved"].erase(pos)
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
	# --- STAMP STRUCTURE ---
	elif _active_brush == Brush.PLACE_STRUCTURE:
		if _current_struct_id == "" or not _available_structures.has(_current_struct_id): return
		var s_data = _available_structures[_current_struct_id]
		
		# [FIXED] Rotate using the new helper
		var footprint = []
		for p in s_data.get("footprint", [Vector2i.ZERO]): footprint.append(_rotate_point(p, _current_struct_rot))
		
		var valid = true
		for pt in footprint:
			var check_pos = pos + pt
			if check_pos.x < 0 or check_pos.x >= r["width"] or check_pos.y < 0 or check_pos.y >= r["height"]: valid = false; break
			
			var is_floor = r.get("floors", {}).has(check_pos) or r.get("exact_floors", {}).has(check_pos)
			if not is_floor: valid = false; break
			
			# [NEW] Block overlapping walls, exact walls, doorways, or reserved masks!
			if r.get("reserved", []).has(check_pos): valid = false; break
			if r.get("walls", {}).has(check_pos) or r.get("exact_walls", {}).has(check_pos): valid = false; break
			
			# [NEW] Check footprint overlaps against ALL other placed structures!
			if r.has("placed_structures"):
				for item in r["placed_structures"]:
					var other_s = _available_structures.get(item["id"], {})
					var other_fp = other_s.get("footprint", [Vector2i.ZERO])
					for opt in other_fp:
						var other_abs = item["pos"] + _rotate_point(opt, item["rot"])
						if check_pos == other_abs: valid = false; break
					if not valid: break
			if not valid: break
			
		if valid:
			if not r.has("placed_structures"): r["placed_structures"] = []
			r["placed_structures"].append({
				"id": _current_struct_id,
				"pos": pos,
				"rot": _current_struct_rot
			})
	# --- STAMP ENTITY ---
	elif _active_brush == Brush.PLACE_ENTITY:
		if _opt_entity.item_count == 0: return
		var ent_id = _opt_entity.get_item_metadata(_opt_entity.selected)
		if ent_id == "" or not _available_entities.has(ent_id): return
		
		# Validation: Must only touch valid floor tiles!
		var valid = true
		var is_floor = r.get("floors", {}).has(pos) or r.get("exact_floors", {}).has(pos)
		if not is_floor: valid = false
		if r.get("reserved", []).has(pos): valid = false
		if r.get("walls", {}).has(pos) or r.get("exact_walls", {}).has(pos): valid = false
		
		if r.has("placed_entities"):
			for item in r["placed_entities"]:
				if item["pos"] == pos: valid = false; break
				
		# Check against structures
		if r.has("placed_structures"):
			for item in r["placed_structures"]:
				var other_s = _available_structures.get(item["id"], {})
				for opt in other_s.get("footprint", [Vector2i.ZERO]):
					if pos == item["pos"] + _rotate_point(opt, item["rot"]): valid = false; break
				if not valid: break
				
		if valid:
			if not r.has("placed_entities"): r["placed_entities"] = []
			r["placed_entities"].append({ "id": ent_id, "pos": pos })
		
	_canvas.queue_redraw()

func _clear_base_tiles(r: Dictionary, pos: Vector2i, keep_keys: Array) -> void:
	for k in ["floors", "walls", "exact_floors", "exact_walls"]:
		if not keep_keys.has(k) and r.has(k): r[k].erase(pos)


# --- ROTATION MATH HELPER ---
func _rotate_footprint(footprint: Array, rot_idx: int) -> Array[Vector2i]:
	var rotated: Array[Vector2i] = []
	for pt in footprint:
		var p = Vector2i(pt)
		for i in range(rot_idx):
			var temp = p.x
			p.x = -p.y
			p.y = temp
		rotated.append(p)
	return rotated
	
# --- VISUAL & MATH HELPERS ---
func _rotate_point(pt: Vector2i, rot_idx: int) -> Vector2i:
	match rot_idx % 4:
		1: return Vector2i(-pt.y, pt.x) # 90 deg CW
		2: return Vector2i(-pt.x, -pt.y) # 180 deg
		3: return Vector2i(pt.y, -pt.x) # 270 deg CW
		_: return pt # 0 deg

func _get_cached_texture(path: String) -> Texture2D:
	if _texture_cache.has(path): return _texture_cache[path]
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(path)
		if img:
			var tex = ImageTexture.create_from_image(img)
			_texture_cache[path] = tex
			return tex
	return null

func _draw_arrow(start: Vector2, end: Vector2, color: Color) -> void:
	_canvas.draw_line(start, end, color, 4.0)
	var dir = (end - start).normalized()
	var right = dir.rotated(PI * 0.75) * 15.0
	var left = dir.rotated(-PI * 0.75) * 15.0
	_canvas.draw_line(end, end + right, color, 4.0)
	_canvas.draw_line(end, end + left, color, 4.0)
	
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
	
	# --- DRAW PLACED STRUCTURES & SPRITES ---
	var draw_struct = func(s_id: String, s_pos: Vector2i, s_rot: int, alpha: float):
		if not _available_structures.has(s_id): return
		var s_data = _available_structures[s_id]
		var footprint = []
		for p in s_data.get("footprint", [Vector2i.ZERO]): footprint.append(_rotate_point(p, s_rot))
		
		var s_color = s_data.get("color", Color.CYAN)
		s_color.a = alpha
		
		var min_coord = footprint[0]
		var max_coord = footprint[0]
		
		for pt in footprint:
			if pt.x < min_coord.x: min_coord.x = pt.x
			if pt.y < min_coord.y: min_coord.y = pt.y
			if pt.x > max_coord.x: max_coord.x = pt.x
			if pt.y > max_coord.y: max_coord.y = pt.y
			
			var draw_p = s_pos + pt
			var px = draw_p.x * scaled_sz.x
			var py = draw_p.y * scaled_sz.y
			_canvas.draw_rect(Rect2(px, py, scaled_sz.x, scaled_sz.y), s_color)
			_canvas.draw_rect(Rect2(px, py, scaled_sz.x, scaled_sz.y), Color(1, 1, 1, alpha), false, 2.0)
			
		# --- DRAW SPRITE OVERLAY ---
		var tex_path = s_data.get("texture_path", "")
		if tex_path != "":
			var tex = _get_cached_texture(tex_path)
			if tex:
				var t_scale = s_data.get("texture_scale", Vector2.ONE)
				var t_offset = s_data.get("texture_offset", Vector2.ZERO)
				
				# Mathematically rotate the visual offset so the sprite stays anchored to its intended side!
				var rot_offset = Vector2(_rotate_point(Vector2i(round(t_offset.x * 10), round(t_offset.y * 10)), s_rot)) / 10.0
				
				var normalized_size = Vector2(scaled_sz.x * t_scale.x, scaled_sz.y * t_scale.y)
				var base_origin = Vector2(s_pos.x * scaled_sz.x + (scaled_sz.x/2.0), s_pos.y * scaled_sz.y + (scaled_sz.y/2.0))
				var draw_pos = base_origin - (normalized_size / 2.0) + (rot_offset * scaled_sz.x)
				
				_canvas.draw_texture_rect(tex, Rect2(draw_pos, normalized_size), false, Color(1, 1, 1, alpha))

		# --- DRAW FACING ARROW ---
		if s_data.get("face_path", true) and footprint.size() > 0:
			var front_dir = s_data.get("front_dir", Vector2i.UP)
			var actual_front = _rotate_point(front_dir, s_rot)
			
			var center_x = (s_pos.x + ((min_coord.x + max_coord.x + 1) / 2.0)) * scaled_sz.x
			var center_y = (s_pos.y + ((min_coord.y + max_coord.y + 1) / 2.0)) * scaled_sz.y
			
			var arrow_start = Vector2(center_x, center_y)
			if actual_front == Vector2i.UP: arrow_start.y = (s_pos.y + min_coord.y) * scaled_sz.y
			elif actual_front == Vector2i.DOWN: arrow_start.y = (s_pos.y + max_coord.y + 1) * scaled_sz.y
			elif actual_front == Vector2i.LEFT: arrow_start.x = (s_pos.x + min_coord.x) * scaled_sz.x
			elif actual_front == Vector2i.RIGHT: arrow_start.x = (s_pos.x + max_coord.x + 1) * scaled_sz.x
			
			var arrow_end = arrow_start + Vector2(actual_front) * scaled_sz.x
			_draw_arrow(arrow_start, arrow_end, Color(1, 0, 0, alpha))
			
	if r.has("placed_structures"):
		for item in r["placed_structures"]:
			draw_struct.call(item["id"], item["pos"], item["rot"], 0.9)
			
	# --- DRAW GHOST PREVIEW ---
	if _active_brush == Brush.PLACE_STRUCTURE and _current_struct_id != "":
		if _mouse_grid_pos.x >= 0 and _mouse_grid_pos.x < w and _mouse_grid_pos.y >= 0 and _mouse_grid_pos.y < h:
			draw_struct.call(_current_struct_id, _mouse_grid_pos, _current_struct_rot, 0.4)
	
	# --- DRAW PLACED ENTITIES ---
	var draw_ent = func(e_id: String, e_pos: Vector2i, alpha: float):
		if not _available_entities.has(e_id): return
		var e_data = _available_entities[e_id]
		var e_color = e_data.get("color", Color.WHITE)
		e_color.a = alpha
		
		var px = e_pos.x * scaled_sz.x
		var py = e_pos.y * scaled_sz.y
		_canvas.draw_rect(Rect2(px, py, scaled_sz.x, scaled_sz.y), e_color)
		_canvas.draw_rect(Rect2(px, py, scaled_sz.x, scaled_sz.y), Color(1, 1, 1, alpha), false, 2.0)
		
		var tex_path = e_data.get("texture_path", "")
		if tex_path != "":
			var tex = _get_cached_texture(tex_path)
			if tex:
				var t_scale = e_data.get("texture_scale", Vector2.ONE)
				var t_offset = e_data.get("texture_offset", Vector2.ZERO)
				var normalized_size = Vector2(scaled_sz.x * t_scale.x, scaled_sz.y * t_scale.y)
				var base_origin = Vector2(e_pos.x * scaled_sz.x + (scaled_sz.x/2.0), e_pos.y * scaled_sz.y + (scaled_sz.y/2.0))
				var draw_pos = base_origin - (normalized_size / 2.0) + (t_offset * scaled_sz.x)
				_canvas.draw_texture_rect(tex, Rect2(draw_pos, normalized_size), false, Color(1, 1, 1, alpha))

	if r.has("placed_entities"):
		for item in r["placed_entities"]:
			draw_ent.call(item["id"], item["pos"], 0.9)
			
	if _active_brush == Brush.PLACE_ENTITY and _opt_entity.item_count > 0:
		var ent_id = _opt_entity.get_item_metadata(_opt_entity.selected)
		if _mouse_grid_pos.x >= 0 and _mouse_grid_pos.x < w and _mouse_grid_pos.y >= 0 and _mouse_grid_pos.y < h:
			draw_ent.call(ent_id, _mouse_grid_pos, 0.4)
	
	

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
		var error_msg = _validate_room_layout(custom_rooms[r_key])
		if error_msg != "":
			_warning_dialog.dialog_text = "Validation Failed for room: '" + r_key + "'\n\n" + error_msg
			_warning_dialog.popup_centered()
			return
			
	confirmed.emit()
	hide()

# --- THE COMPREHENSIVE LAYOUT CHECKER ---
func _validate_room_layout(r: Dictionary) -> String:
	var doors = r.get("doorways", [])
	var reserved = r.get("reserved", [])
	var floors = r.get("floors", {})
	var exact_floors = r.get("exact_floors", {})
	var walls = r.get("walls", {})
	var exact_walls = r.get("exact_walls", {})
	
	# CHECK 1: Ensure all doorways are explicitly marked as reserved!
	for d in doors:
		if not reserved.has(d):
			return "All Doorway markers must also be painted with the 'Reserved' mask!"
			
	# CHECK 2: Ensure reserved masks are on Floors and NOT on Walls or Void!
	for res in reserved:
		var has_floor = floors.has(res) or exact_floors.has(res)
		if not has_floor:
			return "All Reserved masks (and Doorways) must be placed on top of a Floor tile! You cannot place a path in the void."
			
		if walls.has(res) or exact_walls.has(res):
			return "Reserved masks cannot be placed overtop Wall tiles! (They represent the walkable critical path)."

	# CHECK 3: BFS Solvability (Are all doors connected by reserved tiles?)
	if doors.size() > 1:
		# Build a lookup table of valid walkable nodes
		var valid_path = {}
		for res in reserved: valid_path[res] = true
			
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
			if not visited.has(d): 
				return "All Doorways must be connected to each other by a continuous path of 'Reserved' tiles!\n\n(Use the Toggle Reserved Mask brush to link them)."
				
	return "" # Empty string means validation passed!
