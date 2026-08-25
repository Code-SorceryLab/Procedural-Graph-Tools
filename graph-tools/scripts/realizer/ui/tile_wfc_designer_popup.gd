class_name TileWfcDesignerPopup
extends Window

signal confirmed

enum Brush { EXACT_TILE, GENERIC_FLOOR, GENERIC_WALL }

var wfc_palettes: Dictionary = {}
var _current_key: String = ""

# --- UI REFS ---
var _palette_dropdown: OptionButton
var _name_edit: LineEdit
var _width_spin: SpinBox
var _height_spin: SpinBox
var _n_size_spin: SpinBox 


var _chk_wall_aware: CheckBox
var _chk_seamless: CheckBox
var _chk_rotations: CheckBox
var _chk_reflections: CheckBox
var _opt_base_fill: OptionButton
var _opt_fallback_mode: OptionButton
var _btn_fallback_atlas: Button

var _brush_dropdown: OptionButton
var _btn_atlas_picker: Button
var _picker_window: Window
var _picker_rect: TextureRect

# The Two Canvases
var painter: GridCanvasPainter
var preview_painter: GridCanvasPainter

var _opt_preview_shape: OptionButton
var _preview_size_spin: SpinBox
var _preview_grid: Dictionary = {}
var _preview_seed: int = 1000

var _preview_brush_dropdown: OptionButton
var _chk_highlight_fixed: CheckBox
var _preview_fixed_grid: Dictionary = {} # Stores user-painted preview constraints
var _active_preview_brush: int = 0 # 0=None, 1=Exact Tile, 2=Wall

# --- STATE ---
var _tileset_tex: Texture2D
var _tile_size: Vector2i = Vector2i(16, 16)
var _active_atlas_brush: Vector2i = Vector2i.ZERO
var _active_brush: Brush = Brush.EXACT_TILE
var _picking_mode: int = 0 

# --- TOOL MODES ---
var _tool_dropdown: OptionButton
var _active_tool: int = 0 # 0 = Pen, 1 = Fill

var _preview_tool_dropdown: OptionButton
var _active_preview_tool: int = 0 # 0 = Pen, 1 = Fill

func _init() -> void:
	title = "Textural WFC (Overlapping Sample Editor)"
	min_size = Vector2i(1500, 900)
	exclusive = true
	transient = true
	close_requested.connect(func(): hide())
	
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 10)
	add_child(main_vbox)
	
	# --- TOOLBAR 1: PALETTE CONFIG ---
	var toolbar1 = HBoxContainer.new()
	main_vbox.add_child(toolbar1)
	
	_palette_dropdown = OptionButton.new()
	_palette_dropdown.custom_minimum_size.x = 150
	_palette_dropdown.item_selected.connect(_on_palette_selected)
	toolbar1.add_child(_palette_dropdown)
	
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size.x = 150
	_name_edit.placeholder_text = "Rename Palette..."
	_name_edit.text_submitted.connect(_on_palette_renamed)
	toolbar1.add_child(_name_edit)
	
	var btn_add = Button.new(); btn_add.text = "+ New"; btn_add.pressed.connect(_on_add_palette)
	var btn_del = Button.new(); btn_del.text = "Delete"; btn_del.pressed.connect(_on_delete_palette)
	toolbar1.add_child(btn_add); toolbar1.add_child(btn_del)
	toolbar1.add_child(VSeparator.new())
	
	var lbl_n = Label.new(); lbl_n.text = "Pattern Size (N):"
	lbl_n.tooltip_text = "Size of the chunks scanned to learn rules. 2 or 3 is standard."
	_n_size_spin = SpinBox.new(); _n_size_spin.min_value = 2; _n_size_spin.max_value = 4; _n_size_spin.value = 3
	_n_size_spin.value_changed.connect(func(v): if _current_key != "": wfc_palettes[_current_key]["n_size"] = int(v))
	toolbar1.add_child(lbl_n); toolbar1.add_child(_n_size_spin)
	
	_chk_wall_aware = CheckBox.new()
	_chk_wall_aware.text = "Wall-Aware"
	_chk_wall_aware.tooltip_text = "If true, textures physically react to the dungeon walls."
	_chk_wall_aware.toggled.connect(func(v): if _current_key != "": wfc_palettes[_current_key]["wall_aware"] = v)
	toolbar1.add_child(_chk_wall_aware)
	
	_chk_seamless = CheckBox.new()
	_chk_seamless.text = "Seamless"
	_chk_seamless.toggled.connect(func(v): if _current_key != "": wfc_palettes[_current_key]["seamless"] = v)
	toolbar1.add_child(_chk_seamless)
	
	# --- SYMMETRY TOGGLES ---
	_chk_rotations = CheckBox.new()
	_chk_rotations.text = "Rotations"
	_chk_rotations.toggled.connect(func(v): if _current_key != "": wfc_palettes[_current_key]["rotations"] = v)
	toolbar1.add_child(_chk_rotations)
	
	_chk_reflections = CheckBox.new()
	_chk_reflections.text = "Reflections"
	_chk_reflections.toggled.connect(func(v): if _current_key != "": wfc_palettes[_current_key]["reflections"] = v)
	toolbar1.add_child(_chk_reflections)
	
	# --- TOOLBAR 2: BEHAVIOR CONFIG ---
	var toolbar2 = HBoxContainer.new()
	main_vbox.add_child(toolbar2)
	
	var lbl_fill = Label.new(); lbl_fill.text = "Unpainted Cells Act As: "
	toolbar2.add_child(lbl_fill)
	
	_opt_base_fill = OptionButton.new()
	_opt_base_fill.add_item("Empty (Causes Errors)", 0)
	_opt_base_fill.add_item("Generic Biome Floor", 1)
	_opt_base_fill.add_item("Biome Boundary (Wall)", 2)
	_opt_base_fill.item_selected.connect(func(idx): 
		if _current_key != "": 
			wfc_palettes[_current_key]["base_fill"] = idx
			painter.canvas.queue_redraw()
	)
	toolbar2.add_child(_opt_base_fill)
	toolbar2.add_child(VSeparator.new())
	
	var lbl_fall = Label.new(); lbl_fall.text = "Contradiction Fallback:"
	toolbar2.add_child(lbl_fall)
	
	_opt_fallback_mode = OptionButton.new()
	_opt_fallback_mode.add_item("Revert to Generic Biome Floor", 0)
	_opt_fallback_mode.add_item("Fill with Exact Tile", 1)
	_opt_fallback_mode.item_selected.connect(_on_fallback_mode_changed)
	toolbar2.add_child(_opt_fallback_mode)
	
	_btn_fallback_atlas = Button.new()
	_btn_fallback_atlas.text = "Pick Fallback Tile [0, 0]"
	_btn_fallback_atlas.pressed.connect(func(): _picking_mode = 1; _picker_window.popup_centered())
	toolbar2.add_child(_btn_fallback_atlas)
	
	# --- SPLIT LAYOUT (Left = Sample, Right = Preview) ---
	var split = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(split)
	
	# === LEFT PANEL: THE SAMPLE EDITOR ===
	var left_panel = VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left_panel)
	
	var sample_toolbar = HBoxContainer.new()
	left_panel.add_child(sample_toolbar)
	
	var lbl_w = Label.new(); lbl_w.text = "W:"
	_width_spin = SpinBox.new(); _width_spin.min_value = 5; _width_spin.max_value = 50; _width_spin.value = 10
	_width_spin.value_changed.connect(func(v): _update_grid_size())
	
	var lbl_h = Label.new(); lbl_h.text = "H:"
	_height_spin = SpinBox.new(); _height_spin.min_value = 5; _height_spin.max_value = 50; _height_spin.value = 10
	_height_spin.value_changed.connect(func(v): _update_grid_size())
	
	sample_toolbar.add_child(lbl_w); sample_toolbar.add_child(_width_spin)
	sample_toolbar.add_child(lbl_h); sample_toolbar.add_child(_height_spin)
	sample_toolbar.add_child(VSeparator.new())
	
	# --- LEFT TOOL DROPDOWN ---
	var lbl_tool1 = Label.new(); lbl_tool1.text = "Tool:"
	sample_toolbar.add_child(lbl_tool1)
	
	_tool_dropdown = OptionButton.new()
	_tool_dropdown.add_item("Pen", 0)
	_tool_dropdown.add_item("Fill", 1)
	_tool_dropdown.item_selected.connect(func(idx): 
		_active_tool = idx
		painter.highlighted_cells.clear() # Clear when swapping
		painter.canvas.queue_redraw()
	)
	sample_toolbar.add_child(_tool_dropdown)
	
	sample_toolbar.add_child(VSeparator.new())
	
	_brush_dropdown = OptionButton.new()
	_brush_dropdown.add_item("Exact Atlas Tile", Brush.EXACT_TILE)
	_brush_dropdown.add_item("Generic Biome Floor", Brush.GENERIC_FLOOR)
	_brush_dropdown.add_item("Generic Biome Wall (Constraint)", Brush.GENERIC_WALL)
	_brush_dropdown.item_selected.connect(func(idx): 
		_active_brush = _brush_dropdown.get_item_id(idx) as Brush
		_btn_atlas_picker.visible = (_active_brush == Brush.EXACT_TILE)
	)
	sample_toolbar.add_child(_brush_dropdown)
	
	_btn_atlas_picker = Button.new()
	_btn_atlas_picker.text = "Pick Atlas Tile [0, 0]"
	_btn_atlas_picker.pressed.connect(func(): _picking_mode = 0; _picker_window.popup_centered())
	sample_toolbar.add_child(_btn_atlas_picker)
	
	painter = GridCanvasPainter.new()
	painter.origin_mode = GridCanvasPainter.OriginMode.TOP_LEFT
	left_panel.add_child(painter)
	painter.cell_painted.connect(_on_cell_painted)
	painter.cell_hovered.connect(_on_sample_cell_hovered)
	painter.canvas.draw.connect(_on_canvas_draw)
	
	# === RIGHT PANEL: THE LIVE PREVIEW ===
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right_panel)
	
	var preview_toolbar = HBoxContainer.new()
	right_panel.add_child(preview_toolbar)
	
	var btn_gen = Button.new()
	btn_gen.text = "★ Test Generate Preview ★"
	btn_gen.add_theme_color_override("font_color", Color(1.0, 0.8, 0.0))
	btn_gen.pressed.connect(_on_generate_preview)
	preview_toolbar.add_child(btn_gen)
	
	# --- PREVIEW SHAPE SELECTOR ---
	_opt_preview_shape = OptionButton.new()
	_opt_preview_shape.add_item("Square Room", 0)
	_opt_preview_shape.add_item("Narrow Corridor", 1)
	_opt_preview_shape.add_item("L-Shape (Inner Corner)", 2)
	preview_toolbar.add_child(_opt_preview_shape)
	
	preview_toolbar.add_child(VSeparator.new())
	
	var lbl_ps = Label.new(); lbl_ps.text = "Grid Size:"
	_preview_size_spin = SpinBox.new()
	_preview_size_spin.min_value = 5; _preview_size_spin.max_value = 30; _preview_size_spin.value = 15
	preview_toolbar.add_child(lbl_ps); preview_toolbar.add_child(_preview_size_spin)
	
	# --- INTERACTIVE PREVIEW TOOLS ---
	var preview_tools = HBoxContainer.new()
	right_panel.add_child(preview_tools)
	
	# --- RIGHT TOOL DROPDOWN ---
	var lbl_tool2 = Label.new(); lbl_tool2.text = "Tool:"
	preview_tools.add_child(lbl_tool2)
	
	_preview_tool_dropdown = OptionButton.new()
	_preview_tool_dropdown.add_item("Pen", 0)
	_preview_tool_dropdown.add_item("Fill", 1)
	_preview_tool_dropdown.item_selected.connect(func(idx): 
		_active_preview_tool = idx
		preview_painter.highlighted_cells.clear() # Clear when swapping
		preview_painter.canvas.queue_redraw()
	)
	preview_tools.add_child(_preview_tool_dropdown)
	
	preview_tools.add_child(VSeparator.new())
	
	var lbl_pb = Label.new(); lbl_pb.text = "Preview Brush:"
	preview_tools.add_child(lbl_pb)
	
	_preview_brush_dropdown = OptionButton.new()
	_preview_brush_dropdown.add_item("None (View Only)", 0)
	_preview_brush_dropdown.add_item("Fixed Exact Tile", 1)
	_preview_brush_dropdown.add_item("Fixed Wall", 2)
	_preview_brush_dropdown.item_selected.connect(func(idx): _active_preview_brush = idx)
	preview_tools.add_child(_preview_brush_dropdown)
	
	var btn_clear_preview = Button.new()
	btn_clear_preview.text = "Clear Fixed Tiles"
	btn_clear_preview.pressed.connect(func(): 
		_preview_fixed_grid.clear()
		preview_painter.canvas.queue_redraw()
	)
	preview_tools.add_child(btn_clear_preview)
	
	preview_tools.add_child(VSeparator.new())
	
	_chk_highlight_fixed = CheckBox.new()
	_chk_highlight_fixed.text = "Highlight Fixed Tiles"
	_chk_highlight_fixed.button_pressed = true
	_chk_highlight_fixed.toggled.connect(func(v): preview_painter.canvas.queue_redraw())
	preview_tools.add_child(_chk_highlight_fixed)
	
	# --- [UPDATED] PREVIEW PAINTER CONNECTIONS ---
	preview_painter = GridCanvasPainter.new()
	preview_painter.origin_mode = GridCanvasPainter.OriginMode.TOP_LEFT
	preview_painter.grid_bounds = Vector2i(15, 15)
	right_panel.add_child(preview_painter)
	
	preview_painter.cell_painted.connect(_on_preview_cell_painted)
	preview_painter.cell_hovered.connect(_on_preview_cell_hovered)
	preview_painter.canvas.draw.connect(_on_preview_canvas_draw)
	
	
	
	# --- VISUAL TILE PICKER POPUP ---
	_picker_window = Window.new()
	_picker_window.title = "Pick Atlas Tile"
	_picker_window.min_size = Vector2i(500, 500)
	_picker_window.exclusive = true
	_picker_window.transient = true # Fixes the dropdown deadlock
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
	preview_painter.tile_size = float(tile_size.x)
	_preview_grid.clear()
	
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
		"seamless": false,    
		"wall_aware": true,
		"rotations": false,   
		"reflections": false, 
		"base_fill": 1,       
		"fallback_mode": 0,
		"fallback_atlas": Vector2i.ZERO,
		"sample_grid": {} 
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
	
	_chk_wall_aware.set_pressed_no_signal(p.get("wall_aware", true))
	_chk_seamless.set_pressed_no_signal(p.get("seamless", false))
	_chk_rotations.set_pressed_no_signal(p.get("rotations", false))
	_chk_reflections.set_pressed_no_signal(p.get("reflections", false))
	_opt_base_fill.selected = p.get("base_fill", 1)
	
	_opt_fallback_mode.selected = p.get("fallback_mode", 0)
	var f_atlas = p.get("fallback_atlas", Vector2i.ZERO)
	_btn_fallback_atlas.text = "Pick Fallback Tile [%d, %d]" % [f_atlas.x, f_atlas.y]
	_btn_fallback_atlas.visible = (_opt_fallback_mode.selected == 1)
	
	painter.grid_bounds = Vector2i(p.get("width", 10), p.get("height", 10))
	painter.canvas.queue_redraw()
	
	_preview_grid.clear()
	preview_painter.canvas.queue_redraw()

func _on_fallback_mode_changed(idx: int) -> void:
	if _current_key == "" or not wfc_palettes.has(_current_key): return
	wfc_palettes[_current_key]["fallback_mode"] = idx
	_btn_fallback_atlas.visible = (idx == 1)

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
		var picked = Vector2i(ax, ay)
		
		if _picking_mode == 0:
			_active_atlas_brush = picked
			_btn_atlas_picker.text = "Pick Atlas Tile [%d, %d]" % [ax, ay]
		else:
			if _current_key != "" and wfc_palettes.has(_current_key):
				wfc_palettes[_current_key]["fallback_atlas"] = picked
				_btn_fallback_atlas.text = "Pick Fallback Tile [%d, %d]" % [ax, ay]
				
		_picker_window.hide()

# --- LEFT PANEL HOVER ---
func _on_sample_cell_hovered(pos: Vector2i) -> void:
	if _current_key == "" or not wfc_palettes.has(_current_key): return
	var p = wfc_palettes[_current_key]
	var bounds_w = p.get("width", 10)
	var bounds_h = p.get("height", 10)
	
	if pos.x < 0 or pos.y < 0 or pos.x >= bounds_w or pos.y >= bounds_h:
		painter.highlighted_cells.clear()
	else:
		if _active_tool == 1: # Fill Tool
			painter.highlighted_cells = painter.get_flood_fill_area(p["sample_grid"], pos)
		else: # Pen Tool
			painter.highlighted_cells = [pos]
			
	painter.canvas.queue_redraw()

# --- RIGHT PANEL HOVER ---
func _on_preview_cell_hovered(pos: Vector2i) -> void:
	var p_size = int(_preview_size_spin.value)
	if _active_preview_brush == 0 or pos.x < 0 or pos.y < 0 or pos.x >= p_size or pos.y >= p_size:
		preview_painter.highlighted_cells.clear()
	else:
		if _active_preview_tool == 1: # Fill Tool
			preview_painter.highlighted_cells = preview_painter.get_flood_fill_area(_preview_fixed_grid, pos)
		else: # Pen Tool
			preview_painter.highlighted_cells = [pos]
			
	preview_painter.canvas.queue_redraw()

# --- LEFT PANEL PAINTING ---
func _on_cell_painted(pos: Vector2i, erase: bool, is_drag: bool) -> void:
	if _current_key == "" or not wfc_palettes.has(_current_key): return
	var p = wfc_palettes[_current_key]
	
	var val = null
	if not erase:
		if _active_brush == Brush.GENERIC_FLOOR: val = WFCPatternExtractor.CELL_GENERIC_FLOOR
		elif _active_brush == Brush.GENERIC_WALL: val = WFCPatternExtractor.CELL_BOUNDARY
		else: val = _active_atlas_brush
			
	if _active_tool == 1: 
		if not is_drag: # Only fill on the initial click
			painter.perform_flood_fill(p["sample_grid"], pos, erase, val)
	else:
		if erase: p["sample_grid"].erase(pos)
		else: p["sample_grid"][pos] = val
		painter.canvas.queue_redraw()

func _on_canvas_draw() -> void:
	if _current_key == "" or not wfc_palettes.has(_current_key) or not _tileset_tex: return
	var p = wfc_palettes[_current_key]
	var grid = p.get("sample_grid", {})
	
	# Draw Faint Base Fill Background
	var base_idx = p.get("base_fill", 1)
	var fill_color = Color(0, 0, 0, 0)
	if base_idx == 1: fill_color = Color(0.2, 0.5, 0.3, 0.2) 
	elif base_idx == 2: fill_color = Color(0.4, 0.4, 0.4, 0.2) 
	
	if fill_color.a > 0:
		for y in range(p.get("height", 10)):
			for x in range(p.get("width", 10)):
				var pos = Vector2i(x, y)
				if not grid.has(pos):
					painter.draw_cell_rect(pos, fill_color, Color(0,0,0,0), 0)
	
	for pos in grid:
		var val = grid[pos]
		if typeof(val) == TYPE_VECTOR2I and val == WFCPatternExtractor.CELL_BOUNDARY:
			painter.draw_cell_rect(pos, Color(0.4, 0.4, 0.4, 0.8), Color.BLACK, 1.0)
		elif typeof(val) == TYPE_VECTOR2I and val == WFCPatternExtractor.CELL_GENERIC_FLOOR:
			painter.draw_cell_rect(pos, Color(0.2, 0.5, 0.3, 0.8), Color.BLACK, 1.0)
		else:
			painter.draw_atlas_cell(pos, _tileset_tex, val, _tile_size)
	painter.draw_highlights()

# ==============================================================================
# LIVE PREVIEW ENGINE
# ==============================================================================
func _on_generate_preview() -> void:
	if _current_key == "" or not wfc_palettes.has(_current_key): return
	var p = wfc_palettes[_current_key]
	
	var n_size = p.get("n_size", 3)
	var wall_aware = p.get("wall_aware", true)
	var is_seamless = p.get("seamless", false)
	var allow_rots = p.get("rotations", false)
	var allow_refs = p.get("reflections", false)
	var base_fill = p.get("base_fill", 1)
	
	var p_size = int(_preview_size_spin.value)
	preview_painter.grid_bounds = Vector2i(p_size, p_size)
	
	# 1. Math Extraction
	var modules = WFCPatternExtractor.extract(
		p.get("sample_grid", {}), 
		p.get("width", 10), p.get("height", 10), 
		n_size, is_seamless, base_fill, allow_rots, allow_refs
	)
	
	var sockets = []
	var fixed_pixels = {}
	var target_shape = _opt_preview_shape.selected
	var valid_targets = {}
	
	# 1. Carve the specific test shape!
	for y in range(p_size):
		for x in range(p_size):
			var pos = Vector2i(x, y)
			var is_valid = false
			
			if target_shape == 0: # Square Room
				if x > 0 and x < p_size - 1 and y > 0 and y < p_size - 1: is_valid = true
			elif target_shape == 1: # Narrow Corridor
				if x > 0 and x < p_size - 1 and y >= p_size/2 - 1 and y <= p_size/2: is_valid = true
			elif target_shape == 2: # L-Shape (Tests sharp inner corners)
				if x > 0 and x < p_size - 1 and y > 0 and y < p_size - 1:
					if x < p_size/2 or y < p_size/2: is_valid = true
					
			if is_valid: valid_targets[pos] = true
			
	# 2. Expand sockets to lock the walls
	var expanded_sockets = {}
	
	# Step A: Collect all sockets that overlap our valid floor
	for pos in valid_targets:
		for dy in range(-n_size + 1, 1):
			for dx in range(-n_size + 1, 1):
				expanded_sockets[pos + Vector2i(dx, dy)] = true
				
	# Step B: Scan every pixel inside those sockets.
	if wall_aware:
		for s_pos in expanded_sockets:
			for dy in range(n_size):
				for dx in range(n_size):
					var world_pt = s_pos + Vector2i(dx, dy)
					if not valid_targets.has(world_pt):
						fixed_pixels[world_pt] = WFCPatternExtractor.CELL_BOUNDARY
						
	sockets = expanded_sockets.keys()
	
	# --- INJECT USER FIXED CONSTRAINTS ---
	for pos in _preview_fixed_grid:
		fixed_pixels[pos] = _preview_fixed_grid[pos]
	
	# 3. Resolve the Wave Function
	var rng = RandomNumberGenerator.new()
	rng.seed = _preview_seed
	_preview_seed += 1 
	
	var payload = WFCSolver.resolve(sockets, rng, modules, 1, fixed_pixels)
	
	# 4. Parse Results
	_preview_grid.clear()
	if payload.is_empty():
		for pos in sockets: _preview_grid[pos] = Vector2i(-99, -99)
	else:
		if payload.has("exact_floors"):
			for pt in payload["exact_floors"]:
				if valid_targets.has(pt): # Only draw the interior floor
					_preview_grid[pt] = payload["exact_floors"][pt]
				
	preview_painter.canvas.queue_redraw()

# --- RIGHT PANEL (PREVIEW) PAINTING ---
func _on_preview_cell_painted(pos: Vector2i, erase: bool, is_drag: bool) -> void:
	if _active_preview_brush == 0: return # View Only mode
	var p_size = int(_preview_size_spin.value)
	if pos.x < 0 or pos.y < 0 or pos.x >= p_size or pos.y >= p_size: return 
	
	var val = null
	if not erase:
		if _active_preview_brush == 1: val = _active_atlas_brush
		elif _active_preview_brush == 2: val = WFCPatternExtractor.CELL_BOUNDARY
		
	if _active_preview_tool == 1: 
		if not is_drag:
			preview_painter.perform_flood_fill(_preview_fixed_grid, pos, erase, val)
	else:
		if erase: _preview_fixed_grid.erase(pos)
		else: _preview_fixed_grid[pos] = val
		preview_painter.canvas.queue_redraw()

# --- [UPDATED] PREVIEW DRAWING ---
func _on_preview_canvas_draw() -> void:
	if not _tileset_tex: return
	
	# 1. Draw Generated Grid
	for pos in _preview_grid:
		var val = _preview_grid[pos]
		if val == Vector2i(-99, -99):
			preview_painter.draw_cell_rect(pos, Color(1, 0, 0, 0.8), Color.BLACK, 1.0)
		elif val == WFCPatternExtractor.CELL_BOUNDARY:
			preview_painter.draw_cell_rect(pos, Color(0.4, 0.4, 0.4, 0.8), Color.BLACK, 1.0)
		elif val == WFCPatternExtractor.CELL_GENERIC_FLOOR:
			preview_painter.draw_cell_rect(pos, Color(0.2, 0.5, 0.3, 0.8), Color.BLACK, 1.0)
		elif val.x >= 0 and val.y >= 0:
			preview_painter.draw_atlas_cell(pos, _tileset_tex, val, _tile_size)
			
	# 2. Draw Fixed Constraints (overwriting generated tiles for visual clarity)
	for pos in _preview_fixed_grid:
		var val = _preview_fixed_grid[pos]
		if val == WFCPatternExtractor.CELL_BOUNDARY:
			preview_painter.draw_cell_rect(pos, Color(0.4, 0.4, 0.4, 0.8), Color.BLACK, 1.0)
		else:
			preview_painter.draw_atlas_cell(pos, _tileset_tex, val, _tile_size)
			
	# 3. Draw Highlights
	if _chk_highlight_fixed.button_pressed:
		for pos in _preview_fixed_grid:
			# Draw a bright cyan outline so you know exactly which tiles are locked
			preview_painter.draw_cell_rect(pos, Color(0, 1, 1, 0.2), Color.CYAN, 2.0)
	
	preview_painter.draw_highlights()

# ==============================================================================
# SAVE / CLOSE
# ==============================================================================
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
