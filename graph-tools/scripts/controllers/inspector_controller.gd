extends Node
class_name InspectorController




# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor
@export var strategy_controller: StrategyController


@export_group("UI Inspector Tab")
# 0. TAB CONTAINER
@export var inspector_vbox: VBoxContainer

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
var _tracked_agents: Array = []

var _is_updating_ui: bool = false
var _current_walker_ref: Object = null 
var _current_walker_list: Array = [] # Store all agents at this node

# Store the dynamically generated controls
var _walker_inputs: Dictionary = {}
var _edge_inputs: Dictionary = {}        # Store edge controls

func _ready() -> void:
	# 1. Connect Core Signals
	graph_editor.selection_changed.connect(_on_selection_changed)
	
	if graph_editor.has_signal("edge_selection_changed"):
		graph_editor.edge_selection_changed.connect(_on_edge_selection_changed)

	# [CHECK THIS BLOCK]
	if graph_editor.has_signal("agent_selection_changed"):
		graph_editor.agent_selection_changed.connect(_on_agent_selection_changed)
	else:
		push_error("Inspector: GraphEditor missing 'agent_selection_changed' signal!")
	
	graph_editor.graph_loaded.connect(func(_g): refresh_type_options())
	
	if graph_editor.has_signal("request_inspector_view"):
		graph_editor.request_inspector_view.connect(_on_inspector_view_requested)
	

	
	set_process(false)
	
	# --- 1. CONFIGURE SPINBOXES ---
	spin_pos_x.step = GraphSettings.INSPECTOR_POS_STEP
	spin_pos_y.step = GraphSettings.INSPECTOR_POS_STEP
	spin_pos_x.min_value = -99999; spin_pos_x.max_value = 99999
	spin_pos_y.min_value = -99999; spin_pos_y.max_value = 99999

	
	spin_pos_x.value_changed.connect(_on_pos_value_changed)
	spin_pos_y.value_changed.connect(_on_pos_value_changed)
	
	# --- 2. CONFIGURE DROPDOWNS ---
	# Initial build on startup
	refresh_type_options()

	
	option_type.item_selected.connect(_on_type_selected)
	group_option_type.item_selected.connect(_on_group_type_selected)
	
	# WALKER SIGNALS
	opt_walker_select.item_selected.connect(_on_walker_dropdown_selected)

	_clear_inspector()
	#GraphSettings.print_custom_method_names(self)

# The Handler
# This logic is robust: it works if you use a TabContainer OR just a normal layout.
func _on_inspector_view_requested() -> void:
	if not inspector_vbox: return
	
	var parent = inspector_vbox.get_parent()
	
	# Scenario A: It's inside a TabContainer (Your current setup)
	# We must tell the parent to switch tabs, otherwise visibility won't change.
	if parent is TabContainer:
		parent.current_tab = inspector_vbox.get_index()
		
	# Scenario B: It's just a hidden panel (Future proofing)
	else:
		inspector_vbox.visible = true

# Public function to force a rebuild of type lists
# Called on _ready and when graph_loaded signal fires.
func refresh_type_options() -> void:
	_setup_type_dropdown(option_type)
	_setup_type_dropdown(group_option_type)
	# Add the "Mixed" separator to group dropdown pre-emptively
	group_option_type.add_separator()
	group_option_type.add_item("-- Mixed --", -1)

func _setup_type_dropdown(btn: OptionButton) -> void:
	btn.clear()
	# This pulls from the global settings, which includes loaded custom types
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
	_check_selection_state()

func _on_edge_selection_changed(selected_edges: Array) -> void:
	_tracked_edges = selected_edges
	# Immediate rebuild for edges (legacy behavior preserved)
	if not _tracked_edges.is_empty():
		_rebuild_edge_inspector_ui()
	_check_selection_state()

# Handler for direct agent selection
func _on_agent_selection_changed(selected_agents: Array) -> void:
	print("Inspector: Agent Selection Signal Received. Count: ", selected_agents.size())
	_tracked_agents = selected_agents
	_check_selection_state()

# Central State Checker
# Decides if the Inspector should be open or closed
func _check_selection_state() -> void:
	if _tracked_nodes.is_empty() and _tracked_edges.is_empty() and _tracked_agents.is_empty():
		_clear_inspector()
	else:
		_refresh_all_views()

# THE VISIBILITY ROUTER
func _refresh_all_views() -> void:
	var has_nodes = not _tracked_nodes.is_empty()
	var has_edges = not _tracked_edges.is_empty()
	var has_agents = not _tracked_agents.is_empty()
	
	# 1. No Selection State (Only if ALL are empty)
	lbl_no_selection.visible = (not has_nodes and not has_edges and not has_agents)
	
	# 2. Node Inspector Logic
	if has_nodes:
		single_container.visible = (_tracked_nodes.size() == 1)
		group_container.visible = (_tracked_nodes.size() > 1)
		
		# Trigger Node Updates
		if _tracked_nodes.size() == 1:
			_update_single_inspector(_tracked_nodes[0])
		else:
			_update_group_inspector(_tracked_nodes)
	else:
		single_container.visible = false #THIS PART IS IMPORTANT FOR THE BUG!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
		#group_container.visible = false
		pass
	# 3. Edge Inspector Logic (Independent)
	edge_container.visible = has_edges
	
	# 4. Walker Inspector Logic (Decoupled)
	var show_walkers = false
	
	if has_agents:
		# Priority A: Direct Agent Selection
		# If we clicked an agent specifically, SHOW IT.
		show_walkers = true
		_update_walker_inspector_from_selection()
		
	elif has_nodes and _tracked_nodes.size() == 1:
		# Priority B: Indirect Selection (Node Click)
		# If we clicked a node, check if it has agents to show.
		show_walkers = _update_walker_inspector_from_node(_tracked_nodes[0])
		
	walker_container.visible = show_walkers
		
	# 5. Processing (Only needed for live Node position updates)
	set_process(has_nodes)

# ==============================================================================
# EDGE VIEW LOGIC 
# ==============================================================================

# 4. Edge Schema Generator
# Calculates weights/directions and returns the UI settings list.
func _get_edge_inspector_schema() -> Array:
	if _tracked_edges.is_empty(): return []
	
	var graph = graph_editor.graph 
	
	# --- CASE A: SINGLE EDGE ---
	if _tracked_edges.size() == 1:
		var pair = _tracked_edges[0]
		var id_a = pair[0] # Alphabetically first
		var id_b = pair[1] # Alphabetically second
		
		lbl_edge_header.text = "%s <-> %s" % [id_a, id_b]
		
		# [FIX START] Check direction to get correct weight
		var weight = 1.0
		
		# Check forward
		if graph.has_edge(id_a, id_b):
			weight = graph.get_edge_weight(id_a, id_b)
		# Check reverse
		elif graph.has_edge(id_b, id_a):
			weight = graph.get_edge_weight(id_b, id_a)
		# [FIX END]
		
		var has_ab = graph.has_edge(id_a, id_b)
		var has_ba = graph.has_edge(id_b, id_a)
		
		var current_mode = 0 
		if has_ab and not has_ba: current_mode = 1
		elif not has_ab and has_ba: current_mode = 2
		
		return [
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
		
	# --- CASE B: GROUP EDGES ---
	else:
		var count = _tracked_edges.size()
		lbl_edge_header.text = "Selected %d Edges" % count
		
		var display_w = 1.0
		var label_w = "Weight (Bulk)"
		
		var display_mode = -1
		var label_dir = "Orientation (Bulk)"
		
		# Optimization limit
		if count <= GraphSettings.MAX_ANALYSIS_COUNT:
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
		
		return [
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

func _rebuild_edge_inspector_ui() -> void:
	# 1. Get Schema
	var schema = _get_edge_inspector_schema()
	
	# 2. Render
	_edge_inputs = _render_dynamic_section(
		edge_settings_box, 
		schema, 
		_on_edge_setting_changed
	)

func _on_edge_setting_changed(key: String, value: Variant) -> void:
	if _tracked_edges.is_empty(): return
	
	var graph = graph_editor.graph # Get reference for checking existence
	
	for pair in _tracked_edges:
		var u = pair[0]
		var v = pair[1]
		
		match key:
			"weight":
				# [FIX] Apply to whichever direction(s) actually exist
				if graph.has_edge(u, v):
					graph_editor.set_edge_weight(u, v, value)
				
				if graph.has_edge(v, u):
					graph_editor.set_edge_weight(v, u, value)
					
			"direction":
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
	
	# 1. Update Static Node Controls
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
	
	# 2. Update Walker State (Delegated)
	_refresh_walker_list_state(node_id)
	
	_is_updating_ui = false

# --- UI BUILDER LOGIC ---

func _rebuild_walker_ui() -> void:
	if not _current_walker_ref: return
	
	# Safety Check
	if not _current_walker_ref.has_method("get_agent_settings"):
		return

	# 1. Ask Agent for Schema
	var settings = _current_walker_ref.get_agent_settings()
	
	# 2. Render
	_walker_inputs = _render_dynamic_section(
		walker_container, 
		settings, 
		_on_walker_setting_changed
	)
	
	# [FIX] Explicitly show the container
	walker_container.visible = true


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
	
	var internal_connections = -1
	if count <= GraphSettings.MAX_ANALYSIS_COUNT:
		var node_set = {}
		for id in nodes: node_set[id] = true
		internal_connections = 0
		for id in nodes:
			if not graph.nodes.has(id): continue
			var neighbors = graph.get_neighbors(id)
			for n_id in neighbors:
				if node_set.has(n_id):
					internal_connections += 1
		internal_connections /= 2 
	
	_is_updating_ui = true
	
	lbl_group_count.text = "Selected: %d Nodes" % count
	lbl_group_center.text = "Center: (%.1f, %.1f)" % [avg_center.x, avg_center.y]
	lbl_group_bounds.text = "Bounds: %.0f x %.0f" % [size.x, size.y]
	
	if internal_connections >= 0:
		lbl_group_density.text = "Internal Edges: %d" % internal_connections
	else:
		lbl_group_density.text = "Density: (Skipped)"
	
	# [FIX] Don't rebuild list. Just Select.
	if is_mixed:
		# Select the last item (which we added as "-- Mixed --" in refresh_type_options)
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
	_tracked_agents = []
	
	# Cleanup Walker Specifics
	_current_walker_ref = null
	graph_editor.set_node_labels({})
	
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

# 3. State Manager (Refactored)
# Handles fetching the list, diffing it, updating the dropdown, and auto-selecting.
func _refresh_walker_list_state(node_id: String) -> void:
	var new_walker_list = []
	
	# A. Fetch Data
	if strategy_controller and strategy_controller.current_strategy:
		var strat = strategy_controller.current_strategy
		if strat.has_method("get_walkers_at_node"):
			# [FIX] Pass graph_editor.graph as the second argument
			new_walker_list = strat.get_walkers_at_node(node_id, graph_editor.graph)
			
	var show_walker = not new_walker_list.is_empty()
	
	if show_walker:
		# B. Handle List Changes (Diffing)
		if new_walker_list != _current_walker_list:
			_current_walker_list = new_walker_list
			
			opt_walker_select.clear()
			var selected_idx = 0
			
			for i in range(_current_walker_list.size()):
				var w = _current_walker_list[i]
				var status = "" if w.get("active") else " (Paused)"
				opt_walker_select.add_item("Agent #%d%s" % [w.id, status], i)
				
				# Maintain previous selection if it still exists in the list
				if _current_walker_ref and _current_walker_ref == w:
					selected_idx = i
			
			opt_walker_select.selected = selected_idx
			
			# Force activation of the new selection
			_activate_walker_visuals(_current_walker_list[selected_idx])
			
		# C. Safety Check (Sync Dropdown if needed)
		var current_dropdown_idx = opt_walker_select.selected
		if current_dropdown_idx >= 0 and current_dropdown_idx < _current_walker_list.size():
			var selected_agent = _current_walker_list[current_dropdown_idx]
			# If our reference drifted (rare), fix it
			if selected_agent != _current_walker_ref:
				_activate_walker_visuals(selected_agent)
				
		# D. Update Static Labels
		opt_walker_select.visible = (_current_walker_list.size() > 1)
		if _current_walker_ref:
			var steps = _current_walker_ref.get("step_count")
			lbl_walker_id.text = "Agent #%d (Steps: %d)" % [_current_walker_ref.id, steps]
			
	else:
		# E. Cleanup (No walkers here)
		if _current_walker_ref != null:
			# Wipe the trails because we moved to a node with no agent
			graph_editor.set_node_labels({})
			
		_current_walker_list.clear()
		_current_walker_ref = null
		
	# F. Visibility
	if walker_container:
		walker_container.visible = show_walker

# Case A: We selected an agent directly
# We populate the dropdown with siblings so you can still cycle through them.
func _update_walker_inspector_from_selection() -> void:
	if _tracked_agents.is_empty(): return
	var agent = _tracked_agents[0]
	
	var context_node = agent.current_node_id
	if context_node != "":
		_populate_walker_dropdown(context_node, agent)
	else:
		# Fallback: Agent has no node (Floating)
		_current_walker_list = [agent]
		_populate_dropdown_ui(0)
		
		# [FIX] Ensure we activate even if list didn't change
		if _current_walker_ref != agent:
			_activate_walker_visuals(agent)

# Case B: We selected a node, check if it has agents
func _update_walker_inspector_from_node(node_id: String) -> bool:
	# [FIX] Use Graph API directly
	var list = graph_editor.graph.get_agents_at_node(node_id)
	
	if list.is_empty(): 
		return false
	
	_populate_walker_dropdown(node_id, null) 
	return true

# Shared Helper to populate the list and dropdown
func _populate_walker_dropdown(node_id: String, target_selection = null) -> void:
	# Query Graph directly
	var new_list = graph_editor.graph.get_agents_at_node(node_id)
	
	# Diffing logic
	if new_list != _current_walker_list:
		_current_walker_list = new_list
		
		var selected_idx = 0
		if target_selection:
			var found = _current_walker_list.find(target_selection)
			if found != -1: selected_idx = found
		
		_populate_dropdown_ui(selected_idx)
		
		if not _current_walker_list.is_empty():
			_activate_walker_visuals(_current_walker_list[selected_idx])
		
	else:
		# [FIX] FORCE UPDATE if the UI is currently empty or mismatched
		if target_selection:
			var found = _current_walker_list.find(target_selection)
			if found != -1:
				# Trigger if:
				# 1. The dropdown visual is wrong
				# 2. OR The Inspector is blank (ref is null)
				# 3. OR We are looking at a different object reference
				if opt_walker_select.selected != found or _current_walker_ref != target_selection:
					opt_walker_select.selected = found
					_activate_walker_visuals(target_selection)

# Helper to fill the OptionButton
func _populate_dropdown_ui(select_index: int) -> void:
	opt_walker_select.clear()
	for i in range(_current_walker_list.size()):
		var w = _current_walker_list[i]
		var status = "" if w.get("active") else " (Paused)"
		opt_walker_select.add_item("Agent #%d%s" % [w.id, status], i)
	
	opt_walker_select.selected = select_index
	opt_walker_select.visible = (_current_walker_list.size() > 1)

# Helper to get strategy safely
func _get_walker_strategy():
	if strategy_controller and strategy_controller.current_strategy:
		return strategy_controller.current_strategy
	return null

# 1. Signal Handler (Response to Dropdown Click)
func _on_walker_dropdown_selected(index: int) -> void:
	if index < 0 or index >= _current_walker_list.size():
		return
	
	var agent = _current_walker_list[index]
	_activate_walker_visuals(agent)

# 2. Visual Helper (The Core Logic)
func _activate_walker_visuals(walker_obj) -> void:
	# [FIX] Restore the UI Rebuild Logic
	_current_walker_ref = walker_obj
	_rebuild_walker_ui()
	
	# [NEW] Build Trail Visualization
	if walker_obj.has_method("get_history_labels"):
		var trail_labels = walker_obj.get_history_labels()
		graph_editor.set_node_labels(trail_labels)
	
	# --- Strategy Checks (Markers) ---
	if not strategy_controller or not strategy_controller.current_strategy: 
		return
	
	var strat = strategy_controller.current_strategy
	
	# 1. Update Start Positions (Green Markers)
	if strat.has_method("get_all_agent_starts"):
		var starts = strat.get_all_agent_starts(graph_editor.graph)
		graph_editor.set_path_starts(starts)
		
	# 2. Update Current Positions (Red Markers)
	if strat.has_method("get_all_agent_positions"):
		var ends = strat.get_all_agent_positions(graph_editor.graph)
		graph_editor.set_path_ends(ends)

# 2. Dynamic Update Handler - REPLACEMENT
# This catches signals from ALL generated controls (SpinBoxes, CheckBoxes, etc.)
func _on_walker_setting_changed(key: String, value: Variant) -> void:
	if _current_walker_ref == null: return 

	# [NEW] 0. Intercept Actions
	if key == "action_delete":
		# [FIX] Use Editor for Undo Support
		graph_editor.remove_agent(_current_walker_ref)
			
		# Refresh Markers
		if StrategyController.instance.current_strategy:
			var strat = StrategyController.instance.current_strategy
			if strat.has_method("get_all_agent_positions"):
				graph_editor.set_path_ends(strat.get_all_agent_positions(graph_editor.graph))
			if strat.has_method("get_all_agent_starts"):
				graph_editor.set_path_starts(strat.get_all_agent_starts(graph_editor.graph))
		
		# B. Clear UI & Selection & Trails
		graph_editor.set_node_labels({}) 
		_clear_inspector()
		graph_editor.clear_selection()
		
		print("Inspector: Agent deleted successfully.")
		return 

	# 1. Update the Data (Existing Logic)
	_current_walker_ref.apply_setting(key, value)
	
	# 2. Position Snapping Logic
	if key == "pos":
		var graph = graph_editor.graph
		var landed_node_id = graph.get_node_at_position(value, 1.0)
		
		if not landed_node_id.is_empty():
			_current_walker_ref.current_node_id = landed_node_id
			print("Inspector: Walker snapped to node %s" % landed_node_id)
	
	# 3. UI Polish
	if key == "active":
		var idx = opt_walker_select.selected
		var status = "" if value else " (Paused)"
		opt_walker_select.set_item_text(idx, "Agent #%d%s" % [_current_walker_ref.id, status])
		
	print("Inspector: Updated %s -> %s" % [key, value])
		
# --- GENERIC UI HELPER ---
# 1. Clears the container.
# 2. Builds the UI from the schema.
# 3. Connects all live update signals to the callback.
# Returns the dictionary of input controls.
func _render_dynamic_section(container: Control, schema: Array, callback: Callable) -> Dictionary:
	# A. Setup Container
	var content_box = container.get_node_or_null("ContentBox")
	if not content_box:
		# [FIX] Do NOT clear container children here. 
		# That would delete the "opt_walker_select" dropdown which lives in the same parent!
		
		content_box = VBoxContainer.new()
		content_box.name = "ContentBox"
		content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		container.add_child(content_box)
	
	# B. Build UI
	# Note: build_ui clears the *content_box* children, which is safe and correct.
	var inputs = SettingsUIBuilder.build_ui(schema, content_box)
	
	# C. Connect Signals
	SettingsUIBuilder.connect_live_updates(inputs, callback)
	
	return inputs
