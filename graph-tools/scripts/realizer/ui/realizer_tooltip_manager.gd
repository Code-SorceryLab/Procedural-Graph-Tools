class_name RealizerTooltipManager
extends Node

signal lock_hover_changed(new_lock_type: String)

var tile_map_layer: TileMapLayer
var is_active: bool = false
var _realizer: GraphRealizer
var _biome_params: Dictionary = {}

# --- UI REFS ---
var _tooltip_layer: CanvasLayer
var _tooltip_screen: Control
var _tooltip_panel: PanelContainer
var _tooltip_label: RichTextLabel

# --- STATE ---
var _hovered_lock_type: String = ""

func setup(p_tile_map_layer: TileMapLayer) -> void:
	tile_map_layer = p_tile_map_layer
	
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.layer = 100 
	add_child(_tooltip_layer)
	
	_tooltip_screen = Control.new()
	_tooltip_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tooltip_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_layer.add_child(_tooltip_screen)
	
	_tooltip_panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.9)
	style.border_color = Color(0.4, 0.4, 0.5, 1.0)
	style.border_width_left = 2; style.border_width_top = 2
	style.border_width_right = 2; style.border_width_bottom = 2
	style.corner_radius_top_left = 4; style.corner_radius_bottom_right = 4
	style.corner_radius_top_right = 4; style.corner_radius_bottom_left = 4
	_tooltip_panel.add_theme_stylebox_override("panel", style)
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.visible = false
	
	_tooltip_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_tooltip_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tooltip_screen.add_child(_tooltip_panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_tooltip_panel.add_child(margin)
	
	_tooltip_label = RichTextLabel.new()
	_tooltip_label.bbcode_enabled = true
	_tooltip_label.fit_content = true
	_tooltip_label.scroll_active = false
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF 
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	
	_tooltip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tooltip_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tooltip_label.add_theme_font_size_override("font_size", 12)
	margin.add_child(_tooltip_label)

func update_context(realizer: GraphRealizer, biome_params: Dictionary) -> void:
	_realizer = realizer
	_biome_params = biome_params

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion: return
	
	if not is_active or not _realizer or not _realizer.grid or not tile_map_layer:
		_tooltip_panel.visible = false
		return
		
	var local_pos = tile_map_layer.get_local_mouse_position()
	var map_pos = tile_map_layer.local_to_map(local_pos)
	
	if not _realizer.grid.in_bounds_vec(map_pos):
		_tooltip_panel.visible = false; return
		
	var cell_id = _realizer.grid.get_cell(map_pos.x, map_pos.y)
	if cell_id == TilePalette.VOID_ID:
		_tooltip_panel.visible = false; return
		
	var biome_name = "Default Global"
	var terrain_type = "Floor"
	var current_cat_key = "" 
	
	if _realizer.floor_to_semantic.has(cell_id):
		current_cat_key = _realizer.floor_to_semantic[cell_id]
		if SemanticRegistry.categories[SemanticRegistry.TARGET_NODE].has(current_cat_key):
			biome_name = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE][current_cat_key].name
	else:
		terrain_type = "Wall"
		var found = false
		for floor_key in _realizer.semantic_wall_map:
			if _realizer.semantic_wall_map[floor_key] == cell_id:
				if _realizer.floor_to_semantic.has(floor_key):
					current_cat_key = _realizer.floor_to_semantic[floor_key]
					if SemanticRegistry.categories[SemanticRegistry.TARGET_NODE].has(current_cat_key):
						biome_name = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE][current_cat_key].name
						found = true; break
		if not found: biome_name = "Default Global"
			
	# --- FETCH REGION ID FOR TOOLTIP ---
	var region_id = -1
	if _realizer.has_meta("cell_to_region"):
		var c2r = _realizer.get_meta("cell_to_region")
		if c2r.has(map_pos):
			region_id = c2r[map_pos]
			
	var is_vault = false
	if region_id != -1 and _realizer.has_meta("vault_regions"):
		if _realizer.get_meta("vault_regions").has(region_id): is_vault = true
		
	var is_leaf = false
	if region_id != -1 and _realizer.has_meta("leaf_regions"):
		if _realizer.get_meta("leaf_regions").has(region_id): is_leaf = true
			
	if region_id != -1:
		biome_name = "%s:%d%s" % [biome_name.to_lower(), region_id, " [Optional Vault]" if is_vault else ""]
			
	var entity_str = ""
	var new_hover_lock = "" 
	
	if _realizer.grid.entities.has(map_pos):
		var ent = _realizer.grid.entities[map_pos]
		var e_type = ent.get("type", "Unknown")
		if e_type == "structure": 
			entity_str = "\n[Structure] : " + ent.get("name", "Custom")
		elif e_type == "door": 
			entity_str = "\n[Portal ID: %d]\nLock: %s" % [ent.get("portal_id", -1), ent.get("lock_type", "Unlocked")]
			new_hover_lock = ent.get("lock_type", "") 
		else:
			var req = ent.get("key_type", "")
			if req != "": 
				var p_method = ent.get("placement_method", "")
				entity_str = "\n[Item] : Key (" + req + ")"
				if p_method != "": entity_str += " [" + p_method + "]"
				new_hover_lock = req 
			else: 
				entity_str = "\n[Entity] : " + ent.get("name", "Scatter Prop")
				
	# Signal the parent if the locked door/key we are hovering over changed
	if new_hover_lock != _hovered_lock_type:
		_hovered_lock_type = new_hover_lock
		lock_hover_changed.emit(_hovered_lock_type)
			
	# --- ASSEMBLE THE TOOLTIP ---
	var text = "[ %d, %d ]\n" % [map_pos.x, map_pos.y]
	
	if _realizer.has_meta("cell_to_area"):
		var c2a = _realizer.get_meta("cell_to_area")
		if c2a.has(map_pos): text += "Area Depth: %d\n" % c2a[map_pos]
			
	var dist = _realizer.distance_field.get(map_pos, 0)
	text += "Wall Distance: %d\n" % dist
	
	var cell_status = []
	if _realizer.critical_path_cells.has(map_pos): cell_status.append("Critical Path")
	if _realizer.reserved_cells.has(map_pos): cell_status.append("Reserved")
	if not cell_status.is_empty():
		text += "Status: %s\n" % ", ".join(cell_status)
		
	if region_id != -1:
		text += "Topology: %s\n" % ("[color=cyan]Terminal Leaf[/color]" if is_leaf else "[color=orange]Non-Terminal[/color]")
			
	text += "Biome: %s\n" % biome_name
	
	if current_cat_key != "" and _biome_params.has(current_cat_key):
		var b_data = _biome_params[current_cat_key]
		if b_data.get("override_shape", false): text += "  ↳ Room Shapes Overridden\n"
		if b_data.get("override_routing", false): text += "  ↳ Routing & CA Overridden\n"
		if b_data.get("override_spawn_decks", false): text += "  ↳ Spawn Decks Overridden\n"
	
	text += "Terrain: %s" % terrain_type
	if entity_str != "": text += entity_str
		
	_tooltip_label.text = text
	_tooltip_panel.visible = true
	_tooltip_panel.position = event.position + Vector2(15, 15)
