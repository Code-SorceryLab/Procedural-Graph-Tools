extends PanelContainer

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# If the mouse wheel or middle mouse button triggers over this panel...
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_MIDDLE]:
			# ...eat the event instantly so the Camera's _unhandled_input never sees it!
			accept_event()
