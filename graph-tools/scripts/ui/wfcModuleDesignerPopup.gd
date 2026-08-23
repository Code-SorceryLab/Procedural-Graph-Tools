class_name WfcModuleDesignerPopup
extends Window

signal confirmed

enum Brush { NONE, FLOOR_GENERIC, WALL_GENERIC, TILE_EXACT_FLOOR, TILE_EXACT_WALL, PLACE_ENTITY }

const SOCKET_SIZE = 3 # A standard 3x3 WFC chunk

var wfc_modules: Dictionary = {}
var _current_module_key: String = ""

# --- UI REFS ---
var _module_dropdown: OptionButton
var _module_name_edit: LineEdit
var _weight_spin: SpinBox

# Edge Rules
var _edge_n: LineEdit
var _edge_e: LineEdit
var _edge_s: LineEdit
var _edge_w: LineEdit

var _brush_dropdown: OptionButton
var _btn_atlas_picker: Button
var _canvas: Control

var _opt_entity: OptionButton 
var _lbl_ent: Label

# --- ATLAS PICKER WINDOW ---
var _picker_window: Window
var _picker_rect: TextureRect
var _selected_atlas: Vector2i = Vector2i.ZERO

# --- STATE ---
var _draw_mask: int = 0 
var _active_brush: Brush = Brush.NONE
var _tileset_tex: Texture2D
var _tile_size: Vector2i = Vector2i(16, 16)
var _texture_cache: Dictionary = {}
var _zoom: float = 4.0 # Default zoomed in since it's only 3x3
var _available_entities: Dictionary = {} 
var _mouse_grid_pos: Vector2i = Vector2i.ZERO 

func _init() -> void:
	title = "WFC Module Designer (3x3 Chunks)"
	min_size = Vector2i(850, 600)
	exclusive = true
	close_requested.connect(func(): hide())
	
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	add_child(main_vbox)
	
	# --- TOOLBAR 1: MODULE SELECTION & WEIGHT ---
	var toolbar = HBoxContainer.new()
	main_vbox.add_child(toolbar)
	
	_module_dropdown = OptionButton.new()
	_module_dropdown.custom_minimum_size.x = 150
	_module_dropdown.item_selected.connect(_on_module_selected)
	toolbar.add_child(_module_dropdown)
	
	_module_name_edit = LineEdit.new()
	_module_name_edit.custom_minimum_size.x = 150
	_module_name_edit.placeholder_text = "Rename Module..."
	_module_name_edit.text_submitted.connect(_on_module_renamed)
	toolbar.add_child(_module_name_edit)
	
	var btn_add = Button.new(); btn_add.text = "+ New"; btn_add.pressed.connect(_on_add_module)
	var btn_del = Button.new(); btn_del.text = "Delete"; btn_del.pressed.connect(_on_delete_module)
	toolbar.add_child(btn_add); toolbar.add_child(btn_del)
	toolbar.add_child(VSeparator.new())
	
	var lbl_w = Label.new(); lbl_w.text = "Spawn Weight:"
	_weight_spin = SpinBox.new(); _weight_spin.min_value = 0.1; _weight_spin.max_value = 1000.0; _weight_spin.step = 0.1
	_weight_spin.value_changed.connect(func(v): if _current_module_key != "": wfc_modules[_current_module_key]["weight"] = v)
	toolbar.add_child(lbl_w); toolbar.add_child(_weight_spin)
	
	# --- TOOLBAR 2: EDGE RULES ---
	var edge_toolbar = HBoxContainer.new()
	main_vbox.add_child(edge_toolbar)
	
	var edge_title = Label.new()
	edge_title.text = "Edge Rules:"
	edge_toolbar.add_child(edge_title)
	
	var create_edge_input = func(label_text: String) -> LineEdit:
		var hb = HBoxContainer.new()
		var lbl = Label.new()
		lbl.text = label_text
		hb.add_child(lbl)
		
		var le = LineEdit.new()
		le.custom_minimum_size.x = 80
		le.text_changed.connect(func(txt): _update_edge_rules())
		hb.add_child(le)
		edge_toolbar.add_child(hb)
		return le
		
	_edge_n = create_edge_input.call("North:")
	_edge_e = create_edge_input.call("East:")
	_edge_s = create_edge_input.call("South:")
	_edge_w = create_edge_input.call("West:")
	
	# --- TOOLBAR 3: BRUSHES ---
	var brush_toolbar = HBoxContainer.new()
	main_vbox.add_child(brush_toolbar)
	
	var brush_lbl = Label.new()
	brush_lbl.text = "Active Brush:"
	brush_toolbar.add_child(brush_lbl)
	
	_brush_dropdown = OptionButton.new()
	_brush_dropdown.add_item("Generic Biome Floor", Brush.FLOOR_GENERIC)
	_brush_dropdown.add_item("Generic Biome Wall", Brush.WALL_GENERIC)
	_brush_dropdown.add_item("Exact Floor Tile", Brush.TILE_EXACT_FLOOR)
	_brush_dropdown.add_item("Exact Wall Tile", Brush.TILE_EXACT_WALL)
	_brush_dropdown.add_item("Place Entity", Brush.PLACE_ENTITY)
	_brush_dropdown.item_selected.connect(func(idx): _active_brush = _brush_dropdown.get_item_id(idx) as Brush; _update_brush_ui())
	brush_toolbar.add_child(_brush_dropdown)
	
	_btn_atlas_picker = Button.new()
	_btn_atlas_picker.text = "Pick Brush Tile [0, 0]"
	_btn_atlas_picker.pressed.connect(func(): _picker_window.popup_centered())
	brush_toolbar.add_child(_btn_atlas_picker)
	
	_lbl_ent = Label.new(); _lbl_ent.text = "  Select Entity: "
	brush_toolbar.add_child(_lbl_ent)
	
	_opt_entity = OptionButton.new()
	_opt_entity.item_selected.connect(func(idx): _canvas.queue_redraw())
	brush_toolbar.add_child(_opt_entity)
	
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
	_canvas.custom_minimum_size = Vector2(800, 800)
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST 
	_canvas.gui_input.connect(_on_canvas_gui_input)
	_canvas.draw.connect(_on_canvas_draw)
	panel.add_child(_canvas)
	
	# --- BOTTOM BUTTONS ---
	var bottom = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	main_vbox.add_child(bottom)
	
	var btn_save = Button.new(); btn_save.text = "Save Modules"; btn_save.pressed.connect(_on_save_pressed)
	var btn_cancel = Button.new(); btn_cancel.text = "Cancel"; btn_cancel.pressed.connect(func(): hide())
	bottom.add_child(btn_cancel); bottom.add_child(btn_save)

# ==============================================================================
# API & STATE MANAGEMENT
# ==============================================================================
func open(texture_path: String, tile_size: Vector2i, existing_modules: Dictionary, available_ents: Dictionary) -> void:
	_tile_size = tile_size
	_available_entities = available_ents
	
	if texture_path != "" and FileAccess.file_exists(texture_path):
		var img = Image.load_from_file(texture_path)
		if img: 
			_tileset_tex = ImageTexture.create_from_image(img)
			_picker_rect.texture = _tileset_tex
	
	wfc_modules = existing_modules.duplicate(true) 
	if wfc_modules.is_empty():
		_add_new_module_data("Empty_Floor")
		
	_refresh_module_dropdown()
	_refresh_entity_dropdown()
	
	_active_brush = Brush.FLOOR_GENERIC
	_brush_dropdown.selected = 0
	_update_brush_ui()
	popup_centered()

func _add_new_module_data(m_name: String) -> void:
	wfc_modules[m_name] = {
		"weight": 10.0,
		"edges": {"N": "Open", "E": "Open", "S": "Open", "W": "Open"},
		"floors": {},         
		"walls": {},          
		"exact_floors": {},   
		"exact_walls": {},
		"placed_entities": []
	}
	# Pre-fill a 3x3 generic floor as a courtesy
	for y in range(SOCKET_SIZE):
		for x in range(SOCKET_SIZE):
			wfc_modules[m_name]["floors"][Vector2i(x,y)] = true
			
	_current_module_key = m_name

func _update_edge_rules() -> void:
	if _current_module_key == "" or not wfc_modules.has(_current_module_key): return
	wfc_modules[_current_module_key]["edges"] = {
		"N": _edge_n.text.strip_edges(),
		"E": _edge_e.text.strip_edges(),
		"S": _edge_s.text.strip_edges(),
		"W": _edge_w.text.strip_edges()
	}

func _refresh_module_dropdown() -> void:
	_module_dropdown.clear()
	var keys = wfc_modules.keys()
	for i in range(keys.size()):
		_module_dropdown.add_item(keys[i], i)
		if keys[i] == _current_module_key:
			_module_dropdown.selected = i
	
	if keys.size() > 0 and _current_module_key == "":
		_current_module_key = keys[0]
		_module_dropdown.selected = 0
		
	_load_module_to_ui()

func _load_module_to_ui() -> void:
	if not wfc_modules.has(_current_module_key): return
	var m = wfc_modules[_current_module_key]
	
	_module_name_edit.text = _current_module_key
	_weight_spin.set_value_no_signal(m.get("weight", 10.0))
	
	var edges = m.get("edges", {"N": "Open", "E": "Open", "S": "Open", "W": "Open"})
	_edge_n.text = edges.get("N", "Open")
	_edge_e.text = edges.get("E", "Open")
	_edge_s.text = edges.get("S", "Open")
	_edge_w.text = edges.get("W", "Open")
	
	_canvas.queue_redraw()

func _on_module_selected(idx: int) -> void:
	_current_module_key = _module_dropdown.get_item_text(idx)
	_load_module_to_ui()

func _on_module_renamed(new_name: String) -> void:
	var safe_name = new_name.strip_edges()
	if safe_name == "" or safe_name == _current_module_key or wfc_modules.has(safe_name):
		_module_name_edit.text = _current_module_key 
		return
		
	wfc_modules[safe_name] = wfc_modules[_current_module_key]
	wfc_modules.erase(_current_module_key)
	_current_module_key = safe_name
	_module_dropdown.set_item_text(_module_dropdown.selected, safe_name)

func _refresh_entity_dropdown() -> void:
	_opt_entity.clear()
	var keys = _available_entities.keys()
	for i in range(keys.size()):
		_opt_entity.add_item(_available_entities[keys[i]].get("name", "Unnamed"), i)
		_opt_entity.set_item_metadata(i, keys[i])
	if keys.size() > 0: _opt_entity.selected = 0

func _update_brush_ui() -> void:
	var is_ent = (_active_brush == Brush.PLACE_ENTITY)
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
		_selected_atlas = Vector2i(ax, ay)
		_btn_atlas_picker.text = "Pick Brush Tile [%d, %d]" % [ax, ay]
		_picker_window.hide()

# ==============================================================================
# PAINTING LOGIC
# ==============================================================================
func _on_canvas_gui_input(event: InputEvent) -> void:
	if _current_module_key == "" or not wfc_modules.has(_current_module_key): return
	
	if event is InputEventMouseMotion:
		var cell_px = _tile_size.x * _zoom
		_mouse_grid_pos = Vector2i(int(event.position.x / cell_px), int(event.position.y / cell_px))
		if _active_brush == Brush.PLACE_ENTITY: _canvas.queue_redraw()
		
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_draw_mask = 1 if event.button_index == MOUSE_BUTTON_LEFT else 2
			_paint_cell(event.position, _draw_mask == 2)
		else:
			_draw_mask = 0
			
	elif event is InputEventMouseMotion and _draw_mask != 0:
		_paint_cell(event.position, _draw_mask == 2)

func _paint_cell(local_pos: Vector2, erase: bool) -> void:
	var cell_px = _tile_size.x * _zoom
	var cx = int(local_pos.x / cell_px)
	var cy = int(local_pos.y / cell_px)
	
	# Strict 3x3 Bounds Check
	if cx < 0 or cx >= SOCKET_SIZE or cy < 0 or cy >= SOCKET_SIZE: return
	var pos = Vector2i(cx, cy)
	var m = wfc_modules[_current_module_key]
	
	if erase:
		if _active_brush == Brush.PLACE_ENTITY and m.has("placed_entities"):
			for i in range(m["placed_entities"].size() - 1, -1, -1):
				if m["placed_entities"][i]["pos"] == pos:
					m["placed_entities"].remove_at(i)
		elif _active_brush in [Brush.FLOOR_GENERIC, Brush.WALL_GENERIC, Brush.TILE_EXACT_FLOOR, Brush.TILE_EXACT_WALL]:
			m["floors"].erase(pos); m["walls"].erase(pos)
			if m.has("exact_floors"): m["exact_floors"].erase(pos)
			if m.has("exact_walls"): m["exact_walls"].erase(pos)
		_canvas.queue_redraw()
		return
		
	if _active_brush == Brush.FLOOR_GENERIC:
		m["floors"][pos] = true; _clear_base_tiles(m, pos, ["floors"])
	elif _active_brush == Brush.WALL_GENERIC:
		m["walls"][pos] = true; _clear_base_tiles(m, pos, ["walls"])
	elif _active_brush == Brush.TILE_EXACT_FLOOR:
		if not m.has("exact_floors"): m["exact_floors"] = {}
		m["exact_floors"][pos] = _selected_atlas; _clear_base_tiles(m, pos, ["exact_floors"])
	elif _active_brush == Brush.TILE_EXACT_WALL:
		if not m.has("exact_walls"): m["exact_walls"] = {}
		m["exact_walls"][pos] = _selected_atlas; _clear_base_tiles(m, pos, ["exact_walls"])
	elif _active_brush == Brush.PLACE_ENTITY:
		if _opt_entity.item_count == 0: return
		var ent_id = _opt_entity.get_item_metadata(_opt_entity.selected)
		if ent_id == "" or not _available_entities.has(ent_id): return
		
		var is_floor = m.get("floors", {}).has(pos) or m.get("exact_floors", {}).has(pos)
		if not is_floor: return # Must be floor!
		if m.get("walls", {}).has(pos) or m.get("exact_walls", {}).has(pos): return
		
		if not m.has("placed_entities"): m["placed_entities"] = []
		# Overwrite if exists
		for i in range(m["placed_entities"].size() - 1, -1, -1):
			if m["placed_entities"][i]["pos"] == pos: m["placed_entities"].remove_at(i)
		m["placed_entities"].append({ "id": ent_id, "pos": pos })
		
	_canvas.queue_redraw()

func _clear_base_tiles(m: Dictionary, pos: Vector2i, keep_keys: Array) -> void:
	for k in ["floors", "walls", "exact_floors", "exact_walls"]:
		if not keep_keys.has(k) and m.has(k): m[k].erase(pos)

# ==============================================================================
# DRAWING ENGINE
# ==============================================================================
func _on_canvas_draw() -> void:
	if _current_module_key == "" or not wfc_modules.has(_current_module_key): return
	var m = wfc_modules[_current_module_key]
	var scaled_sz = _tile_size * _zoom
	
	# Draw the 3x3 bounds
	_canvas.draw_rect(Rect2(0, 0, SOCKET_SIZE * scaled_sz.x, SOCKET_SIZE * scaled_sz.y), Color(0.1, 0.1, 0.15))
	for y in range(SOCKET_SIZE + 1): _canvas.draw_line(Vector2(0, y * scaled_sz.y), Vector2(SOCKET_SIZE * scaled_sz.x, y * scaled_sz.y), Color(1, 1, 1, 0.2))
	for x in range(SOCKET_SIZE + 1): _canvas.draw_line(Vector2(x * scaled_sz.x, 0), Vector2(x * scaled_sz.x, SOCKET_SIZE * scaled_sz.y), Color(1, 1, 1, 0.2))

	var draw_rect_at = func(pos: Vector2i, color: Color):
		_canvas.draw_rect(Rect2(pos.x * scaled_sz.x, pos.y * scaled_sz.y, scaled_sz.x, scaled_sz.y), color)

	if m.has("floors"): for pos in m["floors"]: draw_rect_at.call(pos, Color(0.2, 0.5, 0.3, 0.8)) 
	if m.has("walls"): for pos in m["walls"]: draw_rect_at.call(pos, Color(0.4, 0.4, 0.4, 0.8)) 
		
	if m.has("exact_floors") and _tileset_tex:
		for pos in m["exact_floors"]:
			var atlas = m["exact_floors"][pos]
			var src_rect = Rect2(atlas.x * _tile_size.x, atlas.y * _tile_size.y, _tile_size.x, _tile_size.y)
			var dest_rect = Rect2(pos.x * scaled_sz.x, pos.y * scaled_sz.y, scaled_sz.x, scaled_sz.y)
			_canvas.draw_texture_rect_region(_tileset_tex, dest_rect, src_rect)
			
	if m.has("exact_walls") and _tileset_tex:
		for pos in m["exact_walls"]:
			var atlas = m["exact_walls"][pos]
			var src_rect = Rect2(atlas.x * _tile_size.x, atlas.y * _tile_size.y, _tile_size.x, _tile_size.y)
			var dest_rect = Rect2(pos.x * scaled_sz.x, pos.y * scaled_sz.y, scaled_sz.x, scaled_sz.y)
			_canvas.draw_texture_rect_region(_tileset_tex, dest_rect, src_rect)

	# --- DRAW ENTITIES ---
	var draw_ent = func(e_id: String, e_pos: Vector2i, alpha: float):
		if not _available_entities.has(e_id): return
		var e_data = _available_entities[e_id]
		var e_color = e_data.get("color", Color.WHITE)
		e_color.a = alpha
		
		var px = e_pos.x * scaled_sz.x
		var py = e_pos.y * scaled_sz.y
		_canvas.draw_rect(Rect2(px, py, scaled_sz.x, scaled_sz.y), e_color)
		_canvas.draw_rect(Rect2(px, py, scaled_sz.x, scaled_sz.y), Color(1, 1, 1, alpha), false, 2.0)

	if m.has("placed_entities"):
		for item in m["placed_entities"]:
			draw_ent.call(item["id"], item["pos"], 1.0)
			
	# Ghost Preview
	if _active_brush == Brush.PLACE_ENTITY and _opt_entity.item_count > 0:
		var ent_id = _opt_entity.get_item_metadata(_opt_entity.selected)
		if _mouse_grid_pos.x >= 0 and _mouse_grid_pos.x < SOCKET_SIZE and _mouse_grid_pos.y >= 0 and _mouse_grid_pos.y < SOCKET_SIZE:
			draw_ent.call(ent_id, _mouse_grid_pos, 0.4)

# ==============================================================================
# SAVE
# ==============================================================================
func _on_add_module() -> void:
	var new_name = "Module_" + str(wfc_modules.size() + 1)
	_add_new_module_data(new_name)
	_refresh_module_dropdown()

func _on_delete_module() -> void:
	if _current_module_key != "":
		wfc_modules.erase(_current_module_key)
		_current_module_key = ""
		_refresh_module_dropdown()

func _on_save_pressed() -> void:
	# Note: Emits the raw dictionary. 
	# Your ConfigManager / UI Controller will receive this and save it to a JSON file.
	confirmed.emit(wfc_modules)
	hide()
