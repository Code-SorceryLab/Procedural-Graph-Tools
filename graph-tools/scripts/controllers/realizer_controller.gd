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

# --- VIEWS ---
var _generator_tab: GeneratorTabView
var _timeline_tab: TimelineTabView
var _report_tab: ReportTabView
var _validation_tab: ValidationTabView

# --- TOOLTIP REFS ---
var _tooltip_layer: CanvasLayer
var _tooltip_panel: PanelContainer
var _tooltip_label: Label

var _atlas_mappings: Dictionary = { "default_floor": Vector2i(0, 0), "default_wall": Vector2i(1, 0) }
var _tileset_image_path: String = ""
var _tileset_tile_size: Vector2i = Vector2i(16, 16)

var _mapping_popup: TileMappingPopup
var _shape_popup: AlgorithmSettingsPopup
var _structure_popup: StructureDesignerPopup
var _interaction_popup: BiomeInteractionPopup
var _scatter_popup: ScatterDesignerPopup

var _custom_structures: Dictionary = {} 
var _scatter_sets: Dictionary = {}
var _procedural_flags: Dictionary = {}
var _palette_params: Dictionary = {}

var _biome_selector: ConfirmationDialog
var _biome_dropdown: OptionButton
var _current_editing_biome: String = ""
var _biome_params: Dictionary = {}

func _ready() -> void:
	# --- SETUP HOVER TOOLTIP ---
	_tooltip_layer = CanvasLayer.new()
	_tooltip_layer.layer = 100 
	add_child(_tooltip_layer)
	
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
	_tooltip_layer.add_child(_tooltip_panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8); margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8); margin.add_theme_constant_override("margin_bottom", 8)
	_tooltip_panel.add_child(margin)
	
	_tooltip_label = Label.new()
	_tooltip_label.add_theme_font_size_override("font_size", 12)
	margin.add_child(_tooltip_label)
	
	_custom_structures = ConfigManager.load_structures() 
	_scatter_sets = ConfigManager.load_scatter_sets() # Load the scatter sets
	
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
	
	_generator_tab.build(_custom_structures, _params)
	
	# Instantiate popups
	_mapping_popup = TileMappingPopup.new(); add_child(_mapping_popup); _mapping_popup.confirmed.connect(_on_mapping_confirmed)
	_shape_popup = AlgorithmSettingsPopup.new(); add_child(_shape_popup); _shape_popup.settings_confirmed.connect(_on_shape_settings_confirmed)
	_shape_popup.canceled.connect(func(): _current_editing_biome = "")
	_structure_popup = StructureDesignerPopup.new(); add_child(_structure_popup); _structure_popup.confirmed.connect(_on_structure_designer_saved)
	_interaction_popup = BiomeInteractionPopup.new(); add_child(_interaction_popup); _interaction_popup.confirmed.connect(_on_interaction_popup_saved)
	_scatter_popup = ScatterDesignerPopup.new(); add_child(_scatter_popup); _scatter_popup.confirmed.connect(_on_scatter_designer_saved)
	
	_biome_selector = ConfirmationDialog.new()
	_biome_selector.title = "Select Biome to Override"
	var vb = VBoxContainer.new()
	var lbl = Label.new(); lbl.text = "Select Semantic Category:"
	vb.add_child(lbl)
	_biome_dropdown = OptionButton.new()
	vb.add_child(_biome_dropdown)
	_biome_selector.add_child(vb)
	add_child(_biome_selector)
	_biome_selector.confirmed.connect(_on_biome_selected)
	
	_biome_params = ConfigManager.load_biome_overrides()
	_update_biome_button_text()
	
	var saved_data = ConfigManager.load_rasterizer_mappings()
	if saved_data.has("mappings") and not saved_data["mappings"].is_empty(): _atlas_mappings.merge(saved_data["mappings"], true)
	if saved_data.has("procedural_flags"): _procedural_flags.merge(saved_data["procedural_flags"], true)
	if saved_data.has("palette_params"): _palette_params.merge(saved_data["palette_params"], true)
	_tileset_image_path = saved_data.get("texture_path", "")
	_tileset_tile_size = saved_data.get("tile_size", Vector2i(16, 16))

static func get_base_biome_rules() -> Array[Dictionary]:
	return [
		{ "name": "ratio_square", "label": "Square Weight", "type": TYPE_INT, "default": 1, "min": 0 },
		{ "name": "ratio_circle", "label": "Circle Weight", "type": TYPE_INT, "default": 0, "min": 0 },
		{ "name": "ratio_triangle", "label": "Triangle Weight", "type": TYPE_INT, "default": 0, "min": 0 },
		{ "name": "sep_rooms", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "room_radius_min", "label": "Min Room Radius", "type": TYPE_INT, "default": 2, "min": 1, "max": 20 },
		{ "name": "room_radius_max", "label": "Max Room Radius", "type": TYPE_INT, "default": 4, "min": 1, "max": 20 },
		{ "name": "enable_room_merging", "label": "Enable Room Merging", "type": TYPE_BOOL, "default": true },
		{ "name": "room_merge_tolerance", "label": "Merge Distance Range", "type": TYPE_FLOAT, "default": 0.8, "min": 0.5, "max": 2.0, "step": 0.05 },
		{ "name": "sep_routing", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "routing_mode", "label": "Routing Style", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "Organic (A*),Orthogonal (L-Path)" },
		{ "name": "allow_diagonal_corridors", "label": "Diagonal Corridors", "type": TYPE_BOOL, "default": false },
		{ "name": "corridor_thickness", "label": "Corridor Thickness", "type": TYPE_INT, "default": 1, "min": 1, "max": 10 },
		{ "name": "corridor_erosion", "label": "Corridor Erosion", "type": TYPE_FLOAT, "default": 0.0, "min": 0.0, "max": 0.9, "step": 0.05 },
		{ "name": "corridor_erosion_scale", "label": "Erosion Chunk Size", "type": TYPE_FLOAT, "default": 0.1, "min": 0.01, "max": 0.5, "step": 0.01 },
		{ "name": "sep_ca", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "ca_iterations", "label": "CA Smoothing Passes", "type": TYPE_INT, "default": 0, "min": 0, "max": 10 },
		{ "name": "ca_survive_min", "label": "CA Survive Min", "type": TYPE_INT, "default": 4, "min": 0, "max": 8 },
		{ "name": "ca_birth_min", "label": "CA Birth Min", "type": TYPE_INT, "default": 5, "min": 0, "max": 8 }
		
		# [FIXED] All hardcoded scatter settings have been removed!
	]

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseMotion: return
	
	# Your exact suggestion: disable the tooltip entirely while generating!
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
	
	if _realizer.floor_to_semantic.has(cell_id):
		var cat_key = _realizer.floor_to_semantic[cell_id]
		if SemanticRegistry.categories[SemanticRegistry.TARGET_NODE].has(cat_key):
			biome_name = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE][cat_key].name
	else:
		terrain_type = "Wall"
		var found = false
		for floor_key in _realizer.semantic_wall_map:
			if _realizer.semantic_wall_map[floor_key] == cell_id:
				if _realizer.floor_to_semantic.has(floor_key):
					var cat_key = _realizer.floor_to_semantic[floor_key]
					if SemanticRegistry.categories[SemanticRegistry.TARGET_NODE].has(cat_key):
						biome_name = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE][cat_key].name
						found = true; break
		if not found: biome_name = "Default Global"
			
	var entity_str = ""
	if _realizer.grid.entities.has(map_pos):
		var ent = _realizer.grid.entities[map_pos]
		var e_type = ent.get("type", "Unknown")
		if e_type == "structure": entity_str = "\n[Structure] : " + ent.get("name", "Custom")
		elif e_type == "door": entity_str = "\n[Portal ID: %d]\nLock: %s" % [ent.get("portal_id", -1), ent.get("lock_type", "Unlocked")]
		else:
			var req = ent.get("key_type", "")
			if req != "": entity_str = "\n[Item] : Key (" + req + ")"
			else: entity_str = "\n[Entity] : " + ent.get("name", "Scatter Prop")
				
	var text = "[ %d, %d ]\n" % [map_pos.x, map_pos.y]
	if _realizer.has_meta("cell_to_area"):
		var c2a = _realizer.get_meta("cell_to_area")
		if c2a.has(map_pos): text += "Area Depth: %d\n" % c2a[map_pos]
			
	text += "Biome: %s\n" % biome_name
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
		
	#elif key == "btn_shape_ratios":
		#_current_editing_biome = "" 
		#var shape_schema: Array[Dictionary] = [
			#{ "name": "ratio_square", "label": "Square Weight", "type": TYPE_INT, "default": _params.get("ratio_square", 1), "min": 0 },
			#{ "name": "ratio_circle", "label": "Circle Weight", "type": TYPE_INT, "default": _params.get("ratio_circle", 0), "min": 0 },
			#{ "name": "ratio_triangle", "label": "Triangle Weight", "type": TYPE_INT, "default": _params.get("ratio_triangle", 0), "min": 0 }
		#]
		#_shape_popup.open_settings("Global Shape Distribution", shape_schema, _params)
		
	elif key == "btn_global_structures":
		_current_editing_biome = "" 
		var struct_schema: Array[Dictionary] = [
			{ "name": "structure_use_density", "label": "Use Density Scatter Mode", "type": TYPE_BOOL, "default": _params.get("structure_use_density", false) },
			{ "name": "sep_str_1", "type": TYPE_NIL, "hint": "separator" },
			{ "name": "spawn_structure", "label": "[Ratio] Spawn Any Structure", "type": TYPE_BOOL, "default": _params.get("spawn_structure", false) }
		]
		
		if _custom_structures.size() > 0:
			struct_schema.append({ "name": "sep_str_weights", "type": TYPE_NIL, "hint": "separator" })
			for structure_key in _custom_structures:
				var s_name = _custom_structures[structure_key].get("name", "Unnamed")
				struct_schema.append({ "name": "weight_" + structure_key, "label": "[Ratio] " + s_name + " Weight", "type": TYPE_INT, "default": _params.get("weight_" + structure_key, 0), "min": 0, "max": 100 })
				struct_schema.append({ "name": "density_" + structure_key, "label": "[Density] " + s_name + " Chance", "type": TYPE_FLOAT, "default": _params.get("density_" + structure_key, 0.0), "min": 0.0, "max": 1.0, "step": 0.001 })
				
		_shape_popup.open_settings("Global Structure Rules", struct_schema, _params)
	
	elif key == "btn_biome_interactions": _interaction_popup.open()
	
	# Dynamic Global Scatter Set Editor
	elif key == "btn_global_scatter":
		_current_editing_biome = "" 
		var scatter_schema: Array[Dictionary] = []
		
		if _scatter_sets.size() > 0:
			for s_key in _scatter_sets:
				var s_name = _scatter_sets[s_key].get("name", "Unnamed Set")
				var mode = _scatter_sets[s_key].get("spawn_mode", 0)
				
				if mode == 0:
					scatter_schema.append({ "name": "density_" + s_key, "label": "[Density] " + s_name, "type": TYPE_FLOAT, "default": _params.get("density_" + s_key, _scatter_sets[s_key].get("density", 0.05)), "min": 0.0, "max": 1.0, "step": 0.001 })
				else:
					scatter_schema.append({ "name": "fixed_quantity_" + s_key, "label": "[Fixed] " + s_name, "type": TYPE_INT, "default": _params.get("fixed_quantity_" + s_key, _scatter_sets[s_key].get("fixed_quantity", 1)), "min": 0, "max": 999 })
		else:
			scatter_schema.append({ "name": "no_sets", "label": "No Scatter Sets created yet.", "type": TYPE_NIL, "hint": "read_only", "default": "" })
			
		_shape_popup.open_settings("Global Scatter Rules", scatter_schema, _params)
	
	elif key == "btn_biome_config":
		_biome_dropdown.clear()
		var node_cats = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE]
		var keys = []
		for cat_key in node_cats:
			keys.append(cat_key)
			var cat = node_cats[cat_key]
			var display_name = cat["name"]
			if _biome_params.has(cat_key) and _biome_params[cat_key].get("override_enabled", false): display_name += "  [ ACTIVE ]"
				
			var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			img.fill(cat["color"])
			var border_color = cat["color"].darkened(0.5)
			for x in range(16):
				img.set_pixel(x, 0, border_color); img.set_pixel(x, 15, border_color)
			for y in range(16):
				img.set_pixel(0, y, border_color); img.set_pixel(15, y, border_color)
				
			var tex = ImageTexture.create_from_image(img)
			_biome_dropdown.add_icon_item(tex, display_name)
			
		_biome_dropdown.set_meta("keys", keys)
		_biome_selector.popup_centered(Vector2(320, 100)) 
	
	elif key == "show_entities":
		_params[key] = value
		if tile_map_layer:
			for child in tile_map_layer.get_children():
				if child.is_in_group("realizer_entity"): child.visible = value
					
	elif key == "debug_routing":
		_params[key] = value
		if tile_map_layer:
			for child in tile_map_layer.get_children():
				if child.is_in_group("realizer_critical_path"): child.visible = value
	else:
		_params[key] = value

func _on_mapping_confirmed() -> void:
	_atlas_mappings = _mapping_popup.mappings.duplicate()
	_procedural_flags = _mapping_popup.procedural_flags.duplicate()
	_palette_params = _mapping_popup.palette_editor.params.duplicate()
	_tileset_image_path = _mapping_popup.atlas_texture_path
	_tileset_tile_size = _mapping_popup.tile_size
	ConfigManager.save_rasterizer_mappings(_atlas_mappings, _tileset_image_path, _tileset_tile_size, _procedural_flags, _palette_params)

func _on_shape_settings_confirmed(new_settings: Dictionary) -> void:
	if _current_editing_biome != "":
		_biome_params[_current_editing_biome] = new_settings
		_current_editing_biome = "" 
		_update_biome_button_text() 
		ConfigManager.save_biome_overrides(_biome_params)
	else:
		_params.merge(new_settings, true)

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

func _on_biome_selected() -> void:
	var idx = _biome_dropdown.selected
	if idx < 0: return
	var keys = _biome_dropdown.get_meta("keys")
	_current_editing_biome = keys[idx]
	var biome_name = _biome_dropdown.get_item_text(idx)
	
	var current_vals = _biome_params.get(_current_editing_biome, { "override_enabled": false })
	var base_rules = get_base_biome_rules()
	
	for rule in base_rules:
		if rule.has("default") and not current_vals.has(rule["name"]):
			current_vals[rule["name"]] = _params.get(rule["name"], rule["default"])
			
	if not current_vals.has("structure_use_density"): current_vals["structure_use_density"] = _params.get("structure_use_density", false)
	if not current_vals.has("spawn_structure"): current_vals["spawn_structure"] = _params.get("spawn_structure", false)
	
	for key in _custom_structures:
		var w_name = "weight_" + key
		if not current_vals.has(w_name): current_vals[w_name] = _params.get(w_name, 0)
		var d_name = "density_" + key
		if not current_vals.has(d_name): current_vals[d_name] = _params.get(d_name, 0.0)

	# [NEW] Pull fallbacks for Scatter Sets
	for key in _scatter_sets:
		var mode = _scatter_sets[key].get("spawn_mode", 0)
		if mode == 0:
			var d_name = "density_" + key
			if not current_vals.has(d_name): current_vals[d_name] = _params.get(d_name, _scatter_sets[key].get("density", 0.05))
		else:
			var f_name = "fixed_quantity_" + key
			if not current_vals.has(f_name): current_vals[f_name] = _params.get(f_name, _scatter_sets[key].get("fixed_quantity", 1))

	var schema: Array[Dictionary] = [
		{ "name": "override_enabled", "label": "Enable Biome Overrides", "type": TYPE_BOOL, "default": false },
		{ "name": "sep_1", "type": TYPE_NIL, "hint": "separator" }
	]
	
	schema.append_array(base_rules)
	
	# [NEW] Inject Scatter Sets into Biome UI
	if _scatter_sets.size() > 0:
		schema.append({ "name": "sep_scatter", "type": TYPE_NIL, "hint": "separator" })
		for key in _scatter_sets:
			var s_name = _scatter_sets[key].get("name", "Unnamed Set")
			var mode = _scatter_sets[key].get("spawn_mode", 0)
			if mode == 0:
				schema.append({ "name": "density_" + key, "label": "[Density] " + s_name, "type": TYPE_FLOAT, "default": _scatter_sets[key].get("density", 0.05), "min": 0.0, "max": 1.0, "step": 0.001 })
			else:
				schema.append({ "name": "fixed_quantity_" + key, "label": "[Fixed] " + s_name, "type": TYPE_INT, "default": _scatter_sets[key].get("fixed_quantity", 1), "min": 0, "max": 999 })
	
	# Append Custom Structures
	if _custom_structures.size() > 0:
		schema.append({ "name": "sep_7", "type": TYPE_NIL, "hint": "separator" })
		schema.append({ "name": "structure_use_density", "label": "Use Density Scatter Mode", "type": TYPE_BOOL, "default": false })
		schema.append({ "name": "spawn_structure", "label": "[Ratio] Spawn Any Structure", "type": TYPE_BOOL, "default": false })
		for key in _custom_structures:
			var s_name = _custom_structures[key].get("name", "Unnamed")
			schema.append({ "name": "weight_" + key, "label": "[Ratio] " + s_name + " Weight", "type": TYPE_INT, "default": 0, "min": 0, "max": 100 })
			schema.append({ "name": "density_" + key, "label": "[Density] " + s_name + " Chance", "type": TYPE_FLOAT, "default": 0.0, "min": 0.0, "max": 1.0, "step": 0.001 })
	
	_shape_popup.open_settings(biome_name + " Rules", schema, current_vals)

# ==============================================================================
# PIPELINE EXECUTION (THREADED)
# ==============================================================================
func _on_rasterize_pressed() -> void:
	if _is_rasterizing: return
	if not graph_editor or not "graph" in graph_editor: return
	var graph = graph_editor.graph
	if graph == null or graph.nodes.is_empty(): return
	if not tile_map_layer: return
	
	# Clean up any running Validator before replacing the map!
	if _validator_thread and _validator_thread.is_started():
		_cancel_validation = true
		_validator_thread.wait_to_finish()

	if _params.get("use_biome_overrides", true): _params["biomes"] = _biome_params
	else: _params["biomes"] = {}
		
	_snapshots.clear()
	_timeline_tab.clear()
	_active_mapping.clear() 
	_report_tab.set_loading()
	_validation_tab.clear_logs()
	
	# Clear visual overlays, including old validator paints
	for child in tile_map_layer.get_children():
		if child.is_in_group("realizer_entity") or child.is_in_group("realizer_critical_path") or child.is_in_group("validator_overlay"):
			child.queue_free()
	
	_is_rasterizing = true
	_realizer = GraphRealizer.new()
	
	if _raster_thread and _raster_thread.is_started():
		_raster_thread.wait_to_finish()
	_raster_thread = Thread.new()
	_raster_thread.start(_run_rasterization_thread.bind(graph, _params))

func _run_rasterization_thread(graph: Graph, params: Dictionary) -> void:
	_realizer.realize(graph, params, _on_snapshot_received)
	call_deferred("_on_rasterization_finished")

func _on_snapshot_received(step_name: String, cells: PackedInt32Array, entities: Dictionary, w: int, h: int) -> void:
	_snapshots.append({ "name": step_name, "cells": cells, "entities": entities, "w": w, "h": h })
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
func _on_validation_run_requested(visualize: bool, full_explore: bool) -> void:
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
	# [FIXED] Pass full_explore into the bound thread
	_validator_thread.start(_run_validation_thread.bind(_realizer.grid, visualize, full_explore))

func _run_validation_thread(grid: GridData, visualize: bool, full_explore: bool) -> void:
	var emit_func = func(type: String, data: Variant = null):
		call_deferred("_on_validation_event", type, data)
	var cancel_func = func() -> bool: return _cancel_validation
		
	# Pass it down to the validator script
	var result = GenerationValidator.run(grid, visualize, full_explore, emit_func, cancel_func)
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


func _on_validation_finished(success: bool) -> void:
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

func _render_overlays(entities: Dictionary) -> void:
	for child in tile_map_layer.get_children():
		if child.is_in_group("realizer_entity") or child.is_in_group("realizer_critical_path") or child.is_in_group("validator_overlay"):
			child.queue_free()
			
	if not tile_map_layer.tile_set: return
	var cell_size = float(tile_map_layer.tile_set.tile_size.x)
	
	# A. Render Critical Path Overlays
	var show_path = _params.get("debug_routing", false)
	
	# Do not attempt to read the critical path while the thread is actively mutating it!
	if _realizer and not _is_rasterizing: 
		for pos in _realizer.critical_path_cells:
			var rect = ColorRect.new()
			rect.color = Color(1.0, 0.0, 1.0, 0.4)
			rect.size = Vector2(cell_size, cell_size) 
			rect.position = Vector2(pos.x * cell_size, pos.y * cell_size)
			rect.visible = show_path
			rect.add_to_group("realizer_critical_path")
			tile_map_layer.add_child(rect)

	var show_entities = _params.get("show_entities", true)
	for pos in entities:
		var entity_data = entities[pos]
		var e_type = entity_data.get("type", "generic_entity")
		var rect = ColorRect.new()
		
		if e_type == "structure":
			var struct_color = entity_data.get("color", Color(0.2, 0.6, 1.0, 0.7))
			var footprint_world = entity_data.get("footprint_world", [])
			for pt in footprint_world:
				var pt_rect = ColorRect.new()
				pt_rect.color = struct_color
				pt_rect.size = Vector2(cell_size, cell_size)
				pt_rect.position = Vector2(pt.x * cell_size, pt.y * cell_size)
				pt_rect.visible = show_entities
				pt_rect.add_to_group("realizer_entity")
				tile_map_layer.add_child(pt_rect)
			continue 
			
		elif e_type == "door":
			var l_type = entity_data.get("lock_type", "Unlocked")
			var c_map = {"Unlocked": Color(0.8, 0.5, 0.2, 0.9), "Red": Color.RED, "Blue": Color.BLUE, "Green": Color.GREEN, "Yellow": Color.YELLOW, "Purple": Color.PURPLE, "Cyan": Color.CYAN, "Orange": Color.ORANGE}
			rect.color = c_map.get(l_type, Color(0.8, 0.5, 0.2, 0.9))
			rect.size = Vector2(cell_size, cell_size)
			rect.position = Vector2(pos.x * cell_size, pos.y * cell_size)
			
		elif e_type == "start_point":
			rect.color = Color(0.2, 1.0, 0.2, 0.9)
			rect.size = Vector2(cell_size * 0.8, cell_size * 0.8) 
			rect.position = Vector2(pos.x * cell_size + (cell_size * 0.1), pos.y * cell_size + (cell_size * 0.1))
			
		elif e_type == "end_point":
			rect.color = Color(1.0, 0.2, 0.2, 0.9)
			rect.size = Vector2(cell_size * 0.8, cell_size * 0.8) 
			rect.position = Vector2(pos.x * cell_size + (cell_size * 0.1), pos.y * cell_size + (cell_size * 0.1))
			
		elif e_type == "key":
			var k_col = entity_data.get("key_type", "Red")
			if k_col.begins_with("Tier"): rect.color = Color.WHITE
			else:
				var c_map = {"Red": Color.RED, "Blue": Color.BLUE, "Green": Color.GREEN, "Yellow": Color.YELLOW, "Purple": Color.PURPLE, "Cyan": Color.CYAN, "Orange": Color.ORANGE}
				rect.color = c_map.get(k_col, Color.WHITE)
			rect.size = Vector2(cell_size * 0.5, cell_size * 0.5) 
			rect.position = Vector2(pos.x * cell_size + (cell_size * 0.25), pos.y * cell_size + (cell_size * 0.25))
			
		elif e_type == "fringe":
			rect.color = Color(0.2, 0.9, 0.2, 0.8)
			rect.size = Vector2(cell_size * 0.4, cell_size * 0.4) 
			rect.position = Vector2(pos.x * cell_size + (cell_size * 0.3), pos.y * cell_size + (cell_size * 0.3))
			
		else:
			# Draw custom scatter entity colors dynamically!
			rect.color = entity_data.get("color", Color(1.0, 0.8, 0.0, 0.4))
			rect.size = Vector2(cell_size * 0.5, cell_size * 0.5) 
			rect.position = Vector2(pos.x * cell_size + (cell_size * 0.25), pos.y * cell_size + (cell_size * 0.25))
		
		rect.visible = show_entities
		rect.add_to_group("realizer_entity")
		tile_map_layer.add_child(rect)

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

func _update_biome_button_text() -> void:
	var active_count = 0
	for b_key in _biome_params:
		if _biome_params[b_key].get("override_enabled", false): active_count += 1
	_generator_tab.update_biome_button(active_count)
