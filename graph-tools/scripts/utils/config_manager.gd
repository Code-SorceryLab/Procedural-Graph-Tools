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
	
	config.set_value("View", "depth_rainbow", GraphSettings.OVERLAY_DEPTH_RAINBOW)
	
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
	
	GraphSettings.OVERLAY_DEPTH_RAINBOW = config.get_value("View", "depth_rainbow", false)
	
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

static func save_rasterizer_mappings(mappings: Dictionary, texture_path: String = "", tile_size: Vector2i = Vector2i(16, 16), procedural_flags: Dictionary = {}, palette_params: Dictionary = {}) -> void:
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH) 
	
	if config.has_section("RasterizerMappings"): config.erase_section("RasterizerMappings")
	if config.has_section("ProceduralFlags"): config.erase_section("ProceduralFlags")
	if config.has_section("PaletteParams"): config.erase_section("PaletteParams")
		
	for key in mappings:
		config.set_value("RasterizerMappings", key, mappings[key])
		
	for key in procedural_flags:
		config.set_value("ProceduralFlags", key, procedural_flags[key])
		
	for key in palette_params:
		config.set_value("PaletteParams", key, palette_params[key])
		
	config.set_value("TileSetSettings", "texture_path", texture_path)
	config.set_value("TileSetSettings", "tile_size", tile_size)
		
	var err = config.save(SETTINGS_PATH)
	if err != OK:
		push_error("ConfigManager: Failed to save Rasterizer Mappings.")

static func load_rasterizer_mappings() -> Dictionary:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	
	var data = {
		"mappings": {},
		"procedural_flags": {},
		"palette_params": {},
		"texture_path": "",
		"tile_size": Vector2i(16, 16)
	}
	
	if err == OK:
		if config.has_section("RasterizerMappings"):
			for key in config.get_section_keys("RasterizerMappings"):
				data["mappings"][key] = config.get_value("RasterizerMappings", key)
				
		if config.has_section("ProceduralFlags"):
			for key in config.get_section_keys("ProceduralFlags"):
				data["procedural_flags"][key] = config.get_value("ProceduralFlags", key)
				
		if config.has_section("PaletteParams"):
			for key in config.get_section_keys("PaletteParams"):
				data["palette_params"][key] = config.get_value("PaletteParams", key)
				
		if config.has_section("TileSetSettings"):
			data["texture_path"] = config.get_value("TileSetSettings", "texture_path", "")
			data["tile_size"] = config.get_value("TileSetSettings", "tile_size", Vector2i(16, 16))
			
	return data

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

# ==============================================================================
# CUSTOM STRUCTURES
# ==============================================================================

static func save_structures(structures: Dictionary) -> void:
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH) # Preserve other settings
	
	if config.has_section("CustomStructures"):
		config.erase_section("CustomStructures")
		
	for key in structures:
		config.set_value("CustomStructures", key, structures[key])
		
	var err = config.save(SETTINGS_PATH)
	if err != OK: 
		push_error("ConfigManager: Failed to save Custom Structures.")

static func load_structures() -> Dictionary:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	var loaded_structures = {}
	
	if err == OK and config.has_section("CustomStructures"):
		for key in config.get_section_keys("CustomStructures"):
			loaded_structures[key] = config.get_value("CustomStructures", key)
			
	return loaded_structures

# ==============================================================================
# BIOME INTERACTIONS
# ==============================================================================

static func save_biome_interactions(interactions: Dictionary) -> void:
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH) # Preserve other settings
	
	if config.has_section("BiomeInteractions"):
		config.erase_section("BiomeInteractions")
		
	for key in interactions:
		config.set_value("BiomeInteractions", key, interactions[key])
		
	var err = config.save(SETTINGS_PATH)
	if err != OK: 
		push_error("ConfigManager: Failed to save Biome Interactions.")

static func load_biome_interactions() -> Dictionary:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	var loaded_interactions = {}
	
	if err == OK and config.has_section("BiomeInteractions"):
		for key in config.get_section_keys("BiomeInteractions"):
			loaded_interactions[key] = config.get_value("BiomeInteractions", key)
			
	return loaded_interactions

# ==============================================================================
# SCATTER SETS
# ==============================================================================

static func save_scatter_sets(scatter_sets: Dictionary) -> void:
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH) # Preserve other settings
	
	if config.has_section("ScatterSets"):
		config.erase_section("ScatterSets")
		
	for key in scatter_sets:
		config.set_value("ScatterSets", key, scatter_sets[key])
		
	var err = config.save(SETTINGS_PATH)
	if err != OK: 
		push_error("ConfigManager: Failed to save Scatter Sets.")

static func load_scatter_sets() -> Dictionary:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	var loaded_sets = {}
	
	if err == OK and config.has_section("ScatterSets"):
		for key in config.get_section_keys("ScatterSets"):
			loaded_sets[key] = config.get_value("ScatterSets", key)
			
	return loaded_sets
	
	
# ==============================================================================
# SPRITE CACHE MANAGEMENT
# ==============================================================================
static func import_sprite(source_path: String) -> String:
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("imported_sprites"):
		dir.make_dir("imported_sprites")
		
	var filename = source_path.get_file()
	# Prepend a timestamp to prevent filename collisions if you upload two different "goblin.png"s
	var new_filename = str(Time.get_unix_time_from_system()) + "_" + filename
	var dest_path = "user://imported_sprites/" + new_filename
	
	var err = DirAccess.copy_absolute(source_path, dest_path)
	if err == OK:
		return dest_path
	return ""

static func clear_sprite_cache() -> void:
	var dir = DirAccess.open("user://imported_sprites")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				dir.remove(file_name)
			file_name = dir.get_next()

# ==============================================================================
# SPAWN DECKS (Unified Distribution)
# ==============================================================================
static func save_spawn_decks(decks: Dictionary) -> void:
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH)
	
	if config.has_section("SpawnDecks"):
		config.erase_section("SpawnDecks")
		
	for key in decks:
		config.set_value("SpawnDecks", key, decks[key])
		
	var err = config.save(SETTINGS_PATH)
	if err != OK: 
		push_error("ConfigManager: Failed to save Spawn Decks.")

static func load_spawn_decks() -> Dictionary:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	var loaded_decks = {}
	
	if err == OK and config.has_section("SpawnDecks"):
		for key in config.get_section_keys("SpawnDecks"):
			loaded_decks[key] = config.get_value("SpawnDecks", key)
			
	return loaded_decks

# ==============================================================================
# ROOM DECKS
# ==============================================================================
static func save_room_decks(decks: Dictionary) -> void:
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH)
	if config.has_section("RoomDecks"): config.erase_section("RoomDecks")
	for key in decks: config.set_value("RoomDecks", key, decks[key])
	var err = config.save(SETTINGS_PATH)
	if err != OK: push_error("ConfigManager: Failed to save Room Decks.")

static func load_room_decks() -> Dictionary:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	var loaded_decks = {}
	if err == OK and config.has_section("RoomDecks"):
		for key in config.get_section_keys("RoomDecks"):
			loaded_decks[key] = config.get_value("RoomDecks", key)
	return loaded_decks

# ==============================================================================
# GLOBAL GENERATOR PARAMS
# ==============================================================================
static func save_global_params(params: Dictionary) -> void:
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH)
	
	if config.has_section("GlobalParams"):
		config.erase_section("GlobalParams")
		
	for key in params:
		config.set_value("GlobalParams", key, params[key])
		
	var err = config.save(SETTINGS_PATH)
	if err != OK: 
		push_error("ConfigManager: Failed to save Global Params.")

static func load_global_params() -> Dictionary:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	var loaded_params = {}
	
	if err == OK and config.has_section("GlobalParams"):
		for key in config.get_section_keys("GlobalParams"):
			loaded_params[key] = config.get_value("GlobalParams", key)
			
	return loaded_params


# ==============================================================================
# CUSTOM ROOMS
# ==============================================================================

static func save_custom_rooms(data: Dictionary) -> void:
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH)
	
	if config.has_section("CustomRooms"):
		config.erase_section("CustomRooms")
		
	var serialized = _serialize_vector2i_keys(data)
	for key in serialized:
		config.set_value("CustomRooms", key, serialized[key])
		
	var err = config.save(SETTINGS_PATH)
	if err != OK: 
		push_error("ConfigManager: Failed to save Custom Rooms.")

static func load_custom_rooms() -> Dictionary:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	var loaded_rooms = {}
	
	if err == OK and config.has_section("CustomRooms"):
		for key in config.get_section_keys("CustomRooms"):
			loaded_rooms[key] = config.get_value("CustomRooms", key)
			
	return _deserialize_vector2i_keys(loaded_rooms)

# --- Serialization Helpers ---
# ConfigFile inherently supports Vector2i Arrays (for doorways/reserved/anchors), 
# but it DOES NOT support Vector2i as Dictionary Keys. We convert keys to Strings for saving!
static func _serialize_vector2i_keys(data: Dictionary) -> Dictionary:
	var out = data.duplicate(true)
	for room_key in out:
		var room = out[room_key]
		for prop in ["floors", "walls", "exact_floors", "exact_walls"]:
			if room.has(prop) and typeof(room[prop]) == TYPE_DICTIONARY:
				var new_dict = {}
				for v in room[prop]:
					var str_key = str(v.x) + "," + str(v.y) if typeof(v) == TYPE_VECTOR2I else str(v)
					new_dict[str_key] = room[prop][v]
				room[prop] = new_dict
	return out

static func _deserialize_vector2i_keys(data: Dictionary) -> Dictionary:
	var out = data.duplicate(true)
	var str_to_vec = func(s: String) -> Vector2i:
		var parts = s.split(",")
		if parts.size() == 2: return Vector2i(parts[0].to_int(), parts[1].to_int())
		return Vector2i.ZERO
		
	for room_key in out:
		var room = out[room_key]
		for prop in ["floors", "walls", "exact_floors", "exact_walls"]:
			if room.has(prop) and typeof(room[prop]) == TYPE_DICTIONARY:
				var new_dict = {}
				for s in room[prop]:
					var vec_key = str_to_vec.call(s) if (typeof(s) == TYPE_STRING and s.contains(",")) else s
					new_dict[vec_key] = room[prop][s]
				room[prop] = new_dict
	return out


# ==============================================================================
# WFC MODULES
# ==============================================================================

static func save_wfc_modules(data: Dictionary) -> void:
	var config = ConfigFile.new()
	config.load(SETTINGS_PATH)
	
	if config.has_section("WfcModules"):
		config.erase_section("WfcModules")
		
	# CRITICAL: We must serialize the Vector2i keys just like Custom Rooms!
	var serialized = _serialize_vector2i_keys(data)
	for key in serialized:
		config.set_value("WfcModules", key, serialized[key])
		
	var err = config.save(SETTINGS_PATH)
	if err != OK: 
		push_error("ConfigManager: Failed to save WFC Modules.")
	
static func load_wfc_modules() -> Dictionary:
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_PATH)
	var loaded_modules = {}
	
	if err == OK and config.has_section("WfcModules"):
		for key in config.get_section_keys("WfcModules"):
			loaded_modules[key] = config.get_value("WfcModules", key)
			
	# CRITICAL: We must deserialize the Vector2i keys back into math objects!
	return _deserialize_vector2i_keys(loaded_modules)


# ==============================================================================
# GLOBAL TEXTURE CACHE
# ==============================================================================
static var _global_texture_cache: Dictionary = {}

static func get_cached_texture(path: String) -> Texture2D:
	if path == "": return null
	if _global_texture_cache.has(path): return _global_texture_cache[path]
	
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(path)
		if img:
			var tex = ImageTexture.create_from_image(img)
			_global_texture_cache[path] = tex
			return tex
	return null

static func clear_memory_cache() -> void:
	_global_texture_cache.clear()
