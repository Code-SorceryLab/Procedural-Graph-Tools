class_name GraphToolCut
extends GraphTool

var _is_dragging: bool = false
var _start_pos: Vector2 = Vector2.ZERO
var _current_pos: Vector2 = Vector2.ZERO

func enter() -> void:
	pass

func exit() -> void:
	_clear_visuals()

func handle_input(event: InputEvent) -> void:
	# 1. Mouse Click (Start Slash)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_dragging = true
			_start_pos = _editor.get_global_mouse_position()
			_current_pos = _start_pos
			_update_visuals()
		else:
			# Mouse Released -> EXECUTE CUT
			if _is_dragging:
				_perform_cut()
			_is_dragging = false
			_clear_visuals()
			
	# 2. Mouse Motion (Update Line)
	elif event is InputEventMouseMotion and _is_dragging:
		_current_pos = _editor.get_global_mouse_position()
		_update_visuals()

# --- LOGIC ---

func _perform_cut() -> void:
	# 1. We collect edges to remove first (Collision Detection)
	var edges_to_remove: Array[Array] = [] # Stores [u_id, v_id]
	
	for u_id in _graph.nodes:
		var u_pos = _graph.get_node_pos(u_id)
		var neighbors = _graph.get_neighbors(u_id)
		
		for v_id in neighbors:
			if u_id > v_id: continue # unique pairs only
				
			var v_pos = _graph.get_node_pos(v_id)
			
			# MATH: Check Intersection
			var intersection = Geometry2D.segment_intersects_segment(
				_start_pos, _current_pos,
				u_pos, v_pos
			)
			
			if intersection != null:
				edges_to_remove.append([u_id, v_id])
	
	# 2. EXECUTE REMOVAL (With Batching)
	if not edges_to_remove.is_empty():
		print("Knife: Severing %d edges." % edges_to_remove.size())
		
		# --- START TRANSACTION ---
		# We group all cuts into one "Cut Edges" action.
		# Pass 'false' so the camera doesn't jump when you undo a simple cut.
		_editor.start_undo_transaction("Cut Edges", false)
		
		for pair in edges_to_remove:
			# The editor handles the specifics (CmdDisconnect creation)
			# Because a transaction is open, these are captured into a batch.
			_editor.disconnect_nodes(pair[0], pair[1])
			
		# --- COMMIT TRANSACTION ---
		_editor.commit_undo_transaction()

# --- VISUALS ---

func _update_visuals() -> void:
	_renderer.tool_line_start = _start_pos
	_renderer.tool_line_end = _current_pos
	_renderer.queue_redraw()

func _clear_visuals() -> void:
	_renderer.tool_line_start = Vector2.INF
	_renderer.tool_line_end = Vector2.INF
	_renderer.queue_redraw()
