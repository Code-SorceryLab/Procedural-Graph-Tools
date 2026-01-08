extends Node
class_name InspectorController


const MAX_ANALYSIS_COUNT: int = 200 # Max items before we skip deep analysis

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

# 5. EDGE INSPECTOR
@export_group("Edge Inspector")
@export var edge_container: Control      # Parent container for edge UI
@export var lbl_edge_header: Label       # e.g. "Edge A->B" or "5 Edges"
@export var edge_settings_box: Control   # Where dynamic controls go

# State tracking
var _tracked_nodes: Array[String] = []
var _tracked_edges: Array = []           # Array of [id_a, id_b] pairs

var _is_updating_ui: bool = false
var _current_walker_ref: Object = null 
var _current_walker_list: Array = [] # Store all agents at this node

# Store the dynamically generated controls
var _walker_inputs: Dictionary = {}
var _edge_inputs: Dictionary = {}        # Store edge controls

func _ready() -> void:
	graph_editor.selection_changed.connect(_on_selection_changed)
	
	# Connect Edge Selection
	if graph_editor.has_signal("edge_selection_changed"):
		graph_editor.edge_selection_changed.connect(_on_edge_selection_changed)
	
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

# ==============================================================================
# SELECTION HANDLERS
# ==============================================================================

func _on_selection_changed(selected_nodes: Array[String]) -> void:
	_tracked_nodes = selected_nodes
	_refresh_all_views()

func _on_edge_selection_changed(selected_edges: Array) -> void:
	_tracked_edges = selected_edges
	
	# Immediate UI rebuild when selection changes (for dynamic controls)
	if not _tracked_edges.is_empty():
		_rebuild_edge_inspector_ui()
		
	_refresh_all_views()

# THE NEW VISIBILITY ROUTER (Replaces _show_view)
func _refresh_all_views() -> void:
	var has_nodes = not _tracked_nodes.is_empty()
	var has_edges = not _tracked_edges.is_empty()
	
	# 1. No Selection State
	lbl_no_selection.visible = (not has_nodes and not has_edges)
	
	# 2. Node Inspector Logic
	if has_nodes:
		single_container.visible = (_tracked_nodes.size() == 1)
		group_container.visible = (_tracked_nodes.size() > 1)
		
		# Trigger updates immediately so we don't wait for next frame
		if _tracked_nodes.size() == 1:
			_update_single_inspector(_tracked_nodes[0])
		else:
			_update_group_inspector(_tracked_nodes)
	else:
		single_container.visible = false
		group_container.visible = false
		
	# 3. Edge Inspector Logic (Independent)
	if has_edges:
		edge_container.visible = true
	else:
		edge_container.visible = false
		
	# 4. Processing (Only needed for live Node position updates)
	set_process(has_nodes)

# ==============================================================================
# EDGE VIEW LOGIC (NEW)
# ==============================================================================

func _rebuild_edge_inspector_ui() -> void:
	# 1. Clean up old UI
	for child in edge_settings_box.get_children():
		child.queue_free()
	_edge_inputs.clear()
	
	if _tracked_edges.is_empty(): return

	# 2. Determine Mode (Single vs Group)
	var schema = []
	var graph = graph_editor.graph 
	
	if _tracked_edges.size() == 1:
		# --- SINGLE EDGE MODE (Unchanged) ---
		var pair = _tracked_edges[0]
		var id_a = pair[0]
		var id_b = pair[1]
		
		lbl_edge_header.text = "%s <-> %s" % [id_a, id_b]
		
		var data = graph.get_edge_data(id_a, id_b)
		var weight = data.get("weight", 1.0)
		
		var has_ab = graph.has_edge(id_a, id_b)
		var has_ba = graph.has_edge(id_b, id_a)
		
		var current_mode = 0 
		if has_ab and not has_ba: current_mode = 1
		elif not has_ab and has_ba: current_mode = 2
		
		schema = [
			{
				"name": "weight", 
				"type": TYPE_FLOAT, 
				"default": weight, 
				"min": 0.1, "max": 100.0, "step": 0.1
			},
			{
				"name": "direction", 
				"label": "Orientation", 
				"type": TYPE_INT, 
				"default": current_mode, 
				"hint": "enum", 
				"hint_string": "Bi-Directional,Forward (A->B),Reverse (B->A)"
			}
		]
		
	else:
		# --- GROUP EDGE MODE ---
		var count = _tracked_edges.size()
		lbl_edge_header.text = "Selected %d Edges" % count
		
		var display_w = 1.0
		var label_w = "Weight (Bulk)"
		
		var display_mode = -1
		var label_dir = "Orientation (Bulk)"
		
		# OPTIMIZATION: Only analyze if count is small
		if count <= MAX_ANALYSIS_COUNT:
			var total_w = 0.0
			var first_w = -1.0
			var is_mixed_w = false
			
			var first_mode = -1
			var is_mixed_dir = false
			
			for i in range(count):
				var pair = _tracked_edges[i]
				var u = pair[0] 
				var v = pair[1] 
				
				# 1. Weight Analysis
				var w = 1.0
				if graph.has_edge(u, v):
					w = graph.get_edge_weight(u, v)
				elif graph.has_edge(v, u):
					w = graph.get_edge_weight(v, u)
				
				if i == 0: first_w = w
				elif not is_equal_approx(w, first_w): is_mixed_w = true
				total_w += w
				
				# 2. Direction Analysis
				var has_ab = graph.has_edge(u, v)
				var has_ba = graph.has_edge(v, u)
				var mode = 0 
				if has_ab and not has_ba: mode = 1 
				elif not has_ab and has_ba: mode = 2 
				
				if i == 0: first_mode = mode
				elif mode != first_mode: is_mixed_dir = true
			
			# Set precise labels
			if is_mixed_w:
				display_w = total_w / count
				label_w = "Weight (Average)"
			else:
				display_w = first_w
				label_w = "Weight"
				
			if is_mixed_dir:
				display_mode = -1
				label_dir = "Orientation (Mixed)"
			else:
				display_mode = first_mode
				label_dir = "Orientation"
		
		schema = [
			{
				"name": "weight", 
				"label": label_w,
				"type": TYPE_FLOAT, 
				"default": display_w, 
				"min": 0.1, "max": 100.0, "step": 0.1
			},
			{
				"name": "direction", 
				"label": label_dir,
				"type": TYPE_INT, 
				"default": display_mode, 
				"hint": "enum", 
				"hint_string": "Bi-Directional,Forward (A->B),Reverse (B->A)"
			}
		]

	# 3. Build UI
	_edge_inputs = SettingsUIBuilder.build_ui(schema, edge_settings_box)
	
	# 4. Connect Signals
	SettingsUIBuilder.connect_live_updates(_edge_inputs, _on_edge_setting_changed)

func _on_edge_setting_changed(key: String, value: Variant) -> void:
	if _tracked_edges.is_empty(): return
	
	for pair in _tracked_edges:
		var u = pair[0]
		var v = pair[1]
		
		match key:
			"weight":
				graph_editor.set_edge_weight(u, v, value)
			"direction":
				# Call the correctly named function with the INT value
				graph_editor.set_edge_directionality(u, v, int(value))
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
	
	# Basic Stats (Fast O(N))
	var center_sum = Vector2.ZERO
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	
	var first_id = nodes[0]
	var first_type = graph.nodes[first_id].type
	var is_mixed = false
	
	# We still need one loop for bounds/center, which is usually fine up to ~5000 nodes
	for id in nodes:
		if not graph.nodes.has(id): continue
		var pos = graph.nodes[id].position
		center_sum += pos
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)
		
		if graph.nodes[id].type != first_type:
			is_mixed = true
	
	var avg_center = center_sum / count
	var size = max_pos - min_pos
	
	# OPTIMIZATION: Skip Density Calculation for large groups
	var internal_connections = -1
	
	if count <= MAX_ANALYSIS_COUNT:
		var node_set = {}
		for id in nodes: node_set[id] = true
		
		internal_connections = 0
		for id in nodes:
			if not graph.nodes.has(id): continue
			var neighbors = graph.get_neighbors(id)
			for n_id in neighbors:
				if node_set.has(n_id):
					internal_connections += 1
		internal_connections /= 2 # Unique edges
	
	_is_updating_ui = true
	
	lbl_group_count.text = "Selected: %d Nodes" % count
	lbl_group_center.text = "Center: (%.1f, %.1f)" % [avg_center.x, avg_center.y]
	lbl_group_bounds.text = "Bounds: %.0f x %.0f" % [size.x, size.y]
	
	if internal_connections >= 0:
		lbl_group_density.text = "Internal Edges: %d" % internal_connections
	else:
		lbl_group_density.text = "Density: (Skipped)"
	
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
	_tracked_edges = []
	_refresh_all_views()

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
		
