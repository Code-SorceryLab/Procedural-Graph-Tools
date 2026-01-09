extends PanelContainer

# --- UI REFERENCES ---
# We remove @onready hard references to prevent crash-on-load
var chk_atomic: CheckBox
var spin_history: SpinBox
var chk_grid: CheckBox
var btn_close: Button
var input_container: VBoxContainer
var btn_reset: Button

signal closed

# --- REBINDING STATE ---
var _current_rebind_action: String = ""
var _current_rebind_button: Button = null

func _ready() -> void:
	# 1. SAFE NODE LOOKUP
	# We use find_child so the script works even if you change the MarginContainer hierarchy
	chk_atomic = find_child("ChkAtomic", true, false)
	spin_history = find_child("SpinHistory", true, false)
	chk_grid = find_child("ChkGrid", true, false)
	btn_close = find_child("BtnClose", true, false)
	
	# Find InputContainer safely (it's nested deep)
	var scroll = find_child("ScrollInputs", true, false)
	if scroll:
		input_container = scroll.get_node_or_null("InputContainer")
	
	btn_reset = find_child("BtnResetInputs", true, false)
	
	# 2. SAFE CONNECTIONS (Connect Close button FIRST)
	if btn_close:
		btn_close.pressed.connect(_on_close_pressed)
	else:
		push_error("SettingsWindow: CRITICAL - BtnClose not found!")

	if btn_reset: btn_reset.pressed.connect(_on_reset_pressed)
	
	# 3. INITIALIZE VALUES (With Safety Checks)
	if chk_atomic:
		chk_atomic.button_pressed = GraphSettings.USE_ATOMIC_UNDO
		chk_atomic.toggled.connect(_on_atomic_toggled)
		
	if spin_history:
		spin_history.value = GraphSettings.MAX_HISTORY_STEPS
		spin_history.value_changed.connect(_on_history_changed)
		
	if chk_grid:
		# CHECK if the variable exists before accessing it!
		if "SHOW_GRID" in GraphSettings:
			chk_grid.button_pressed = GraphSettings.SHOW_GRID
		chk_grid.toggled.connect(_on_grid_toggled)
	
	# 4. Build Input List
	_build_input_list()
	
	# Start hidden
	hide()
	set_process_input(false)

func show_settings() -> void:
	# Refresh values
	if chk_atomic: chk_atomic.button_pressed = GraphSettings.USE_ATOMIC_UNDO
	if spin_history: spin_history.value = GraphSettings.MAX_HISTORY_STEPS
	
	# [FIX] You were missing the Grid refresh in your previous code
	if chk_grid and "SHOW_GRID" in GraphSettings:
		chk_grid.button_pressed = GraphSettings.SHOW_GRID
	
	# Refresh inputs
	_build_input_list()
	show()

# ==============================================================================
# 1. SETTINGS LOGIC
# ==============================================================================
func _on_atomic_toggled(toggled_on: bool) -> void:
	GraphSettings.USE_ATOMIC_UNDO = toggled_on

func _on_history_changed(value: float) -> void:
	GraphSettings.MAX_HISTORY_STEPS = int(value)

func _on_grid_toggled(toggled_on: bool) -> void:
	# Safety check for setting the variable
	if "SHOW_GRID" in GraphSettings:
		GraphSettings.SHOW_GRID = toggled_on

func _on_close_pressed() -> void:
	_cancel_rebind()
	# ConfigManager.save_config() # Uncomment if you have this class
	hide()
	closed.emit()

# ==============================================================================
# 2. INPUT REBINDING LOGIC
# ==============================================================================
func _on_reset_pressed() -> void:
	InputMap.load_from_project_settings()
	_build_input_list()

func _build_input_list() -> void:
	if not input_container: return

	for child in input_container.get_children():
		child.queue_free()
		
	# Verify ConfigManager exists before accessing it
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
	InputMap.action_erase_events(_current_rebind_action)
	InputMap.action_add_event(_current_rebind_action, event)
	_cancel_rebind()

func _cancel_rebind() -> void:
	if _current_rebind_button:
		_current_rebind_button.text = _get_key_text(_current_rebind_action)
		_current_rebind_button.button_pressed = false
	_current_rebind_action = ""
	_current_rebind_button = null
	set_process_input(false)

func _get_key_text(action: String) -> String:
	var events = InputMap.action_get_events(action)
	if events.is_empty(): return "Unbound"
	var event = events[0]
	if event is InputEventKey: return event.as_text()
	return "Complex"
