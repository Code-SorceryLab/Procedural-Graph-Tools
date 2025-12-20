extends Camera2D
class_name GraphCamera

@export var zoom_speed: float = 0.1
@export var min_zoom: float = 0.2
@export var max_zoom: float = 5.0

var _is_panning: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		# Zooming
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_at_mouse(1.0 + zoom_speed)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_at_mouse(1.0 - zoom_speed)
			get_viewport().set_input_as_handled()
		
		# Panning Start/End
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = event.pressed
			get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and _is_panning:
		# Panning Action
		position -= event.relative / zoom
		get_viewport().set_input_as_handled()

func _zoom_at_mouse(factor: float) -> void:
	var target_zoom = zoom * factor
	
	# Clamp zoom
	if target_zoom.x < min_zoom: target_zoom = Vector2(min_zoom, min_zoom)
	if target_zoom.x > max_zoom: target_zoom = Vector2(max_zoom, max_zoom)
	
	# Zoom towards mouse pointer
	var mouse_world_before = get_global_mouse_position()
	zoom = target_zoom
	var mouse_world_after = get_global_mouse_position()
	position += (mouse_world_before - mouse_world_after)

func reset_view() -> void:
	position = Vector2(500, 300) # Or your screen center
	zoom = Vector2(1.0, 1.0)


func center_on_rect(rect: Rect2, margin: float = 50.0) -> void:
	# 1. Center the camera on the center of the bounding box
	position = rect.get_center()
	
	# 2. Calculate the zoom needed to fit the rectangle
	var viewport_size = get_viewport_rect().size
	
	# Avoid division by zero if graph is empty/single point
	if rect.size.x <= 1 or rect.size.y <= 1:
		zoom = Vector2(1, 1)
		return

	# Determine how much we need to scale to fit width and height
	# We use the smaller of the two scales to ensure BOTH fit
	var scale_x = viewport_size.x / (rect.size.x + margin * 2)
	var scale_y = viewport_size.y / (rect.size.y + margin * 2)
	var target_zoom = min(scale_x, scale_y)
	
	# Clamp the calculated zoom to our limits
	target_zoom = clamp(target_zoom, min_zoom, max_zoom)
	
	zoom = Vector2(target_zoom, target_zoom)
