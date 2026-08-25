class_name CustomRoomDesignerPopup
extends Window

signal confirmed

enum Brush { NONE, FLOOR_GENERIC, WALL_GENERIC, TILE_EXACT_FLOOR, TILE_EXACT_WALL, DOORWAY, ANCHOR, TOGGLE_RESERVED, PLACE_STRUCTURE, PLACE_ENTITY, PLACE_WFC_SOCKET }

var custom_rooms: Dictionary = {}
var _current_room_key: String = ""

# --- UI REFS ---
var _room_dropdown: OptionButton
var _room_name_edit: LineEdit
var _width_spin: SpinBox
var _height_spin: SpinBox
var _brush_dropdown: OptionButton
var _btn_atlas_picker: Button
var _warning_dialog: AcceptDialog 
var _struct_toolbar: HBoxContainer 
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
var _picking_mode: int = 0 

# --- STATE ---
var _tool_dropdown: OptionButton
var _active_tool: int = 0 # 0 = Pen, 1 = Fill
var _active_brush: Brush = Brush.NONE
var _tileset_tex: Texture2D
var _tile_size: Vector2i = Vector2i(16, 16)
var _available_structures: Dictionary = {}
var _available_entities: Dictionary = {} 
var _current_struct_id: String = ""
var _current_struct_rot: int = 0
var _mouse_grid_pos: Vector2i = Vector2i.ZERO 

# [NEW] Replaces the Canvas, Math, and Zoom tools!
var painter: GridCanvasPainter 

func _init() -> void:
	title = "Custom Room Designer"
	min_size = Vector2i(900, 650)
	exclusive = true
	transient = true
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
	
	# Add Tool Selector
	var lbl_tool = Label.new(); lbl_tool.text = "Tool: "
	brush_toolbar.add_child(lbl_tool)
	
	_tool_dropdown = OptionButton.new()
	_tool_dropdown.add_item("Pen", 0)
	_tool_dropdown.add_item("Fill", 1)
	_tool_dropdown.item_selected.connect(func(idx): 
		_active_tool = idx
		painter.highlighted_cells.clear()
		painter.canvas.queue_redraw()
	)
	brush_toolbar.add_child(_tool_dropdown)
	brush_toolbar.add_child(VSeparator.new())
	
	var lbl_brush = Label.new(); lbl_brush.text = "Active Brush: "
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
	_brush_dropdown.add_item("WFC Socket Zone (3x3)", Brush.PLACE_WFC_SOCKET)
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
		painter.canvas.queue_redraw()
	)
	_struct_toolbar.add_child(_opt_structure)
	
	_btn_rotate_struct = Button.new()
	_btn_rotate_struct.text = "Rotate 90° (R)"
	_btn_rotate_struct.pressed.connect(func():
		_current_struct_rot = (_current_struct_rot + 1) % 4
		painter.canvas.queue_redraw()
	)
	_struct_toolbar.add_child(_btn_rotate_struct)
	
	_lbl_ent = Label.new(); _lbl_ent.text = "  Select Entity: "
	_struct_toolbar.add_child(_lbl_ent)
	
	_opt_entity = OptionButton.new()
	_opt_entity.item_selected.connect(func(idx): painter.canvas.queue_redraw())
	_struct_toolbar.add_child(_opt_entity)
	
	# --- VISUAL TILE PICKER POPUP ---
	_picker_window = Window.new()
	_picker_window.title = "Pick Atlas Tile"
	_picker_window.min_size = Vector2i(500, 500)
	_picker_window.exclusive = true
	_picker_window.transient = true
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
	
	# --- PAINTER ---
	painter = GridCanvasPainter.new()
	painter.origin_mode = GridCanvasPainter.OriginMode.TOP_LEFT
	main_vbox.add_child(painter)
	
	painter.cell_painted.connect(_on_cell_painted)
	painter.cell_hovered.connect(_on_cell_hovered)
	painter.canvas.draw.connect(_on_canvas_draw)
	
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
	painter.tile_size = float(tile_size.x)
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
		"placed_structures": [], 
		"placed_entities": [],
		"sockets": [],
		"unused_door_mode": 1, 
		"unused_door_atlas": Vector2i.ZERO
	}
	_current_room_key = r_name

func _update_current_room_size() -> void:
	if _current_room_key == "" or not custom_rooms.has(_current_room_key): return
	var w = int(_width_spin.value)
	var h = int(_height_spin.value)
	custom_rooms[_current_room_key]["width"] = w
	custom_rooms[_current_room_key]["height"] = h
	painter.grid_bounds = Vector2i(w, h)
	painter.canvas.queue_redraw()

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
	painter.grid_bounds = Vector2i(r.get("width", 9), r.get("height", 9))
	_room_name_edit.text = _current_room_key
	
	_opt_unused_door.selected = r.get("unused_door_mode", 1)
	var d_atlas = r.get("unused_door_atlas", Vector2i.ZERO)
	_lbl_unused_atlas.text = "[%d, %d]" % [d_atlas.x, d_atlas.y]
	_btn_unused_atlas.visible = (_opt_unused_door.selected == 2)
	_lbl_unused_atlas.visible = (_opt_unused_door.selected == 2)
	
	painter.canvas.queue_redraw()

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
# INPUT & MATH
# ==============================================================================
func _input(event: InputEvent) -> void:
	if not visible: return
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if _active_brush == Brush.PLACE_STRUCTURE:
			_current_struct_rot = (_current_struct_rot + 1) % 4
			painter.canvas.queue_redraw()

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

func _clear_base_tiles(r: Dictionary, pos: Vector2i, keep_keys: Array) -> void:
	for k in ["floors", "walls", "exact_floors", "exact_walls"]:
		if not keep_keys.has(k) and r.has(k): r[k].erase(pos)

# ==============================================================================
# VIRTUAL GRID & HOVER HIGHLIGHTS
# ==============================================================================
func _get_target_grid(r: Dictionary, brush: Brush) -> Dictionary:
	var grid = {}
	if brush == Brush.TOGGLE_RESERVED:
		for pos in r.get("reserved", []): grid[pos] = true
	elif brush == Brush.DOORWAY:
		for pos in r.get("doorways", []): grid[pos] = true
	elif brush == Brush.PLACE_ENTITY:
		for item in r.get("placed_entities", []): grid[item["pos"]] = item["id"]
	else: 
		# Base Tiles (Floors, Walls, Anchor)
		if r.has("floors"): for pos in r["floors"]: grid[pos] = "floor"
		if r.has("walls"): for pos in r["walls"]: grid[pos] = "wall"
		if r.has("exact_floors"): for pos in r["exact_floors"]: grid[pos] = str(r["exact_floors"][pos]) + "_f"
		if r.has("exact_walls"): for pos in r["exact_walls"]: grid[pos] = str(r["exact_walls"][pos]) + "_w"
	return grid

func _on_cell_hovered(pos: Vector2i) -> void:
	_mouse_grid_pos = pos
	if _current_room_key == "" or not custom_rooms.has(_current_room_key): return
	var r = custom_rooms[_current_room_key]
	
	if pos.x < 0 or pos.y < 0 or pos.x >= r.get("width", 9) or pos.y >= r.get("height", 9):
		painter.highlighted_cells.clear()
	else:
		var multi_tile = _active_brush in [Brush.PLACE_STRUCTURE, Brush.PLACE_WFC_SOCKET]
		
		if _active_tool == 1 and not multi_tile:
			# Fill Tool: Highlight the entire contiguous region
			var target_grid = _get_target_grid(r, _active_brush)
			painter.highlighted_cells = painter.get_flood_fill_area(target_grid, pos)
		else:
			# Pen Tool: Highlight just the single cell under the cursor
			painter.highlighted_cells = [pos]
			
	painter.canvas.queue_redraw()

# ==============================================================================
# PAINTER API USAGE
# ==============================================================================
func _on_cell_painted(pos: Vector2i, erase: bool, is_drag: bool) -> void:
	if _current_room_key == "" or not custom_rooms.has(_current_room_key): return
	var r = custom_rooms[_current_room_key]
	
	var multi_tile = _active_brush in [Brush.PLACE_STRUCTURE, Brush.PLACE_WFC_SOCKET]
	var target_cells = [pos]
	
	if _active_tool == 1 and not multi_tile and not is_drag:
		var target_grid = _get_target_grid(r, _active_brush)
		target_cells = painter.get_flood_fill_area(target_grid, pos)
		
	if _active_tool == 1 and is_drag:
		return # Prevents infinite spamming if holding click with Fill Tool
		
	for cell_pos in target_cells:
		_apply_brush_to_cell(r, cell_pos, erase)
		
	painter.canvas.queue_redraw()

func _apply_brush_to_cell(r: Dictionary, pos: Vector2i, erase: bool) -> void:
	if erase:
		if _active_brush == Brush.PLACE_WFC_SOCKET and r.has("sockets"):
			for i in range(r["sockets"].size() - 1, -1, -1):
				var s_rect = Rect2i(r["sockets"][i], Vector2i(3, 3))
				if s_rect.has_point(pos): r["sockets"].remove_at(i)
		elif _active_brush == Brush.PLACE_STRUCTURE and r.has("placed_structures"):
			for i in range(r["placed_structures"].size() - 1, -1, -1):
				if r["placed_structures"][i]["pos"] == pos: r["placed_structures"].remove_at(i)
		elif _active_brush == Brush.PLACE_ENTITY and r.has("placed_entities"):
			for i in range(r["placed_entities"].size() - 1, -1, -1):
				if r["placed_entities"][i]["pos"] == pos: r["placed_entities"].remove_at(i)
		elif _active_brush == Brush.TOGGLE_RESERVED and r.has("reserved"): r["reserved"].erase(pos)
		elif _active_brush == Brush.DOORWAY and r.has("doorways"): r["doorways"].erase(pos)
		elif _active_brush in [Brush.FLOOR_GENERIC, Brush.WALL_GENERIC, Brush.TILE_EXACT_FLOOR, Brush.TILE_EXACT_WALL]:
			r["floors"].erase(pos); r["walls"].erase(pos)
			if r.has("exact_floors"): r["exact_floors"].erase(pos)
			if r.has("exact_walls"): r["exact_walls"].erase(pos)
		return
		
	if _active_brush == Brush.ANCHOR: r["anchor"] = pos
	elif _active_brush == Brush.TOGGLE_RESERVED:
		if not r.has("reserved"): r["reserved"] = []
		if not r["reserved"].has(pos): r["reserved"].append(pos)
	elif _active_brush == Brush.DOORWAY:
		if not r.has("doorways"): r["doorways"] = []
		if not r["doorways"].has(pos): r["doorways"].append(pos)
	elif _active_brush == Brush.FLOOR_GENERIC:
		if not r.has("floors"): r["floors"] = {}
		r["floors"][pos] = true; _clear_base_tiles(r, pos, ["floors"])
	elif _active_brush == Brush.WALL_GENERIC:
		if not r.has("walls"): r["walls"] = {}
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
		
		var footprint = []
		for p in s_data.get("footprint", [Vector2i.ZERO]): footprint.append(painter.rotate_point(p, _current_struct_rot))
		
		var valid = true
		for pt in footprint:
			var check_pos = pos + pt
			if not painter.is_in_bounds(check_pos): valid = false; break
			
			var is_floor = r.get("floors", {}).has(check_pos) or r.get("exact_floors", {}).has(check_pos)
			if not is_floor: valid = false; break
			
			if r.get("reserved", []).has(check_pos): valid = false; break
			if r.get("walls", {}).has(check_pos) or r.get("exact_walls", {}).has(check_pos): valid = false; break
			
			if r.has("placed_structures"):
				for item in r["placed_structures"]:
					var other_s = _available_structures.get(item["id"], {})
					for opt in other_s.get("footprint", [Vector2i.ZERO]):
						var other_abs = item["pos"] + painter.rotate_point(opt, item["rot"])
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
		
		var valid = true
		var is_floor = r.get("floors", {}).has(pos) or r.get("exact_floors", {}).has(pos)
		if not is_floor: valid = false
		if r.get("reserved", []).has(pos): valid = false
		if r.get("walls", {}).has(pos) or r.get("exact_walls", {}).has(pos): valid = false
		
		if r.has("placed_entities"):
			for item in r["placed_entities"]:
				if item["pos"] == pos: valid = false; break
				
		if r.has("placed_structures"):
			for item in r["placed_structures"]:
				var other_s = _available_structures.get(item["id"], {})
				for opt in other_s.get("footprint", [Vector2i.ZERO]):
					if pos == item["pos"] + painter.rotate_point(opt, item["rot"]): valid = false; break
				if not valid: break
				
		if valid:
			if not r.has("placed_entities"): r["placed_entities"] = []
			r["placed_entities"].append({ "id": ent_id, "pos": pos })
	
	elif _active_brush == Brush.PLACE_WFC_SOCKET:
		var valid = true
		var new_rect = Rect2i(pos, Vector2i(3, 3))
		
		if pos.x < 0 or pos.x + 2 >= r.get("width", 9) or pos.y < 0 or pos.y + 2 >= r.get("height", 9): valid = false
			
		if valid and r.has("sockets"):
			for s_pos in r["sockets"]:
				if new_rect.intersects(Rect2i(s_pos, Vector2i(3, 3))): valid = false; break
					
		if valid and r.has("reserved"):
			for res_pos in r["reserved"]:
				if new_rect.has_point(res_pos): valid = false; break
					
		if valid and r.has("placed_structures"):
			for item in r["placed_structures"]:
				var other_s = _available_structures.get(item["id"], {})
				for opt in other_s.get("footprint", [Vector2i.ZERO]):
					var struct_pt = item["pos"] + painter.rotate_point(opt, item["rot"])
					if new_rect.has_point(struct_pt): valid = false; break
				if not valid: break
				
		if valid:
			if not r.has("sockets"): r["sockets"] = []
			if not r["sockets"].has(pos): r["sockets"].append(pos)

func _on_canvas_draw() -> void:
	if _current_room_key == "" or not custom_rooms.has(_current_room_key): return
	var r = custom_rooms[_current_room_key]
	
	if r.has("floors"): for pos in r["floors"]: painter.draw_cell_rect(pos, Color(0.2, 0.5, 0.3, 0.8)) 
	if r.has("walls"): for pos in r["walls"]: painter.draw_cell_rect(pos, Color(0.4, 0.4, 0.4, 0.8)) 
		
	if r.has("exact_floors") and _tileset_tex:
		for pos in r["exact_floors"]: painter.draw_atlas_cell(pos, _tileset_tex, r["exact_floors"][pos], _tile_size)
			
	if r.has("exact_walls") and _tileset_tex:
		for pos in r["exact_walls"]: painter.draw_atlas_cell(pos, _tileset_tex, r["exact_walls"][pos], _tile_size)

	if r.has("reserved"):
		for pos in r["reserved"]:
			var p_rect = painter.get_pixel_rect(pos)
			painter.canvas.draw_line(p_rect.position, p_rect.end, Color(1, 0, 0, 0.6), 2.0)
			
	if r.has("doorways"):
		for pos in r["doorways"]: painter.draw_cell_rect(pos, Color(0.9, 0.2, 0.2, 0.5)) 
			
	if r.has("anchor"):
		var p_rect = painter.get_pixel_rect(r["anchor"])
		painter.canvas.draw_circle(p_rect.get_center(), p_rect.size.x * 0.3, Color.YELLOW)
	
	if r.has("sockets"):
		for pos in r["sockets"]:
			var p_rect = painter.get_pixel_rect(pos)
			p_rect.size *= 3
			painter.canvas.draw_rect(p_rect, Color(0.6, 0.2, 0.8, 0.3))
			painter.canvas.draw_rect(p_rect, Color(0.8, 0.4, 1.0, 0.8), false, 2.0)
	
	# --- DRAW PLACED STRUCTURES ---
	var draw_struct = func(s_id: String, s_pos: Vector2i, s_rot: int, alpha: float):
		if not _available_structures.has(s_id): return
		var s_data = _available_structures[s_id]
		var footprint = s_data.get("footprint", [Vector2i.ZERO])
		
		var s_color = s_data.get("color", Color.CYAN)
		s_color.a = alpha
		
		for pt in footprint:
			painter.draw_cell_rect(s_pos + painter.rotate_point(pt, s_rot), s_color, Color(1, 1, 1, alpha), 2.0)
			
		var tex_path = s_data.get("texture_path", "")
		if tex_path != "":
			var tex = ConfigManager.get_cached_texture(tex_path)
			if tex:
				painter.draw_normalized_sprite(s_pos, tex, s_data.get("texture_offset", Vector2.ZERO), s_data.get("texture_scale", Vector2.ONE), s_rot, alpha)

		if s_data.get("face_path", true) and footprint.size() > 0:
			painter.draw_facing_arrow(s_pos, footprint, s_data.get("front_dir", Vector2i.UP), s_rot, Color(1, 0, 0, alpha))
			
	if r.has("placed_structures"):
		for item in r["placed_structures"]: draw_struct.call(item["id"], item["pos"], item["rot"], 0.9)
			
	# --- GHOST PREVIEW FOR STANDARD BRUSHES ---
	if painter.is_in_bounds(_mouse_grid_pos) and _active_tool == 0:
		var ghost_pos = _mouse_grid_pos
		if _active_brush == Brush.FLOOR_GENERIC:
			painter.draw_cell_rect(ghost_pos, Color(0.2, 0.5, 0.3, 0.4))
		elif _active_brush == Brush.WALL_GENERIC:
			painter.draw_cell_rect(ghost_pos, Color(0.4, 0.4, 0.4, 0.4))
		elif _active_brush == Brush.TILE_EXACT_FLOOR and _tileset_tex:
			painter.draw_atlas_cell(ghost_pos, _tileset_tex, _selected_atlas, _tile_size)
			# Add a subtle translucent tint over the atlas preview so it looks like a ghost
			painter.draw_cell_rect(ghost_pos, Color(1, 1, 1, 0.3))
		elif _active_brush == Brush.TILE_EXACT_WALL and _tileset_tex:
			painter.draw_atlas_cell(ghost_pos, _tileset_tex, _selected_atlas, _tile_size)
			painter.draw_cell_rect(ghost_pos, Color(1, 1, 1, 0.3))
		elif _active_brush == Brush.DOORWAY:
			painter.draw_cell_rect(ghost_pos, Color(0.9, 0.2, 0.2, 0.3))
		elif _active_brush == Brush.TOGGLE_RESERVED:
			var p_rect = painter.get_pixel_rect(ghost_pos)
			painter.canvas.draw_line(p_rect.position, p_rect.end, Color(1, 0, 0, 0.4), 2.0)
		elif _active_brush == Brush.ANCHOR:
			var p_rect = painter.get_pixel_rect(ghost_pos)
			painter.canvas.draw_circle(p_rect.get_center(), p_rect.size.x * 0.3, Color(1, 1, 0, 0.4))
	
	# --- GHOST PREVIEW STRUCTURE ---
	if _active_brush == Brush.PLACE_STRUCTURE and _current_struct_id != "":
		if painter.is_in_bounds(_mouse_grid_pos):
			draw_struct.call(_current_struct_id, _mouse_grid_pos, _current_struct_rot, 0.4)
	
	# --- DRAW PLACED ENTITIES ---
	var draw_ent = func(e_id: String, e_pos: Vector2i, alpha: float):
		if not _available_entities.has(e_id): return
		var e_data = _available_entities[e_id]
		
		var e_color = e_data.get("color", Color.WHITE)
		e_color.a = alpha
		painter.draw_cell_rect(e_pos, e_color, Color(1, 1, 1, alpha), 2.0)
		
		var tex_path = e_data.get("texture_path", "")
		if tex_path != "":
			var tex = ConfigManager.get_cached_texture(tex_path)
			if tex:
				painter.draw_normalized_sprite(e_pos, tex, e_data.get("texture_offset", Vector2.ZERO), e_data.get("texture_scale", Vector2.ONE), 0, alpha)

	if r.has("placed_entities"):
		for item in r["placed_entities"]: draw_ent.call(item["id"], item["pos"], 0.9)
			
	# --- GHOST PREVIEW ENTITY ---
	if _active_brush == Brush.PLACE_ENTITY and _opt_entity.item_count > 0:
		var ent_id = _opt_entity.get_item_metadata(_opt_entity.selected)
		if painter.is_in_bounds(_mouse_grid_pos):
			draw_ent.call(ent_id, _mouse_grid_pos, 0.4)
	
	# --- GHOST PREVIEW WFC SOCKET ---
	if _active_brush == Brush.PLACE_WFC_SOCKET:
		if painter.is_in_bounds(_mouse_grid_pos):
			var valid = true
			var ghost_rect = Rect2i(_mouse_grid_pos, Vector2i(3, 3))
			
			# Validate Bounds
			if _mouse_grid_pos.x + 2 >= r.get("width", 9) or _mouse_grid_pos.y + 2 >= r.get("height", 9):
				valid = false
			else:
				# Validate overlaps for visual feedback
				if r.has("sockets"):
					for s_pos in r["sockets"]:
						if ghost_rect.intersects(Rect2i(s_pos, Vector2i(3, 3))): valid = false; break
				if valid and r.has("reserved"):
					for res_pos in r["reserved"]:
						if ghost_rect.has_point(res_pos): valid = false; break
				if valid and r.has("placed_structures"):
					for item in r["placed_structures"]:
						var other_s = _available_structures.get(item["id"], {})
						for opt in other_s.get("footprint", [Vector2i.ZERO]):
							if ghost_rect.has_point(item["pos"] + painter.rotate_point(opt, item["rot"])):
								valid = false; break
						if not valid: break
			
			var fill_color = Color(0.6, 0.2, 0.8, 0.3) if valid else Color(1.0, 0.0, 0.0, 0.3)
			var border_color = Color(0.8, 0.4, 1.0, 0.8) if valid else Color(1.0, 0.2, 0.2, 0.8)
			
			var p_rect = painter.get_pixel_rect(_mouse_grid_pos)
			p_rect.size *= 3
			painter.canvas.draw_rect(p_rect, fill_color)
			painter.canvas.draw_rect(p_rect, border_color, false, 2.0)
	
	# --- RENDER FILL HIGHLIGHTS ---
	if _active_tool == 1:
		painter.draw_highlights()
	

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
				
	# CHECK 4: WFC Sockets cannot overlap with Reserved critical paths!
	if r.has("sockets"):
		for s_pos in r["sockets"]:
			for dy in range(3):
				for dx in range(3):
					if reserved.has(s_pos + Vector2i(dx, dy)):
						return "WFC Sockets (3x3) cannot overlap with 'Reserved' tiles! Leave the critical path clear."
	
	return "" # Empty string means validation passed!
