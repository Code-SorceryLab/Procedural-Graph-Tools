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

var _active_mapping: Dictionary = {} 


# --- VIEWS ---
var _generator_tab: GeneratorTabView
var _timeline_tab: TimelineTabView
var _report_tab: ReportTabView
var _validation_tab: ValidationTabView

var _tooltip_manager: RealizerTooltipManager
var _renderer: RealizerOverlayRenderer
var _execution_manager: RealizerExecutionManager

var _atlas_mappings: Dictionary = { "default_floor": Vector2i(0, 0), "default_wall": Vector2i(1, 0) }
var _tileset_image_path: String = ""
var _tileset_tile_size: Vector2i = Vector2i(16, 16)


var _biome_designer: BiomeDesignerPopup
var _mapping_popup: TileMappingPopup
var _structure_popup: StructureDesignerPopup
var _interaction_popup: BiomeInteractionPopup
var _scatter_popup: ScatterDesignerPopup
var _custom_room_popup: CustomRoomDesignerPopup
var _wfc_popup: WfcModuleDesignerPopup
var _tile_wfc_popup: TileWfcDesignerPopup

var _custom_rooms: Dictionary = {}
var _wfc_modules: Dictionary = {}
var _tile_wfc_patterns: Dictionary = {}
var _custom_structures: Dictionary = {} 
var _scatter_sets: Dictionary = {}
var _procedural_flags: Dictionary = {}
var _palette_params: Dictionary = {}

var _biome_params: Dictionary = {}

func _ready() -> void:
	_renderer = RealizerOverlayRenderer.new()
	add_child(_renderer)
	_renderer.setup(tile_map_layer, floor_source_id)
	
	
	_tooltip_manager = RealizerTooltipManager.new()
	add_child(_tooltip_manager)
	_tooltip_manager.setup(tile_map_layer)
	_tooltip_manager.lock_hover_changed.connect(_renderer.draw_ghost_web)
	
	_execution_manager = RealizerExecutionManager.new()
	add_child(_execution_manager)
	
	_execution_manager.rasterization_started.connect(_on_rasterization_started)
	_execution_manager.snapshot_ready.connect(_on_snapshot_received)
	_execution_manager.rasterization_finished.connect(_on_rasterization_finished)
	
	_execution_manager.validation_started.connect(_on_validation_started)
	_execution_manager.validation_log.connect(func(msg): _validation_tab.append_log(msg))
	_execution_manager.validation_flood.connect(_on_validation_flood)
	_execution_manager.validation_finished.connect(func(): _validation_tab.set_running(false))
	
	
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
	
	# --- WFC MODULE SETUP ---
	_wfc_modules = ConfigManager.load_wfc_modules()
	
	_wfc_popup = WfcModuleDesignerPopup.new()
	_wfc_popup.hide()
	add_child(_wfc_popup)
	
	_wfc_popup.confirmed.connect(func(saved_modules):
		_wfc_modules = saved_modules.duplicate(true)

		ConfigManager.save_wfc_modules(_wfc_modules)
	)
	# --- WFC TILE SETUP ---
	_tile_wfc_patterns = ConfigManager.load_textural_palettes()
	_tile_wfc_popup = TileWfcDesignerPopup.new()
	_tile_wfc_popup.hide()
	add_child(_tile_wfc_popup)
	
	_tile_wfc_popup.confirmed.connect(func(saved_patterns):
		_tile_wfc_patterns = saved_patterns.duplicate(true)

		ConfigManager.save_textural_palettes(_tile_wfc_patterns)
	)



# ==============================================================================
# UI ROUTING
# ==============================================================================
func _on_ui_interaction(key: String, value: Variant) -> void:
	match key:
		"btn_rasterize":
			_on_rasterize_pressed()
		
		"btn_clear":
			_on_clear_pressed()
		
		"btn_open_mapper":
			_mapping_popup.open(_tileset_image_path, _tileset_tile_size, _atlas_mappings, _procedural_flags, _palette_params)
		
		"btn_open_structure_designer":
			_structure_popup.open()
		
		"btn_open_scatter_designer":
			_scatter_popup.open()
		
		"btn_biome_interactions":
			_interaction_popup.open()
		
		"btn_open_biome_designer":
			_biome_designer.open(_params)
		
		"btn_open_custom_room_designer":
			_custom_room_popup.open(_tileset_image_path, _tileset_tile_size, _custom_rooms, _custom_structures, _scatter_sets)
		
		# --- WFC ROUTER ---
		"btn_open_wfc_designer":
			_wfc_popup.open(_tileset_image_path, _tileset_tile_size, _wfc_modules, _scatter_sets)
		
		"btn_open_tile_wfc_designer":
			_tile_wfc_popup.open(_tileset_image_path, _tileset_tile_size, _tile_wfc_patterns)
		
		_:
			# Catch-all: all toggles, generic settings, debug visibility, etc.
			_params[key] = value
			ConfigManager.save_global_params(_params)
			
			# Only for instant visibility toggles, redraw the current overlay state.
			if key.begins_with("show_") or key == "debug_routing":
				if not _snapshots.is_empty() and tile_map_layer:
					_renderer.render_overlays(_realizer, _snapshots[-1]["entities"], _params, _execution_manager.is_rasterizing)

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
				
		# 4. Textural WFC
		if b_data.get("override_wfc", false):
			clean_data["override_wfc"] = true
			if b_data.has("wfc_palette_ref"):
				clean_data["wfc_palette_ref"] = b_data["wfc_palette_ref"]
				
		# Only append if this biome actually has active overrides
		if not clean_data.is_empty():
			filtered[b_key] = clean_data
			
	return filtered

# ==============================================================================
# EXECUTION ROUTING
# ==============================================================================
func _on_rasterize_pressed() -> void:
	if _execution_manager.is_rasterizing: return
	if not graph_editor or not "graph" in graph_editor: return
	if not tile_map_layer: return
	
	_params["custom_rooms"] = _custom_rooms
	_params["wfc_modules"] = _wfc_modules
	_params["tile_wfc_patterns"] = _tile_wfc_patterns
	_params["scatter_sets"] = _scatter_sets
	_params["biomes"] = _build_filtered_biomes()
	
	# --- [CHANGED] Pass the raw _biome_params down! ---
	_execution_manager.run_rasterization(graph_editor.graph, _params, _biome_params)

func _on_rasterization_started() -> void:
	_snapshots.clear()
	_timeline_tab.clear()
	_active_mapping.clear() 
	_report_tab.set_loading()
	_validation_tab.clear_logs()
	
	_renderer.clear_overlays()
	_tooltip_manager.is_active = false
	
	# --- Grab the reference instantly so the VCR has access to the Palette! ---
	_realizer = _execution_manager.current_realizer

func _on_snapshot_received(snapshot: Dictionary) -> void:
	_snapshots.append(snapshot)
	var idx = _snapshots.size() - 1
	_timeline_tab.add_snapshot(snapshot["name"])
	
	if _active_mapping.is_empty():
		_active_mapping = _renderer.rebuild_dynamic_tileset_and_mapping(_execution_manager.current_realizer, _custom_rooms, _atlas_mappings, _tileset_image_path, _tileset_tile_size, _procedural_flags, _palette_params)
	_jump_to_snapshot(idx)

func _on_rasterization_finished(realizer: GraphRealizer, report: Dictionary) -> void:
	_realizer = realizer
	_tooltip_manager.is_active = true
	_tooltip_manager.update_context(_realizer, _biome_params)
	
	_report_tab.update_report(report) 
	_timeline_tab.set_buttons_active(true)
	
	if not _snapshots.is_empty():
		_renderer.render_overlays(_realizer, _snapshots[-1]["entities"], _params, false)

func _on_validation_run_requested(visualize: bool, full_explore: bool, delay_doors: bool) -> void:
	if _execution_manager.is_rasterizing: return
	if not _realizer or not _realizer.grid:
		_validation_tab.append_log("[color=red]Error: Rasterize the graph first.[/color]")
		return
		
	_execution_manager.run_validation(_realizer.grid, visualize, full_explore, delay_doors)

func _on_validation_started() -> void:
	_validation_tab.clear_logs()
	_validation_tab.set_running(true)
	for child in tile_map_layer.get_children():
		if child.is_in_group("validator_overlay"): child.queue_free()

func _on_validation_flood(cells: Array, color_index: int) -> void:
	if not tile_map_layer or not tile_map_layer.tile_set: return
	var cell_size = float(tile_map_layer.tile_set.tile_size.x)
	var is_vis = _validation_tab.is_visualize_on()
	
	for pos in cells:
		var rect = ColorRect.new()
		var hue = fmod(0.55 + (color_index * 0.0005), 1.0)
		rect.color = Color.from_hsv(hue, 0.8, 1.0, 0.4) 
		rect.size = Vector2(cell_size, cell_size)
		rect.position = Vector2(pos.x * cell_size, pos.y * cell_size)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.visible = is_vis 
		rect.add_to_group("validator_overlay")
		tile_map_layer.add_child(rect)

func _on_validation_stop_requested() -> void:
	_execution_manager.cancel_validation()

func _on_visualize_toggled(is_on: bool) -> void:
	if tile_map_layer:
		for child in tile_map_layer.get_children():
			if child.is_in_group("validator_overlay"): child.visible = is_on

# ==============================================================================
# TIMELINE / VCR RENDERER
# ==============================================================================
func _on_step_list_selected(index: int) -> void:
	if _execution_manager.is_rasterizing: return 
	_jump_to_snapshot(index)

func _jump_to_snapshot(index: int) -> void:
	if _snapshots.is_empty() or _active_mapping.is_empty(): return
	
	# [FIXED] Cancel running validator if user scrubs timeline
	_execution_manager.cancel_validation()
	_validation_tab.set_running(false)
	
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
		
	_renderer.render_overlays(_realizer, snapshot["entities"], _params, _execution_manager.is_rasterizing)
	_tooltip_manager.update_context(_realizer, _biome_params)


# ==============================================================================
# CLEANUP
# ==============================================================================
func _on_clear_pressed() -> void:
	if _execution_manager.is_rasterizing: return
	
	_execution_manager.cancel_validation()
	_validation_tab.set_running(false)
		
	if tile_map_layer:
		tile_map_layer.clear()
		_renderer.clear_overlays()
				
	_realizer = null
	_tooltip_manager.is_active = false
	_snapshots.clear()
	_timeline_tab.clear()
	_report_tab.clear()
	_validation_tab.clear_logs()
