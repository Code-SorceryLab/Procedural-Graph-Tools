class_name GraphToolCut
extends GraphTool

var _is_dragging: bool = false
var _start_pos: Vector2 = Vector2.ZERO
var _current_pos: Vector2 = Vector2.ZERO

var _intersected_edges: Array = []

func enter() -> void:
	_show_status("Cut Tool: Drag across edges to sever them.")

func exit() -> void:
	super.exit()
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

func _calculate_intersections() -> void:
	_intersected_edges.clear()
	
	for u_id in _graph.nodes:
		var u_pos = _graph.get_node_pos(u_id)
		var neighbors = _graph.get_neighbors(u_id)
		
		for v_id in neighbors:
			if u_id > v_id: continue # unique pairs only
				
			var v_pos = _graph.get_node_pos(v_id)
			var intersection = Geometry2D.segment_intersects_segment(
				_start_pos, _current_pos, u_pos, v_pos
			)
			
			if intersection != null:
				var pair = [u_id, v_id]
				pair.sort()
				_intersected_edges.append(pair)

func _perform_cut() -> void:
	if _intersected_edges.is_empty(): return
		
	print("Knife: Severing %d edges." % _intersected_edges.size())
	_editor.start_undo_transaction("Cut Edges", false)
	
	for pair in _intersected_edges:
		_editor.disconnect_nodes(pair[0], pair[1])
		
	_editor.commit_undo_transaction()

# --- VISUALS ---

func _update_visuals() -> void:
	_renderer.tool_line_start = _start_pos
	_renderer.tool_line_end = _current_pos
	
	# Live calculate intersections while dragging
	_calculate_intersections()
	
	# Send to renderer for live feedback
	if "cut_preview_edges" in _renderer:
		_renderer.cut_preview_edges = _intersected_edges
		
	_renderer.queue_redraw()

func _clear_visuals() -> void:
	_intersected_edges.clear()
	_renderer.tool_line_start = Vector2.INF
	_renderer.tool_line_end = Vector2.INF
	
	if "cut_preview_edges" in _renderer:
		_renderer.cut_preview_edges.clear()
		
	_renderer.queue_redraw()
