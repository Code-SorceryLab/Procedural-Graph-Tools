extends Node
class_name ZoneController

# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor

@export_group("UI Nodes")
@export var zone_list: VBoxContainer    # The container for the rows
@export var btn_add_zone: Button
@export var lbl_stats: Label

# --- STATE ---
# Key: GraphZone Object | Value: Control (The Row)
var _zone_map: Dictionary = {}

func _ready() -> void:
	# 1. Listen for Graph Data Changes (Local)
	if graph_editor:
		graph_editor.graph_modified.connect(_on_graph_modified)
		graph_editor.graph_loaded.connect(func(_g): _full_zone_rebuild())
	
	# 2. Listen for Selection Changes (Global)
	SignalManager.zone_selection_changed.connect(_on_zone_selection_changed)
		
	# 3. Setup UI Inputs
	if btn_add_zone:
		btn_add_zone.pressed.connect(_on_add_zone_pressed)
	
	# Handle clicking empty space in the list
	if zone_list:
		zone_list.empty_clicked.connect(_on_zone_list_empty_clicked)
	
	# Initial Build
	_full_zone_rebuild()

# ==============================================================================
# 1. MANAGEMENT LOGIC
# ==============================================================================

func _on_add_zone_pressed() -> void:
	# 1. Create Zone
	var random_color = Color.from_hsv(randf(), 0.6, 0.8, 0.3)
	var new_zone = GraphZone.new("New Zone", random_color)
	
	var graph = graph_editor.graph
	var spacing = GraphSettings.GRID_SPACING
	
	# CASE A: Nodes are Selected -> Wrap them!
	if not graph_editor.selected_nodes.is_empty():
		for id in graph_editor.selected_nodes:
			if graph.nodes.has(id):
				var pos = graph.nodes[id].position
				
				# 1. Register Logic
				new_zone.register_node(id)
				
				# 2. Register Visuals (Smart 2x2 Patch)
				# This creates the "tight fit" look around your selection
				new_zone.add_patch_at_world_pos(pos, spacing, 0)
				
	# CASE B: No Selection -> Spawn a "Landing Pad"
	else:
		var spawn_pos = Vector2.ZERO
		
		# Find graph center (if nodes exist)
		if graph and not graph.nodes.is_empty():
			var sum = Vector2.ZERO
			var count = 0
			for id in graph.nodes:
				sum += graph.nodes[id].position
				count += 1
				if count >= 10: break # Optimization
			if count > 0:
				spawn_pos = sum / count
		
		# Paint a larger 3x3 patch so it's easy to see
		new_zone.add_patch_at_world_pos(spawn_pos, spacing, 1)
		
		# Auto-capture any lucky nodes sitting exactly on the landing pad
		if graph:
			for id in graph.nodes:
				# Check if node center is inside the new 3x3 grid
				var node_grid = Vector2i(round(graph.nodes[id].position.x / spacing.x), round(graph.nodes[id].position.y / spacing.y))
				if new_zone.has_cell(node_grid):
					new_zone.register_node(id)

	# 3. Commit
	graph_editor.add_zone(new_zone)
	graph_editor.set_zone_selection([new_zone])

func _full_zone_rebuild() -> void:
	if not zone_list: return
	
	# Clear existing rows
	for child in zone_list.get_children():
		child.queue_free()
	_zone_map.clear()
	
	if not graph_editor or not graph_editor.graph: return
	
	# Iterate zones and build rows
	# We iterate normally; in a "Layer" stack, index 0 is bottom.
	# If you want "Top Layer First", iterate backwards.
	for zone in graph_editor.graph.zones:
		_create_zone_row(zone)
		
	_update_stats()

func _create_zone_row(zone: GraphZone) -> void:
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	# A. Color Indicator
	var icon = ColorRect.new()
	icon.custom_minimum_size = Vector2(16, 16)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.color = zone.zone_color
	# Make it visible even if the alpha is low
	icon.color.a = 1.0 
	row.add_child(icon)
	
	# B. Name
	var lbl = Label.new()
	lbl.text = zone.zone_name
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.clip_text = true
	row.add_child(lbl)
	
	# C. Cell Count
	var lbl_count = Label.new()
	lbl_count.text = "[%d]" % zone.cells.size()
	lbl_count.modulate = Color(1, 1, 1, 0.5)
	row.add_child(lbl_count)
	
	# D. Select Button (Invisible Overlay)
	# This allows clicking anywhere on the row to select
	var btn_select = Button.new()
	btn_select.flat = true
	btn_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_select.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Anchor it to cover the HBox? HBox layout prevents simple overlay.
	# Simpler approach: Just add a discrete "Select" button or use the row as a button parent.
	# For now, explicit "Select" button:
	btn_select.text = "Select"
	btn_select.pressed.connect(func(): _select_zone(zone))
	row.add_child(btn_select)
	
	# E. Delete Button
	var btn_del = Button.new()
	btn_del.text = "X"
	btn_del.modulate = Color(1, 0.5, 0.5)
	btn_del.flat = true
	btn_del.pressed.connect(func(): _delete_zone(zone))
	row.add_child(btn_del)
	
	zone_list.add_child(row)
	_zone_map[zone] = row

func _select_zone(zone: GraphZone) -> void:
	graph_editor.set_zone_selection([zone])

func _delete_zone(zone: GraphZone) -> void:
	graph_editor.remove_zone(zone)

# ==============================================================================
# 2. FEEDBACK & EVENTS
# ==============================================================================

# [NEW] Signal Handler
func _on_zone_list_empty_clicked(_pos: Vector2, _mouse_btn_index: int) -> void:
	# Clear the selection in the Editor (which will callback to update this UI)
	graph_editor.set_zone_selection([])

func _on_zone_selection_changed(selected_zones: Array) -> void:
	# 1. Reset all highlights
	for z in _zone_map:
		_zone_map[z].modulate = Color.WHITE
		
	if selected_zones.is_empty(): return
	
	# 2. Highlight selected
	var primary = selected_zones[0]
	if _zone_map.has(primary):
		_zone_map[primary].modulate = Color(0.5, 1.0, 1.0) # Cyan Highlight

func _on_graph_modified() -> void:
	# Rebuild to catch Name/Color changes or new Zones
	_full_zone_rebuild()

func _update_stats() -> void:
	if lbl_stats:
		lbl_stats.text = "Zones: %d" % graph_editor.graph.zones.size()
