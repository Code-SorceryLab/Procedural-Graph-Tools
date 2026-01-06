class_name GraphToolDelete
extends GraphTool

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked_id = _get_node_at_pos(_editor.get_global_mouse_position())
		
		if not clicked_id.is_empty():
			# --- BATCH DELETE LOGIC ---
			# If we clicked a node that is currently selected, delete ALL selected nodes.
			if _editor.selected_nodes.has(clicked_id):
				# 1. Duplicate the array because delete_node() modifies the original list
				var batch_to_delete = _editor.selected_nodes.duplicate()
				
				# 2. Iterate and destroy
				for id in batch_to_delete:
					_editor.delete_node(id)
					
			else:
				# Normal Single Delete
				_editor.delete_node(clicked_id)

	elif event is InputEventMouseMotion:
		_update_hover(_editor.get_global_mouse_position())
