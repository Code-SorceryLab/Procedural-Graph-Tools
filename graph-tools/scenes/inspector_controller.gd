extends Node
class_name InspectorController

# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor

@export_group("UI Inspector Tab")
# 1. THE VIEW CONTAINERS
@export var lbl_no_selection: Label     # State 0: None
@export var single_container: Control   # State 1: Single
@export var group_container: Control    # State 2: Multi (NEW)

# 2. SINGLE NODE LABELS
@export var lbl_id: Label
@export var lbl_pos: Label
@export var lbl_type: Label
@export var lbl_edges: Label
@export var lbl_neighbors: RichTextLabel

# 3. GROUP STATS LABELS (NEW)
@export var lbl_group_count: Label
@export var lbl_group_center: Label
@export var lbl_group_bounds: Label
@export var lbl_group_density: Label

# State tracking
var _tracked_nodes: Array[String] = []

func _ready() -> void:
	graph_editor.selection_changed.connect(_on_selection_changed)
	set_process(false)
	_clear_inspector()

func _on_selection_changed(selected_nodes: Array[String]) -> void:
	_tracked_nodes = selected_nodes
	
	if _tracked_nodes.is_empty():
		# STATE 0: NONE
		set_process(false)
		_show_view(0)
		
	elif _tracked_nodes.size() == 1:
		# STATE 1: SINGLE
		set_process(true) # Live update for dragging single nodes
		_show_view(1)
		_update_single_inspector(_tracked_nodes[0])
		
	else:
		# STATE 2: GROUP
		set_process(true) # Live update (dragging whole group)
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
		_on_selection_changed([]) # Reset if deleted
		return

	var node_data = graph.nodes[node_id]
	var neighbors = graph.get_neighbors(node_id)
	
	lbl_id.text = "ID: %s" % node_id
	lbl_pos.text = "Pos: (%.1f, %.1f)" % [node_data.position.x, node_data.position.y]
	
	# Node Type
	var type_str = "Unknown"
	match node_data.type:
		NodeData.RoomType.EMPTY: type_str = "Empty"
		NodeData.RoomType.SPAWN: type_str = "Spawn"
		NodeData.RoomType.ENEMY: type_str = "Enemy"
		NodeData.RoomType.TREASURE: type_str = "Treasure"
		NodeData.RoomType.BOSS: type_str = "Boss"
		NodeData.RoomType.SHOP: type_str = "Shop"
	lbl_type.text = "Type: %s" % type_str
	
	lbl_edges.text = "Connections: %d" % neighbors.size()
	
	# Neighbors List
	var neighbor_text = ""
	for n_id in neighbors:
		neighbor_text += "- %s\n" % n_id
	lbl_neighbors.text = neighbor_text

func _update_group_inspector(nodes: Array[String]) -> void:
	var graph = graph_editor.graph
	
	var count = nodes.size()
	var center_sum = Vector2.ZERO
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	var internal_connections = 0
	
	# We use a Dictionary for O(1) lookups to check internal connections
	var node_set = {} 
	for id in nodes:
		node_set[id] = true
	
	for id in nodes:
		if not graph.nodes.has(id): continue
		
		var pos = graph.nodes[id].position
		
		# 1. Calc Center
		center_sum += pos
		
		# 2. Calc Bounds
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)
		
		# 3. Calc Internal Density
		# Check how many neighbors are ALSO in the selection
		var neighbors = graph.get_neighbors(id)
		for n_id in neighbors:
			if node_set.has(n_id):
				internal_connections += 1
	
	# Final Calculations
	var avg_center = center_sum / count
	var size = max_pos - min_pos
	
	# Note: internal_connections counts A->B and B->A separately, so we divide by 2
	var unique_edges = internal_connections / 2
	
	# Update UI
	lbl_group_count.text = "Selected: %d Nodes" % count
	lbl_group_center.text = "Center: (%.1f, %.1f)" % [avg_center.x, avg_center.y]
	lbl_group_bounds.text = "Bounds: %.0f x %.0f" % [size.x, size.y]
	lbl_group_density.text = "Internal Edges: %d" % unique_edges

func _show_view(view_index: int) -> void:
	lbl_no_selection.visible = (view_index == 0)
	single_container.visible = (view_index == 1)
	group_container.visible = (view_index == 2)

func _clear_inspector() -> void:
	_tracked_nodes = []
	_show_view(0)
