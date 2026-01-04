class_name GraphToolSelect
extends GraphTool

# State A: Moving a Node
var _drag_node_id: String = ""

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
					# CASE A: Clicked a Node -> Start Moving
					_start_moving_node(clicked_id)
				else:
					# CASE B: Clicked Empty Space -> Start Boxing
					_start_box_selection(mouse_pos)
			else:
				# --- CLICK RELEASE ---
				if not _drag_node_id.is_empty():
					_finish_moving_node()
				elif _box_start_pos != Vector2.INF:
					_finish_box_selection(mouse_pos)
		
		# Always redraw on click updates
		_renderer.queue_redraw()

	# 2. MOUSE MOTION INPUT
	elif event is InputEventMouseMotion:
		var mouse_pos = _editor.get_global_mouse_position()
		
		# Update Move State
		if not _drag_node_id.is_empty():
			var move_pos = mouse_pos
			# CONTEXT: Shift during Move = Snap Grid
			if Input.is_key_pressed(KEY_SHIFT):
				move_pos = move_pos.snapped(GraphSettings.SNAP_GRID_SIZE)
			
			_graph.set_node_position(_drag_node_id, move_pos)
			_renderer.queue_redraw()
			
		# Update Box State
		elif _box_start_pos != Vector2.INF:
			# 1. Update the visual rect in the renderer
			var rect = _get_rect(_box_start_pos, mouse_pos)
			_renderer.selection_rect = rect
			
			# 2. Update Pre-Selection Highlight
			# This gives the "Live Feedback" that nodes are about to be picked
			var potential_nodes = _graph.get_nodes_in_rect(rect)
			_renderer.pre_selection_ref = potential_nodes
			_renderer.queue_redraw()
		
		# Update Hover (Standard)
		_update_hover(mouse_pos)

# --- HELPER FUNCTIONS ---

func _start_moving_node(id: String) -> void:
	_drag_node_id = id
	_renderer.drag_start_id = id
	
	# Selection Logic for Single Click
	# If we click a node that isn't selected, select it (and deselect others)
	# Unless Shift is held (Add to selection)
	if Input.is_key_pressed(KEY_SHIFT):
		_editor.add_to_selection(id)
	elif Input.is_key_pressed(KEY_CTRL):
		# Ctrl Click on node usually toggles off, or does nothing in move mode
		# Let's keep it simple: Ctrl Click toggles
		_editor.toggle_selection(id)
	else:
		if not _editor.selected_nodes.has(id):
			_editor.clear_selection()
			_editor.add_to_selection(id)

func _finish_moving_node() -> void:
	_drag_node_id = ""
	_renderer.drag_start_id = ""

func _start_box_selection(pos: Vector2) -> void:
	_box_start_pos = pos
	# Don't clear selection yet! We might be doing Shift+Drag.

func _finish_box_selection(mouse_pos: Vector2) -> void:
	# 1. Define the final box
	var rect = _get_rect(_box_start_pos, mouse_pos)
	
	# 2. Get nodes inside
	# (We use the SpatialGrid for speed!)
	var nodes_in_box = _graph.get_nodes_in_rect(rect)
	
	# 3. Determine Logic Mode
	var is_shift = Input.is_key_pressed(KEY_SHIFT) # Add
	var is_ctrl = Input.is_key_pressed(KEY_CTRL)   # Subtract
	
	if not is_shift and not is_ctrl:
		# Normal: Clear old, select new
		_editor.clear_selection()
		for id in nodes_in_box:
			_editor.add_to_selection(id)
			
	elif is_shift:
		# Add: Keep old, append new
		for id in nodes_in_box:
			_editor.add_to_selection(id)
			
	elif is_ctrl:
		# Subtract: Remove new from old
		for id in nodes_in_box:
			if _editor.selected_nodes.has(id):
				_editor.toggle_selection(id) # Toggle off
	
	# 4. Cleanup
	_box_start_pos = Vector2.INF
	_renderer.selection_rect = Rect2() # clear visual
	
	# NEW: Clear the pre-selection list so it doesn't get stuck
	_renderer.pre_selection_ref = []
	_renderer.queue_redraw()

func _get_rect(p1: Vector2, p2: Vector2) -> Rect2:
	# Handles dragging in any direction (negative width/height)
	var min_x = min(p1.x, p2.x)
	var max_x = max(p1.x, p2.x)
	var min_y = min(p1.y, p2.y)
	var max_y = max(p1.y, p2.y)
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

# Cleanup if we switch tools while dragging
func exit() -> void:
	_drag_node_id = ""
	_box_start_pos = Vector2.INF
	_renderer.selection_rect = Rect2()
	_renderer.pre_selection_ref = []
	_renderer.queue_redraw()
