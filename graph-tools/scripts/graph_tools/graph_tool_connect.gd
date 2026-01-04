class_name GraphToolConnect
extends GraphTool

var _drag_start_id: String = ""

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = _editor.get_global_mouse_position()
		
		if event.pressed:
			var clicked_id = _get_node_at_pos(mouse_pos)
			if not clicked_id.is_empty():
				_drag_start_id = clicked_id
				_renderer.drag_start_id = clicked_id
		else:
			if not _drag_start_id.is_empty():
				var release_id = _get_node_at_pos(mouse_pos)
				if not release_id.is_empty() and release_id != _drag_start_id:
					_graph.add_edge(_drag_start_id, release_id)
			
			_drag_start_id = ""
			_renderer.drag_start_id = ""
		
		_renderer.queue_redraw()
		
	elif event is InputEventMouseMotion:
		if not _drag_start_id.is_empty():
			_renderer.queue_redraw() # Fix stutter
		_update_hover(_editor.get_global_mouse_position())
