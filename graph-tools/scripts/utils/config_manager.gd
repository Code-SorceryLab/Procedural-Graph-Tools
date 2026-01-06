class_name ConfigManager
extends RefCounted

const SETTINGS_PATH = "user://settings.cfg"

static func save_config() -> void:
	var config = ConfigFile.new()
	
	# 1. Store Values from GraphSettings
	config.set_value("History", "max_steps", GraphSettings.MAX_HISTORY_STEPS)
	config.set_value("History", "atomic_undo", GraphSettings.USE_ATOMIC_UNDO)
	
	# Future: Add other sections here (e.g., "Visuals")
	
	# 2. Save to Disk
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
		
	# 1. Load Values into GraphSettings (With defaults if missing)
	GraphSettings.MAX_HISTORY_STEPS = config.get_value("History", "max_steps", 50)
	GraphSettings.USE_ATOMIC_UNDO = config.get_value("History", "atomic_undo", false)
	
	print("ConfigManager: Settings loaded.")
