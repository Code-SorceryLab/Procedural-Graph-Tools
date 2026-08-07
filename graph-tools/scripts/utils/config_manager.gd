class_name ConfigManager
extends RefCounted

const SETTINGS_PATH = "user://settings.cfg"

# Define which actions we want to save/load. 
# We don't want to save built-in UI actions (ui_up, ui_down) to avoid bloating the file.
const INPUT_ACTIONS = [
	"tool_select", "tool_add", "tool_delete", "tool_connect", 
	"tool_cut", "tool_paint", "tool_type", "tool_spawn", "tool_zone_brush", "tool_agent_control", "tool_stamp",
	"file_save", "file_undo", "file_redo",
	"edit_copy", "edit_cut", "edit_paste", "edit_delete"
]

static func save_config() -> void:
	var config = ConfigFile.new()
	
	# [CRITICAL FIX] Load the file first so we don't accidentally wipe out 
	# Biomes, Rasterizer Mappings, and Semantic Data when saving inputs!
	config.load(SETTINGS_PATH) 
	
	# 1. Store Values from GraphSettings
	config.set_value("History", "max_steps", GraphSettings.MAX_HISTORY_STEPS)
	config.set_value("History", "atomic_undo", GraphSettings.USE_ATOMIC_UNDO)
	
	
	
	# Save the Grid and Layout Toggles
	if "SHOW_GRID" in GraphSettings:
		config.set_value("View", "show_grid", GraphSettings.SHOW_GRID)
	config.set_value("View", "show_left_bar", GraphSettings.UI_SHOW_LEFT_BAR)
	config.set_value("View", "show_right_bar", GraphSettings.UI_SHOW_RIGHT_BAR)
	config.set_value("View", "show_top_bar", GraphSettings.UI_SHOW_TOP_BAR)
	
	# 2. Store Input Map
	_save_inputs(config)
	
	# 3. Save to Disk
	var err = config.save(SETTINGS_PATH)
	if err != OK:
		push_error("ConfigManager: Failed to save settings. Error code: %d" % err)
	else:
		print("ConfigManager: Settings saved to %s" % SETTINGS_PATH)

static func load_config() -> void:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	
	if err != OK:
		print("ConfigManager: No settings file found (or error). Using defaults.")
		return
		
	# 1. Load Values into GraphSettings
	GraphSettings.MAX_HISTORY_STEPS = config.get_value("History", "max_steps", 50)
	GraphSettings.USE_ATOMIC_UNDO = config.get_value("History", "atomic_undo", false)
	
	# Load the Grid and Layout Toggles
	if "SHOW_GRID" in GraphSettings:
		GraphSettings.SHOW_GRID = config.get_value("View", "show_grid", true)
	GraphSettings.UI_SHOW_LEFT_BAR = config.get_value("View", "show_left_bar", true)
	GraphSettings.UI_SHOW_RIGHT_BAR = config.get_value("View", "show_right_bar", true)
	GraphSettings.UI_SHOW_TOP_BAR = config.get_value("View", "show_top_bar", true)
	
	# 2. Load Input Map
	_load_inputs(config)
	
	print("ConfigManager: Settings loaded.")

# --- INPUT HELPERS ---

static func _save_inputs(config: ConfigFile) -> void:
	for action in INPUT_ACTIONS:
		var events = InputMap.action_get_events(action)
		if events.is_empty(): 
			continue
			
		# We only save the primary (first) keybind
		var event = events[0]
		if event is InputEventKey:
			# Store as a Dictionary so we capture Modifiers (Ctrl/Shift) too!
			var data = {
				"keycode": event.physical_keycode,
				"ctrl": event.ctrl_pressed,
				"shift": event.shift_pressed,
				"alt": event.alt_pressed
			}
			config.set_value("Inputs", action, data)

static func _load_inputs(config: ConfigFile) -> void:
	if not config.has_section("Inputs"):
		return

	for action in INPUT_ACTIONS:
		# Check if the user has a custom bind for this action
		if config.has_section_key("Inputs", action):
			var data = config.get_value("Inputs", action)
			
			# Validate data integrity
			if typeof(data) == TYPE_DICTIONARY and data.has("keycode"):
				_apply_input_bind(action, data)

static func _apply_input_bind(action: String, data: Dictionary) -> void:
	# 1. Create the new event
	var new_event = InputEventKey.new()
	new_event.physical_keycode = int(data.get("keycode", 0))
	new_event.ctrl_pressed = data.get("ctrl", false)
	new_event.shift_pressed = data.get("shift", false)
	new_event.alt_pressed = data.get("alt", false)
	
	# 2. Wipe the old default (e.g., remove "1")
	InputMap.action_erase_events(action)
	
	# 3. Add the new custom bind
	InputMap.action_add_event(action, new_event)


# ==============================================================================
# RASTERIZER MAPPINGS
# ==============================================================================

static func save_rasterizer_mappings(mappings: Dictionary) -> void:
	var config = ConfigFile.new()
	# Load existing file first to preserve Input and History settings!
	config.load(SETTINGS_PATH) 
	
	# Clear the old section entirely to prevent orphaned keys if you deleted a semantic type
	if config.has_section("RasterizerMappings"):
		config.erase_section("RasterizerMappings")
		
	# Save the new mapping Dictionary
	for key in mappings:
		config.set_value("RasterizerMappings", key, mappings[key])
		
	var err = config.save(SETTINGS_PATH)
	if err != OK:
		push_error("ConfigManager: Failed to save Rasterizer Mappings.")

static func load_rasterizer_mappings() -> Dictionary:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	var loaded_mappings = {}
	
	if err == OK and config.has_section("RasterizerMappings"):
		for key in config.get_section_keys("RasterizerMappings"):
			loaded_mappings[key] = config.get_value("RasterizerMappings", key)
			
	return loaded_mappings

# ==============================================================================
# SEMANTIC DATA MAPPINGS
# ==============================================================================

static func save_semantic_data(categories: Dictionary, properties: Dictionary) -> void:
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH) # Preserve other settings
	
	if config.has_section("SemanticCategories"): config.erase_section("SemanticCategories")
	if config.has_section("SemanticProperties"): config.erase_section("SemanticProperties")
	
	# Save only User-created categories (ignore Core)
	for target in categories:
		var target_cats = {}
		for key in categories[target]:
			if not categories[target][key].get("is_core", false):
				target_cats[key] = categories[target][key]
		config.set_value("SemanticCategories", target, target_cats)
		
	# Save only User-created properties (ignore Core)
	for target in properties:
		var target_props = {}
		for key in properties[target]:
			if not properties[target][key].get("is_core", false):
				target_props[key] = properties[target][key]
		config.set_value("SemanticProperties", target, target_props)
		
	var err = config.save(SETTINGS_PATH)
	if err != OK: push_error("ConfigManager: Failed to save Semantic Data.")

static func load_semantic_data(categories_ref: Dictionary, properties_ref: Dictionary) -> void:
	var config = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK: return
	
	if config.has_section("SemanticCategories"):
		for target in config.get_section_keys("SemanticCategories"):
			var saved_cats = config.get_value("SemanticCategories", target, {})
			for key in saved_cats:
				# Protect existing core categories from being overwritten by old save files!
				if categories_ref[target].has(key) and categories_ref[target][key].get("is_core", false):
					continue
				categories_ref[target][key] = saved_cats[key]
				
	if config.has_section("SemanticProperties"):
		for target in config.get_section_keys("SemanticProperties"):
			var saved_props = config.get_value("SemanticProperties", target, {})
			for key in saved_props:
				# Protect existing core properties from being overwritten by old save files!
				if properties_ref[target].has(key) and properties_ref[target][key].get("is_core", false):
					continue
				properties_ref[target][key] = saved_props[key]

# ==============================================================================
# BIOME OVERRIDES
# ==============================================================================

static func save_biome_overrides(biomes: Dictionary) -> void:
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH) # Preserve other settings
	
	if config.has_section("BiomeOverrides"):
		config.erase_section("BiomeOverrides")
		
	# Save the nested dictionaries
	for key in biomes:
		config.set_value("BiomeOverrides", key, biomes[key])
		
	var err = config.save(SETTINGS_PATH)
	if err != OK: 
		push_error("ConfigManager: Failed to save Biome Overrides.")

static func load_biome_overrides() -> Dictionary:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	var loaded_biomes = {}
	
	if err == OK and config.has_section("BiomeOverrides"):
		for key in config.get_section_keys("BiomeOverrides"):
			loaded_biomes[key] = config.get_value("BiomeOverrides", key)
			
	return loaded_biomes
