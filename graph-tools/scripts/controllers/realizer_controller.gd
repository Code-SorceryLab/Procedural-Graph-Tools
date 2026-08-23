class_name RealizerController
extends Node

@export_group("Core References")
@export var graph_editor: GraphEditor
@export var tile_map_layer: TileMapLayer
@export var ui_container: VBoxContainer

@export_group("Tile Mapping (Visuals)")
@export var floor_source_id: int = 0

var _realizer: GraphRealizer
var _params: Dictionary = {}

# --- STATE ---
var _snapshots: Array[Dictionary] = []
var _raster_thread: Thread
var _is_rasterizing: bool = false
var _active_mapping: Dictionary = {} 

var _validator_thread: Thread
var _cancel_validation: bool = false
var _validator_paint_counter: int = 0 # Tracks chronological flood order for the gradient

# --- LOCK & KEY LINE CACHES ---
var _ghost_web_layer: Node2D
var _ghost_tween: Tween
var _hovered_lock_type: String = ""
var _door_centers_cache: Dictionary = {} # lock_type -> Array of Vector2
var _key_centers_cache: Dictionary = {}  # key_type -> Array of Vector2

# --- VIEWS ---
var _generator_tab: GeneratorTabView
var _timeline_tab: TimelineTabView
var _report_tab: ReportTabView
var _validation_tab: ValidationTabView

# --- TOOLTIP REFS ---
var _tooltip_layer: CanvasLayer
var _tooltip_screen: Control
var _tooltip_panel: PanelContainer
var _tooltip_label: RichTextLabel

var _atlas_mappings: Dictionary = { "default_floor": Vector2i(0, 0), "default_wall": Vector2i(1, 0) }
var _tileset_image_path: String = ""
var _tileset_tile_size: Vector2i = Vector2i(16, 16)
var _texture_cache: Dictionary = {}

var _biome_designer: BiomeDesignerPopup
var _mapping_popup: TileMappingPopup
var _structure_popup: StructureDesignerPopup
var _interaction_popup: BiomeInteractionPopup
var _scatter_popup: ScatterDesignerPopup
var _custom_room_popup: CustomRoomDesignerPopup
var _wfc_popup: WfcModuleDesignerPopup

var _custom_rooms: Dictionary = {}
var _wfc_modules: Dictionary = {}
var _custom_structures: Dictionary = {} 
var _scatter_sets: Dictionary = {}
var _procedural_flags: Dictionary = {}
var _palette_params: Dictionary = {}

var _biome_params: Dictionary = {}

func _ready() -> void:
	# --- SETUP HOVER TOOLTIP ---
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
	margin.add_theme_constant_override("margin_left", 8); margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8); margin.add_theme_constant_override("margin_bottom", 8)
	_tooltip_panel.add_child(margin)
	
	_tooltip_label = RichTextLabel.new()
	_tooltip_label.bbcode_enabled = true
	_tooltip_label.fit_content = true
	_tooltip_label.scroll_active = false
	
	# [FIXED] These two settings are mandatory for floating RichTextLabels!
	_tooltip_label.autowrap_mode = TextServer.AUTOWRAP_OFF # Forces width to match the longest line
	_tooltip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE # Prevents the text from eating your mouse clicks
	
	_tooltip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tooltip_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_tooltip_label.add_theme_font_size_override("font_size", 12)
	margin.add_child(_tooltip_label)
	
	_custom_structures = ConfigManager.load_structures() 
	_scatter_sets = ConfigManager.load_scatter_sets() # Load the scatter sets
	
	# --- [FIXED] LOAD GLOBAL PARAMS FIRST ---
	_params = ConfigManager.load_global_params()
	
	# ==========================================================================
	# ATTACH THE DUMB VIEWS
	# ==========================================================================
	var tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui_container.add_child(tabs)
	
	_generator_tab = GeneratorTabView.new()
	_generator_tab.interaction_triggered.connect(_on_ui_interaction)
	tabs.add_child(_generator_tab)
	
	_timeline_tab = TimelineTabView.new()
	_timeline_tab.snapshot_selected.connect(_on_step_list_selected)
	tabs.add_child(_timeline_tab)
	
	_report_tab = ReportTabView.new()
	tabs.add_child(_report_tab)
	
	# The Validation Tab
	_validation_tab = ValidationTabView.new()
	_validation_tab.run_requested.connect(_on_validation_run_requested)
	_validation_tab.stop_requested.connect(_on_validation_stop_requested)
	_validation_tab.visualize_toggled.connect(_on_visualize_toggled) 
	tabs.add_child(_validation_tab)
	
	# [FIXED] Build exactly once with the loaded parameters!
	_generator_tab.build(_custom_structures, _params)
	
	# Instantiate popups
	_mapping_popup = TileMappingPopup.new(); add_child(_mapping_popup); _mapping_popup.confirmed.connect(_on_mapping_confirmed)
	_structure_popup = StructureDesignerPopup.new(); add_child(_structure_popup); _structure_popup.confirmed.connect(_on_structure_designer_saved)
	_interaction_popup = BiomeInteractionPopup.new(); add_child(_interaction_popup); _interaction_popup.confirmed.connect(_on_interaction_popup_saved)
	_scatter_popup = ScatterDesignerPopup.new(); add_child(_scatter_popup); _scatter_popup.confirmed.connect(_on_scatter_designer_saved)
	
	_biome_designer = BiomeDesignerPopup.new()
	add_child(_biome_designer)
	
	# --- CONNECT THE SAVE SIGNALS ---
	_biome_designer.global_settings_changed.connect(func(p): 
		_params = p
		ConfigManager.save_global_params(p)
	)
	_biome_designer.biome_settings_changed.connect(func(b): 
		_biome_params = b
		ConfigManager.save_biome_overrides(b)
	)
	_biome_designer.spawn_decks_changed.connect(func(d): 
		ConfigManager.save_spawn_decks(d)
	)
	
	_biome_params = ConfigManager.load_biome_overrides()
	_biome_designer.room_decks_changed.connect(func(d): ConfigManager.save_room_decks(d))
	
	var saved_data = ConfigManager.load_rasterizer_mappings()
	if saved_data.has("mappings") and not saved_data["mappings"].is_empty(): _atlas_mappings.merge(saved_data["mappings"], true)
	if saved_data.has("procedural_flags"): _procedural_flags.merge(saved_data["procedural_flags"], true)
	if saved_data.has("palette_params"): _palette_params.merge(saved_data["palette_params"], true)
	_tileset_image_path = saved_data.get("texture_path", "")
	_tileset_tile_size = saved_data.get("tile_size", Vector2i(16, 16))
	
	_custom_rooms = ConfigManager.load_custom_rooms()
	_custom_room_popup = CustomRoomDesignerPopup.new()
	_custom_room_popup.hide()
	add_child(_custom_room_popup)
	
	_custom_room_popup.confirmed.connect(func():
		_custom_rooms = _custom_room_popup.custom_rooms.duplicate(true)
		ConfigManager.save_custom_rooms(_custom_rooms)
	)
	
	# --- [NEW] WFC MODULE SETUP ---
	# (Assuming you add load_wfc_modules / save_wfc_modules to your ConfigManager!)
	_wfc_modules = ConfigManager.load_wfc_modules()
	
	_wfc_popup = WfcModuleDesignerPopup.new()
	_wfc_popup.hide()
	add_child(_wfc_popup)
	
	_wfc_popup.confirmed.connect(func(saved_modules):
		_wfc_modules = saved_modules.duplicate(true)

		ConfigManager.save_wfc_modules(_wfc_modules)
	)


func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion: return
	
	if _is_rasterizing or not _realizer or not _realizer.grid or not tile_map_layer:
		if _tooltip_panel: _tooltip_panel.visible = false
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
			
	# Check if this region is a marked Vault
	var is_vault = false
	if region_id != -1 and _realizer.has_meta("vault_regions"):
		var vr = _realizer.get_meta("vault_regions")
		if vr.has(region_id): is_vault = true
		
	# --- [NEW] CHECK TOPOLOGY FOR TOOLTIP ---
	var is_leaf = false
	if region_id != -1 and _realizer.has_meta("leaf_regions"):
		if _realizer.get_meta("leaf_regions").has(region_id):
			is_leaf = true
			
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
				
	if new_hover_lock != _hovered_lock_type:
		_hovered_lock_type = new_hover_lock
		_draw_ghost_web(_hovered_lock_type)
			
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
		
	# --- INJECT TOPOLOGY INTO TEXT ---
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

# ==============================================================================
# UI ROUTING
# ==============================================================================
func _on_ui_interaction(key: String, value: Variant) -> void:
	if key == "btn_rasterize": _on_rasterize_pressed()
	elif key == "btn_clear": _on_clear_pressed()
	elif key == "btn_open_mapper": _mapping_popup.open(_tileset_image_path, _tileset_tile_size, _atlas_mappings, _procedural_flags, _palette_params)
	elif key == "btn_open_structure_designer": _structure_popup.open()
	elif key == "btn_open_scatter_designer": _scatter_popup.open()
	elif key == "btn_biome_interactions": _interaction_popup.open()
	elif key == "btn_open_biome_designer": _biome_designer.open(_params)
	elif key == "btn_open_custom_room_designer": 
		_custom_room_popup.open(_tileset_image_path, _tileset_tile_size, _custom_rooms, _custom_structures, _scatter_sets)
	
	# --- WFC ROUTER ---
	elif key == "btn_open_wfc_designer":
		_wfc_popup.open(_tileset_image_path, _tileset_tile_size, _wfc_modules, _scatter_sets)
	
	# Catch all view toggles and redraw instantly!
	elif key.begins_with("show_") or key == "debug_routing":
		_params[key] = value
		ConfigManager.save_global_params(_params)
		if not _snapshots.is_empty() and tile_map_layer:
			_render_overlays(_snapshots[-1]["entities"])
			
	else:
		_params[key] = value
		ConfigManager.save_global_params(_params)

func _on_mapping_confirmed() -> void:
	_atlas_mappings = _mapping_popup.mappings.duplicate()
	_procedural_flags = _mapping_popup.procedural_flags.duplicate()
	_palette_params = _mapping_popup.palette_editor.params.duplicate()
	_tileset_image_path = _mapping_popup.atlas_texture_path
	_tileset_tile_size = _mapping_popup.tile_size
	ConfigManager.save_rasterizer_mappings(_atlas_mappings, _tileset_image_path, _tileset_tile_size, _procedural_flags, _palette_params)


func _on_structure_designer_saved() -> void:
	ConfigManager.save_structures(_structure_popup.structures)
	_custom_structures = _structure_popup.structures.duplicate()
	for key in _custom_structures:
		var weight_key = "weight_" + key
		if not _params.has(weight_key): _params[weight_key] = 0

func _on_interaction_popup_saved() -> void:
	ConfigManager.save_biome_interactions(_interaction_popup.interactions)

func _on_scatter_designer_saved() -> void:
	ConfigManager.save_scatter_sets(_scatter_popup.scatter_sets)
	_scatter_sets = _scatter_popup.scatter_sets.duplicate(true)
	
	# Auto-populate default params so they exist for the generation thread
	for key in _scatter_sets:
		var mode = _scatter_sets[key].get("spawn_mode", 0)
		if mode == 0 and not _params.has("density_" + key):
			_params["density_" + key] = _scatter_sets[key].get("density", 0.05)
		elif mode == 1 and not _params.has("fixed_quantity_" + key):
			_params["fixed_quantity_" + key] = _scatter_sets[key].get("fixed_quantity", 1)

# --- DATA FIREWALL ---
# Strips out any stale settings from disabled tabs before generation!
func _build_filtered_biomes() -> Dictionary:
	var filtered = {}
	for b_key in _biome_params:
		var b_data = _biome_params[b_key]
		var clean_data = {}
		
		# 1. Shape & Topology
		if b_data.get("override_shape", false):
			var shape_keys = ["room_radius_min", "room_radius_max", "enable_room_merging", "room_merge_tolerance", "ratio_square", "ratio_circle", "ratio_triangle"]
			for k in shape_keys:
				if b_data.has(k): clean_data[k] = b_data[k]
				
		# 2. Routing & CA
		if b_data.get("override_routing", false):
			var routing_keys = ["routing_mode", "allow_diagonal_corridors", "corridor_thickness", "corridor_erosion", "corridor_erosion_scale", "ca_iterations", "ca_survive_min", "ca_birth_min"]
			for k in routing_keys:
				if b_data.has(k): clean_data[k] = b_data[k]
				
		# 3. Spawn Decks
		if b_data.get("override_spawn_decks", false):
			clean_data["override_spawn_decks"] = true
			clean_data["override_enabled"] = true
			if b_data.has("spawn_decks"):
				clean_data["spawn_decks"] = b_data["spawn_decks"]
				
		# Only append if this biome actually has active overrides
		if not clean_data.is_empty():
			filtered[b_key] = clean_data
			
	return filtered

# ==============================================================================
# PIPELINE EXECUTION (THREADED)
# ==============================================================================
func _on_rasterize_pressed() -> void:
	if _is_rasterizing: return
	if not graph_editor or not "graph" in graph_editor: return
	var graph = graph_editor.graph
	if graph == null or graph.nodes.is_empty(): return
	if not tile_map_layer: return
	
	if _validator_thread and _validator_thread.is_started():
		_cancel_validation = true
		_validator_thread.wait_to_finish()
	
	_params["custom_rooms"] = _custom_rooms
	_params["wfc_modules"] = _wfc_modules
	_params["biomes"] = _build_filtered_biomes()
		
	_snapshots.clear()
	_timeline_tab.clear()
	_active_mapping.clear() 
	_report_tab.set_loading()
	_validation_tab.clear_logs()
	
	for child in tile_map_layer.get_children():
		if child.is_in_group("realizer_entity") or child.is_in_group("realizer_critical_path") or child.is_in_group("validator_overlay"):
			child.queue_free()
	
	_is_rasterizing = true
	_realizer = GraphRealizer.new()
	
	if _raster_thread and _raster_thread.is_started():
		_raster_thread.wait_to_finish()
		
	# --- [NEW] DUAL DISTRIBUTION PASS ---
	var seed_str = str(_params.get("realizer_seed", "default"))
	
	# Pass 1: Room Shapes & Custom Rooms
	var global_room_decks = ConfigManager.load_room_decks()
	var room_lists = DistributionEngine.generate_shopping_lists(graph, global_room_decks, _biome_params, seed_str, "room_decks")
	_params["room_shopping_lists"] = room_lists # Pack it safely into params!
	
	# Pass 2: Scatter & Structures
	var global_spawn_decks = ConfigManager.load_spawn_decks()
	var spawn_lists = DistributionEngine.generate_shopping_lists(graph, global_spawn_decks, _biome_params, seed_str, "spawn_decks")
	
	_raster_thread = Thread.new()
	# Only pass the spawn_lists to the thread (which preserves StructureBuilder compatibility)
	_raster_thread.start(_run_rasterization_thread.bind(graph, _params, spawn_lists))

func _run_rasterization_thread(graph: Graph, params: Dictionary, shopping_lists: Dictionary) -> void:
	_realizer.realize(graph, params, shopping_lists, _on_snapshot_received)
	call_deferred("_on_rasterization_finished")

func _on_snapshot_received(step_name: String, cells: PackedInt32Array, entities: Dictionary, atlas_overrides: Dictionary, w: int, h: int) -> void:
	# [UPDATED] Save it into the snapshot dictionary
	_snapshots.append({ "name": step_name, "cells": cells, "entities": entities, "atlas_overrides": atlas_overrides, "w": w, "h": h })
	var idx = _snapshots.size() - 1
	_timeline_tab.add_snapshot(step_name)
	
	if _active_mapping.is_empty(): _rebuild_dynamic_tileset_and_mapping()
	_jump_to_snapshot(idx)

func _on_rasterization_finished() -> void:
	if _raster_thread and _raster_thread.is_started(): 
		_raster_thread.wait_to_finish()
	_is_rasterizing = false # <--- Lock lifted!
	
	if _realizer and _realizer.has_meta("progression_report"):
		_report_tab.update_report(_realizer.get_meta("progression_report"))
	else:
		_report_tab.update_report({}) 
		
	_timeline_tab.set_buttons_active(true)
	
	# Redraw the overlays now that it is safe to read the realizer
	if not _snapshots.is_empty():
		_render_overlays(_snapshots[-1]["entities"])

# ==============================================================================
# VALIDATION ENGINE
# ==============================================================================
func _on_validation_run_requested(visualize: bool, full_explore: bool, delay_doors: bool) -> void:
	if _is_rasterizing: return
	if not _realizer or not _realizer.grid:
		_validation_tab.append_log("[color=red]Error: Rasterize the graph first.[/color]")
		return

	if _validator_thread and _validator_thread.is_started():
		_cancel_validation = true
		_validator_thread.wait_to_finish()

	_validation_tab.clear_logs()
	_validation_tab.set_running(true)
	_cancel_validation = false
	_validator_paint_counter = 0

	for child in tile_map_layer.get_children():
		if child.is_in_group("validator_overlay"): child.queue_free()

	_validator_thread = Thread.new()
	_validator_thread.start(_run_validation_thread.bind(_realizer.grid, visualize, full_explore, delay_doors))

func _run_validation_thread(grid: GridData, visualize: bool, full_explore: bool, delay_doors: bool) -> void:
	var emit_func = func(type: String, data: Variant = null):
		call_deferred("_on_validation_event", type, data)
	var cancel_func = func() -> bool: return _cancel_validation
		
	# Pass it down to the validator script
	var result = GenerationValidator.run(grid, visualize, full_explore, delay_doors, emit_func, cancel_func)
	call_deferred("_on_validation_finished", result)

func _on_validation_stop_requested() -> void:
	_cancel_validation = true

# Toggle Flood Fill Visibility
func _on_visualize_toggled(is_on: bool) -> void:
	if tile_map_layer:
		for child in tile_map_layer.get_children():
			if child.is_in_group("validator_overlay"):
				child.visible = is_on

func _on_validation_event(type: String, data: Variant) -> void:
	if type == "log":
		_validation_tab.append_log(data)
	elif type == "flood":
		if not tile_map_layer or not tile_map_layer.tile_set: return
		var cell_size = float(tile_map_layer.tile_set.tile_size.x)
		var is_vis = _validation_tab.is_visualize_on()
		
		for pos in data:
			var rect = ColorRect.new()
			
			# --- CHRONOLOGICAL GRADIENT ---
			# Starts at Cyan (0.55 Hue) and slowly shifts toward Blue, Purple, and Red 
			# based on its exact chronological position in the BFS search!
			var hue = fmod(0.55 + (_validator_paint_counter * 0.0005), 1.0)
			rect.color = Color.from_hsv(hue, 0.8, 1.0, 0.4) 
			# ------------------------------------
			
			rect.size = Vector2(cell_size, cell_size)
			rect.position = Vector2(pos.x * cell_size, pos.y * cell_size)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rect.visible = is_vis 
			rect.add_to_group("validator_overlay")
			tile_map_layer.add_child(rect)
			
			_validator_paint_counter += 1 # Increment for the next tile


func _on_validation_finished(result: Dictionary) -> void:
	if _validator_thread and _validator_thread.is_started():
		_validator_thread.wait_to_finish()
	_validation_tab.set_running(false)

# ==============================================================================
# TIMELINE / VCR RENDERER
# ==============================================================================
func _on_step_list_selected(index: int) -> void:
	if _is_rasterizing: return 
	_jump_to_snapshot(index)

func _jump_to_snapshot(index: int) -> void:
	if _snapshots.is_empty() or _active_mapping.is_empty(): return
	
	# [FIXED] Cancel running validator if user scrubs timeline
	if _validator_thread and _validator_thread.is_started():
		_cancel_validation = true
		_validator_thread.wait_to_finish()
		_validation_tab.set_running(false)
		_validation_tab.append_log("[color=orange]Validation cancelled (Timeline Scrubbed).[/color]")
	
	index = clampi(index, 0, _snapshots.size() - 1)
	
	_timeline_tab.select_index(index)
	var snapshot = _snapshots[index]
	var mock_grid = GridData.new(snapshot["w"], snapshot["h"], _realizer.palette)
	mock_grid.cells = snapshot["cells"]
	mock_grid.cell_atlas_overrides = snapshot.get("atlas_overrides", {}) # Restore the exact tiles
	
	tile_map_layer.clear()
	TileMapAdapter.apply_to_layer(mock_grid, tile_map_layer, _active_mapping)
	
	if tile_map_layer.tile_set:
		var cell_size = float(tile_map_layer.tile_set.tile_size.x)
		var visual_scale = _params["grid_scale"] / cell_size
		tile_map_layer.scale = Vector2(visual_scale, visual_scale)
		var offset_x = _realizer._world_offset.x - (_params["padding"] * _params["grid_scale"])
		var offset_y = _realizer._world_offset.y - (_params["padding"] * _params["grid_scale"])
		tile_map_layer.position = Vector2(offset_x, offset_y)
		
	_render_overlays(snapshot["entities"])

func _get_cached_texture(path: String) -> Texture2D:
	if _texture_cache.has(path): return _texture_cache[path]
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(path)
		if img:
			var tex = ImageTexture.create_from_image(img)
			_texture_cache[path] = tex
			return tex
	return null

func _render_overlays(entities: Dictionary) -> void:
	for child in tile_map_layer.get_children():
		if child.is_in_group("realizer_entity") or child.is_in_group("realizer_critical_path") or child.is_in_group("validator_overlay"):
			child.queue_free()
			
	if not tile_map_layer.tile_set: return
	var cell_size = float(tile_map_layer.tile_set.tile_size.x)
	
	# A. Render Critical Path Overlays
	var show_path = _params.get("debug_routing", false)
	if _realizer and not _is_rasterizing: 
		for pos in _realizer.critical_path_cells:
			var rect = ColorRect.new()
			rect.color = Color(1.0, 0.0, 1.0, 0.4)
			rect.size = Vector2(cell_size, cell_size) 
			rect.position = Vector2(pos.x * cell_size, pos.y * cell_size)
			rect.visible = show_path
			rect.add_to_group("realizer_critical_path")
			tile_map_layer.add_child(rect)

	# B. Master Visibility Check
	var master_vis = _params.get("show_entities", true)
	if not master_vis: return

	# --- GHOST WEB LAYER SETUP ---
	if not _ghost_web_layer:
		_ghost_web_layer = Node2D.new()
		_ghost_web_layer.z_index = 5 # Float above all entities
		tile_map_layer.add_child(_ghost_web_layer)
	
	_door_centers_cache.clear()
	_key_centers_cache.clear()

	# --- DOOR & KEY CENTROID PRE-PASS ---
	var portal_centers = {}
	var portal_counts = {}
	var portal_locks = {}
	
	for p in entities:
		var e_type = entities[p].get("type", "")
		if e_type == "door":
			var pid = entities[p].get("portal_id", -1)
			var l_type = entities[p].get("lock_type", "Unlocked")
			if pid != -1:
				if not portal_centers.has(pid):
					portal_centers[pid] = Vector2.ZERO
					portal_counts[pid] = 0
					portal_locks[pid] = l_type
				portal_centers[pid] += Vector2(p)
				portal_counts[pid] += 1
				
		elif e_type == "key":
			var k_type = entities[p].get("key_type", "")
			if k_type != "":
				if not _key_centers_cache.has(k_type): _key_centers_cache[k_type] = []
				var k_world = Vector2(p) * cell_size + Vector2(cell_size / 2.0, cell_size / 2.0)
				_key_centers_cache[k_type].append(k_world)
				
	for pid in portal_centers:
		var center_grid = portal_centers[pid] / float(portal_counts[pid])
		var center_world = center_grid * cell_size + Vector2(cell_size / 2.0, cell_size / 2.0)
		portal_centers[pid] = center_grid # Save for the labels below
		
		var l_type = portal_locks[pid]
		if not _door_centers_cache.has(l_type): _door_centers_cache[l_type] = []
		_door_centers_cache[l_type].append(center_world)

	var drawn_door_labels = {}

	for pos in entities:
		var entity_data = entities[pos]
		var e_type = entity_data.get("type", "generic_entity")
		
		# 1. Route the exact toggles based on Entity Type
		var show_sprite = false
		var show_footprint = false
		
		if e_type == "structure":
			show_sprite = _params.get("show_struct_sprites", true)
			show_footprint = _params.get("show_struct_footprints", true)
		elif e_type in ["door", "key", "fringe"]:
			if not _params.get("show_progression", true): continue
			show_footprint = true
		elif e_type in ["start_point", "end_point"]:
			if not _params.get("show_endpoints", true): continue
			show_footprint = true
		else: # Scatter Sets & Generic
			show_sprite = _params.get("show_scatter_sprites", true)
			show_footprint = _params.get("show_scatter_footprints", true)

		var tex_path = entity_data.get("texture_path", "")
		var has_sprite = (tex_path != "")
		
		# 2. Render Visual Sprites (Structures & Scatter Sets)
		if has_sprite and show_sprite:
			var tex = _get_cached_texture(tex_path)
			if tex:
				var sprite = Sprite2D.new()
				sprite.texture = tex
				
				var t_off = entity_data.get("texture_offset", Vector2.ZERO)
				var t_scale = entity_data.get("texture_scale", Vector2.ONE)
				var t_filter = entity_data.get("texture_filter", 0)
				var rot_idx = entity_data.get("rot", 0)
				
				var base_scale_x = cell_size / tex.get_size().x
				var base_scale_y = cell_size / tex.get_size().y
				sprite.scale = Vector2(base_scale_x * t_scale.x, base_scale_y * t_scale.y)
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if t_filter == 0 else CanvasItem.TEXTURE_FILTER_LINEAR
				sprite.rotation = rot_idx * (PI / 2.0)
				
				sprite.position = Vector2(pos.x * cell_size + (cell_size / 2.0), pos.y * cell_size + (cell_size / 2.0))
				sprite.offset = (t_off * cell_size) / sprite.scale
				sprite.z_index = 1
				sprite.add_to_group("realizer_entity")
				tile_map_layer.add_child(sprite)

		# 3. Render Hitboxes & Indicators
		if show_footprint or (show_sprite and not has_sprite):
			if e_type == "structure":
				var struct_color = entity_data.get("color", Color(0.2, 0.6, 1.0, 0.7))
				var footprint_world = entity_data.get("footprint_world", [])
				for pt in footprint_world:
					var pt_rect = ColorRect.new()
					pt_rect.color = struct_color
					pt_rect.size = Vector2(cell_size, cell_size)
					pt_rect.position = Vector2(pt.x * cell_size, pt.y * cell_size)
					pt_rect.add_to_group("realizer_entity")
					tile_map_layer.add_child(pt_rect)
			else:
				var rect = ColorRect.new()
				var label_to_add = null 
				var pid = -1 # Needed for door labeling
				
				if e_type == "door":
					var l_type = entity_data.get("lock_type", "Unlocked")
					if l_type == "Unlocked": 
						rect.color = Color(0.8, 0.5, 0.2, 0.9)
					elif l_type.begins_with("Tier "): 
						rect.color = Color(0.35, 0.35, 0.35, 0.9) # Darker Iron for Contrast
						
						# Run exactly once per door clump
						pid = entity_data.get("portal_id", -1)
						if pid != -1 and not drawn_door_labels.has(pid):
							drawn_door_labels[pid] = true
							
							label_to_add = Label.new()
							label_to_add.text = l_type.trim_prefix("Tier ")
							label_to_add.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
							label_to_add.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
							label_to_add.add_theme_color_override("font_color", Color.WHITE)
							label_to_add.add_theme_color_override("font_outline_color", Color.BLACK)
							label_to_add.add_theme_constant_override("outline_size", 16) # Massive outline!
							label_to_add.add_theme_font_size_override("font_size", 100) # High-res font
					else: 
						rect.color = Color.from_string(l_type, Color(0.8, 0.5, 0.2, 0.9))
						
				elif e_type == "start_point": rect.color = Color(0.2, 1.0, 0.2, 0.9)
				elif e_type == "end_point": rect.color = Color(1.0, 0.2, 0.2, 0.9)
				elif e_type == "key":
					rect.color = Color.BLACK # Use the base rect as the border!
					var inner_rect = ColorRect.new()
					
					var k_col = entity_data.get("key_type", "Red")
					if k_col.begins_with("Tier "): 
						inner_rect.color = Color.WHITE
						
						label_to_add = Label.new()
						label_to_add.text = k_col.trim_prefix("Tier ")
						label_to_add.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
						label_to_add.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
						label_to_add.add_theme_color_override("font_color", Color.BLACK)
						label_to_add.add_theme_font_size_override("font_size", 100) # High-res font
					else: 
						inner_rect.color = Color.from_string(k_col, Color.WHITE)
						
					rect.add_child(inner_rect)
				elif e_type == "fringe": rect.color = Color(0.2, 0.9, 0.2, 0.8)
				else: rect.color = entity_data.get("color", Color(1.0, 0.8, 0.0, 0.4))
				
				# Position & Sizing
				var s_mult = 1.0 if e_type == "door" else (0.8 if e_type in ["start_point", "end_point"] else (0.4 if e_type == "fringe" else 0.5))
				rect.size = Vector2(cell_size * s_mult, cell_size * s_mult)
				var center_offset = (cell_size - rect.size.x) / 2.0
				rect.position = Vector2(pos.x * cell_size + center_offset, pos.y * cell_size + center_offset)
				
				# Scale the key's inner colored square to form a perfect border
				if rect.get_child_count() > 0 and rect.get_child(0) is ColorRect:
					var inner = rect.get_child(0)
					var b_size = max(1.0, cell_size * 0.06) # 6% border width
					inner.position = Vector2(b_size, b_size)
					inner.size = rect.size - Vector2(b_size * 2, b_size * 2)

				rect.add_to_group("realizer_entity")
				tile_map_layer.add_child(rect)
				
				# Attach the scaled-down, perfectly centered High-Res label!
				if label_to_add:
					label_to_add.size = Vector2(200, 200) # Virtual resolution
					if e_type == "key":
						label_to_add.scale = rect.size / 200.0
						label_to_add.position = rect.position
					else: # Door label
						label_to_add.scale = Vector2(cell_size, cell_size) / 200.0
						var center_grid = portal_centers[pid]
						var center_world = center_grid * cell_size + Vector2(cell_size / 2.0, cell_size / 2.0)
						label_to_add.position = center_world - (label_to_add.size * label_to_add.scale / 2.0)
						
					label_to_add.z_index = 2 # Strictly render over everything
					label_to_add.add_to_group("realizer_entity")
					tile_map_layer.add_child(label_to_add)

# ==============================================================================
# VISUAL RENDERING ENGINES
# ==============================================================================
func _rebuild_dynamic_tileset_and_mapping() -> void:
	var dynamic_tileset = TileSet.new()
	dynamic_tileset.tile_size = _tileset_tile_size
	
	var active_proc_keys = []
	for key in _realizer.semantic_floor_ids:
		if _procedural_flags.get(key, false): active_proc_keys.append(key)
	active_proc_keys.sort() 
	
	var biome_colors = {}
	var wall_shift = _palette_params.get("wall_shift", 0.1)
	for i in range(active_proc_keys.size()):
		var key = active_proc_keys[i]
		var t = float(i) / max(1.0, float(active_proc_keys.size() - 1))
		biome_colors[key + "_floor"] = CosinePaletteEditor.get_iq_color(t, _palette_params)
		biome_colors[key + "_wall"] = CosinePaletteEditor.get_iq_color(t + wall_shift, _palette_params)

	var def_floor_atlas = _atlas_mappings.get("default_floor", Vector2i(0,0))
	var def_wall_atlas = _atlas_mappings.get("default_wall", Vector2i(1,0))
	var debug_path_atlas = _atlas_mappings.get("debug_path", Vector2i(2,0)) 
	var biome_alt_ids = {}
	
	if _tileset_image_path != "" and FileAccess.file_exists(_tileset_image_path):
		var img = Image.load_from_file(_tileset_image_path)
		if img:
			var source = TileSetAtlasSource.new()
			source.texture = ImageTexture.create_from_image(img)
			source.texture_region_size = _tileset_tile_size
			
			var ensure_base_tile = func(coord: Vector2i):
				if not source.has_tile(coord): source.create_tile(coord)
			
			ensure_base_tile.call(def_floor_atlas)
			ensure_base_tile.call(def_wall_atlas)
			ensure_base_tile.call(debug_path_atlas)
			for mapping_key in _atlas_mappings:
				ensure_base_tile.call(_atlas_mappings[mapping_key])
				
			# --- REGISTER CUSTOM ROOM EXACT TILES ---
			for r_key in _custom_rooms:
				var r_data = _custom_rooms[r_key]
				if r_data.has("exact_floors"):
					for pos in r_data["exact_floors"]: ensure_base_tile.call(r_data["exact_floors"][pos])
				if r_data.has("exact_walls"):
					for pos in r_data["exact_walls"]: ensure_base_tile.call(r_data["exact_walls"][pos])
			# ----------------------------------------------
				
			var next_alt_id = {}
			for cat_key in _realizer.semantic_floor_ids:
				if _procedural_flags.get(cat_key, false):
					var f_coord = _atlas_mappings.get(cat_key + "_floor", def_floor_atlas)
					var w_coord = _atlas_mappings.get(cat_key + "_wall", def_wall_atlas)
					
					var f_alt = next_alt_id.get(f_coord, 1); next_alt_id[f_coord] = f_alt + 1
					source.create_alternative_tile(f_coord, f_alt)
					source.get_tile_data(f_coord, f_alt).modulate = biome_colors[cat_key + "_floor"]
					biome_alt_ids[cat_key + "_floor"] = f_alt
					
					var w_alt = next_alt_id.get(w_coord, 1); next_alt_id[w_coord] = w_alt + 1
					source.create_alternative_tile(w_coord, w_alt)
					source.get_tile_data(w_coord, w_alt).modulate = biome_colors[cat_key + "_wall"]
					biome_alt_ids[cat_key + "_wall"] = w_alt
					
			dynamic_tileset.add_source(source, floor_source_id)
			
	tile_map_layer.tile_set = dynamic_tileset
	
	var get_mapping_data = func(atlas_coord: Vector2i, alt_id: int = 0) -> Dictionary:
		return { "is_terrain": false, "source_id": floor_source_id, "atlas_coords": atlas_coord, "alternative_tile": alt_id }

	_active_mapping = {
		_realizer.floor_id: get_mapping_data.call(def_floor_atlas),
		_realizer.wall_id: get_mapping_data.call(def_wall_atlas),
		_realizer.debug_path_id: get_mapping_data.call(debug_path_atlas)
	}
	
	for cat_key in _realizer.semantic_floor_ids:
		var s_floor_id = _realizer.semantic_floor_ids[cat_key]
		var s_wall_id = _realizer.semantic_wall_map[s_floor_id]
		
		var custom_floor = _atlas_mappings.get(cat_key + "_floor", def_floor_atlas)
		var custom_wall = _atlas_mappings.get(cat_key + "_wall", def_wall_atlas)
		var floor_alt = biome_alt_ids.get(cat_key + "_floor", 0)
		var wall_alt = biome_alt_ids.get(cat_key + "_wall", 0)
		
		_active_mapping[s_floor_id] = get_mapping_data.call(custom_floor, floor_alt)
		_active_mapping[s_wall_id] = get_mapping_data.call(custom_wall, wall_alt)

func _draw_ghost_web(lock_str: String) -> void:
	if not _ghost_web_layer: return
	for child in _ghost_web_layer.get_children():
		child.queue_free()
		
	if lock_str == "" or lock_str == "Unlocked": return
	
	var key_positions = _key_centers_cache.get(lock_str, [])
	var door_positions = _door_centers_cache.get(lock_str, [])
	
	if key_positions.is_empty() or door_positions.is_empty(): return
	
	# Determine Web Color
	var web_color = Color.WHITE
	if not lock_str.begins_with("Tier "):
		web_color = Color.from_string(lock_str, Color.WHITE)
		
	# Draw Many-to-Many Connections
	for k_pos in key_positions:
		for d_pos in door_positions:
			var line = Line2D.new()
			line.add_point(k_pos)
			line.add_point(d_pos)
			line.width = 6.0
			line.default_color = web_color
			line.modulate.a = 0.5
			line.antialiased = true
			
			var core = Line2D.new()
			core.add_point(k_pos)
			core.add_point(d_pos)
			core.width = 2.0
			core.default_color = Color.WHITE
			core.antialiased = true
			
			line.add_child(core)
			_ghost_web_layer.add_child(line)
			
	# Start Pulsing Animation
	if _ghost_tween: _ghost_tween.kill()
	_ghost_tween = create_tween().set_loops()
	_ghost_web_layer.modulate.a = 0.2
	_ghost_tween.tween_property(_ghost_web_layer, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	_ghost_tween.tween_property(_ghost_web_layer, "modulate:a", 0.2, 0.6).set_trans(Tween.TRANS_SINE)

# ==============================================================================
# CLEANUP
# ==============================================================================
func _on_clear_pressed() -> void:
	if _is_rasterizing: return
	
	if _validator_thread and _validator_thread.is_started():
		_cancel_validation = true
		_validator_thread.wait_to_finish()
		_validation_tab.set_running(false)
		_validation_tab.append_log("[color=orange]Validation cancelled.[/color]")
		
	if tile_map_layer:
		tile_map_layer.clear()
		for child in tile_map_layer.get_children():
			if child.is_in_group("realizer_entity") or child.is_in_group("realizer_critical_path") or child.is_in_group("validator_overlay"):
				child.queue_free()
				
	_realizer = null
	if _tooltip_panel: _tooltip_panel.visible = false
	_snapshots.clear()
	_timeline_tab.clear()
	_report_tab.clear()
	_validation_tab.clear_logs()
