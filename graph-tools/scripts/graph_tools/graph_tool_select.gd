class_name GraphToolSelect
extends GraphTool

const DRAG_THRESHOLD: float = 4.0 # Pixels

# State A: Moving a Node
var _drag_node_id: String = ""
# REMOVED: var _has_moved: bool = false (Handled by Editor Wrapper)

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
					_start_box_selection(mouse_pos)
			else:
				# --- CLICK RELEASE ---
				if not _drag_node_id.is_empty():
					_finish_moving_node()
				elif _box_start_pos != Vector2.INF:
					_finish_box_selection(mouse_pos)
		
		# Keep this redraw for selection clicks (which don't use the wrapper)
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
			
			# --- REFACTOR START ---
			# OLD: _graph.set_node_position(...) + manual redraw + manual dirty flag
			# NEW: Use the Editor Facade. It handles the Dirty Flag and Redraw automatically.
			_editor.set_node_position(_drag_node_id, move_pos)
			# --- REFACTOR END ---
			
		# Update Box State
		elif _box_start_pos != Vector2.INF:
			var rect = _get_rect(_box_start_pos, mouse_pos)
			_renderer.selection_rect = rect
			
			var potential_nodes = _graph.get_nodes_in_rect(rect)
			_renderer.pre_selection_ref = potential_nodes
			_renderer.queue_redraw()
		
		_update_hover(mouse_pos)

# --- HELPER FUNCTIONS ---

func _start_moving_node(id: String) -> void:
	_drag_node_id = id
	_renderer.drag_start_id = id
	# REMOVED: _has_moved = false
	
	if Input.is_key_pressed(KEY_SHIFT):
		_editor.add_to_selection(id)
	elif Input.is_key_pressed(KEY_CTRL):
		_editor.toggle_selection(id)
	else:
		if not _editor.selected_nodes.has(id):
			_editor.clear_selection()
			_editor.add_to_selection(id)

func _finish_moving_node() -> void:
	# REMOVED: Manual dirty check.
	# The data was modified 'live' during the drag via _editor.set_node_position()
	
	_drag_node_id = ""
	_renderer.drag_start_id = ""

func _start_box_selection(pos: Vector2) -> void:
	_box_start_pos = pos

func _finish_box_selection(mouse_pos: Vector2) -> void:
	var drag_dist = _box_start_pos.distance_to(mouse_pos)
	
	if drag_dist < DRAG_THRESHOLD:
		if not Input.is_key_pressed(KEY_SHIFT) and not Input.is_key_pressed(KEY_CTRL):
			_editor.clear_selection()
			
		_box_start_pos = Vector2.INF
		_renderer.selection_rect = Rect2()
		_renderer.pre_selection_ref = []
		_renderer.queue_redraw()
		return
	
	var rect = _get_rect(_box_start_pos, mouse_pos)
	var nodes_in_box = _graph.get_nodes_in_rect(rect)
	
	var is_shift = Input.is_key_pressed(KEY_SHIFT) # Add
	var is_ctrl = Input.is_key_pressed(KEY_CTRL)   # Subtract
	
	if not is_shift and not is_ctrl:
		_editor.clear_selection()
		for id in nodes_in_box:
			_editor.add_to_selection(id)
			
	elif is_shift:
		for id in nodes_in_box:
			_editor.add_to_selection(id)
			
	elif is_ctrl:
		for id in nodes_in_box:
			if _editor.selected_nodes.has(id):
				_editor.toggle_selection(id)
	
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
	_box_start_pos = Vector2.INF
	_renderer.selection_rect = Rect2()
	_renderer.pre_selection_ref = []
	_renderer.queue_redraw()
