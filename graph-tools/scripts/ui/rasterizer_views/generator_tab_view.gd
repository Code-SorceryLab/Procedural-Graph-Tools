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
		
		{ "name": "btn_global_structures", "label": "Global Structure Rules...", "type": TYPE_NIL, "hint": "button" },
		{ "name": "btn_global_scatter", "label": "Global Scatter Rules...", "type": TYPE_NIL, "hint": "button" },
		{ "name": "use_biome_overrides", "label": "Use Biome Overrides", "type": TYPE_BOOL, "default": true },
		{ "name": "btn_biome_config", "label": "Override Biome Rules...", "type": TYPE_NIL, "hint": "button" },
		{ "name": "btn_biome_interactions", "label": "Biome Edge Matrix...", "type": TYPE_NIL, "hint": "button" },
		{ "name": "sep_base", "type": TYPE_NIL, "hint": "separator" }
	]
	
	# Inject the core schema!
	schema.append_array(RealizerController.get_base_biome_rules())
	
	schema.append_array([
		{ "name": "sep_view", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "show_entities", "label": "Show Scattered Entities", "type": TYPE_BOOL, "default": true },
		{ "name": "debug_routing", "label": "Show Critical Path", "type": TYPE_BOOL, "default": false },
		
		{ "name": "sep_prog", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "progression_enabled", "label": "Generate Locks & Keys", "type": TYPE_BOOL, "default": true },
		{ "name": "progression_lock_chance", "label": "Door Lock Chance", "type": TYPE_FLOAT, "default": 0.4, "min": 0.0, "max": 1.0, "step": 0.05 },
		{ "name": "progression_max_locks", "label": "Max Locks (0: Unlimited)", "type": TYPE_INT, "default": 0, "min": 0, "max": 99 },
		{ "name": "progression_key_copies_min", "label": "Min Key Copies", "type": TYPE_INT, "default": 1, "min": 1, "max": 5 },
		{ "name": "progression_key_copies_max", "label": "Max Key Copies", "type": TYPE_INT, "default": 2, "min": 1, "max": 5 },
		{ "name": "main_path_key_stash", "label": "Force Main Path Detours", "type": TYPE_BOOL, "default": true }
	])
	
	# Safely inject missing defaults without overriding user settings
	for item in schema:
		if item.has("default") and not current_params.has(item["name"]):
			current_params[item["name"]] = item["default"]
			
	# (The remaining structure overrides can be kept identical)
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
