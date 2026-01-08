extends PanelContainer

# --- UI REFERENCES ---
@onready var chk_atomic: CheckBox = $MarginContainer/VBoxContainer/GridContainer/ChkAtomic
@onready var spin_history: SpinBox = $MarginContainer/VBoxContainer/GridContainer/SpinHistory
@onready var btn_close: Button = $MarginContainer/VBoxContainer/BtnClose

# Input Section
@onready var input_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollInputs/InputContainer
@onready var btn_reset: Button = $MarginContainer/VBoxContainer/BtnResetInputs

signal closed

# --- REBINDING STATE ---
var _current_rebind_action: String = ""
var _current_rebind_button: Button = null

func _ready() -> void:
	# 1. Initialize UI with current values
	chk_atomic.button_pressed = GraphSettings.USE_ATOMIC_UNDO
	spin_history.value = GraphSettings.MAX_HISTORY_STEPS
	
	# 2. Connect Signals
	chk_atomic.toggled.connect(_on_atomic_toggled)
	spin_history.value_changed.connect(_on_history_changed)
	btn_close.pressed.connect(_on_close_pressed)
	btn_reset.pressed.connect(_on_reset_pressed)
	
	# 3. Build the Input List
	_build_input_list()
	
	# Start hidden and disable input processing until needed
	hide()
	set_process_input(false)

func show_settings() -> void:
	# Refresh values
	chk_atomic.button_pressed = GraphSettings.USE_ATOMIC_UNDO
	spin_history.value = GraphSettings.MAX_HISTORY_STEPS
	
	# Refresh inputs (in case they changed elsewhere)
	_build_input_list()
	
	show()

# ==============================================================================
# 1. SETTINGS LOGIC
# ==============================================================================
func _on_atomic_toggled(toggled_on: bool) -> void:
	GraphSettings.USE_ATOMIC_UNDO = toggled_on

func _on_history_changed(value: float) -> void:
	GraphSettings.MAX_HISTORY_STEPS = int(value)

func _on_close_pressed() -> void:
	# Cancel any active rebind if the user panics and clicks close
	_cancel_rebind()
	
	# Save to disk
	ConfigManager.save_config()
	
	hide()
	closed.emit()

# ==============================================================================
# 2. INPUT REBINDING LOGIC
# ==============================================================================

func _on_reset_pressed() -> void:
	# 1. Ask Godot to reload the Input Map from project.godot
	InputMap.load_from_project_settings()
	
	# 2. Refresh the UI to show the old defaults
	_build_input_list()
	
	# 3. (Optional) Force the ConfigManager to save immediately 
	# so the file on disk matches the new defaults
	ConfigManager.save_config()

func _build_input_list() -> void:
	# Clear existing items
	for child in input_container.get_children():
		child.queue_free()
		
	# Loop through the specific actions we defined in ConfigManager
	for action in ConfigManager.INPUT_ACTIONS:
		_create_input_row(action)

func _create_input_row(action: String) -> void:
	# 1. Create a Horizontal Container for the row
	var row = HBoxContainer.new()
	input_container.add_child(row)
	
	# 2. Create the Label (Action Name)
	var lbl = Label.new()
	lbl.text = _format_action_name(action)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL # Push button to the right
	row.add_child(lbl)
	
	# 3. Create the Button (Current Key)
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(100, 0) # Fixed width for neatness
	btn.text = _get_key_text(action)
	btn.toggle_mode = true # Visual feedback
	row.add_child(btn)
	
	# 4. Connect Click Event
	btn.pressed.connect(func(): _start_rebind(action, btn))

func _start_rebind(action: String, btn: Button) -> void:
	# If we were already rebinding another key, reset it first
	_cancel_rebind()
	
	_current_rebind_action = action
	_current_rebind_button = btn
	
	btn.text = "Press Key..."
	btn.button_pressed = true # Keep it pressed visually
	
	# Enable _input processing to catch the next key press
	set_process_input(true)

func _input(event: InputEvent) -> void:
	if _current_rebind_action == "":
		set_process_input(false)
		return

	# Handle Mouse Click (Cancel)
	if event is InputEventMouseButton and event.pressed:
		if _current_rebind_button and not _current_rebind_button.get_global_rect().has_point(event.global_position):
			_cancel_rebind()
			get_viewport().set_input_as_handled()
		return

	# Handle Keyboard Input
	if event is InputEventKey and event.pressed:
		# 1. Ignore standalone Modifier presses
		# We wait until the user presses the ACTUAL key (like 'S') while holding Ctrl
		if event.keycode in [KEY_CTRL, KEY_SHIFT, KEY_ALT, KEY_META]:
			return

		# 2. Check for Cancel (Escape)
		if event.keycode == KEY_ESCAPE:
			_cancel_rebind()
		
		# 3. Apply the Bind (Now includes modifiers!)
		else:
			_apply_rebind(event)
			
		get_viewport().set_input_as_handled()

func _apply_rebind(event: InputEventKey) -> void:
	# 1. Update Godot's Input Map
	InputMap.action_erase_events(_current_rebind_action)
	InputMap.action_add_event(_current_rebind_action, event)
	
	# 2. Update UI
	if _current_rebind_button:
		_current_rebind_button.text = _get_key_text(_current_rebind_action)
		_current_rebind_button.button_pressed = false
		
	# 3. Clean up
	_current_rebind_action = ""
	_current_rebind_button = null
	set_process_input(false)
	
	# 4. Optional: Force Toolbar refresh immediately
	# (You can emit a signal here if needed, but saving on close usually suffices)

func _cancel_rebind() -> void:
	if _current_rebind_button:
		# Restore original text
		_current_rebind_button.text = _get_key_text(_current_rebind_action)
		_current_rebind_button.button_pressed = false
		
	_current_rebind_action = ""
	_current_rebind_button = null
	set_process_input(false)

# --- HELPERS ---

func _get_key_text(action: String) -> String:
	var events = InputMap.action_get_events(action)
	if events.is_empty():
		return "Unbound"
	
	# We look at the first event (primary bind)
	var event = events[0]
	
	if event is InputEventKey:
		# FIX: Rely on Godot's internal formatter. 
		# It handles "Ctrl+S", "Shift+F1", etc. automatically without duplication errors.
		return event.as_text()
		
	return "Complex"

func _format_action_name(action: String) -> String:
	# Converts "tool_select" -> "Tool Select"
	return action.replace("_", " ").capitalize()
