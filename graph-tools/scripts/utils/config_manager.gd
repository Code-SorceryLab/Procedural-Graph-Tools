class_name ConfigManager
extends RefCounted

const SETTINGS_PATH = "user://settings.cfg"

# Define which actions we want to save/load. 
# We don't want to save built-in UI actions (ui_up, ui_down) to avoid bloating the file.
const INPUT_ACTIONS = [
	"tool_select", "tool_add", "tool_delete", "tool_connect", 
	"tool_cut", "tool_paint", "tool_type", "tool_spawn", "tool_zone_brush",
	"file_save", "file_undo", "file_redo",
	"edit_copy", "edit_cut", "edit_paste", "edit_delete"
]

static func save_config() -> void:
	var config = ConfigFile.new()
	
	# 1. Store Values from GraphSettings
	config.set_value("History", "max_steps", GraphSettings.MAX_HISTORY_STEPS)
	config.set_value("History", "atomic_undo", GraphSettings.USE_ATOMIC_UNDO)
	
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
