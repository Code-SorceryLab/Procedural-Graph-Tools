extends Node
class_name AgentController

# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor

@export_group("UI Nodes")
@export var roster_list: VBoxContainer        
@export var behavior_settings_box: Control    
@export var lbl_stats: Label
@export var lbl_edit_mode: Label

# --- STATE ---
# Key: AgentWalker Object | Value: Control (The Row)
# Using the Object as the key prevents ID collisions from breaking the UI.
var _roster_map: Dictionary = {}  
var _active_inputs: Dictionary = {} 

# Simulation Parameters
var sim_params: Dictionary = {
	"merge_overlaps": true,
	"grid_spacing": GraphSettings.GRID_SPACING
}

func _ready() -> void:
	# 1. Listen for Graph Structure Changes
	graph_editor.graph_modified.connect(_on_graph_modified)
	graph_editor.graph_loaded.connect(func(_g): _full_roster_rebuild())
	
	if graph_editor.has_signal("agent_selection_changed"):
		graph_editor.agent_selection_changed.connect(_on_agent_selection_changed)
	
	# 2. Listen to the Global Event Bus
	SignalManager.simulation_stepped.connect(_on_simulation_stepped)
	SignalManager.simulation_reset.connect(_on_simulation_reset)
	
	# 3. Build Initial UI
	_full_roster_rebuild()
	_build_behavior_ui()

# ==============================================================================
# 1. SIMULATION HANDLERS
# ==============================================================================

func _on_simulation_stepped(_tick: int) -> void:
	_refresh_roster_status()
	
	if not graph_editor.selected_agent_ids.is_empty():
		# Note: selected_agent_ids now holds Objects, so this is safe
		var agent = graph_editor.selected_agent_ids[0]
		_sync_inputs_to_agent(agent)
		_update_visualization(agent)

func _on_simulation_reset() -> void:
	_refresh_roster_status()
	
	if not graph_editor.selected_agent_ids.is_empty():
		var agent = graph_editor.selected_agent_ids[0]
		_sync_inputs_to_agent(agent)
		_update_visualization(agent)

# ==============================================================================
# 2. ROSTER LOGIC (The Fix)
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
	# Use UUID or Memory Address for unique Node Name to avoid Godot renaming spam
	row.name = "Row_%s" % [agent.uuid if "uuid" in agent else agent.get_instance_id()]
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# A. Status Icon
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(12, 12)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_update_icon_color(icon, agent) # Extracted helper
	row.add_child(icon)
	
	# B. Name
	var lbl = Label.new()
	# Use display_id if available, fallback to id
	var d_id = agent.display_id if "display_id" in agent else agent.id
	lbl.text = "Agent #%d" % d_id
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)
	
	# C. Location
	var lbl_loc = Label.new()
	lbl_loc.text = "@ %s" % agent.current_node_id
	lbl_loc.modulate = Color(1, 1, 1, 0.7)
	row.add_child(lbl_loc)
	
	# D. View Button
	var btn_view = Button.new()
	btn_view.text = "View"
	btn_view.flat = true
	btn_view.pressed.connect(func(): 
		_select_agent_from_roster(agent)
	)
	row.add_child(btn_view)

	# E. Settings Button
	var btn_edit = Button.new()
	btn_edit.text = "⚙"
	btn_edit.tooltip_text = "Edit Agent Behavior"
	btn_edit.pressed.connect(func(): 
		_select_agent_from_roster(agent)
		if graph_editor.has_signal("request_inspector_view"):
			graph_editor.request_inspector_view.emit()
	)
	row.add_child(btn_edit)
	
	roster_list.add_child(row)
	
	# [FIX] Map Key is the OBJECT, not the ID
	_roster_map[agent] = row

func _select_agent_from_roster(agent) -> void:
	graph_editor.set_selection_batch([agent.current_node_id], [], true)
	graph_editor.set_agent_selection([agent], false)

func _on_agent_selection_changed(selected_agents: Array) -> void:
	# 1. Reset Highlight
	for a in _roster_map:
		_roster_map[a].modulate = Color.WHITE
	
	if selected_agents.is_empty():
		# CASE A: No Selection -> Edit Global Template
		_sync_inputs_to_dictionary(AgentWalker.spawn_template)
		
		if lbl_edit_mode: 
			lbl_edit_mode.text = "EDITING: Global Defaults (New Agents)"
			lbl_edit_mode.modulate = Color(0.7, 0.7, 0.7)
			
		_update_visualization(null)
		return

	# CASE B: Selection -> Edit Specific Agent
	var primary_agent = selected_agents[0]
	
	# Direct Object Lookup (Fast & Safe)
	if _roster_map.has(primary_agent):
		_roster_map[primary_agent].modulate = Color(1, 0.8, 0.2)
		
	_sync_inputs_to_agent(primary_agent)
	
	if lbl_edit_mode:
		var d_id = primary_agent.display_id if "display_id" in primary_agent else primary_agent.id
		lbl_edit_mode.text = "EDITING: Agent #%d" % d_id
		lbl_edit_mode.modulate = Color(1, 0.8, 0.2)

	_update_visualization(primary_agent)

# DRIVES THE GRAPHEDITOR VISUALS
func _update_visualization(agent) -> void:
	if not graph_editor: return
	
	if agent and agent.active:
		graph_editor.set_path_starts([agent.current_node_id])
		
		if agent.behavior_mode == 3 and agent.target_node_id != "":
			graph_editor.set_path_ends([agent.target_node_id])
			
			if graph_editor.has_method("run_pathfinding"):
				graph_editor.run_pathfinding(agent.movement_algo)
		else:
			graph_editor.set_path_ends([])
			graph_editor.current_path.clear()
			graph_editor.renderer.current_path_ref = []
			graph_editor.renderer.queue_redraw()
	else:
		graph_editor.set_path_starts([])
		graph_editor.set_path_ends([])
		graph_editor.current_path.clear()
		graph_editor.renderer.current_path_ref = []
		graph_editor.renderer.queue_redraw()

func _sync_inputs_to_agent(agent: AgentWalker) -> void:
	if _active_inputs.has("global_behavior"):
		var opt = _active_inputs["global_behavior"] as OptionButton
		if opt: opt.selected = agent.behavior_mode
		
	if _active_inputs.has("movement_algo"):
		var opt = _active_inputs["movement_algo"] as OptionButton
		if opt: opt.selected = agent.movement_algo
		
	if _active_inputs.has("target_node"):
		var field = _active_inputs["target_node"] as LineEdit
		if field: 
			field.text = agent.target_node_id
			SettingsUIBuilder.sync_picker_button(_active_inputs, "action_pick_target", "Target Node", agent.target_node_id)

func _sync_inputs_to_dictionary(data: Dictionary) -> void:
	if _active_inputs.has("global_behavior") and data.has("global_behavior"):
		_active_inputs["global_behavior"].selected = data["global_behavior"]
		
	if _active_inputs.has("movement_algo") and data.has("movement_algo"):
		_active_inputs["movement_algo"].selected = data["movement_algo"]
		
	if _active_inputs.has("target_node") and data.has("target_node_id"):
		_active_inputs["target_node"].text = data["target_node_id"]
		SettingsUIBuilder.sync_picker_button(_active_inputs, "action_pick_target", "Target Node", data["target_node_id"])

func _update_stats() -> void:
	if lbl_stats:
		var count = graph_editor.graph.agents.size()
		var active = 0
		for a in graph_editor.graph.agents:
			if a.active: active += 1
		lbl_stats.text = "Agents: %d (%d Active)" % [count, active]

func _on_graph_modified() -> void:
	_full_roster_rebuild()
	if not graph_editor.selected_agent_ids.is_empty():
		_update_visualization(graph_editor.selected_agent_ids[0])

func _refresh_roster_status() -> void:
	# Iterate KEYS (Agents) directly
	for agent in _roster_map:
		_update_row_visuals(agent)

# [FIXED] Takes Agent Object, not ID
func _update_row_visuals(agent) -> void:
	if not _roster_map.has(agent): return
	
	var row = _roster_map[agent]
	var icon = row.get_child(0) as ColorRect
	var lbl_loc = row.get_child(2) as Label
	
	# No loop needed! We have the direct object reference.
	lbl_loc.text = "@ %s" % agent.current_node_id
	_update_icon_color(icon, agent)

func _update_icon_color(rect: ColorRect, agent) -> void:
	if not agent.active:
		rect.color = Color.RED
	elif agent.is_finished:
		rect.color = Color.YELLOW
	else:
		rect.color = Color.GREEN

# ==============================================================================
# 3. BEHAVIOR UI LOGIC
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
		{
			"name": "action_pick_target",
			"label": "Pick Target Node (None)", 
			"type": TYPE_BOOL, 
			"hint": "action"   
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
	if key == "action_pick_target":
		graph_editor.request_node_pick(_on_target_picked)
		return

	if key == "target_node":
		SettingsUIBuilder.sync_picker_button(_active_inputs, "action_pick_target", "Target Node", value)

	if graph_editor.selected_agent_ids.is_empty():
		AgentWalker.update_template(key, value)
		print("Updated Global Template: %s -> %s" % [key, value])
	else:
		var agents_to_update = graph_editor.selected_agent_ids
		for agent in agents_to_update:
			if agent.has_method("apply_setting"):
				agent.apply_setting(key, value)
				
		if not agents_to_update.is_empty():
			_update_visualization(agents_to_update[0])

func _on_target_picked(node_id: String) -> void:
	if _active_inputs.has("target_node"):
		var line_edit = _active_inputs["target_node"] as LineEdit
		line_edit.text = node_id
		_on_behavior_changed("target_node", node_id)
		
	print("Picked Target Node: ", node_id)
