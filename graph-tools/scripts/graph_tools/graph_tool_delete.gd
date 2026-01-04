class_name GraphToolDelete
extends GraphTool

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked_id = _get_node_at_pos(_editor.get_global_mouse_position())
		if not clicked_id.is_empty():
			_editor.delete_node(clicked_id)
			_renderer.queue_redraw()
	
	elif event is InputEventMouseMotion:
		_update_hover(_editor.get_global_mouse_position())
