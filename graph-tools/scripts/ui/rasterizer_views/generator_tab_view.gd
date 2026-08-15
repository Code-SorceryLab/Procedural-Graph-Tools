class_name GeneratorTabView
extends MarginContainer

signal interaction_triggered(key: String, value: Variant)

var active_inputs: Dictionary = {}

func _init() -> void:
	name = "Generator"
	add_theme_constant_override("margin_top", 5)
	add_theme_constant_override("margin_left", 5)
	add_theme_constant_override("margin_right", 5)
	add_theme_constant_override("margin_bottom", 5)

func build(custom_structures: Dictionary, current_params: Dictionary) -> void:
	for child in get_children():
		child.queue_free()
		
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	
	var schema = [
		{ "name": "btn_rasterize", "label": "Rasterize Graph", "type": TYPE_NIL, "hint": "action" },
		{ "name": "btn_clear", "label": "Clear TileMap", "type": TYPE_NIL, "hint": "action" },
		{ "name": "sep_1", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "btn_open_mapper", "label": "Open Visual Tile Mapper", "type": TYPE_NIL, "hint": "action" },
		{ "name": "btn_open_structure_designer", "label": "Open Structure Designer", "type": TYPE_NIL, "hint": "action" },
		{ "name": "sep_mapper", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "realizer_seed", "label": "Generator Seed", "type": TYPE_STRING, "default": "research_01", 
		  "hint_text": "Determines the random sizing of rooms. The same seed produces identical room sizes for a given graph topology." },
		{ "name": "grid_scale", "label": "Grid Scale", "type": TYPE_FLOAT, "default": 25.0, "step": 1.0, "min": 10.0, "max": 200.0, 
		  "hint_text": "How many abstract graph pixels map to 1 physical TileMap cell. (e.g. 25 Graph Units = 1 Tile)" },
		{ "name": "padding", "label": "Map Padding", "type": TYPE_INT, "default": 15, "min": 0, "max": 20, 
		  "hint_text": "Extra tiles added around the outermost boundaries of the map to prevent rooms on the edges from being clipped." },
		{ "name": "sep_2", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "btn_shape_ratios", "label": "Global Shape Ratios...", "type": TYPE_NIL, "hint": "button" },
		{ "name": "btn_global_structures", "label": "Global Structure Rules...", "type": TYPE_NIL, "hint": "button" },
		{ "name": "use_biome_overrides", "label": "Use Biome Overrides", "type": TYPE_BOOL, "default": true, 
		  "hint_text": "If disabled, all rooms will use the global rasterization settings regardless of their type." },
		{ "name": "btn_biome_config", "label": "Override Biome Rules...", "type": TYPE_NIL, "hint": "button" },
		{ "name": "btn_biome_interactions", "label": "Biome Edge Matrix...", "type": TYPE_NIL, "hint": "button" },
		
		{ "name": "room_radius_min", "label": "Min Room Radius", "type": TYPE_INT, "default": 2, "min": 1, "max": 20 },
		{ "name": "room_radius_max", "label": "Max Room Radius", "type": TYPE_INT, "default": 4, "min": 1, "max": 20 },
		{ "name": "enable_room_merging", "label": "Enable Room Merging", "type": TYPE_BOOL, "default": true },
		{ "name": "room_merge_tolerance", "label": "Merge Distance Range", "type": TYPE_FLOAT, "default": 0.8, "min": 0.5, "max": 2.0, "step": 0.05 },
		{ "name": "sep_3", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "routing_mode", "label": "Routing Style", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "Organic (A*),Orthogonal (L-Path)" },
		{ "name": "allow_diagonal_corridors", "label": "Diagonal Corridors", "type": TYPE_BOOL, "default": false },
		{ "name": "corridor_thickness", "label": "Corridor Thickness", "type": TYPE_INT, "default": 1, "min": 1, "max": 10 },
		
		{ "name": "corridor_erosion", "label": "Corridor Erosion", "type": TYPE_FLOAT, "default": 0.0, "min": 0.0, "max": 0.9, "step": 0.05 },
		{ "name": "corridor_erosion_scale", "label": "Erosion Chunk Size", "type": TYPE_FLOAT, "default": 0.1, "min": 0.01, "max": 0.5, "step": 0.01 },
		
		{ "name": "debug_routing", "label": "Show Critical Path", "type": TYPE_BOOL, "default": false },
		{ "name": "sep_4", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "ca_iterations", "label": "CA Smoothing Passes", "type": TYPE_INT, "default": 0, "min": 0, "max": 10 },
		{ "name": "ca_survive_min", "label": "CA Survive Min", "type": TYPE_INT, "default": 4, "min": 0, "max": 8 },
		{ "name": "ca_birth_min", "label": "CA Birth Min", "type": TYPE_INT, "default": 5, "min": 0, "max": 8 },
		
		{ "name": "sep_scatter", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "scatter_density", "label": "Entity Scatter Density", "type": TYPE_FLOAT, "default": 0.05, "min": 0.0, "max": 0.5, "step": 0.001 },
		{ "name": "scatter_min_dist", "label": "Scatter Min Wall Dist", "type": TYPE_INT, "default": 0, "min": 0, "max": 20 },
		{ "name": "scatter_max_dist", "label": "Scatter Max Wall Dist", "type": TYPE_INT, "default": 99, "min": 1, "max": 99 },
		{ "name": "structure_symmetry", "label": "Structure Symmetry", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "None,X-Axis (Left/Right),Y-Axis (Top/Bottom),Radial (Point),4-Way" },
		{ "name": "scatter_symmetry", "label": "Scatter Symmetry", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "None,X-Axis (Left/Right),Y-Axis (Top/Bottom),Radial (Point),4-Way" },

		{ "name": "show_entities", "label": "Show Scattered Entities", "type": TYPE_BOOL, "default": true },
		
		{ "name": "sep_prog", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "progression_enabled", "label": "Generate Locks & Keys", "type": TYPE_BOOL, "default": true },
		{ "name": "progression_lock_chance", "label": "Door Lock Chance", "type": TYPE_FLOAT, "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.05 },
		{ "name": "progression_max_locks", "label": "Max Locks (0: Unlimited)", "type": TYPE_INT, "default": 0, "min": 0, "max": 99 },
		{ "name": "progression_key_copies_min", "label": "Min Key Copies", "type": TYPE_INT, "default": 1, "min": 1, "max": 5 },
		{ "name": "progression_key_copies_max", "label": "Max Key Copies", "type": TYPE_INT, "default": 2, "min": 1, "max": 5 },
		{ "name": "main_path_key_stash", "label": "Force Main Path Detours", "type": TYPE_BOOL, "default": true }
	]
	
	# Safely inject missing defaults without overriding user settings
	for item in schema:
		if item.has("default") and not current_params.has(item["name"]):
			current_params[item["name"]] = item["default"]
			
	if not current_params.has("ratio_square"): current_params["ratio_square"] = 1
	if not current_params.has("ratio_circle"): current_params["ratio_circle"] = 0
	if not current_params.has("ratio_triangle"): current_params["ratio_triangle"] = 0
	if not current_params.has("structure_use_density"): current_params["structure_use_density"] = false
	if not current_params.has("spawn_structure"): current_params["spawn_structure"] = false
	
	for key in custom_structures:
		if not current_params.has("weight_" + key): current_params["weight_" + key] = 0
		if not current_params.has("density_" + key): current_params["density_" + key] = 0.0
			
	var section = SettingsUIBuilder.create_collapsible_section(vbox, "TileMap Realizer", true)
	active_inputs = SettingsUIBuilder.render_dynamic_section(section, schema, func(k, v): interaction_triggered.emit(k, v))

func update_biome_button(active_count: int) -> void:
	if not active_inputs.has("btn_biome_config"): return
	var btn = active_inputs["btn_biome_config"] as Button
	if active_count > 0:
		btn.text = "Override Biome Rules (%d Active)..." % active_count
		btn.modulate = Color(0.6, 1.0, 0.6)
	else:
		btn.text = "Override Biome Rules..."
		btn.modulate = Color.WHITE
