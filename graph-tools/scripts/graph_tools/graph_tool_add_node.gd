class_name GraphToolAddNode
extends GraphTool

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = _editor.get_global_mouse_position()
		var clicked_id = _get_node_at_pos(mouse_pos)
		
		# Only create if we clicked empty space
		if clicked_id.is_empty():
			var place_pos = mouse_pos
			if Input.is_key_pressed(KEY_SHIFT):
				# [REFACTOR] Use the new GRID_SPACING vector
				place_pos = mouse_pos.snapped(GraphSettings.GRID_SPACING)
			
			_editor.create_node(place_pos)

	elif event is InputEventMouseMotion:
		# Custom Hover for Add Tool (Snap Ghost)
		var mouse_pos = _editor.get_global_mouse_position()
		_update_hover(mouse_pos)
		
		var snap_pos = Vector2.INF
		if _renderer.hovered_id.is_empty() and Input.is_key_pressed(KEY_SHIFT):
			# [REFACTOR] Update ghost snapping
			snap_pos = mouse_pos.snapped(GraphSettings.GRID_SPACING)
		
		if snap_pos != _renderer.snap_preview_pos:
			_renderer.snap_preview_pos = snap_pos
			_renderer.queue_redraw()

func exit() -> void:
	# Cleanup ghost when leaving tool
	_renderer.snap_preview_pos = Vector2.INF
	_renderer.queue_redraw()
