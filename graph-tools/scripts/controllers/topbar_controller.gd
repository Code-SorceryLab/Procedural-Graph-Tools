class_name TopbarController
extends Node

# --- REFERENCES ---
@export var graph_editor: GraphEditor
@export var status_label: Label
@export var tool_options_container: HBoxContainer 
@export var file_controller: FileController

# [NEW] Moved from FileController
@export var settings_window: PanelContainer

# --- MENUS ---
@export_group("Menus")
@export var menu_file: PopupMenu
@export var menu_edit: PopupMenu
@export var menu_graph: PopupMenu

# Simulation Controls
@export_group("Simulation Controls")
@export var btn_step: Button
@export var btn_play: Button
@export var btn_reset: Button
@export var sb_speed: SpinBox

# --- STATE ---
var _active_tool_inputs: Dictionary = {}
var is_buoyancy_active: bool = false
var is_auto_crystallize_active: bool = false # Tracks crystallization state

var is_edge_snapping_active: bool = false
var is_node_fusing_active: bool = false

# Playback State
var is_playing: bool = false
var play_timer: float = 0.0
var play_speed: float = 0.1 # Seconds per tick

func _ready() -> void:
	if not graph_editor or not status_label:
		push_warning("TopbarController: Missing references.")
		return
		
	# 1. Listen for Status Updates
	if SignalManager.has_signal("status_message_changed"):
		SignalManager.status_message_changed.connect(_on_status_changed)
	
	status_label.text = "Ready"
	
	# 2. Listen for Tool Changes
	if SignalManager.has_signal("active_tool_changed"):
		SignalManager.active_tool_changed.connect(_on_tool_changed)
		
	# 3. Setup UI Modules
	_setup_menus()
	_setup_simulation_controls()

# ==============================================================================
# MENU BAR LOGIC
# ==============================================================================

func _setup_menus() -> void:
	# Setup File Menu
	if menu_file:
		menu_file.clear()
		menu_file.add_item("New Graph", 101)
		menu_file.add_item("Save", 102)
		menu_file.add_item("Save As...", 104)
		menu_file.add_item("Load", 103)
		menu_file.id_pressed.connect(_on_file_menu_pressed)
		
	# Setup Edit Menu
	if menu_edit:
		menu_edit.clear()
		menu_edit.add_item("Undo", 201)
		menu_edit.add_item("Redo", 202)
		menu_edit.add_separator()
		menu_edit.add_item("Clear Graph", 203)
		menu_edit.add_separator() 
		menu_edit.add_item("Settings", 204) # [NEW] Added Settings to Edit Menu
		menu_edit.id_pressed.connect(_on_edit_menu_pressed)
		
		# Hook into the popup event to dynamically update labels!
		menu_edit.about_to_popup.connect(_on_edit_menu_about_to_popup)
		
	# Setup Graph Menu
	if menu_graph:
		menu_graph.clear()
		
		# --- BUOYANCY PHYSICS SECTION ---
		menu_graph.add_separator() 
		menu_graph.add_check_item("Enable Buoyancy Mode", 301)
		menu_graph.add_check_item("Auto-Crystallize (Snap & Freeze)", 303)
		menu_graph.add_check_item("Enable Edge Tension Snapping", 304)
		menu_graph.add_check_item("Enable Node Collision Fusing", 305)
		menu_graph.add_item("Force Directed Layout (1 Step)", 302)
		menu_graph.add_separator() 
		
		menu_graph.id_pressed.connect(_on_graph_menu_pressed)
		

# Dynamic Undo/Redo Labels
func _on_edit_menu_about_to_popup() -> void:
	if not graph_editor or not graph_editor.history: return
	
	var history = graph_editor.history
	var undo_idx = menu_edit.get_item_index(201)
	var redo_idx = menu_edit.get_item_index(202)
	
	# Update Undo
	if history.can_undo():
		menu_edit.set_item_text(undo_idx, "Undo " + history.get_undo_name())
		menu_edit.set_item_disabled(undo_idx, false)
	else:
		menu_edit.set_item_text(undo_idx, "Undo")
		menu_edit.set_item_disabled(undo_idx, true)
		
	# Update Redo
	if history.can_redo():
		menu_edit.set_item_text(redo_idx, "Redo " + history.get_redo_name())
		menu_edit.set_item_disabled(redo_idx, false)
	else:
		menu_edit.set_item_text(redo_idx, "Redo")
		menu_edit.set_item_disabled(redo_idx, true)

func _on_file_menu_pressed(id: int) -> void:
	if not file_controller: return
	
	match id:
		101: # New Graph (Guarded by FileController's discard check)
			file_controller.request_new_graph()
		102: # Save 
			file_controller._on_save_button_pressed()
		104: # Save As... 
			file_controller._on_save_as_button_pressed()
		103: # Load (Guarded by FileController's discard check)
			file_controller._on_load_button_pressed()

func _on_edit_menu_pressed(id: int) -> void:
	match id:
		201: if graph_editor: graph_editor.undo()
		202: if graph_editor: graph_editor.redo()
		203: if graph_editor: graph_editor.clear_graph()
		204: if settings_window: settings_window.show_settings() # [NEW] Shows the settings panel

func _on_graph_menu_pressed(id: int) -> void:
	match id:
		301: # Toggle Buoyancy Mode
			is_buoyancy_active = not is_buoyancy_active
			var idx = menu_graph.get_item_index(301)
			menu_graph.set_item_checked(idx, is_buoyancy_active)
			
			if graph_editor and graph_editor.has_method("set_buoyancy_active"):
				graph_editor.set_buoyancy_active(is_buoyancy_active)
				
		302: # Fire a single instantaneous physics step
			if graph_editor and graph_editor.has_method("apply_buoyancy_step"):
				graph_editor.apply_buoyancy_step()
				
		303: # Toggle Auto-Crystallize Mode
			is_auto_crystallize_active = not is_auto_crystallize_active
			var idx = menu_graph.get_item_index(303)
			menu_graph.set_item_checked(idx, is_auto_crystallize_active)
			
			if graph_editor and graph_editor.has_method("set_buoyancy_crystallize"):
				graph_editor.set_buoyancy_crystallize(is_auto_crystallize_active)
		
		304: # Toggle Edge Snapping
			is_edge_snapping_active = not is_edge_snapping_active
			var idx = menu_graph.get_item_index(304)
			menu_graph.set_item_checked(idx, is_edge_snapping_active)
			if graph_editor and graph_editor.has_method("set_buoyancy_edge_snapping"):
				graph_editor.set_buoyancy_edge_snapping(is_edge_snapping_active)
		
		305: # Toggle Node Fusing
			is_node_fusing_active = not is_node_fusing_active
			var idx = menu_graph.get_item_index(305)
			menu_graph.set_item_checked(idx, is_node_fusing_active)
			if graph_editor and graph_editor.has_method("set_buoyancy_node_fusing"):
				graph_editor.set_buoyancy_node_fusing(is_node_fusing_active)

# ==============================================================================
# SIMULATION HANDLERS
# ==============================================================================

func _process(delta: float) -> void:
	if not is_playing: return
	
	play_timer -= delta
	if play_timer <= 0:
		play_timer = play_speed
		_perform_step()

func _setup_simulation_controls() -> void:
	if btn_step: btn_step.pressed.connect(_on_step_pressed)
	if btn_reset: btn_reset.pressed.connect(_on_reset_pressed)
	
	if btn_play:
		btn_play.toggle_mode = true
		btn_play.toggled.connect(_on_play_toggled)
		
	if sb_speed:
		sb_speed.value_changed.connect(_on_speed_changed)
		_on_speed_changed(sb_speed.value) # Init value

func _on_step_pressed() -> void:
	if is_playing and btn_play: btn_play.button_pressed = false
	_perform_step()

func _on_play_toggled(toggled_on: bool) -> void:
	is_playing = toggled_on
	if btn_play: btn_play.text = "Pause" if toggled_on else "Play"

func _on_reset_pressed() -> void:
	if is_playing and btn_play: btn_play.button_pressed = false
	if graph_editor and graph_editor.simulation:
		var cmd = graph_editor.simulation.reset_state()
		if cmd: graph_editor._commit_command(cmd)
		
		# Force the Control Tool to recalculate its paths and UI instantly!
		if graph_editor.tool_manager and graph_editor.tool_manager.current_tool:
			var current_tool = graph_editor.tool_manager.current_tool
			if current_tool.has_method("_update_action_edges"):
				current_tool._update_action_edges()
			if current_tool.has_method("_refresh_ui"):
				current_tool._refresh_ui()
				
		graph_editor.request_redraw()

func _on_speed_changed(value: float) -> void:
	var old_delay = play_speed
	if value > 0: play_speed = 1.0 / value
	else: play_speed = 1.0
	
	if play_speed < old_delay and play_timer > play_speed:
		play_timer = play_speed

func _perform_step() -> void:
	if not graph_editor or not graph_editor.simulation: return
	
	var cmd = graph_editor.simulation.step()
	if cmd:
		graph_editor._commit_command(cmd)
	else:
		if is_playing and btn_play: btn_play.button_pressed = false

# ==============================================================================
# EXISTING TOOL HANDLERS
# ==============================================================================

func _on_status_changed(msg: String) -> void:
	status_label.text = msg

func _on_tool_changed(tool_id: int) -> void:
	if tool_options_container:
		for child in tool_options_container.get_children():
			child.queue_free()
	_active_tool_inputs.clear()
	
	var tool_instance = null
	if graph_editor and graph_editor.tool_manager:
		if graph_editor.tool_manager.active_tool_id == tool_id:
			tool_instance = graph_editor.tool_manager.current_tool

	if not tool_instance: return

	var schema = tool_instance.get_options_schema()
	if schema.is_empty(): return
		
	if tool_options_container:
		_active_tool_inputs = SettingsUIBuilder.build_ui(schema, tool_options_container)
		SettingsUIBuilder.connect_live_updates(_active_tool_inputs, tool_instance.apply_option)
		tool_options_container.add_theme_constant_override("separation", 15)
