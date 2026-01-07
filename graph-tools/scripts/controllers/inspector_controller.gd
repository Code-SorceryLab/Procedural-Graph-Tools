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
@export var opt_walker_paint: OptionButton 
@export var chk_walker_active: CheckBox    # Active/Paused
@export var spin_walker_x: SpinBox         # Manual X Position
@export var spin_walker_y: SpinBox         # Manual Y Position
@export var btn_walker_reset: Button       # Reset Steps

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
var _current_walker_list: Array = [] # <--- NEW: Store all agents at this node

func _ready() -> void:
	graph_editor.selection_changed.connect(_on_selection_changed)
	set_process(false)
	
	# --- 1. CONFIGURE SPINBOXES ---
	spin_pos_x.step = GraphSettings.INSPECTOR_POS_STEP
	spin_pos_y.step = GraphSettings.INSPECTOR_POS_STEP
	spin_pos_x.min_value = -99999; spin_pos_x.max_value = 99999
	spin_pos_y.min_value = -99999; spin_pos_y.max_value = 99999
	spin_walker_x.step = GraphSettings.INSPECTOR_POS_STEP
	spin_walker_y.step = GraphSettings.INSPECTOR_POS_STEP
	
	spin_pos_x.value_changed.connect(_on_pos_value_changed)
	spin_pos_y.value_changed.connect(_on_pos_value_changed)
	
	# --- 2. CONFIGURE DROPDOWNS ---
	_setup_type_dropdown(option_type)
	_setup_type_dropdown(group_option_type)
	_setup_type_dropdown(opt_walker_paint)
	
	option_type.item_selected.connect(_on_type_selected)
	group_option_type.item_selected.connect(_on_group_type_selected)
	
	# WALKER SIGNALS
	opt_walker_paint.item_selected.connect(_on_walker_paint_selected)
	opt_walker_select.item_selected.connect(_on_walker_agent_selected)

	chk_walker_active.toggled.connect(_on_walker_active_toggled)
	spin_walker_x.value_changed.connect(_on_walker_pos_changed)
	spin_walker_y.value_changed.connect(_on_walker_pos_changed)
	btn_walker_reset.pressed.connect(_on_walker_reset_pressed)
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
	# 2. WALKER INSPECTION LOGIC
	# ---------------------------------------------------------
	var show_walker = false
	var new_walker_list = []
	
	if strategy_controller and strategy_controller.current_strategy:
		var strat = strategy_controller.current_strategy
		if strat.has_method("get_walkers_at_node"):
			new_walker_list = strat.get_walkers_at_node(node_id)
	
	if not new_walker_list.is_empty():
		show_walker = true
		
		# Sync List
		if new_walker_list != _current_walker_list:
			_current_walker_list = new_walker_list
			opt_walker_select.clear()
			var selected_idx = 0
			for i in range(_current_walker_list.size()):
				var w = _current_walker_list[i]
				var status = "" if w.active else " (Paused)"
				opt_walker_select.add_item("Agent #%d%s" % [w.id, status], i)
				if _current_walker_ref and _current_walker_ref == w:
					selected_idx = i
			opt_walker_select.selected = selected_idx
			_current_walker_ref = _current_walker_list[selected_idx]
		
		# Fallback
		if _current_walker_ref == null and not _current_walker_list.is_empty():
			_current_walker_ref = _current_walker_list[0]
			opt_walker_select.selected = 0

	else:
		_current_walker_list.clear()
		_current_walker_ref = null

	# Refresh UI
	if show_walker and _current_walker_ref:
		opt_walker_select.visible = (_current_walker_list.size() > 1)
		lbl_walker_id.text = "Agent #%d (Steps: %d)" % [_current_walker_ref.id, _current_walker_ref.step_count]
		
		# Sync Paint Dropdown
		if not opt_walker_paint.has_focus():
			var w_idx = opt_walker_paint.get_item_index(_current_walker_ref.my_paint_type)
			if opt_walker_paint.selected != w_idx: opt_walker_paint.selected = w_idx
			
		# Sync Active Checkbox
		chk_walker_active.set_pressed_no_signal(_current_walker_ref.active)
		
		# Sync Position Spins (Only if not focused)
		if not spin_walker_x.get_line_edit().has_focus():
			spin_walker_x.set_value_no_signal(_current_walker_ref.pos.x)
		if not spin_walker_y.get_line_edit().has_focus():
			spin_walker_y.set_value_no_signal(_current_walker_ref.pos.y)
	
	if walker_container:
		walker_container.visible = show_walker
	# ---------------------------------------------------------
	
	_is_updating_ui = false

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

# WALKER HANDLERS ---

func _on_walker_active_toggled(toggled: bool) -> void:
	if _is_updating_ui or not _current_walker_ref: return
	_current_walker_ref.active = toggled
	print("Inspector: Agent #%d Active: %s" % [_current_walker_ref.id, toggled])

func _on_walker_pos_changed(_val: float) -> void:
	if _is_updating_ui or not _current_walker_ref: return
	
	# Update the walker's internal position
	# NOTE: In 'Paint' mode, this might desync visual from logical node if moved off-grid.
	# In 'Grow' mode, this effectively teleports the growth head.
	var new_pos = Vector2(spin_walker_x.value, spin_walker_y.value)
	_current_walker_ref.pos = new_pos
	
	# If we moved significantly, we might want to update the 'current_node_id' 
	# if we landed on a valid existing node.
	var graph = graph_editor.graph
	var landed_node = graph.get_node_at_position(new_pos, 1.0) # strict tolerance
	if not landed_node.is_empty():
		_current_walker_ref.current_node_id = landed_node

func _on_walker_reset_pressed() -> void:
	if not _current_walker_ref: return
	_current_walker_ref.step_count = 0
	# Force refresh text
	lbl_walker_id.text = "Agent #%d (Steps: 0)" % _current_walker_ref.id
	print("Inspector: Agent #%d steps reset." % _current_walker_ref.id)

func _on_walker_agent_selected(index: int) -> void:
	if index >= 0 and index < _current_walker_list.size():
		_current_walker_ref = _current_walker_list[index]
		
		# Force Immediate UI Sync
		lbl_walker_id.text = "Agent #%d (Steps: %d)" % [_current_walker_ref.id, _current_walker_ref.step_count]
		var w_idx = opt_walker_paint.get_item_index(_current_walker_ref.my_paint_type)
		opt_walker_paint.select(w_idx)

func _on_walker_paint_selected(index: int) -> void:
	if _is_updating_ui: return
	if not _current_walker_ref: return
	
	var paint_type_id = opt_walker_paint.get_item_id(index)
	_current_walker_ref.my_paint_type = paint_type_id
	print("Inspector: Updated Agent %d paint brush to %d" % [_current_walker_ref.id, paint_type_id])
