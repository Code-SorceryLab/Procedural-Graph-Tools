class_name RealizerConfigManager
extends Node

signal rasterize_requested()
signal clear_requested()
signal mappings_changed()
signal overlays_need_redraw()
signal regenerate_selection_requested()
signal btn_preview_regen_requested()

# --- POPUPS ---
var _biome_designer: BiomeDesignerPopup
var _mapping_popup: TileMappingPopup
var _structure_popup: StructureDesignerPopup
var _interaction_popup: BiomeInteractionPopup
var _scatter_popup: ScatterDesignerPopup
var _custom_room_popup: CustomRoomDesignerPopup
var _wfc_popup: WfcModuleDesignerPopup
var _tile_wfc_popup: TileWfcDesignerPopup

# --- CONFIG DATA ---
var global_params: Dictionary = {}
var biome_params: Dictionary = {}
var custom_rooms: Dictionary = {}
var wfc_modules: Dictionary = {}
var tile_wfc_patterns: Dictionary = {}
var custom_structures: Dictionary = {} 
var scatter_sets: Dictionary = {}
var procedural_flags: Dictionary = {}
var palette_params: Dictionary = {}
var atlas_mappings: Dictionary = { "default_floor": Vector2i(0, 0), "default_wall": Vector2i(1, 0) }
var tileset_image_path: String = ""
var tileset_tile_size: Vector2i = Vector2i(16, 16)

func setup() -> void:
	# 1. Load all configurations
	global_params = ConfigManager.load_global_params()
	custom_structures = ConfigManager.load_structures() 
	scatter_sets = ConfigManager.load_scatter_sets()
	biome_params = ConfigManager.load_biome_overrides()
	custom_rooms = ConfigManager.load_custom_rooms()
	wfc_modules = ConfigManager.load_wfc_modules()
	tile_wfc_patterns = ConfigManager.load_textural_palettes()
	
	var saved_data = ConfigManager.load_rasterizer_mappings()
	if saved_data.has("mappings") and not saved_data["mappings"].is_empty(): atlas_mappings.merge(saved_data["mappings"], true)
	if saved_data.has("procedural_flags"): procedural_flags.merge(saved_data["procedural_flags"], true)
	if saved_data.has("palette_params"): palette_params.merge(saved_data["palette_params"], true)
	tileset_image_path = saved_data.get("texture_path", "")
	tileset_tile_size = saved_data.get("tile_size", Vector2i(16, 16))

	# 2. Instantiate Popups & Connect Saves
	_mapping_popup = TileMappingPopup.new(); add_child(_mapping_popup)
	_mapping_popup.confirmed.connect(_on_mapping_confirmed)
	
	_structure_popup = StructureDesignerPopup.new(); add_child(_structure_popup)
	_structure_popup.confirmed.connect(_on_structure_designer_saved)
	
	_interaction_popup = BiomeInteractionPopup.new(); add_child(_interaction_popup)
	_interaction_popup.confirmed.connect(func(): ConfigManager.save_biome_interactions(_interaction_popup.interactions))
	
	_scatter_popup = ScatterDesignerPopup.new(); add_child(_scatter_popup)
	_scatter_popup.confirmed.connect(_on_scatter_designer_saved)
	
	_biome_designer = BiomeDesignerPopup.new(); add_child(_biome_designer)
	_biome_designer.global_settings_changed.connect(func(p): global_params = p; ConfigManager.save_global_params(p))
	_biome_designer.biome_settings_changed.connect(func(b): biome_params = b; ConfigManager.save_biome_overrides(b))
	_biome_designer.spawn_decks_changed.connect(func(d): ConfigManager.save_spawn_decks(d))
	_biome_designer.room_decks_changed.connect(func(d): ConfigManager.save_room_decks(d))
	
	_custom_room_popup = CustomRoomDesignerPopup.new(); _custom_room_popup.hide(); add_child(_custom_room_popup)
	_custom_room_popup.confirmed.connect(func(): custom_rooms = _custom_room_popup.custom_rooms.duplicate(true); ConfigManager.save_custom_rooms(custom_rooms))
	
	_wfc_popup = WfcModuleDesignerPopup.new(); _wfc_popup.hide(); add_child(_wfc_popup)
	_wfc_popup.confirmed.connect(func(m): wfc_modules = m.duplicate(true); ConfigManager.save_wfc_modules(wfc_modules))
	
	_tile_wfc_popup = TileWfcDesignerPopup.new(); _tile_wfc_popup.hide(); add_child(_tile_wfc_popup)
	_tile_wfc_popup.confirmed.connect(func(p): tile_wfc_patterns = p.duplicate(true); ConfigManager.save_textural_palettes(tile_wfc_patterns))

func handle_interaction(key: String, value: Variant) -> void:
	match key:
		"btn_rasterize": rasterize_requested.emit()
		"btn_regenerate_selection": regenerate_selection_requested.emit()
		"btn_preview_regen": btn_preview_regen_requested.emit()
		"btn_clear": clear_requested.emit()
		"btn_open_mapper": _mapping_popup.open(tileset_image_path, tileset_tile_size, atlas_mappings, procedural_flags, palette_params)
		"btn_open_structure_designer": _structure_popup.open()
		"btn_open_scatter_designer": _scatter_popup.open()
		"btn_biome_interactions": _interaction_popup.open()
		"btn_open_biome_designer": _biome_designer.open(global_params)
		"btn_open_custom_room_designer": _custom_room_popup.open(tileset_image_path, tileset_tile_size, custom_rooms, custom_structures, scatter_sets)
		"btn_open_wfc_designer": _wfc_popup.open(tileset_image_path, tileset_tile_size, wfc_modules, scatter_sets)
		"btn_open_tile_wfc_designer": _tile_wfc_popup.open(tileset_image_path, tileset_tile_size, tile_wfc_patterns)
		_:
			# Generic settings and toggles
			global_params[key] = value
			ConfigManager.save_global_params(global_params)
			if key.begins_with("show_") or key == "debug_routing":
				overlays_need_redraw.emit()

func _on_mapping_confirmed() -> void:
	atlas_mappings = _mapping_popup.mappings.duplicate()
	procedural_flags = _mapping_popup.procedural_flags.duplicate()
	palette_params = _mapping_popup.palette_editor.params.duplicate()
	tileset_image_path = _mapping_popup.atlas_texture_path
	tileset_tile_size = _mapping_popup.tile_size
	ConfigManager.save_rasterizer_mappings(atlas_mappings, tileset_image_path, tileset_tile_size, procedural_flags, palette_params)
	mappings_changed.emit()

func _on_structure_designer_saved() -> void:
	ConfigManager.save_structures(_structure_popup.structures)
	custom_structures = _structure_popup.structures.duplicate()
	for key in custom_structures:
		var weight_key = "weight_" + key
		if not global_params.has(weight_key): global_params[weight_key] = 0

func _on_scatter_designer_saved() -> void:
	ConfigManager.save_scatter_sets(_scatter_popup.scatter_sets)
	scatter_sets = _scatter_popup.scatter_sets.duplicate(true)
	for key in scatter_sets:
		var mode = scatter_sets[key].get("spawn_mode", 0)
		if mode == 0 and not global_params.has("density_" + key):
			global_params["density_" + key] = scatter_sets[key].get("density", 0.05)
		elif mode == 1 and not global_params.has("fixed_quantity_" + key):
			global_params["fixed_quantity_" + key] = scatter_sets[key].get("fixed_quantity", 1)

func get_execution_params() -> Dictionary:
	var p = global_params.duplicate(true)
	p["custom_rooms"] = custom_rooms
	p["wfc_modules"] = wfc_modules
	p["tile_wfc_patterns"] = tile_wfc_patterns
	p["scatter_sets"] = scatter_sets
	p["biomes"] = _build_filtered_biomes()
	return p

func _build_filtered_biomes() -> Dictionary:
	var filtered = {}
	for b_key in biome_params:
		var b_data = biome_params[b_key]
		var clean_data = {}
		
		if b_data.get("override_shape", false):
			for k in ["room_radius_min", "room_radius_max", "enable_room_merging", "room_merge_tolerance", "ratio_square", "ratio_circle", "ratio_triangle"]:
				if b_data.has(k): clean_data[k] = b_data[k]
				
		if b_data.get("override_routing", false):
			for k in ["routing_mode", "allow_diagonal_corridors", "corridor_thickness", "corridor_erosion", "corridor_erosion_scale", "ca_iterations", "ca_survive_min", "ca_birth_min"]:
				if b_data.has(k): clean_data[k] = b_data[k]
				
		if b_data.get("override_spawn_decks", false):
			clean_data["override_spawn_decks"] = true
			clean_data["override_enabled"] = true
			if b_data.has("spawn_decks"): clean_data["spawn_decks"] = b_data["spawn_decks"]
			
		if b_data.get("override_wfc", false):
			clean_data["override_wfc"] = true
			if b_data.has("wfc_palette_ref"): clean_data["wfc_palette_ref"] = b_data["wfc_palette_ref"]
			
		if not clean_data.is_empty():
			filtered[b_key] = clean_data
			
	return filtered
