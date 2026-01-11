class_name TopbarController
extends Node

# --- REFERENCES ---
@export var graph_editor: GraphEditor
@export var status_label: Label
@export var tool_options_container: HBoxContainer 

# [NEW] Simulation Controls
@export_group("Simulation Controls")
@export var btn_step: Button
@export var btn_play: Button
@export var btn_reset: Button
@export var sb_speed: SpinBox

# --- STATE ---
var _active_tool_inputs: Dictionary = {}

# [NEW] Playback State
var is_playing: bool = false
var play_timer: float = 0.0
var play_speed: float = 0.1 # Seconds per tick

func _ready() -> void:
	if not graph_editor or not status_label:
		push_warning("TopbarController: Missing references.")
		return
		
	# 1. Listen for Status Updates
	graph_editor.status_message_changed.connect(_on_status_changed)
	status_label.text = "Ready"
	
	# 2. Listen for Tool Changes
	if graph_editor.tool_manager:
		graph_editor.tool_manager.tool_changed.connect(_on_tool_changed)
	else:
		push_error("DEBUG ERROR: TopbarController could not find ToolManager!")
		
	# [NEW] 3. Setup Simulation Controls
	_setup_simulation_controls()

# [NEW] Heartbeat Loop
func _process(delta: float) -> void:
	if not is_playing: return
	
	play_timer -= delta
	if play_timer <= 0:
		play_timer = play_speed
		_perform_step()

# --- SETUP HELPER ---
func _setup_simulation_controls() -> void:
	if btn_step: btn_step.pressed.connect(_on_step_pressed)
	if btn_reset: btn_reset.pressed.connect(_on_reset_pressed)
	
	if btn_play:
		btn_play.toggle_mode = true
		btn_play.toggled.connect(_on_play_toggled)
		
	if sb_speed:
		sb_speed.value_changed.connect(_on_speed_changed)
		_on_speed_changed(sb_speed.value) # Init value

# --- SIMULATION HANDLERS ---

func _on_step_pressed() -> void:
	# Pause if manual stepping
	if is_playing and btn_play: btn_play.button_pressed = false
	_perform_step()

func _on_play_toggled(toggled_on: bool) -> void:
	is_playing = toggled_on
	if btn_play:
		# Optional: Swap icon or text
		btn_play.text = "Pause" if toggled_on else "Play"

func _on_reset_pressed() -> void:
	if is_playing and btn_play: btn_play.button_pressed = false
	
	if graph_editor.simulation:
		var cmd = graph_editor.simulation.reset_state()
		if cmd: graph_editor._commit_command(cmd)
		
		# Refresh Visuals
		if graph_editor.renderer: graph_editor.renderer.queue_redraw()
		
		# Force Agent Tab to refresh (via graph_modified signal usually)
		# If you notice the roster not updating, we can emit a signal here.

func _on_speed_changed(value: float) -> void:
	var old_delay = play_speed
	
	if value > 0:
		play_speed = 1.0 / value
	else:
		play_speed = 1.0
		
	# Instant Feedback Check
	if play_speed < old_delay and play_timer > play_speed:
		play_timer = play_speed

func _perform_step() -> void:
	if not graph_editor or not graph_editor.simulation: return
	
	var cmd = graph_editor.simulation.step()
	if cmd:
		graph_editor._commit_command(cmd)
		# Optional: Update tick count in status label?
		# status_label.text = "Tick: %d" % graph_editor.simulation.tick_count
	else:
		# Auto-pause if simulation finishes/stalls
		if is_playing and btn_play: btn_play.button_pressed = false

# --- EXISTING TOOL HANDLERS ---

func _on_status_changed(msg: String) -> void:
	status_label.text = msg

func _on_tool_changed(_tool_id: int, tool_instance: GraphTool) -> void:
	if tool_options_container:
		for child in tool_options_container.get_children():
			child.queue_free()
	_active_tool_inputs.clear()
	
	if not tool_instance: return

	var schema = tool_instance.get_options_schema()
	if schema.is_empty(): return
		
	if tool_options_container:
		_active_tool_inputs = SettingsUIBuilder.build_ui(schema, tool_options_container)
		SettingsUIBuilder.connect_live_updates(_active_tool_inputs, tool_instance.apply_option)
		tool_options_container.add_theme_constant_override("separation", 15)
