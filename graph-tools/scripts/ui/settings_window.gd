extends PanelContainer

# --- UI REFERENCES ---
var chk_atomic: CheckBox
var spin_history: SpinBox
var chk_grid: CheckBox
var chk_rainbow_depth: CheckBox
var input_container: VBoxContainer

var btn_close: Button
var btn_apply: Button
var btn_defaults: Button

signal closed

# --- STATE BUFFER (Staging Area) ---
# Holds changes before they are committed
var _temp_settings: Dictionary = {}
var _temp_inputs: Dictionary = {} 

# Rebinding State
var _current_rebind_action: String = ""
var _current_rebind_button: Button = null

func _ready() -> void:
	# 1. SAFE NODE LOOKUP
	chk_atomic = find_child("ChkAtomic", true, false)
	spin_history = find_child("SpinHistory", true, false)
	chk_grid = find_child("ChkGrid", true, false)
	chk_rainbow_depth = find_child("ChkRainbowDepth", true, false)
	
	btn_close = find_child("BtnClose", true, false)
	btn_apply = find_child("ApplyBtn", true, false)
	btn_defaults = find_child("DefaultsBtn", true, false)
	
	var scroll = find_child("ScrollInputs", true, false)
	if scroll: input_container = scroll.get_node_or_null("InputContainer")
	
	# 2. CONNECT BUTTONS
	if btn_close: btn_close.pressed.connect(_on_close_pressed)
	if btn_apply: btn_apply.pressed.connect(_on_apply_pressed)
	if btn_defaults: btn_defaults.pressed.connect(_on_defaults_pressed)

	# 3. CONNECT UI CONTROLS
	if chk_atomic: chk_atomic.toggled.connect(_on_setting_changed.bind("atomic"))
	if spin_history: spin_history.value_changed.connect(_on_setting_changed.bind("history"))
	if chk_grid: chk_grid.toggled.connect(_on_setting_changed.bind("grid"))
	if chk_rainbow_depth: chk_rainbow_depth.toggled.connect(_on_setting_changed.bind("rainbow_depth"))
	
	hide()
	set_process_input(false)

func show_settings() -> void:
	# 1. Load LIVE state into our STAGING buffer
	_temp_settings["atomic"] = GraphSettings.USE_ATOMIC_UNDO
	_temp_settings["history"] = GraphSettings.MAX_HISTORY_STEPS
	
	if "SHOW_GRID" in GraphSettings:
		_temp_settings["grid"] = GraphSettings.SHOW_GRID
		
	# Load Rainbow Depth
	if "OVERLAY_DEPTH_RAINBOW" in GraphSettings:
		_temp_settings["rainbow_depth"] = GraphSettings.OVERLAY_DEPTH_RAINBOW
		
	_temp_inputs.clear() # Clear any unapplied input changes from last time
	
	# 2. Sync UI to the Staging buffer
	_sync_ui_to_temp_state()
	_evaluate_dirty()
	
	show()
	move_to_front()

# ==============================================================================
# 1. STATE MANAGEMENT & DIRTY CHECKING
# ==============================================================================

# Generic handler for the checkboxes and spinboxes
func _on_setting_changed(value: Variant, key: String) -> void:
	_temp_settings[key] = value
	_evaluate_dirty()

# Evaluates if ANY temporary setting differs from the LIVE setting
func _evaluate_dirty() -> void:
	var is_dirty = false
	
	if _temp_settings.get("atomic") != GraphSettings.USE_ATOMIC_UNDO: is_dirty = true
	if _temp_settings.get("history") != GraphSettings.MAX_HISTORY_STEPS: is_dirty = true
	
	if "SHOW_GRID" in GraphSettings and _temp_settings.get("grid") != GraphSettings.SHOW_GRID: is_dirty = true
	
	if "OVERLAY_DEPTH_RAINBOW" in GraphSettings and _temp_settings.get("rainbow_depth") != GraphSettings.OVERLAY_DEPTH_RAINBOW: 
		is_dirty = true
	
	# If we have any pending keybind changes, we are dirty
	if not _temp_inputs.is_empty(): is_dirty = true
		
	if btn_apply: 
		btn_apply.disabled = not is_dirty

# Silently updates the UI without triggering the "changed" signals again
func _sync_ui_to_temp_state() -> void:
	if chk_atomic: chk_atomic.set_pressed_no_signal(_temp_settings.get("atomic", false))
	if spin_history: spin_history.set_value_no_signal(_temp_settings.get("history", 50))
	if chk_grid: chk_grid.set_pressed_no_signal(_temp_settings.get("grid", true))
	if chk_rainbow_depth: chk_rainbow_depth.set_pressed_no_signal(_temp_settings.get("rainbow_depth", false))
	
	_build_input_list()

# ==============================================================================
# 2. ACTION BUTTONS
# ==============================================================================

func _on_apply_pressed() -> void:
	# 1. Commit Settings to Memory
	GraphSettings.USE_ATOMIC_UNDO = _temp_settings.get("atomic", false)
	GraphSettings.MAX_HISTORY_STEPS = _temp_settings.get("history", 50)
	
	if "SHOW_GRID" in GraphSettings:
		GraphSettings.SHOW_GRID = _temp_settings.get("grid", true)
		
	if "OVERLAY_DEPTH_RAINBOW" in GraphSettings:
		GraphSettings.OVERLAY_DEPTH_RAINBOW = _temp_settings.get("rainbow_depth", false)
		
	# 2. Commit Inputs to Memory
	for action in _temp_inputs:
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, _temp_inputs[action])
		
	_temp_inputs.clear() # Clear the buffer now that it's live
	
	# 3. Save everything to Disk!
	ConfigManager.save_config()
	
	# 4. Lock the apply button again
	_evaluate_dirty()

func _on_defaults_pressed() -> void:
	# 1. Load hardcoded defaults into the staging buffer
	_temp_settings["atomic"] = false
	_temp_settings["history"] = 50
	_temp_settings["grid"] = true
	_temp_settings["rainbow_depth"] = false # Default off
	
	# 2. Fetch default keybinds directly from Godot's ProjectSettings
	for action in ConfigManager.INPUT_ACTIONS:
		var prop_name = "input/" + action
		if ProjectSettings.has_setting(prop_name):
			var action_data = ProjectSettings.get_setting(prop_name)
			if typeof(action_data) == TYPE_DICTIONARY and action_data.has("events"):
				for e in action_data["events"]:
					if e is InputEventKey:
						_temp_inputs[action] = e
						break # Just grab the first key event
						
	# 3. Update the visual UI to reflect the defaults (Without saving yet!)
	_sync_ui_to_temp_state()
	_evaluate_dirty()

func _on_close_pressed() -> void:
	_cancel_rebind()
	
	# By NOT calling ConfigManager.save_config() or committing variables here, 
	# any unapplied changes in _temp_settings naturally evaporate!
	
	hide()
	closed.emit()

# ==============================================================================
# 3. INPUT REBINDING LOGIC
# ==============================================================================

func _build_input_list() -> void:
	if not input_container: return

	for child in input_container.get_children():
		child.queue_free()
		
	if not ClassDB.class_exists("ConfigManager") and not get_tree().root.has_node("ConfigManager"):
		if not "INPUT_ACTIONS" in ConfigManager: return

	for action in ConfigManager.INPUT_ACTIONS:
		_create_input_row(action)

func _create_input_row(action: String) -> void:
	var row = HBoxContainer.new()
	input_container.add_child(row)
	
	var lbl = Label.new()
	lbl.text = action.replace("_", " ").capitalize()
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(100, 0)
	btn.text = _get_key_text(action)
	btn.toggle_mode = true
	row.add_child(btn)
	
	btn.pressed.connect(func(): _start_rebind(action, btn))

func _start_rebind(action: String, btn: Button) -> void:
	_cancel_rebind()
	_current_rebind_action = action
	_current_rebind_button = btn
	btn.text = "Press Key..."
	btn.button_pressed = true
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if _current_rebind_action == "":
		set_process_input(false)
		return

	if event is InputEventMouseButton and event.pressed:
		if _current_rebind_button and not _current_rebind_button.get_global_rect().has_point(event.global_position):
			_cancel_rebind()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META]: return
		if event.keycode == KEY_ESCAPE:
			_cancel_rebind()
		else:
			_apply_rebind(event)
		get_viewport().set_input_as_handled()

func _apply_rebind(event: InputEventKey) -> void:
	# Store in our temporary buffer
	_temp_inputs[_current_rebind_action] = event
	
	_evaluate_dirty()
	_sync_ui_to_temp_state() # Will rebuild the list to show the new key text
	_cancel_rebind()

func _cancel_rebind() -> void:
	if _current_rebind_button:
		_current_rebind_button.text = _get_key_text(_current_rebind_action)
		_current_rebind_button.button_pressed = false
	_current_rebind_action = ""
	_current_rebind_button = null
	set_process_input(false)

func _get_key_text(action: String) -> String:
	# Check our temporary buffer FIRST
	if _temp_inputs.has(action):
		return _temp_inputs[action].as_text()
		
	# Fallback to the live InputMap
	var events = InputMap.action_get_events(action)
	if events.is_empty(): return "Unbound"
	var event = events[0]
	if event is InputEventKey: return event.as_text()
	return "Complex"
