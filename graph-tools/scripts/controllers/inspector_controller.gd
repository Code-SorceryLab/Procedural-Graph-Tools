extends Node
class_name InspectorController

# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor
@export var strategy_controller: StrategyController

@export_group("UI Inspector Tab")
@export var inspector_vbox: VBoxContainer    # The main container

# 1. VIEW CONTAINERS
@export var lbl_no_selection: Label      
@export var single_container: Control     
@export var group_container: Control      

# 2. STATIC NODE CONTROLS
@export var lbl_id: Label
@export var spin_pos_x: SpinBox
@export var spin_pos_y: SpinBox
@export var option_type: OptionButton
@export var lbl_edges: Label
@export var lbl_neighbors: RichTextLabel

# 3. DYNAMIC WALKER CONTROLS
@export_group("Walker Inspector")
@export var walker_container: VBoxContainer 
@export var opt_walker_select: OptionButton            
# [REMOVED] lbl_walker_id is gone

# 4. GROUP CONTROLS
@export_group("Group Inspector")
@export var lbl_group_count: Label
@export var lbl_group_center: Label
@export var lbl_group_bounds: Label
@export var lbl_group_density: Label
@export var group_option_type: OptionButton 

# 5. EDGE CONTROLS
@export_group("Edge Inspector")
@export var edge_container: Control      
@export var lbl_edge_header: Label       
@export var edge_settings_box: Control   

# --- STATE ---
var _tracked_nodes: Array[String] = []
var _tracked_edges: Array = []           
var _tracked_agents: Array = []

var _is_updating_ui: bool = false
var _current_walker_ref: Object = null 
var _current_walker_list: Array = [] 

# Maps for dynamic controls
var _walker_inputs: Dictionary = {}
var _edge_inputs: Dictionary = {}

func _ready() -> void:
	# 1. Connect Signals
	graph_editor.selection_changed.connect(_on_selection_changed)
	
	if graph_editor.has_signal("edge_selection_changed"):
		graph_editor.edge_selection_changed.connect(_on_edge_selection_changed)

	# Listen to Global Bus for Agent Selection
	if SignalManager.has_signal("agent_selection_changed"):
		SignalManager.agent_selection_changed.connect(_on_agent_selection_changed)
	
	graph_editor.graph_loaded.connect(func(_g): refresh_type_options())
	
	if graph_editor.has_signal("request_inspector_view"):
		graph_editor.request_inspector_view.connect(_on_inspector_view_requested)

	set_process(false)
	
	# 2. Configure Static Controls
	spin_pos_x.step = GraphSettings.INSPECTOR_POS_STEP
	spin_pos_y.step = GraphSettings.INSPECTOR_POS_STEP
	
	spin_pos_x.value_changed.connect(_on_pos_value_changed)
	spin_pos_y.value_changed.connect(_on_pos_value_changed)
	
	refresh_type_options()

	option_type.item_selected.connect(_on_type_selected)
	group_option_type.item_selected.connect(_on_group_type_selected)
	opt_walker_select.item_selected.connect(_on_walker_dropdown_selected)

	_clear_inspector()

# --- UTILITY ---
func _on_inspector_view_requested() -> void:
	if not inspector_vbox: return
	var parent = inspector_vbox.get_parent()
	if parent is TabContainer:
		parent.current_tab = inspector_vbox.get_index()
	else:
		inspector_vbox.visible = true

func refresh_type_options() -> void:
	_setup_type_dropdown(option_type)
	_setup_type_dropdown(group_option_type)
	group_option_type.add_separator()
	group_option_type.add_item("-- Mixed --", -1)

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
	_check_selection_state()

func _on_edge_selection_changed(selected_edges: Array) -> void:
	_tracked_edges = selected_edges
	if not _tracked_edges.is_empty():
		_rebuild_edge_inspector_ui()
	_check_selection_state()

func _on_agent_selection_changed(selected_agents: Array) -> void:
	_tracked_agents = selected_agents
	_check_selection_state()

# Central State Checker
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
	
	# 1. No Selection
	lbl_no_selection.visible = (not has_nodes and not has_edges and not has_agents)
	
	# 2. Node Inspector
	single_container.visible = (has_nodes and _tracked_nodes.size() == 1)
	group_container.visible = (has_nodes and _tracked_nodes.size() > 1)
	
	if single_container.visible:
		_update_single_inspector(_tracked_nodes[0])
	elif group_container.visible:
		_update_group_inspector(_tracked_nodes)
		
	# 3. Edge Inspector
	edge_container.visible = has_edges
	
	# 4. Walker Inspector
	var show_walkers = false
	if has_agents:
		show_walkers = true
		_update_walker_inspector_from_selection()
	elif has_nodes and _tracked_nodes.size() == 1:
		show_walkers = _update_walker_inspector_from_node(_tracked_nodes[0])
		
	walker_container.visible = show_walkers
	set_process(has_nodes)

# ==============================================================================
# EDGE VIEW LOGIC 
# ==============================================================================

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
		{ "name": "weight", "type": TYPE_FLOAT, "default": display_w, "min": 0.1, "max": 100.0, "step": 0.1 },
		{ "name": "direction", "type": TYPE_INT, "default": display_mode, "hint": "enum", "hint_string": "Bi-Directional,Forward,Reverse" }
	]

func _rebuild_edge_inspector_ui() -> void:
	var schema = _get_edge_inspector_schema()
	_edge_inputs = _render_dynamic_section(edge_settings_box, schema, _on_edge_setting_changed)

func _on_edge_setting_changed(key: String, value: Variant) -> void:
	if _tracked_edges.is_empty(): return
	var graph = graph_editor.graph 
	
	for pair in _tracked_edges:
		var u = pair[0]; var v = pair[1]
		match key:
			"weight":
				if graph.has_edge(u, v): graph_editor.set_edge_weight(u, v, value)
				if graph.has_edge(v, u): graph_editor.set_edge_weight(v, u, value)
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
	
	_refresh_walker_list_state(node_id)
	_is_updating_ui = false

func _rebuild_walker_ui() -> void:
	if not _current_walker_ref: return
	
	# 1. Ask Agent for Schema
	var raw_settings = _current_walker_ref.get_agent_settings()
	
	# 2. [NEW] Inject Picker Button into Schema
	var final_settings = []
	for item in raw_settings:
		# Detect the target_node field
		if item.name == "target_node":
			# Add our Picker Action Button right before it
			final_settings.append({
				"name": "action_pick_target",
				"label": "Pick Target Node", # Default Label
				"type": TYPE_BOOL, 
				"hint": "action"   
			})
			
		final_settings.append(item)
	
	# 3. Render
	_walker_inputs = _render_dynamic_section(
		walker_container, 
		final_settings, 
		_on_walker_setting_changed
	)
	
	# 4. [NEW] Sync the Button State immediately
	# This ensures if the agent already has a target, the button turns green instantly
	if _current_walker_ref.get("target_node_id"):
		SettingsUIBuilder.sync_picker_button(_walker_inputs, "action_pick_target", "Target Node", _current_walker_ref.target_node_id)
	
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
	
	if is_mixed:
		group_option_type.select(group_option_type.item_count - 1)
	else:
		var idx = group_option_type.get_item_index(first_type)
		group_option_type.select(idx)
		
	_is_updating_ui = false

func _clear_inspector() -> void:
	_tracked_nodes = []
	_tracked_edges = []
	_tracked_agents = []
	
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

func _refresh_walker_list_state(node_id: String) -> void:
	# 1. Fetch
	var new_list = []
	if strategy_controller and strategy_controller.current_strategy:
		var strat = strategy_controller.current_strategy
		if strat.has_method("get_walkers_at_node"):
			new_list = strat.get_walkers_at_node(node_id, graph_editor.graph)
			
	if new_list.is_empty():
		_current_walker_list.clear()
		_current_walker_ref = null
		walker_container.visible = false
		return

	# 2. Update UI
	_populate_walker_dropdown(node_id, null)
	walker_container.visible = true

func _update_walker_inspector_from_selection() -> void:
	if _tracked_agents.is_empty(): return
	var agent = _tracked_agents[0]
	
	var context_node = agent.current_node_id
	if context_node != "":
		_populate_walker_dropdown(context_node, agent)
	else:
		_current_walker_list = [agent]
		_populate_dropdown_ui(0)
		if _current_walker_ref != agent:
			_activate_walker_visuals(agent)

func _update_walker_inspector_from_node(node_id: String) -> bool:
	var list = graph_editor.graph.get_agents_at_node(node_id)
	if list.is_empty(): return false
	_populate_walker_dropdown(node_id, null) 
	return true

func _populate_walker_dropdown(node_id: String, target_selection = null) -> void:
	var new_list = graph_editor.graph.get_agents_at_node(node_id)
	
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
		if target_selection:
			var found = _current_walker_list.find(target_selection)
			if found != -1:
				if opt_walker_select.selected != found or _current_walker_ref != target_selection:
					opt_walker_select.selected = found
					_activate_walker_visuals(target_selection)

func _populate_dropdown_ui(select_index: int) -> void:
	opt_walker_select.clear()
	for i in range(_current_walker_list.size()):
		var w = _current_walker_list[i]
		var status = "" if w.get("active") else " (Paused)"
		opt_walker_select.add_item("Agent #%d%s" % [w.id, status], i)
	
	opt_walker_select.selected = select_index
	opt_walker_select.visible = (_current_walker_list.size() > 1)

func _on_walker_dropdown_selected(index: int) -> void:
	if index < 0 or index >= _current_walker_list.size(): return
	var agent = _current_walker_list[index]
	_activate_walker_visuals(agent)

# Replace the previous implementation of this function:

func _activate_walker_visuals(walker_obj) -> void:
	_current_walker_ref = walker_obj
	
	# 1. Build UI
	_rebuild_walker_ui()
	
	# 2. Visuals (Trails)
	if walker_obj.has_method("get_history_labels"):
		graph_editor.set_node_labels(walker_obj.get_history_labels())
	
	# 3. [FIX] Markers (Direct Graph Access)
	# No longer dependent on 'strategy_controller.current_strategy'
	
	var all_starts: Array[String] = []
	var all_ends: Array[String] = []
	
	if graph_editor.graph:
		for agent in graph_editor.graph.agents:
			if agent.current_node_id != "":
				all_ends.append(agent.current_node_id)
			if agent.get("start_node_id") and agent.start_node_id != "":
				all_starts.append(agent.start_node_id)
				
	graph_editor.set_path_starts(all_starts)
	graph_editor.set_path_ends(all_ends)

func _on_walker_setting_changed(key: String, value: Variant) -> void:
	if _current_walker_ref == null: return 

	# [NEW] PICKER LOGIC
	if key == "action_pick_target":
		graph_editor.request_node_pick(_on_inspector_target_picked)
		return
		
	if key == "target_node":
		SettingsUIBuilder.sync_picker_button(_walker_inputs, "action_pick_target", "Target Node", value)

	# [NEW] DELETE LOGIC
	if key == "action_delete":
		graph_editor.remove_agent(_current_walker_ref)
		_clear_inspector()
		graph_editor.clear_selection()
		return 

	# Standard Update
	_current_walker_ref.apply_setting(key, value)
	
	# Position Snap
	if key == "pos":
		var landed = graph_editor.graph.get_node_at_position(value, 1.0)
		if not landed.is_empty(): _current_walker_ref.current_node_id = landed

	# Dropdown Update
	if key == "active":
		var idx = opt_walker_select.selected
		var status = "" if value else " (Paused)"
		opt_walker_select.set_item_text(idx, "Agent #%d%s" % [_current_walker_ref.id, status])

func _on_inspector_target_picked(node_id: String) -> void:
	if _walker_inputs.has("target_node"):
		_walker_inputs["target_node"].text = node_id
		_on_walker_setting_changed("target_node", node_id)

# --- GENERIC UI HELPER ---
func _render_dynamic_section(container: Control, schema: Array, callback: Callable) -> Dictionary:
	var content_box = container.get_node_or_null("ContentBox")
	if not content_box:
		content_box = VBoxContainer.new()
		content_box.name = "ContentBox"
		content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		container.add_child(content_box)
	
	var inputs = SettingsUIBuilder.build_ui(schema, content_box)
	SettingsUIBuilder.connect_live_updates(inputs, callback)
	return inputs
