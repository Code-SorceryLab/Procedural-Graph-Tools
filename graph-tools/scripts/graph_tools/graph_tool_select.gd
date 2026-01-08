class_name GraphToolSelect
extends GraphTool

const DRAG_THRESHOLD: float = 4.0

# State A: Moving Nodes
var _drag_node_id: String = ""       # The "Anchor" node we clicked on
var _group_offsets: Dictionary = {}  # Stores { "node_id": Vector2_offset_from_anchor }
var _drag_start_positions: Dictionary = {}

# State B: Box Selection
var _box_start_pos: Vector2 = Vector2.INF

func handle_input(event: InputEvent) -> void:
	# 1. MOUSE BUTTON INPUT
	if event is InputEventMouseButton:
		var mouse_pos = _editor.get_global_mouse_position()
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# --- CLICK DOWN ---
				var clicked_id = _get_node_at_pos(mouse_pos)
				
				if not clicked_id.is_empty():
					_start_moving_node(clicked_id)
				else:
					# Check for Edge Click
					var clicked_edge = _graph.get_edge_at_position(mouse_pos)
					
					if not clicked_edge.is_empty():
						_handle_edge_click(clicked_edge)
					else:
						# If neither node nor edge, start box select
						_start_box_selection(mouse_pos)

			else:
				# --- CLICK RELEASE ---
				if not _drag_node_id.is_empty():
					_finish_moving_node()
				elif _box_start_pos != Vector2.INF:
					_finish_box_selection(mouse_pos)
		
		_renderer.queue_redraw()

	# 2. MOUSE MOTION INPUT
	elif event is InputEventMouseMotion:
		var mouse_pos = _editor.get_global_mouse_position()
		
		# Update Move State
		if not _drag_node_id.is_empty():
			# 1. Calculate Anchor Position (Snap logic applies to the Anchor)
			var anchor_pos = mouse_pos
			if Input.is_key_pressed(KEY_SHIFT):
				anchor_pos = anchor_pos.snapped(GraphSettings.SNAP_GRID_SIZE)
			
			# 2. Move the Anchor
			_editor.set_node_position(_drag_node_id, anchor_pos)
			
			# 3. Move the Group (Relative to Anchor)
			for id in _group_offsets:
				if id == _drag_node_id: continue
				
				var offset = _group_offsets[id]
				var new_group_pos = anchor_pos + offset
				
				_editor.set_node_position(id, new_group_pos)
			
		# Update Box State
		elif _box_start_pos != Vector2.INF:
			var rect = _get_rect(_box_start_pos, mouse_pos)
			_renderer.selection_rect = rect
			var potential_nodes = _graph.get_nodes_in_rect(rect)
			_renderer.pre_selection_ref = potential_nodes
			_renderer.queue_redraw()
		
		_update_hover(mouse_pos)

# --- HELPER FUNCTIONS ---

# Edge Selection Logic
func _handle_edge_click(edge_pair: Array) -> void:
	# Check modifiers
	if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL):
		_editor.toggle_edge_selection(edge_pair)
	else:
		# Standard Click: Clear everything else, select this edge
		_editor.clear_selection()
		_editor.set_edge_selection(edge_pair)

func _start_moving_node(id: String) -> void:
	_drag_node_id = id
	_renderer.drag_start_id = id
	
	# --- SELECTION LOGIC ---
	# Case 1: Modifiers held (Shift/Ctrl) -> We are editing selection, not moving group yet
	if Input.is_key_pressed(KEY_SHIFT):
		_editor.add_to_selection(id)
	elif Input.is_key_pressed(KEY_CTRL):
		_editor.toggle_selection(id)
	else:
		# Case 2: No Modifiers
		# If we clicked a node NOT in the selection, it becomes the new single selection.
		if not _editor.selected_nodes.has(id):
			_editor.clear_selection()
			_editor.add_to_selection(id)
		# If we clicked a node INSIDE the selection, we keep the group!
	
	# --- GROUP OFFSET & HISTORY CAPTURE ---
	# We only prepare for movement if the clicked node ended up selected
	if _editor.selected_nodes.has(id):
		_group_offsets.clear()
		_drag_start_positions.clear() 
		
		var anchor_pos = _graph.nodes[id].position
		
		for selected_id in _editor.selected_nodes:
			# 1. Capture Visual Offset
			if selected_id != id:
				var diff = _graph.nodes[selected_id].position - anchor_pos
				_group_offsets[selected_id] = diff
			
			# 2. Capture History Start Position
			if _graph.nodes.has(selected_id):
				_drag_start_positions[selected_id] = _graph.nodes[selected_id].position
				
	else:
		# FIX: If we deselected the node (Ctrl click), cancel BOTH logic and visuals
		_drag_node_id = ""
		_renderer.drag_start_id = "" 
		_renderer.queue_redraw()

func _finish_moving_node() -> void:
	# --- COMMIT UNDO HISTORY ---
	if not _drag_start_positions.is_empty():
		var move_payload = {}
		
		for id in _drag_start_positions:
			if _graph.nodes.has(id):
				move_payload[id] = {
					"from": _drag_start_positions[id],
					"to": _graph.nodes[id].position
				}
		
		_editor.commit_move_batch(move_payload)
	
	# --- CLEANUP ---
	_drag_start_positions.clear()
	_drag_node_id = ""
	_renderer.drag_start_id = ""
	_group_offsets.clear()

# --- BOX SELECTION (OPTIMIZED) ---
func _start_box_selection(pos: Vector2) -> void:
	_box_start_pos = pos

func _finish_box_selection(mouse_pos: Vector2) -> void:
	var drag_dist = _box_start_pos.distance_to(mouse_pos)
	
	# Deselect logic for small clicks
	if drag_dist < DRAG_THRESHOLD:
		if not Input.is_key_pressed(KEY_SHIFT) and not Input.is_key_pressed(KEY_CTRL):
			_editor.clear_selection()
		_box_start_pos = Vector2.INF
		_renderer.selection_rect = Rect2()
		_renderer.pre_selection_ref = []
		_renderer.queue_redraw()
		return
	
	# Commit Box Selection
	var rect = _get_rect(_box_start_pos, mouse_pos)
	var nodes_in_box = _graph.get_nodes_in_rect(rect)
	var edges_in_box = _graph.get_edges_in_rect(rect)
	
	var is_shift = Input.is_key_pressed(KEY_SHIFT)
	var is_ctrl = Input.is_key_pressed(KEY_CTRL)
	
	if not is_shift and not is_ctrl:
		# REPLACE Selection
		# Optimization: Direct batch set (clears existing)
		_editor.set_selection_batch(nodes_in_box, edges_in_box, true)
		
	elif is_shift:
		# ADD to Selection (Union)
		# Filter to avoid duplicates in the append operation
		var nodes_to_add: Array[String] = []
		for id in nodes_in_box:
			if not _editor.selected_nodes.has(id):
				nodes_to_add.append(id)
				
		var edges_to_add: Array = []
		for pair in edges_in_box:
			pair.sort()
			if not _editor.is_edge_selected(pair):
				edges_to_add.append(pair)
		
		if not nodes_to_add.is_empty() or not edges_to_add.is_empty():
			# Optimization: Batch append (does NOT clear existing)
			_editor.set_selection_batch(nodes_to_add, edges_to_add, false)
		
	elif is_ctrl:
		# SUBTRACT Selection (Difference)
		# We must calculate the final state manually, then set it batch-wise
		var final_nodes = _editor.selected_nodes.duplicate()
		for id in nodes_in_box:
			if final_nodes.has(id):
				final_nodes.erase(id)
		
		var final_edges = _editor.selected_edges.duplicate()
		for pair in edges_in_box:
			pair.sort()
			if _editor.is_edge_selected(pair):
				final_edges.erase(pair)
		
		# Optimization: Set the newly calculated reduced list
		_editor.set_selection_batch(final_nodes, final_edges, true)
			
	# Cleanup
	_box_start_pos = Vector2.INF
	_renderer.selection_rect = Rect2()
	_renderer.pre_selection_ref = []
	_renderer.queue_redraw()

func _get_rect(p1: Vector2, p2: Vector2) -> Rect2:
	var min_x = min(p1.x, p2.x)
	var max_x = max(p1.x, p2.x)
	var min_y = min(p1.y, p2.y)
	var max_y = max(p1.y, p2.y)
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

func exit() -> void:
	_drag_node_id = ""
	_group_offsets.clear()
	_box_start_pos = Vector2.INF
	_renderer.selection_rect = Rect2()
	_renderer.pre_selection_ref = []
	_renderer.queue_redraw()
