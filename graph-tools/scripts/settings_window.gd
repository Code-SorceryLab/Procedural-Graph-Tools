extends PanelContainer

@onready var chk_atomic: CheckBox = $VBoxContainer/GridContainer/ChkAtomic

@onready var spin_history: SpinBox = $VBoxContainer/GridContainer/SpinHistory
@onready var btn_close: Button = $VBoxContainer/BtnClose


signal closed

func _ready() -> void:
	# 1. Initialize UI with current values from GraphSettings
	chk_atomic.button_pressed = GraphSettings.USE_ATOMIC_UNDO
	spin_history.value = GraphSettings.MAX_HISTORY_STEPS
	
	# 2. Connect Signals
	chk_atomic.toggled.connect(_on_atomic_toggled)
	spin_history.value_changed.connect(_on_history_changed)
	btn_close.pressed.connect(_on_close_pressed)
	
	# Start hidden
	hide()

func show_settings() -> void:
	# Refresh values in case they changed elsewhere
	chk_atomic.button_pressed = GraphSettings.USE_ATOMIC_UNDO
	spin_history.value = GraphSettings.MAX_HISTORY_STEPS
	show()
	
	# Optional: Pause game processing if desired
	# get_tree().paused = true

func _on_atomic_toggled(toggled_on: bool) -> void:
	GraphSettings.USE_ATOMIC_UNDO = toggled_on
	print("Settings: Atomic Undo set to ", toggled_on)

func _on_history_changed(value: float) -> void:
	GraphSettings.MAX_HISTORY_STEPS = int(value)
	print("Settings: Max History set to ", int(value))

func _on_close_pressed() -> void:
	# Save to disk when the user is done modifying
	ConfigManager.save_config()
	
	hide()
	closed.emit()
