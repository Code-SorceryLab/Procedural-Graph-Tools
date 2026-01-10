class_name GraphDragHandler
extends RefCounted

# --- SIGNALS ---
# Fired when the user clicks without dragging (Perform Spawn/Select)
signal clicked(position: Vector2)
# Fired when the user finishes dragging a box (Perform Box Select)
signal box_selected(rect: Rect2)
signal drag_updated(rect: Rect2)

# --- STATE ---
var _editor: GraphEditor
var _drag_start_pos: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
const DRAG_THRESHOLD: float = 10.0

func _init(editor_ref: GraphEditor) -> void:
	_editor = editor_ref

# Returns TRUE if the event was consumed (logic handled)
func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# MOUSE DOWN: Prepare
				_drag_start_pos = _editor.get_global_mouse_position()
				_is_dragging = false
				return true # Consumed
			else:
				# MOUSE UP: Decide Action
				if _is_dragging:
					_finish_drag()
				else:
					clicked.emit(_editor.get_global_mouse_position())
				
				# Reset
				_is_dragging = false
				return true # Consumed
				
	elif event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var current_pos = _editor.get_global_mouse_position()
			
			if not _is_dragging:
				if _drag_start_pos.distance_to(current_pos) > DRAG_THRESHOLD:
					_is_dragging = true
			
			if _is_dragging:
				_update_visual(current_pos)
			return true # Consumed

	return false # Not a drag event

func _update_visual(current_pos: Vector2) -> void:
	var rect = Rect2(_drag_start_pos, current_pos - _drag_start_pos).abs()
	_editor.tool_overlay_rect = rect
	_editor.queue_redraw()
	
	# Emit signal so Tool can perform live highlighting
	drag_updated.emit(rect)

func _finish_drag() -> void:
	var final_rect = _editor.tool_overlay_rect
	# Clear Visuals
	_editor.tool_overlay_rect = Rect2()
	_editor.queue_redraw()
	
	# Notify Listener
	if final_rect.has_area():
		box_selected.emit(final_rect)
