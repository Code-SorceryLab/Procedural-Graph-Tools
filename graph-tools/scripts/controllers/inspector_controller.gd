extends Node
class_name InspectorController

# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor
@export var strategy_controller: StrategyController

@export_group("UI Inspector Tab")
# 1. THE VIEW CONTAINERS
@export var lbl_no_selection: Label      
@export var single_container: Control    
@export var group_container: Control     

# 2. SINGLE NODE CONTROLS
@export var lbl_id: Label
@export var spin_pos_x: SpinBox
@export var spin_pos_y: SpinBox
@export var option_type: OptionButton
@export var lbl_edges: Label
@export var lbl_neighbors: RichTextLabel

# 3. WALKER CONTROLS
@export_group("Walker Inspector")
@export var walker_container: Control      
@export var opt_walker_select: OptionButton 
@export var lbl_walker_id: Label           


# 4. GROUP STATS CONTROLS
@export_group("Group Inspector")
@export var lbl_group_count: Label
@export var lbl_group_center: Label
@export var lbl_group_bounds: Label
@export var lbl_group_density: Label
@export var group_option_type: OptionButton 

# State tracking
var _tracked_nodes: Array[String] = []
var _is_updating_ui: bool = false
var _current_walker_ref: Object = null 
var _current_walker_list: Array = [] # Store all agents at this node

# Store the dynamically generated controls
var _walker_inputs: Dictionary = {}

func _ready() -> void:
	graph_editor.selection_changed.connect(_on_selection_changed)
	set_process(false)
	
	# --- 1. CONFIGURE SPINBOXES ---
	spin_pos_x.step = GraphSettings.INSPECTOR_POS_STEP
	spin_pos_y.step = GraphSettings.INSPECTOR_POS_STEP
	spin_pos_x.min_value = -99999; spin_pos_x.max_value = 99999
	spin_pos_y.min_value = -99999; spin_pos_y.max_value = 99999

	
	spin_pos_x.value_changed.connect(_on_pos_value_changed)
	spin_pos_y.value_changed.connect(_on_pos_value_changed)
	
	# --- 2. CONFIGURE DROPDOWNS ---
	_setup_type_dropdown(option_type)
	_setup_type_dropdown(group_option_type)

	
	option_type.item_selected.connect(_on_type_selected)
	group_option_type.item_selected.connect(_on_group_type_selected)
	
	# WALKER SIGNALS
	opt_walker_select.item_selected.connect(_on_walker_agent_selected)

	_clear_inspector()

func _setup_type_dropdown(btn: OptionButton) -> void:
	btn.clear()
	var ids = GraphSettings.current_names.keys()
	ids.sort() 
	for id in ids:
		var type_name = GraphSettings.get_type_name(id)
		btn.add_item(type_name, id)

func _on_selection_changed(selected_nodes: Array[String]) -> void:
	_tracked_nodes = selected_nodes
	
	if _tracked_nodes.is_empty():
		set_process(false)
		_show_view(0)
	elif _tracked_nodes.size() == 1:
		set_process(true)
		_show_view(1)
		_update_single_inspector(_tracked_nodes[0])
	else:
		set_process(true)
		_show_view(2)
		_update_group_inspector(_tracked_nodes)

func _process(_delta: float) -> void:
	if _tracked_nodes.size() == 1:
		_update_single_inspector(_tracked_nodes[0])
	elif _tracked_nodes.size() > 1:
		_update_group_inspector(_tracked_nodes)

# --- VIEW LOGIC ---

func _update_single_inspector(node_id: String) -> void:
	var graph = graph_editor.graph
	if not graph.nodes.has(node_id):
		_on_selection_changed([]) 
		return

	var node_data = graph.nodes[node_id]
	var neighbors = graph.get_neighbors(node_id)
	
	_is_updating_ui = true
	
	# 1. Standard Node Data
	lbl_id.text = "ID: %s" % node_id
	
	var x_focus = spin_pos_x.get_line_edit().has_focus()
	var y_focus = spin_pos_y.get_line_edit().has_focus()
	if not x_focus: spin_pos_x.value = node_data.position.x
	if not y_focus: spin_pos_y.value = node_data.position.y
		
	if not option_type.has_focus():
		var idx = option_type.get_item_index(node_data.type)
		if option_type.selected != idx:
			option_type.selected = idx
	
	lbl_edges.text = "Connections: %d" % neighbors.size()
	var neighbor_text = ""
	for n_id in neighbors:
		neighbor_text += "- %s\n" % n_id
	lbl_neighbors.text = neighbor_text
	
	# ---------------------------------------------------------
	# 2. WALKER INSPECTION LOGIC (DYNAMIC)
	# ---------------------------------------------------------
	var show_walker = false
	var new_walker_list = []
	
	if strategy_controller and strategy_controller.current_strategy:
		var strat = strategy_controller.current_strategy
		if strat.has_method("get_walkers_at_node"):
			new_walker_list = strat.get_walkers_at_node(node_id)
	
	if not new_walker_list.is_empty():
		show_walker = true
		
		# A. Handle List Changes (Only Rebuild if List Content Changed)
		if new_walker_list != _current_walker_list:
			_current_walker_list = new_walker_list
			
			opt_walker_select.clear()
			var selected_idx = 0
			for i in range(_current_walker_list.size()):
				var w = _current_walker_list[i]
				var status = "" if w.get("active") else " (Paused)"
				opt_walker_select.add_item("Agent #%d%s" % [w.id, status], i)
				
				if _current_walker_ref and _current_walker_ref == w:
					selected_idx = i
			
			opt_walker_select.selected = selected_idx
			_current_walker_ref = _current_walker_list[selected_idx]
			
			# REBUILD UI: Reference changed due to list update
			_rebuild_walker_ui()

		# B. Handle Manual Dropdown Changes
		var current_dropdown_idx = opt_walker_select.selected
		if current_dropdown_idx >= 0 and current_dropdown_idx < _current_walker_list.size():
			var selected_agent = _current_walker_list[current_dropdown_idx]
			if selected_agent != _current_walker_ref:
				_current_walker_ref = selected_agent
				# REBUILD UI: User selected different agent
				_rebuild_walker_ui()
	else:
		_current_walker_list.clear()
		_current_walker_ref = null

	# Refresh Dynamic Values (Polling)
	# We only update the Label here. The generated controls update themselves 
	# via the builder unless we wanted to support 2-way sync (Agent -> UI).
	# For now, we assume UI drives Agent.
	if show_walker and _current_walker_ref:
		opt_walker_select.visible = (_current_walker_list.size() > 1)
		var steps = _current_walker_ref.get("step_count")
		lbl_walker_id.text = "Agent #%d (Steps: %d)" % [_current_walker_ref.id, steps]
	
	if walker_container:
		walker_container.visible = show_walker
	# ---------------------------------------------------------
	
	_is_updating_ui = false

# --- UI BUILDER LOGIC ---

func _rebuild_walker_ui() -> void:
	if not _current_walker_ref: return
	
	# 1. Ask Agent for Schema
	# This calls the function we added to WalkerAgent earlier
	var settings = _current_walker_ref.get_agent_settings()
	
	# 2. Setup Container
	# We create a specific VBox for settings so we don't delete the Selector/Label
	var settings_box = walker_container.get_node_or_null("SettingsBox")
	if not settings_box:
		settings_box = VBoxContainer.new()
		settings_box.name = "SettingsBox"
		walker_container.add_child(settings_box)
		
	# 3. Generate Controls
	_walker_inputs = SettingsUIBuilder.build_ui(settings, settings_box)
	
	# 4. Bind Live Updates
	SettingsUIBuilder.connect_live_updates(_walker_inputs, _on_walker_setting_changed)


func _update_group_inspector(nodes: Array[String]) -> void:
	var graph = graph_editor.graph
	var count = nodes.size()
	var center_sum = Vector2.ZERO
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	var internal_connections = 0
	
	var first_id = nodes[0]
	var first_type = graph.nodes[first_id].type
	var is_mixed = false
	var node_set = {} 
	
	for id in nodes:
		node_set[id] = true
		if graph.nodes[id].type != first_type:
			is_mixed = true
	
	for id in nodes:
		if not graph.nodes.has(id): continue
		var pos = graph.nodes[id].position
		center_sum += pos
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)
		
		var neighbors = graph.get_neighbors(id)
		for n_id in neighbors:
			if node_set.has(n_id):
				internal_connections += 1
	
	var avg_center = center_sum / count
	var size = max_pos - min_pos
	var unique_edges = internal_connections / 2
	
	_is_updating_ui = true
	
	lbl_group_count.text = "Selected: %d Nodes" % count
	lbl_group_center.text = "Center: (%.1f, %.1f)" % [avg_center.x, avg_center.y]
	lbl_group_bounds.text = "Bounds: %.0f x %.0f" % [size.x, size.y]
	lbl_group_density.text = "Internal Edges: %d" % unique_edges
	
	_setup_type_dropdown(group_option_type)
	if is_mixed:
		group_option_type.add_separator()
		group_option_type.add_item("-- Mixed --", -1)
		group_option_type.select(group_option_type.item_count - 1)
	else:
		var idx = group_option_type.get_item_index(first_type)
		group_option_type.select(idx)
		
	_is_updating_ui = false

func _show_view(view_index: int) -> void:
	lbl_no_selection.visible = (view_index == 0)
	single_container.visible = (view_index == 1)
	group_container.visible = (view_index == 2)

func _clear_inspector() -> void:
	_tracked_nodes = []
	_show_view(0)

# --- INPUT HANDLERS ---

func _on_pos_value_changed(_val: float) -> void:
	if _is_updating_ui: return
	if _tracked_nodes.size() != 1: return
	var id = _tracked_nodes[0]
	var current_pos = graph_editor.graph.get_node_pos(id)
	var new_pos = Vector2(spin_pos_x.value, spin_pos_y.value)
	
	graph_editor.set_node_position(id, new_pos)
	var move_data = { id: { "from": current_pos, "to": new_pos } }
	graph_editor.commit_move_batch(move_data)

func _on_type_selected(index: int) -> void:
	if _is_updating_ui: return
	if _tracked_nodes.size() != 1: return
	var id = _tracked_nodes[0]
	var selected_type_id = option_type.get_item_id(index)
	graph_editor.set_node_type(id, selected_type_id)

func _on_group_type_selected(index: int) -> void:
	if _is_updating_ui: return
	var selected_type_id = group_option_type.get_item_id(index)
	if selected_type_id == -1: return 
	graph_editor.set_node_type_bulk(_tracked_nodes, selected_type_id)
	_update_group_inspector(_tracked_nodes)

# --- WALKER HANDLERS ---

# 1. Selection Handler (Meta-Control) - KEEPER
func _on_walker_agent_selected(index: int) -> void:
	# User selected a specific agent from the top dropdown
	if index >= 0 and index < _current_walker_list.size():
		_current_walker_ref = _current_walker_list[index]
		# Rebuild the UI immediately for the new agent
		_rebuild_walker_ui()

# 2. Dynamic Update Handler - REPLACEMENT
# This catches signals from ALL generated controls (SpinBoxes, CheckBoxes, etc.)
func _on_walker_setting_changed(key: String, value: Variant) -> void:
	if _current_walker_ref:
		# 1. Update the Data
		_current_walker_ref.apply_setting(key, value)
		
		# 2. RESTORED: Position Snapping Logic
		# If we moved the walker manually, check if we landed on a valid node.
		if key == "pos":
			var graph = graph_editor.graph
			# Strict tolerance (1.0) to ensure we are right on top of it
			var landed_node_id = graph.get_node_at_position(value, 1.0)
			
			if not landed_node_id.is_empty():
				_current_walker_ref.current_node_id = landed_node_id
				print("Inspector: Walker snapped to node %s" % landed_node_id)
		
		# 3. UI Polish: Update Dropdown Label
		if key == "active":
			var idx = opt_walker_select.selected
			var status = "" if value else " (Paused)"
			opt_walker_select.set_item_text(idx, "Agent #%d%s" % [_current_walker_ref.id, status])
			
		print("Inspector: Updated %s -> %s" % [key, value])
		
