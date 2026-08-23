class_name TileWfcDesignerPopup
extends Window

signal confirmed

var wfc_palettes: Dictionary = {}
var _current_key: String = ""

# --- UI REFS ---
var _palette_dropdown: OptionButton
var _name_edit: LineEdit
var _width_spin: SpinBox
var _height_spin: SpinBox
var _n_size_spin: SpinBox # The 'N' in NxN overlapping model (usually 2 or 3)

var _btn_atlas_picker: Button
var _picker_window: Window
var _picker_rect: TextureRect

var painter: GridCanvasPainter

# --- STATE ---
var _tileset_tex: Texture2D
var _tile_size: Vector2i = Vector2i(16, 16)
var _active_atlas_brush: Vector2i = Vector2i.ZERO
var _draw_mask: int = 0

func _init() -> void:
	title = "Textural WFC (Overlapping Sample Editor)"
	min_size = Vector2i(850, 600)
	exclusive = true
	close_requested.connect(func(): hide())
	
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	add_child(main_vbox)
	
	# --- TOOLBAR 1: PALETTE CONFIG ---
	var toolbar = HBoxContainer.new()
	main_vbox.add_child(toolbar)
	
	_palette_dropdown = OptionButton.new()
	_palette_dropdown.custom_minimum_size.x = 150
	_palette_dropdown.item_selected.connect(_on_palette_selected)
	toolbar.add_child(_palette_dropdown)
	
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size.x = 150
	_name_edit.placeholder_text = "Rename Palette..."
	_name_edit.text_submitted.connect(_on_palette_renamed)
	toolbar.add_child(_name_edit)
	
	var btn_add = Button.new(); btn_add.text = "+ New"; btn_add.pressed.connect(_on_add_palette)
	var btn_del = Button.new(); btn_del.text = "Delete"; btn_del.pressed.connect(_on_delete_palette)
	toolbar.add_child(btn_add); toolbar.add_child(btn_del)
	
	toolbar.add_child(VSeparator.new())
	
	var lbl_n = Label.new(); lbl_n.text = "Pattern Size (N):"
	lbl_n.tooltip_text = "Size of the chunks scanned to learn rules. 2 or 3 is standard."
	_n_size_spin = SpinBox.new(); _n_size_spin.min_value = 2; _n_size_spin.max_value = 4; _n_size_spin.value = 3
	_n_size_spin.value_changed.connect(func(v): if _current_key != "": wfc_palettes[_current_key]["n_size"] = int(v))
	toolbar.add_child(lbl_n); toolbar.add_child(_n_size_spin)
	
	# --- TOOLBAR 2: CANVAS SETTINGS & BRUSH ---
	var brush_toolbar = HBoxContainer.new()
	main_vbox.add_child(brush_toolbar)
	
	var lbl_w = Label.new(); lbl_w.text = "Sample W:"
	_width_spin = SpinBox.new(); _width_spin.min_value = 5; _width_spin.max_value = 50; _width_spin.value = 10
	_width_spin.value_changed.connect(func(v): _update_grid_size())
	
	var lbl_h = Label.new(); lbl_h.text = "H:"
	_height_spin = SpinBox.new(); _height_spin.min_value = 5; _height_spin.max_value = 50; _height_spin.value = 10
	_height_spin.value_changed.connect(func(v): _update_grid_size())
	
	brush_toolbar.add_child(lbl_w); brush_toolbar.add_child(_width_spin)
	brush_toolbar.add_child(lbl_h); brush_toolbar.add_child(_height_spin)
	brush_toolbar.add_child(VSeparator.new())
	
	var lbl_brush = Label.new(); lbl_brush.text = "Active Brush (L-Click Paint, R-Click Erase): "
	brush_toolbar.add_child(lbl_brush)
	
	_btn_atlas_picker = Button.new()
	_btn_atlas_picker.text = "Pick Atlas Tile [0, 0]"
	_btn_atlas_picker.pressed.connect(func(): _picker_window.popup_centered())
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
	
	# --- PAINTER ---
	painter = GridCanvasPainter.new()
	painter.origin_mode = GridCanvasPainter.OriginMode.TOP_LEFT
	main_vbox.add_child(painter)
	
	painter.cell_painted.connect(_on_cell_painted)
	painter.canvas.draw.connect(_on_canvas_draw)
	
	# --- BOTTOM BUTTONS ---
	var bottom = HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_END
	main_vbox.add_child(bottom)
	
	var btn_save = Button.new(); btn_save.text = "Save Palettes"; btn_save.pressed.connect(_on_save_pressed)
	var btn_cancel = Button.new(); btn_cancel.text = "Cancel"; btn_cancel.pressed.connect(func(): hide())
	bottom.add_child(btn_cancel); bottom.add_child(btn_save)

# ==============================================================================
# API & STATE MANAGEMENT
# ==============================================================================
func open(texture_path: String, tile_size: Vector2i, existing_palettes: Dictionary) -> void:
	_tile_size = tile_size
	painter.tile_size = float(tile_size.x)
	
	if texture_path != "" and FileAccess.file_exists(texture_path):
		var img = Image.load_from_file(texture_path)
		if img: 
			_tileset_tex = ImageTexture.create_from_image(img)
			_picker_rect.texture = _tileset_tex
			
	wfc_palettes = existing_palettes.duplicate(true)
	if wfc_palettes.is_empty():
		_add_new_palette("Grass_And_Water")
		
	_refresh_dropdown()
	popup_centered()

func _add_new_palette(p_name: String) -> void:
	wfc_palettes[p_name] = {
		"width": 10, "height": 10,
		"n_size": 3,
		"sample_grid": {} # Maps Vector2i -> Vector2i (Atlas Coord)
	}
	_current_key = p_name

func _refresh_dropdown() -> void:
	_palette_dropdown.clear()
	var keys = wfc_palettes.keys()
	for i in range(keys.size()):
		_palette_dropdown.add_item(keys[i], i)
		if keys[i] == _current_key:
			_palette_dropdown.selected = i
			
	if keys.size() > 0 and _current_key == "":
		_current_key = keys[0]
		_palette_dropdown.selected = 0
		
	_load_palette_to_ui()

func _load_palette_to_ui() -> void:
	if not wfc_palettes.has(_current_key): return
	var p = wfc_palettes[_current_key]
	_name_edit.text = _current_key
	_width_spin.set_value_no_signal(p.get("width", 10))
	_height_spin.set_value_no_signal(p.get("height", 10))
	_n_size_spin.set_value_no_signal(p.get("n_size", 3))
	
	painter.grid_bounds = Vector2i(p.get("width", 10), p.get("height", 10))
	painter.canvas.queue_redraw()

func _update_grid_size() -> void:
	if _current_key == "" or not wfc_palettes.has(_current_key): return
	var w = int(_width_spin.value)
	var h = int(_height_spin.value)
	wfc_palettes[_current_key]["width"] = w
	wfc_palettes[_current_key]["height"] = h
	painter.grid_bounds = Vector2i(w, h)
	painter.canvas.queue_redraw()

func _on_palette_selected(idx: int) -> void:
	_current_key = _palette_dropdown.get_item_text(idx)
	_load_palette_to_ui()

func _on_palette_renamed(new_name: String) -> void:
	var safe_name = new_name.strip_edges()
	if safe_name == "" or safe_name == _current_key or wfc_palettes.has(safe_name):
		_name_edit.text = _current_key 
		return
		
	wfc_palettes[safe_name] = wfc_palettes[_current_key]
	wfc_palettes.erase(_current_key)
	_current_key = safe_name
	_palette_dropdown.set_item_text(_palette_dropdown.selected, safe_name)

# ==============================================================================
# INPUT & PAINTER
# ==============================================================================
func _on_picker_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var ax = int(event.position.x / _tile_size.x)
		var ay = int(event.position.y / _tile_size.y)
		_active_atlas_brush = Vector2i(ax, ay)
		_btn_atlas_picker.text = "Pick Atlas Tile [%d, %d]" % [ax, ay]
		_picker_window.hide()

func _on_cell_painted(pos: Vector2i, erase: bool, is_drag: bool) -> void:
	if _current_key == "" or not wfc_palettes.has(_current_key): return
	var p = wfc_palettes[_current_key]
	
	if erase:
		p["sample_grid"].erase(pos)
	else:
		p["sample_grid"][pos] = _active_atlas_brush
		
	painter.canvas.queue_redraw()

func _on_canvas_draw() -> void:
	if _current_key == "" or not wfc_palettes.has(_current_key) or not _tileset_tex: return
	var p = wfc_palettes[_current_key]
	var grid = p.get("sample_grid", {})
	
	for pos in grid:
		painter.draw_atlas_cell(pos, _tileset_tex, grid[pos], _tile_size)

func _on_add_palette() -> void:
	var new_name = "Palette_" + str(wfc_palettes.size() + 1)
	_add_new_palette(new_name)
	_refresh_dropdown()

func _on_delete_palette() -> void:
	if _current_key != "":
		wfc_palettes.erase(_current_key)
		_current_key = ""
		_refresh_dropdown()

func _on_save_pressed() -> void:
	confirmed.emit(wfc_palettes)
	hide()
