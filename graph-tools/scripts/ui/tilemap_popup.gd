class_name TileMappingPopup
extends AcceptDialog

# Data
var tile_set: TileSet
var atlas_texture: Texture2D
var tile_size: Vector2i = Vector2i(16, 16)
var mappings: Dictionary = {} # Maps category_key (String) -> Atlas Coords (Vector2i)

# State
var selected_category: String = ""
var semantic_keys: Array[String] = []

# UI Refs
var item_list: ItemList
var texture_rect: TextureRect
var overlay: Control

func _init() -> void:
	title = "Visual Tile Mapper"
	size = Vector2i(700, 500)
	
	var hbox = HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(hbox)
	
	# --- LEFT: CATEGORY LIST ---
	var left_panel = VBoxContainer.new()
	left_panel.custom_minimum_size.x = 200
	hbox.add_child(left_panel)
	
	var lbl = Label.new()
	lbl.text = "Semantic Types"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_panel.add_child(lbl)
	
	item_list = ItemList.new()
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.item_selected.connect(_on_category_selected)
	left_panel.add_child(item_list)
	
	# --- RIGHT: ATLAS VIEWER ---
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(right_panel)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.add_child(scroll)
	
	texture_rect = TextureRect.new()
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP
	texture_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_child(texture_rect)
	
	# Overlay for drawing the grid and highlights
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.add_child(overlay)
	
	overlay.draw.connect(_on_overlay_draw)
	texture_rect.gui_input.connect(_on_texture_gui_input)

func open(p_tile_set: TileSet, default_mappings: Dictionary) -> void:
	tile_set = p_tile_set
	mappings = default_mappings.duplicate()
	
	# 1. Extract Texture and Size from the Godot TileSet
	if tile_set and tile_set.get_source_count() > 0:
		tile_size = tile_set.tile_size
		var source = tile_set.get_source(tile_set.get_source_id(0))
		if source is TileSetAtlasSource:
			atlas_texture = source.texture
			texture_rect.texture = atlas_texture
			
	# 2. Populate Semantic Categories (Floors AND Walls!)
	item_list.clear()
	semantic_keys.clear()
	
	# Always include default Floor and Wall
	_add_category_item("default_floor", "Default Floor", Color.LIGHT_GRAY)
	_add_category_item("default_wall", "Default Wall", Color.DARK_GRAY)
	
	# Fetch all custom node types from the registry
	var node_cats = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE]
	for key in node_cats:
		var cat_name = node_cats[key]["name"]
		var base_color = node_cats[key]["color"]
		
		# Add a Floor entry (Uses base color)
		_add_category_item(key + "_floor", cat_name + " (Floor)", base_color)
		
		# Add a Wall entry (Darkens the color slightly so it looks like a wall in the UI)
		_add_category_item(key + "_wall", cat_name + " (Wall)", base_color.darkened(0.3))
		
	if item_list.item_count > 0:
		item_list.select(0)
		_on_category_selected(0)
		
	popup_centered()

func _add_category_item(key: String, display_name: String, color: Color) -> void:
	semantic_keys.append(key)
	
	# Create a tiny color square for the icon
	var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(color)
	var tex = ImageTexture.create_from_image(img)
	
	item_list.add_item(display_name, tex)

func _on_category_selected(index: int) -> void:
	selected_category = semantic_keys[index]
	overlay.queue_redraw()

func _on_texture_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if selected_category == "" or not atlas_texture: return
		
		# Convert mouse pixel position to grid coordinates
		var grid_x = int(event.position.x / tile_size.x)
		var grid_y = int(event.position.y / tile_size.y)
		var clicked_coord = Vector2i(grid_x, grid_y)
		
		# Bounds check
		var tex_size = atlas_texture.get_size()
		if event.position.x > tex_size.x or event.position.y > tex_size.y: return
		
		mappings[selected_category] = clicked_coord
		overlay.queue_redraw()
		
		# Auto-advance to the next item to make mapping very fast!
		var next_idx = (item_list.get_selected_items()[0] + 1) % item_list.item_count
		item_list.select(next_idx)
		_on_category_selected(next_idx)

func _on_overlay_draw() -> void:
	if not atlas_texture: return
	var tex_size = atlas_texture.get_size()
	
	# 1. Draw Grid
	var grid_color = Color(1, 1, 1, 0.2)
	for x in range(0, int(tex_size.x) + 1, tile_size.x):
		overlay.draw_line(Vector2(x, 0), Vector2(x, tex_size.y), grid_color, 1.0)
	for y in range(0, int(tex_size.y) + 1, tile_size.y):
		overlay.draw_line(Vector2(0, y), Vector2(tex_size.x, y), grid_color, 1.0)
		
	# 2. Draw Assigned Highlights
	var node_cats = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE]
	
	for key in mappings:
		var coord = mappings[key]
		var rect = Rect2(coord.x * tile_size.x, coord.y * tile_size.y, tile_size.x, tile_size.y)
		
		var outline_color = Color.WHITE
		if key == "default_floor": outline_color = Color.LIGHT_GRAY
		elif key == "default_wall": outline_color = Color.DARK_GRAY
		else:
			# Extract the base category key (e.g. "scp_heavy" from "scp_heavy_wall")
			var base_key = key.replace("_floor", "").replace("_wall", "")
			if node_cats.has(base_key):
				outline_color = node_cats[base_key]["color"]
				if key.ends_with("_wall"): outline_color = outline_color.darkened(0.3)
		
		# Thick border for the currently selected category, thin for others
		var thickness = 3.0 if key == selected_category else 1.0
		if key == selected_category:
			overlay.draw_rect(rect, Color(outline_color, 0.4), true)
			
		overlay.draw_rect(rect, outline_color, false, thickness)
