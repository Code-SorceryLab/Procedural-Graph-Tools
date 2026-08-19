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
		{ "name": "btn_open_scatter_designer", "label": "Open Scatter Designer", "type": TYPE_NIL, "hint": "action" }, 
		{ "name": "sep_mapper", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "realizer_seed", "label": "Generator Seed", "type": TYPE_STRING, "default": "research_01", 
		  "hint_text": "Determines the random sizing of rooms. The same seed produces identical room sizes for a given graph topology." },
		{ "name": "grid_scale", "label": "Grid Scale", "type": TYPE_FLOAT, "default": 25.0, "step": 1.0, "min": 10.0, "max": 200.0 },
		{ "name": "padding", "label": "Map Padding", "type": TYPE_INT, "default": 15, "min": 0, "max": 20 },
		{ "name": "sep_2", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "btn_open_biome_designer", "label": "Biome & Generation Designer...", "type": TYPE_NIL, "hint": "button" },
		{ "name": "btn_biome_interactions", "label": "Biome Edge Matrix...", "type": TYPE_NIL, "hint": "button" },
		
		{ "name": "sep_view", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "show_entities", "label": "Master Entity Visibility", "type": TYPE_BOOL, "default": true },
		{ "name": "show_struct_sprites", "label": "  ↳ Show Structure Sprites", "type": TYPE_BOOL, "default": true },
		{ "name": "show_struct_footprints", "label": "  ↳ Show Structure Footprints", "type": TYPE_BOOL, "default": true },
		{ "name": "show_scatter_sprites", "label": "  ↳ Show Scatter Sprites", "type": TYPE_BOOL, "default": true },
		{ "name": "show_scatter_footprints", "label": "  ↳ Show Scatter Footprints", "type": TYPE_BOOL, "default": true },
		{ "name": "show_progression", "label": "  ↳ Show Locks & Keys", "type": TYPE_BOOL, "default": true },
		{ "name": "show_endpoints", "label": "  ↳ Show Start/End Points", "type": TYPE_BOOL, "default": true },
		{ "name": "debug_routing", "label": "Show Critical Path", "type": TYPE_BOOL, "default": false },
		
		{ "name": "sep_prog", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "progression_enabled", "label": "Generate Locks & Keys", "type": TYPE_BOOL, "default": true },
		{ "name": "progression_lock_chance", "label": "Door Lock Chance", "type": TYPE_FLOAT, "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.05 },
		{ "name": "progression_max_locks", "label": "Max Critical Locks (0: Unl)", "type": TYPE_INT, "default": 0, "min": 0, "max": 99 },
		{ "name": "progression_style_ratio", "label": "Key Style (0: Tiers, 1: Colors)", "type": TYPE_FLOAT, "default": 0.5, "min": 0.0, "max": 1.0, "step": 0.05 },
		
		{ "name": "sep_vaults", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "progression_max_vaults", "label": "Max Optional Vaults", "type": TYPE_INT, "default": 2, "min": 0, "max": 10 },
		{ "name": "main_path_key_stash", "label": "Force Main Path Detours", "type": TYPE_BOOL, "default": true },
		
		{ "name": "sep_shortcuts", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "progression_shortcut_min", "label": "Min Extra Shortcuts", "type": TYPE_INT, "default": 0, "min": 0, "max": 10 },
		{ "name": "progression_shortcut_max", "label": "Max Extra Shortcuts", "type": TYPE_INT, "default": 2, "min": 0, "max": 10 },
		{ "name": "progression_sequence_break_limit", "label": "Sequence Break Limit", "type": TYPE_INT, "default": 2, "min": 1, "max": 10 }
	]
	
	# Safely inject missing defaults without overriding user settings
	for item in schema:
		if item.has("default") and not current_params.has(item["name"]):
			current_params[item["name"]] = item["default"]
			
	var section = SettingsUIBuilder.create_collapsible_section(vbox, "TileMap Realizer", true)
	active_inputs = SettingsUIBuilder.render_dynamic_section(section, schema, func(k, v): interaction_triggered.emit(k, v))
