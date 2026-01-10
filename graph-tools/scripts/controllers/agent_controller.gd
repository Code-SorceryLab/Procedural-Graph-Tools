extends Node
class_name AgentController

# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor

@export_group("UI Nodes")
@export var roster_list: VBoxContainer        # The VBox inside the ScrollContainer
@export var behavior_settings_box: Control    # The VBox inside the Bottom Panel
@export var btn_step: Button
@export var btn_play: Button
@export var btn_reset: Button
@export var lbl_stats: Label

# --- STATE ---
var _roster_map: Dictionary = {}  # agent_id -> Control
var _active_inputs: Dictionary = {} # For the Behavior Panel

func _ready() -> void:
	# 1. Listen for Graph Changes
	graph_editor.graph_modified.connect(_on_graph_modified)
	graph_editor.graph_loaded.connect(func(_g): _full_roster_rebuild())
	
	if graph_editor.has_signal("agent_selection_changed"):
		graph_editor.agent_selection_changed.connect(_on_agent_selection_changed)
	
	# 2. Playback Signals
	if btn_step: btn_step.pressed.connect(_on_step_pressed)
	if btn_play: btn_play.pressed.connect(_on_play_pressed)
	if btn_reset: btn_reset.pressed.connect(_on_reset_pressed)
	
	# 3. Build Initial UI
	_full_roster_rebuild()
	_build_behavior_ui()

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
	
	# Optional: Center Camera
	# var pos = graph_editor.graph.get_node_pos(agent.current_node_id)
	# graph_editor.camera.center_on_position(pos)

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
# 3. PLAYBACK STUBS
# ==============================================================================
func _on_step_pressed() -> void:
	print("Step!")

func _on_play_pressed() -> void:
	print("Play/Pause")

func _on_reset_pressed() -> void:
	graph_editor.graph.agents.clear()
	graph_editor.set_path_starts([])
	graph_editor.set_path_ends([])
	graph_editor.queue_redraw()
	_full_roster_rebuild()
