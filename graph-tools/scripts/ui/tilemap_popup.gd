class_name TileMappingPopup
extends AcceptDialog

# --- DATA ---
var atlas_texture: ImageTexture
var atlas_texture_path: String = "" 
var tile_size: Vector2i = Vector2i(16, 16)
var mappings: Dictionary = {} # Maps category_key (String) -> Atlas Coords (Vector2i)

# --- IN-MEMORY PAINTING STATE ---
var _active_image: Image
var _current_mode: int = 0 # 0 = Map, 1 = Paint

# --- UI REFS ---
var item_list: ItemList
var texture_rect: TextureRect
var overlay: Control
var file_dialog: FileDialog 
var save_dialog: FileDialog
var spin_w: SpinBox 
var spin_h: SpinBox 
var zoom_label: Label
var paint_toolbar: HBoxContainer
var opt_color_source: OptionButton
var color_picker: ColorPickerButton
var chk_procedural: CheckBox
var palette_editor: CosinePaletteEditor
var scroll_atlas: ScrollContainer # Wrap texture_rect's parent so we can hide it

var procedural_flags: Dictionary = {} # Maps base biome key -> bool
var palette_params: Dictionary = {} 



# --- STATE ---
var selected_category: String = ""
var semantic_keys: Array[String] = []
var zoom_level: float = 1.0



func _init() -> void:
	title = "Visual Tile Mapper & Painter"
	size = Vector2i(850, 600)
	
	var vbox_main = VBoxContainer.new()
	vbox_main.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox_main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox_main)
	
	# ==========================================================================
	# TOP BAR: FILE & CONFIG
	# ==========================================================================
	var top_bar = HBoxContainer.new()
	vbox_main.add_child(top_bar)
	
	var btn_load = Button.new()
	btn_load.text = "Load Image..."
	btn_load.pressed.connect(_on_load_image_pressed)
	top_bar.add_child(btn_load)
	
	var btn_new = Button.new()
	btn_new.text = "New Blank Image"
	btn_new.pressed.connect(_on_new_blank_pressed)
	top_bar.add_child(btn_new)
	
	top_bar.add_child(VSeparator.new())
	
	var lbl_w = Label.new()
	lbl_w.text = "Tile W:"
	top_bar.add_child(lbl_w)
	
	spin_w = SpinBox.new()
	spin_w.min_value = 4
	spin_w.max_value = 256
	spin_w.value = 16
	spin_w.value_changed.connect(func(v): tile_size.x = int(v); overlay.queue_redraw())
	top_bar.add_child(spin_w)
	
	var lbl_h = Label.new()
	lbl_h.text = "H:"
	top_bar.add_child(lbl_h)
	
	spin_h = SpinBox.new()
	spin_h.min_value = 4
	spin_h.max_value = 256
	spin_h.value = 16
	spin_h.value_changed.connect(func(v): tile_size.y = int(v); overlay.queue_redraw())
	top_bar.add_child(spin_h)
	
	top_bar.add_child(VSeparator.new())
	
	var btn_zoom_out = Button.new()
	btn_zoom_out.text = " - "
	btn_zoom_out.pressed.connect(func(): _set_zoom(zoom_level - 0.25))
	top_bar.add_child(btn_zoom_out)
	
	zoom_label = Label.new()
	zoom_label.text = "100%"
	zoom_label.custom_minimum_size.x = 45
	zoom_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_bar.add_child(zoom_label)
	
	var btn_zoom_in = Button.new()
	btn_zoom_in.text = " + "
	btn_zoom_in.pressed.connect(func(): _set_zoom(zoom_level + 0.25))
	top_bar.add_child(btn_zoom_in)
	
	top_bar.add_child(VSeparator.new())
	
	var opt_mode = OptionButton.new()
	opt_mode.add_item("Mode: Map Semantics", 0)
	opt_mode.add_item("Mode: Paint Tiles", 1)
	opt_mode.add_item("Mode: Procedural Palette", 2) 
	opt_mode.item_selected.connect(_on_mode_changed)
	top_bar.add_child(opt_mode)
	
	

	vbox_main.add_child(HSeparator.new())
	
	# ==========================================================================
	# MAIN SPLIT VIEW
	# ==========================================================================
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox_main.add_child(hbox)
	
	# --- LEFT: CATEGORY LIST ---
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size.x = 220
	hbox.add_child(left_panel)
	
	var lbl = Label.new()
	lbl.text = "Semantic Types"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(lbl)
	
	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.item_selected.connect(_on_category_selected)
	left_panel.add_child(item_list)
	
	chk_procedural = CheckBox.new()
	chk_procedural.text = "Use Procedural Color"
	chk_procedural.tooltip_text = "Overrides this biome's tile colors with the mathematical Cosine palette."
	chk_procedural.toggled.connect(_on_procedural_toggled)
	left_panel.add_child(chk_procedural)
	
	# --- RIGHT: ATLAS VIEWER & PAINT TOOLS ---
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(right_panel)
	
	# Paint Toolbar (Hidden by default)
	paint_toolbar = HBoxContainer.new()
	paint_toolbar.visible = false
	right_panel.add_child(paint_toolbar)
	
	opt_color_source = OptionButton.new()
	opt_color_source.add_item("Use Semantic Color")
	opt_color_source.add_item("Use Custom Color")
	opt_color_source.item_selected.connect(func(idx): color_picker.visible = (idx == 1))
	paint_toolbar.add_child(opt_color_source)
	
	color_picker = ColorPickerButton.new()
	color_picker.custom_minimum_size.x = 40
	color_picker.color = Color.WHITE
	color_picker.visible = false
	paint_toolbar.add_child(color_picker)
	
	paint_toolbar.add_child(VSeparator.new())
	
	var btn_exp_x = Button.new()
	btn_exp_x.text = "Add Col [+]"
	btn_exp_x.pressed.connect(func(): _expand_image(1, 0))
	paint_toolbar.add_child(btn_exp_x)
	
	var btn_exp_y = Button.new()
	btn_exp_y.text = "Add Row [+]"
	btn_exp_y.pressed.connect(func(): _expand_image(0, 1))
	paint_toolbar.add_child(btn_exp_y)
	
	# Spacer to push Save to the right
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paint_toolbar.add_child(spacer)
	
	var btn_save = Button.new()
	btn_save.text = "💾 Save PNG"
	btn_save.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	btn_save.pressed.connect(_on_save_image_pressed)
	paint_toolbar.add_child(btn_save)
	
	# Image Scroller
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(scroll)
	
	texture_rect = TextureRect.new()
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE # Allows us to override the size
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED # Keeps proportions
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # Keeps pixel art crisp!
	texture_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(texture_rect)
	
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.add_child(overlay)
	
	overlay.draw.connect(_on_overlay_draw)
	texture_rect.gui_input.connect(_on_texture_gui_input)
	
	scroll_atlas = ScrollContainer.new() # [NEW] Name the scroll container!
	scroll_atlas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(scroll_atlas)
	
	palette_editor = CosinePaletteEditor.new()
	palette_editor.visible = false
	right_panel.add_child(palette_editor)
	
	# Change texture_rect's parent from `scroll` to `scroll_atlas`:
	# scroll_atlas.add_child(texture_rect)
	
	# --- DIALOGS ---
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.png, *.jpg, *.jpeg ; Image Files"]
	file_dialog.file_selected.connect(_on_file_selected)
	add_child(file_dialog)
	
	save_dialog = FileDialog.new()
	save_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	save_dialog.access = FileDialog.ACCESS_FILESYSTEM
	save_dialog.filters = ["*.png ; PNG Image"]
	save_dialog.file_selected.connect(_on_save_file_confirmed)
	add_child(save_dialog)

# ==============================================================================
# DATA LIFECYCLE
# ==============================================================================

func open(texture_path: String, t_size: Vector2i, default_mappings: Dictionary, default_flags: Dictionary, default_palette: Dictionary) -> void:
	mappings = default_mappings.duplicate()
	tile_size = t_size
	atlas_texture_path = texture_path
	
	spin_w.set_value_no_signal(tile_size.x)
	spin_h.set_value_no_signal(tile_size.y)
	
	# 1. Load the file into VOLATILE MEMORY
	if atlas_texture_path != "" and FileAccess.file_exists(atlas_texture_path):
		_active_image = Image.load_from_file(atlas_texture_path)
		if _active_image:
			if _active_image.get_format() != Image.FORMAT_RGBA8:
				_active_image.convert(Image.FORMAT_RGBA8)
			atlas_texture = ImageTexture.create_from_image(_active_image)
			texture_rect.texture = atlas_texture
			
	# 2. Populate Semantic Categories
	item_list.clear()
	semantic_keys.clear()
	
	_add_category_item("default_floor", "Default Floor", Color.LIGHT_GRAY)
	_add_category_item("default_wall", "Default Wall", Color.DARK_GRAY)
	
	var node_cats = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE]
	for key in node_cats:
		var cat_name = node_cats[key]["name"]
		var base_color = node_cats[key]["color"]
		_add_category_item(key + "_floor", cat_name + " (Floor)", base_color)
		_add_category_item(key + "_wall", cat_name + " (Wall)", base_color.darkened(0.3))
		
	if item_list.item_count > 0:
		item_list.select(0)
		_on_category_selected(0)
	
	procedural_flags = default_flags.duplicate()
	if not default_palette.is_empty():
		palette_editor.params = default_palette.duplicate()
		palette_editor._sync_ui_to_params()
	
	_set_zoom(zoom_level)
	popup_centered()

func _on_mode_changed(idx: int) -> void:
	_current_mode = idx
	paint_toolbar.visible = (idx == 1)
	scroll_atlas.visible = (idx == 0 or idx == 1)
	palette_editor.visible = (idx == 2)
	overlay.queue_redraw()

func _set_zoom(new_zoom: float) -> void:
	zoom_level = clamp(new_zoom, 0.5, 5.0) # Restrict from 50% to 500%
	zoom_label.text = str(int(zoom_level * 100)) + "%"
	
	if atlas_texture:
		var new_size = atlas_texture.get_size() * zoom_level
		texture_rect.custom_minimum_size = new_size
		
	overlay.queue_redraw()

# ==============================================================================
# FILE MANAGEMENT
# ==============================================================================

func _on_load_image_pressed() -> void:
	file_dialog.popup_centered_ratio(0.7)

func _on_file_selected(path: String) -> void:
	_active_image = Image.load_from_file(path)
	if _active_image:
		if _active_image.get_format() != Image.FORMAT_RGBA8:
			_active_image.convert(Image.FORMAT_RGBA8)
			
		atlas_texture_path = path
		atlas_texture = ImageTexture.create_from_image(_active_image)
		texture_rect.texture = atlas_texture
		_set_zoom(zoom_level)
		overlay.queue_redraw()

func _on_new_blank_pressed() -> void:
	# Create a tiny 1x1 grid image to start
	_active_image = Image.create(tile_size.x, tile_size.y, false, Image.FORMAT_RGBA8)
	atlas_texture = ImageTexture.create_from_image(_active_image)
	texture_rect.texture = atlas_texture
	atlas_texture_path = "" 
	_set_zoom(zoom_level)
	overlay.queue_redraw()

func _on_save_image_pressed() -> void:
	if not _active_image: return
	if atlas_texture_path == "":
		save_dialog.popup_centered_ratio(0.7)
	else:
		_on_save_file_confirmed(atlas_texture_path)

func _on_save_file_confirmed(path: String) -> void:
	if _active_image:
		var err = _active_image.save_png(path)
		if err == OK:
			atlas_texture_path = path
			print("Tilemap Image Saved to: ", path)
		else:
			push_error("Failed to save Image to path: " + path)

func _expand_image(add_x: int, add_y: int) -> void:
	if not _active_image: 
		_on_new_blank_pressed()
		return
		
	var new_w = _active_image.get_width() + (add_x * tile_size.x)
	var new_h = _active_image.get_height() + (add_y * tile_size.y)
	
	var new_img = Image.create(new_w, new_h, false, Image.FORMAT_RGBA8)
	
	# Stamp the old image into the top left corner of the new larger image
	var src_rect = Rect2i(0, 0, _active_image.get_width(), _active_image.get_height())
	new_img.blit_rect(_active_image, src_rect, Vector2i.ZERO)
	
	_active_image = new_img
	atlas_texture = ImageTexture.create_from_image(_active_image)
	texture_rect.texture = atlas_texture
	_set_zoom(zoom_level)
	overlay.queue_redraw()

# ==============================================================================
# INPUT & PAINTING
# ==============================================================================

func _on_category_selected(index: int) -> void:
	selected_category = semantic_keys[index]
	var base_key = selected_category.replace("_floor", "").replace("_wall", "")
	
	# Update checkbox based on the biome's saved flag
	chk_procedural.set_pressed_no_signal(procedural_flags.get(base_key, false))
	overlay.queue_redraw()

func _on_procedural_toggled(toggled: bool) -> void:
	var base_key = selected_category.replace("_floor", "").replace("_wall", "")
	procedural_flags[base_key] = toggled

func _get_grid_coord(pos: Vector2) -> Vector2i:
	return Vector2i(int(pos.x / tile_size.x), int(pos.y / tile_size.y))

func _on_texture_gui_input(event: InputEvent) -> void:
	if not _active_image: return
	
	var is_click = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	var is_drag = event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0
	
	if is_click or is_drag:
		if selected_category == "": return
		
		# Divide the mouse position by the zoom scale!
		var raw_pos = event.position / zoom_level 
		
		# Bounds check using the scaled coordinate
		var tex_size = _active_image.get_size()
		if raw_pos.x > tex_size.x or raw_pos.y > tex_size.y: return
		
		var coord = _get_grid_coord(raw_pos)
		
		if _current_mode == 0:
			# MAP MODE (Click only)
			if is_click:
				mappings[selected_category] = coord
				overlay.queue_redraw()
				
				# Auto-advance
				var next_idx = (item_list.get_selected_items()[0] + 1) % item_list.item_count
				item_list.select(next_idx)
				_on_category_selected(next_idx)
				
		elif _current_mode == 1:
			# PAINT MODE (Click + Drag)
			_paint_cell(coord)

func _paint_cell(coord: Vector2i) -> void:
	var rect = Rect2i(coord.x * tile_size.x, coord.y * tile_size.y, tile_size.x, tile_size.y)
	
	var fill_color = Color.WHITE
	if opt_color_source.selected == 1:
		fill_color = color_picker.color
	else:
		fill_color = _get_semantic_color(selected_category)
		
	_active_image.fill_rect(rect, fill_color)
	
	# Extremely fast visual update! Does not recreate the texture resource!
	atlas_texture.update(_active_image)

func _get_semantic_color(key: String) -> Color:
	if key == "default_floor": return Color.LIGHT_GRAY
	if key == "default_wall": return Color.DARK_GRAY
	
	var node_cats = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE]
	var base_key = key.replace("_floor", "").replace("_wall", "")
	
	if node_cats.has(base_key):
		var c = node_cats[base_key]["color"]
		if key.ends_with("_wall"): return c.darkened(0.3)
		return c
		
	return Color.WHITE

# ==============================================================================
# RENDERING
# ==============================================================================

func _add_category_item(key: String, display_name: String, color: Color) -> void:
	semantic_keys.append(key)
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex = ImageTexture.create_from_image(img)
	item_list.add_item(display_name, tex)

func _on_overlay_draw() -> void:
	if not _active_image: return
	var tex_size = _active_image.get_size()
	
	# 1. Draw Grid (Scaled)
	var grid_color = Color(1, 1, 1, 0.2)
	for x in range(0, int(tex_size.x) + 1, tile_size.x):
		var px = x * zoom_level
		overlay.draw_line(Vector2(px, 0), Vector2(px, tex_size.y * zoom_level), grid_color, 1.0)
	for y in range(0, int(tex_size.y) + 1, tile_size.y):
		var py = y * zoom_level
		overlay.draw_line(Vector2(0, py), Vector2(tex_size.x * zoom_level, py), grid_color, 1.0)
		
	# 2. Draw Assigned Highlights (ONLY IN MAP MODE)
	if _current_mode == 0:
		for key in mappings:
			var coord = mappings[key]
			# Multiply position and size by zoom_level
			var rect = Rect2(coord.x * tile_size.x * zoom_level, coord.y * tile_size.y * zoom_level, tile_size.x * zoom_level, tile_size.y * zoom_level)
			
			var outline_color = _get_semantic_color(key)
			
			var thickness = 3.0 if key == selected_category else 1.0
			if key == selected_category:
				overlay.draw_rect(rect, Color(outline_color, 0.4), true)
				
			overlay.draw_rect(rect, outline_color, false, thickness)
