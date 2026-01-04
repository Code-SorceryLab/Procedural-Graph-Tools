class_name GraphToolSelect
extends GraphTool

var _drag_start_id: String = ""

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_pos = _editor.get_global_mouse_position()
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var clicked_id = _get_node_at_pos(mouse_pos)
				
				if not clicked_id.is_empty():
					_drag_start_id = clicked_id
					_renderer.drag_start_id = clicked_id
					
					if Input.is_key_pressed(KEY_SHIFT):
						_editor.toggle_selection(clicked_id)
					elif not _editor.selected_nodes.has(clicked_id):
						_editor.clear_selection()
						_editor.add_to_selection(clicked_id)
				else:
					_editor.clear_selection()
			else:
				_drag_start_id = ""
				_renderer.drag_start_id = ""

		_renderer.queue_redraw()

	elif event is InputEventMouseMotion:
		if not _drag_start_id.is_empty():
			var move_pos = _editor.get_global_mouse_position()
			if Input.is_key_pressed(KEY_SHIFT):
				move_pos = move_pos.snapped(GraphSettings.SNAP_GRID_SIZE)
				
			_graph.set_node_position(_drag_start_id, move_pos)
			_renderer.queue_redraw()
		
		_update_hover(_editor.get_global_mouse_position())
