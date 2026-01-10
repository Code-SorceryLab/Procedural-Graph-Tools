extends Node
class_name AgentController

# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor

@export_group("UI Nodes")
@export var roster_list: VBoxContainer		# The VBox inside the ScrollContainer
@export var behavior_settings_box: Control	# The VBox inside the Bottom Panel
@export var btn_step: Button
@export var btn_play: Button
@export var btn_reset: Button
@export var lbl_stats: Label
@export var sb_speed: SpinBox

# --- STATE ---
var _roster_map: Dictionary = {}  # agent_id -> Control
var _active_inputs: Dictionary = {} # For the Behavior Panel

# [NEW] Playback State
var is_playing: bool = false
var play_timer: float = 0.0
var play_speed: float = 0.1 # Seconds per tick (0.1 = 10 ticks/sec)

# [NEW] Simulation Parameters (Passed to the engine)
var sim_params: Dictionary = {
	"merge_overlaps": true,
	"grid_spacing": GraphSettings.GRID_SPACING
}

func _ready() -> void:
	# 1. Listen for Graph Changes
	graph_editor.graph_modified.connect(_on_graph_modified)
	graph_editor.graph_loaded.connect(func(_g): _full_roster_rebuild())
	
	if graph_editor.has_signal("agent_selection_changed"):
		graph_editor.agent_selection_changed.connect(_on_agent_selection_changed)
	
	# 2. Playback Signals
	if btn_step: btn_step.pressed.connect(_on_step_pressed)
	if btn_reset: btn_reset.pressed.connect(_on_reset_pressed)
	
	if btn_play: 
		btn_play.toggle_mode = true
		btn_play.toggled.connect(_on_play_toggled)
		# Safety: Disconnect old signal if it exists (from editor setups)
		if btn_play.pressed.is_connected(_on_play_pressed):
			btn_play.pressed.disconnect(_on_play_pressed)
			
	# Connect Speed Control
	if sb_speed:
		sb_speed.value_changed.connect(_on_speed_changed)
		# Set initial value
		_on_speed_changed(sb_speed.value)
	
	# 3. Build Initial UI
	_full_roster_rebuild()
	_build_behavior_ui()

# [NEW] Heartbeat Loop for Auto-Play
func _process(delta: float) -> void:
	if not is_playing: return
	
	play_timer -= delta
	if play_timer <= 0:
		play_timer = play_speed # Reset timer using the current speed
		_perform_step()

# [UPDATED] Speed Handler with Instant Feedback
func _on_speed_changed(value: float) -> void:
	# 1. Capture the old speed to check if we are speeding up
	var old_delay = play_speed 
	
	# 2. Update the CORRECT variable (play_speed)
	# Convert TPS (Ticks Per Second) to Delay (Seconds)
	if value > 0:
		play_speed = 1.0 / value
	else:
		# If user types 0, default to 1 second per tick (Slow)
		play_speed = 1.0 
		
	# 3. Impatience Check
	# If we sped up (delay got smaller) and the timer is waiting too long,
	# cut the wait short so the user sees the speed change instantly.
	if play_speed < old_delay and play_timer > play_speed:
		play_timer = play_speed

# ==============================================================================
# 1. ROSTER LOGIC (Custom UI)
# ==============================================================================

func _full_roster_rebuild() -> void:
	if not roster_list: return
	
	for child in roster_list.get_children():
		child.queue_free()
	_roster_map.clear()
	
	if not graph_editor or not graph_editor.graph: return
	
	for agent in graph_editor.graph.agents:
		_create_agent_row(agent)
	
	_update_stats()

func _create_agent_row(agent) -> void:
	var row = HBoxContainer.new()
	row.name = "Row_%d" % agent.id
	
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# A. Status Icon
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(12, 12)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.color = Color.GREEN if agent.active else Color.RED
	row.add_child(icon)
	
	# B. Name
	var lbl = Label.new()
	lbl.text = "Agent #%d" % agent.id
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	
	# C. Location
	var lbl_loc = Label.new()
	lbl_loc.text = "@ %s" % agent.current_node_id
	lbl_loc.modulate = Color(1, 1, 1, 0.7)
	row.add_child(lbl_loc)
	
	# D. Select Button
	var btn = Button.new()
	btn.text = "View"
	btn.flat = true
	btn.pressed.connect(func(): _select_agent_from_roster(agent))
	row.add_child(btn)
	
	roster_list.add_child(row)
	_roster_map[agent.id] = row

func _select_agent_from_roster(agent) -> void:
	# Trigger Editor Selection
	graph_editor.set_selection_batch([agent.current_node_id], [], true)
	graph_editor.set_agent_selection([agent], false)

func _on_agent_selection_changed(selected_agents: Array) -> void:
	# Highlight the row in the list
	for id in _roster_map:
		_roster_map[id].modulate = Color.WHITE
		
	if not selected_agents.is_empty():
		var id = selected_agents[0].id
		if _roster_map.has(id):
			_roster_map[id].modulate = Color(1, 0.8, 0.2) # Gold Highlight

func _update_stats() -> void:
	if lbl_stats:
		var count = graph_editor.graph.agents.size()
		var active = 0
		for a in graph_editor.graph.agents:
			if a.active: active += 1
		lbl_stats.text = "Agents: %d (%d Active)" % [count, active]

func _on_graph_modified() -> void:
	# Simple rebuild for now. In future, optimize to only update changed rows.
	_full_roster_rebuild()

# Updates the text/color of existing rows without destroying them (Fast)
func _refresh_roster_status() -> void:
	for id in _roster_map:
		_update_row_visuals(id)

# Updates a single row's UI based on the agent's current state
func _update_row_visuals(agent_id: int) -> void:
	if not _roster_map.has(agent_id): return
	
	var row = _roster_map[agent_id]
	# Children order based on creation: [0]=Icon, [1]=Name, [2]=Location, [3]=Button
	var icon = row.get_child(0) as ColorRect
	var lbl_loc = row.get_child(2) as Label
	
	# Find the actual agent object in the graph
	var agent = null
	for a in graph_editor.graph.agents:
		if a.id == agent_id:
			agent = a
			break
			
	if agent:
		# Update UI values
		lbl_loc.text = "@ %s" % agent.current_node_id
		icon.color = Color.GREEN if agent.active else Color.RED

# ==============================================================================
# 2. BEHAVIOR LOGIC (Using SettingsUIBuilder)
# ==============================================================================

func _build_behavior_ui() -> void:
	if not behavior_settings_box: return
	
	# DEFINE SCHEMA (This is where Phase 3 & 4 happen)
	var schema = [
		{ 
			"name": "global_behavior", 
			"label": "Global Order", 
			"type": TYPE_INT, 
			"default": 0, 
			"hint": "enum", 
			"hint_string": "Hold Position,Paint (Random),Grow (Expansion),Seek Target" 
		},
		{
			"name": "movement_algo",
			"label": "Algorithm",
			"type": TYPE_INT,
			"default": 0,
			"hint": "enum",
			"hint_string": "Random Walk,Breadth-First,Depth-First,A-Star"
		},
		{
			"name": "target_node",
			"label": "Target Node ID",
			"type": TYPE_STRING,
			"default": "",
			"hint": "Destination for Seek/A*"
		}
	]
	
	# BUILD UI
	_active_inputs = SettingsUIBuilder.build_ui(schema, behavior_settings_box)
	SettingsUIBuilder.connect_live_updates(_active_inputs, _on_behavior_changed)

func _on_behavior_changed(key: String, value: Variant) -> void:
	print("Global Behavior Change: %s -> %s" % [key, value])
	# TODO: In Phase 4, we will loop through graph.agents and update their state here.

# ==============================================================================
# 3. PLAYBACK CONTROLS
# ==============================================================================

func _on_step_pressed() -> void:
	# Pause auto-play if we step manually
	if btn_play and is_playing: 
		btn_play.button_pressed = false
	_perform_step()

func _perform_step() -> void:
	var sim = graph_editor.simulation
	if not sim: return
	
	# [UPDATED] We could pass sim_params here if we update Simulation.step() signature later
	var cmd = sim.step()
	
	if cmd:
		graph_editor._commit_command(cmd)
		_update_stats()
		_refresh_roster_status()
	else:
		if btn_play: btn_play.button_pressed = false
		_update_stats()
		_refresh_roster_status()

# [UPDATED] Replaces stub with proper Toggle logic
func _on_play_toggled(toggled_on: bool) -> void:
	is_playing = toggled_on
	if btn_play: btn_play.text = "Pause" if toggled_on else "Play"

# Deprecated Stub - Removed/Disconnected in _ready
func _on_play_pressed() -> void:
	pass

# [UPDATED] Reset Handler
func _on_reset_pressed() -> void:
	if btn_play: btn_play.button_pressed = false
	
	if graph_editor.simulation:
		# 1. Reset Logic
		graph_editor.simulation.reset_state()
		
		# 2. Reset Visuals (The Fix)
		# We must talk to the RENDERER, not just the editor root
		if graph_editor.renderer:
			graph_editor.renderer.queue_redraw()
		else:
			# Fallback if renderer isn't exposed directly
			graph_editor.queue_redraw()
			
		# 3. Reset UI
		_full_roster_rebuild()
