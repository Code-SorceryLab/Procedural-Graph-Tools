extends Node
class_name AgentController

# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor

@export_group("UI Nodes")
@export var roster_list: VBoxContainer		# The VBox inside the ScrollContainer
@export var behavior_settings_box: Control	# The VBox inside the Bottom Panel
@export var lbl_stats: Label


# --- STATE ---
var _roster_map: Dictionary = {}  # agent_id -> Control
var _active_inputs: Dictionary = {} # For the Behavior Panel


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
	

	
	# 2. Build Initial UI
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
	
	# D. View Button (Focus Camera)
	var btn_view = Button.new()
	btn_view.text = "View"
	btn_view.flat = true
	# "View" selects AND focuses camera
	btn_view.pressed.connect(func(): 
		_select_agent_from_roster(agent)
		# Optional: Add camera jump logic here if not already in selection
	)
	row.add_child(btn_view)

	# E. Settings Button (Gear)
	var btn_edit = Button.new()
	btn_edit.text = "⚙" # Unicode Gear
	btn_edit.tooltip_text = "Edit Agent Behavior"
	# "Gear" just selects the agent (which updates the bottom panel inputs)
	btn_edit.pressed.connect(func(): 
		_select_agent_from_roster(agent)
		
	# Reuse the existing signal pipeline
		if graph_editor.has_signal("request_inspector_view"):
			graph_editor.request_inspector_view.emit()
	)
	row.add_child(btn_edit)
	
	roster_list.add_child(row)
	_roster_map[agent.id] = row

func _select_agent_from_roster(agent) -> void:
	# Trigger Editor Selection
	graph_editor.set_selection_batch([agent.current_node_id], [], true)
	graph_editor.set_agent_selection([agent], false)

func _on_agent_selection_changed(selected_agents: Array) -> void:
	# 1. Highlight the row (Existing logic)
	for id in _roster_map:
		_roster_map[id].modulate = Color.WHITE
		
	if selected_agents.is_empty():
		return

	var primary_agent = selected_agents[0]
	var id = primary_agent.id
	if _roster_map.has(id):
		_roster_map[id].modulate = Color(1, 0.8, 0.2) # Gold Highlight

	# 2. Sync UI to Selected Agent
	_sync_inputs_to_agent(primary_agent)

# Helper to push Agent Data -> UI Inputs
func _sync_inputs_to_agent(agent: AgentWalker) -> void:
	# We access the UI controls stored in _active_inputs and update them
	
	# Global Behavior (Dropdown)
	if _active_inputs.has("global_behavior"):
		var opt = _active_inputs["global_behavior"] as OptionButton
		if opt: opt.selected = agent.behavior_mode
		
	# Movement Algo (Dropdown)
	if _active_inputs.has("movement_algo"):
		var opt = _active_inputs["movement_algo"] as OptionButton
		if opt: opt.selected = agent.movement_algo
		
	# Target Node (LineEdit)
	if _active_inputs.has("target_node"):
		var field = _active_inputs["target_node"] as LineEdit
		if field: field.text = agent.target_node_id
		
	# Add any other fields here (e.g. Paint Color) if you added them to the schema


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
		# [NEW] Pick Button (Action)
		{
			"name": "action_pick_target",
			"label": "Pick Target Node",
			"type": TYPE_BOOL, # Type doesn't matter for actions
			"hint": "action"   # Tells builder to make a button
		},
		{
			"name": "target_node",
			"label": "Target Node ID",
			"type": TYPE_STRING,
			"default": "",
			"hint": "Destination for Seek/A*"
		}
	]
	
	_active_inputs = SettingsUIBuilder.build_ui(schema, behavior_settings_box)
	SettingsUIBuilder.connect_live_updates(_active_inputs, _on_behavior_changed)

func _on_behavior_changed(key: String, value: Variant) -> void:
	# [NEW] Handle Pick Action
	if key == "action_pick_target":
		graph_editor.request_node_pick(_on_target_picked)
		return
	# 1. Get Selected Agents
	var agents_to_update = []
	
	if not graph_editor.selected_agent_ids.is_empty():
		# [FIX] The array already contains AgentWalker objects (passed from Roster).
		# We don't need to search for them by ID.
		agents_to_update = graph_editor.selected_agent_ids
	else:
		# Fallback: Update everyone if nothing selected (Global Order)
		agents_to_update = graph_editor.graph.agents
	
	# 2. Apply Value
	for agent in agents_to_update:
		# Safety check to ensure we are talking to a Walker
		if agent.has_method("apply_setting"):
			agent.apply_setting(key, value)
		
	print("Updated %d agents: %s -> %s" % [agents_to_update.size(), key, value])

# [NEW] Callback when node is clicked
func _on_target_picked(node_id: String) -> void:
	# 1. Update the UI Text Box (so the user sees the ID)
	if _active_inputs.has("target_node"):
		var line_edit = _active_inputs["target_node"] as LineEdit
		line_edit.text = node_id
		# Trigger the change event manually to update agents
		_on_behavior_changed("target_node", node_id)
		
	print("Picked Target Node: ", node_id)
