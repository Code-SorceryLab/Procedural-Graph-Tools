extends Node
class_name InspectorController

# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor

@export_group("UI Inspector Tab")
# 1. THE VIEW CONTAINERS
@export var lbl_no_selection: Label      # State 0: None
@export var single_container: Control    # State 1: Single
@export var group_container: Control     # State 2: Multi

# 2. SINGLE NODE CONTROLS
@export var lbl_id: Label
@export var spin_pos_x: SpinBox
@export var spin_pos_y: SpinBox
@export var option_type: OptionButton
@export var lbl_edges: Label
@export var lbl_neighbors: RichTextLabel

# 3. GROUP STATS CONTROLS
@export var lbl_group_count: Label
@export var lbl_group_center: Label
@export var lbl_group_bounds: Label
@export var lbl_group_density: Label
@export var group_option_type: OptionButton 

# State tracking
var _tracked_nodes: Array[String] = []
var _is_updating_ui: bool = false # Flag to prevent loops

func _ready() -> void:
	graph_editor.selection_changed.connect(_on_selection_changed)
	set_process(false)
	
	# --- 1. CONFIGURE SPINBOXES ---
	spin_pos_x.step = GraphSettings.INSPECTOR_POS_STEP
	spin_pos_y.step = GraphSettings.INSPECTOR_POS_STEP
	
	spin_pos_x.min_value = -99999
	spin_pos_x.max_value = 99999
	spin_pos_y.min_value = -99999
	spin_pos_y.max_value = 99999
	
	spin_pos_x.value_changed.connect(_on_pos_value_changed)
	spin_pos_y.value_changed.connect(_on_pos_value_changed)
	
	# --- 2. CONFIGURE DROPDOWNS ---
	# Setup both Single and Group dropdowns
	_setup_type_dropdown(option_type)
	_setup_type_dropdown(group_option_type)
	
	option_type.item_selected.connect(_on_type_selected)
	group_option_type.item_selected.connect(_on_group_type_selected)
	
	_clear_inspector()

# FIX 1: Dynamic Dropdown Population
func _setup_type_dropdown(btn: OptionButton) -> void:
	btn.clear()
	
	# Get all registered IDs (Defaults + Customs)
	var ids = GraphSettings.current_names.keys()
	ids.sort() # Keep them consistently ordered
	
	for id in ids:
		var type_name = GraphSettings.get_type_name(id)
		# We add the name as the Label, and the 'id' as the value
		btn.add_item(type_name, id)

func _on_selection_changed(selected_nodes: Array[String]) -> void:
	_tracked_nodes = selected_nodes
	
	if _tracked_nodes.is_empty():
		# STATE 0: NONE
		set_process(false)
		_show_view(0)
		
	elif _tracked_nodes.size() == 1:
		# STATE 1: SINGLE
		set_process(true)
		_show_view(1)
		_update_single_inspector(_tracked_nodes[0])
		
	else:
		# STATE 2: GROUP
		set_process(true)
		_show_view(2)
		_update_group_inspector(_tracked_nodes)

func _process(_delta: float) -> void:
	# Only update if we have a valid selection
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

	# The Legend might have changed since the app started (e.g. after loading a file).
	_setup_type_dropdown(option_type)

	var node_data = graph.nodes[node_id]
	var neighbors = graph.get_neighbors(node_id)
	
	_is_updating_ui = true
	
	# 1. ID
	lbl_id.text = "ID: %s" % node_id
	
	# 2. POSITION (Focus Guard)
	# Only update spinboxes if the user ISN'T typing in them right now.
	var x_focus = spin_pos_x.get_line_edit().has_focus()
	var y_focus = spin_pos_y.get_line_edit().has_focus()
	
	if not x_focus:
		spin_pos_x.value = node_data.position.x
	if not y_focus:
		spin_pos_y.value = node_data.position.y
		
	# 3. TYPE
	if not option_type.has_focus():
		# IMPORTANT: Map the ID to the Dropdown Index
		# The drop-down index (0, 1, 2) might not match the Type ID (0, 10, 99).
		var idx = option_type.get_item_index(node_data.type)
		option_type.selected = idx
	
	# 4. NEIGHBORS
	lbl_edges.text = "Connections: %d" % neighbors.size()
	var neighbor_text = ""
	for n_id in neighbors:
		neighbor_text += "- %s\n" % n_id
	lbl_neighbors.text = neighbor_text
	
	_is_updating_ui = false

func _update_group_inspector(nodes: Array[String]) -> void:
	var graph = graph_editor.graph
	
	var count = nodes.size()
	var center_sum = Vector2.ZERO
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	var internal_connections = 0
	
	# --- HOMOGENEITY CHECK ---
	var first_id = nodes[0]
	var first_type = graph.nodes[first_id].type
	var is_mixed = false
	
	var node_set = {} 
	for id in nodes:
		node_set[id] = true
		
		# Check mixed state
		if graph.nodes[id].type != first_type:
			is_mixed = true
	
	# --- STATS CALC ---
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
	
	# --- UPDATE UI ---
	_is_updating_ui = true
	
	lbl_group_count.text = "Selected: %d Nodes" % count
	lbl_group_center.text = "Center: (%.1f, %.1f)" % [avg_center.x, avg_center.y]
	lbl_group_bounds.text = "Bounds: %.0f x %.0f" % [size.x, size.y]
	lbl_group_density.text = "Internal Edges: %d" % unique_edges
	
	# Handle Mixed Dropdown State
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

# --- INPUT HANDLERS (UPDATED) ---

func _on_pos_value_changed(_val: float) -> void:
	if _is_updating_ui: return
	if _tracked_nodes.size() != 1: return
	
	var id = _tracked_nodes[0]
	var current_pos = graph_editor.graph.get_node_pos(id)
	var new_pos = Vector2(spin_pos_x.value, spin_pos_y.value)
	
	# FIX 2: Use Editor Command for Undo Support
	
	# 1. Update Visuals (Immediate feedback)
	graph_editor.set_node_position(id, new_pos)
	
	# 2. Commit Command (History)
	# We simulate a "Drag Finish" event so the history knows we moved from A to B.
	var move_data = {
		id: {
			"from": current_pos, 
			"to": new_pos
		}
	}
	graph_editor.commit_move_batch(move_data)

func _on_type_selected(index: int) -> void:
	if _is_updating_ui: return
	if _tracked_nodes.size() != 1: return
	
	var id = _tracked_nodes[0]
	# Get the actual ID from the metadata
	var selected_type_id = option_type.get_item_id(index)
	
	# FIX 3: Use Editor API
	# This handles CmdSetType, Dirty Flags, and Redraws automatically.
	graph_editor.set_node_type(id, selected_type_id)

func _on_group_type_selected(index: int) -> void:
	if _is_updating_ui: return
	
	# Check for "Mixed" selection
	var selected_type_id = group_option_type.get_item_id(index)
	if selected_type_id == -1:
		return 
		
	# FIX 4: Use Batch API
	# This creates a single Undo Step for the whole group change.
	graph_editor.set_node_type_bulk(_tracked_nodes, selected_type_id)
	
	# Refresh UI to remove "Mixed" state
	_update_group_inspector(_tracked_nodes)
