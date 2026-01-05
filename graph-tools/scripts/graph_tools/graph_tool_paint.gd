class_name GraphToolPaint
extends GraphTool

# --- STATE ---
var _is_painting: bool = false
var _last_node_id: String = ""
var _last_pos: Vector2 = Vector2.ZERO

# --- SETTINGS ---
const PAINT_SPACING: float = 60.0

func handle_input(event: InputEvent) -> void:
	# 1. Mouse Click (Start / Stop)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_painting = true
			_last_node_id = "" # Start a fresh chain
			
			# Paint the first node immediately on click
			_paint_node(_editor.get_global_mouse_position())
		else:
			_is_painting = false
			_last_node_id = ""
			
	# 2. Mouse Motion (Dragging)
	elif event is InputEventMouseMotion:
		if _is_painting:
			var current_pos = _editor.get_global_mouse_position()
			
			# Check distance to avoid clustering
			if current_pos.distance_to(_last_pos) > PAINT_SPACING:
				_paint_node(current_pos)
		
		# Optional: Update hover effect while painting (like Connect tool does)
		_update_hover(_editor.get_global_mouse_position())

func _paint_node(pos: Vector2) -> void:
	# 1. Create the node via API and CAPTURE the ID
	var new_id = _editor.create_node(pos)
	
	# 2. Connect to previous
	if not _last_node_id.is_empty():
		_graph.add_edge(_last_node_id, new_id)
	
	# 3. Update State
	_last_node_id = new_id
	_last_pos = pos
	
	_renderer.queue_redraw()
