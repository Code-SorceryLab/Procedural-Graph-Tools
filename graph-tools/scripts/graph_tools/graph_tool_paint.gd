class_name GraphToolPaint
extends GraphTool

# --- STATE ---
var _is_painting: bool = false
var _last_node_id: String = ""
var _last_pos: Vector2 = Vector2.ZERO
var _last_grid_pos: Vector2i = Vector2i(999999, 999999)

# --- SETTINGS ---
const PAINT_SPACING: float = 60.0
# We assume square cells, reading from your global settings
var _cell_size: float = GraphSettings.CELL_SIZE 

func enter() -> void:
	# Show ghost immediately upon entering
	_update_ghost(_editor.get_global_mouse_position(), Input.is_key_pressed(KEY_SHIFT))

func exit() -> void:
	_is_painting = false
	_last_node_id = ""
	# Cleanup: Hide the ghost using your existing renderer property
	_renderer.snap_preview_pos = Vector2.INF
	_renderer.queue_redraw()

func handle_input(event: InputEvent) -> void:
	# 1. Mouse Click (Start / Stop)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_painting = true
			_last_node_id = "" 
			
			# Paint immediately
			var target_pos = _get_paint_position(_editor.get_global_mouse_position(), Input.is_key_pressed(KEY_SHIFT))
			_paint_node(target_pos)
		else:
			_is_painting = false
			_last_node_id = ""
			_last_grid_pos = Vector2i(999999, 999999)
			
	# 2. Mouse Motion (Ghost + Dragging)
	elif event is InputEventMouseMotion:
		var raw_pos = _editor.get_global_mouse_position()
		var shift = Input.is_key_pressed(KEY_SHIFT) # Check global input state for smoother handling
		
		# A. UPDATE GHOST (Reuse existing renderer logic)
		_update_ghost(raw_pos, shift)
		
		# B. PAINT (Only if dragging)
		if _is_painting:
			# Shift Mode: Snap Logic
			if shift:
				var grid_pos = _get_grid_coord(raw_pos)
				if grid_pos != _last_grid_pos:
					var snap_pos = _get_paint_position(raw_pos, true)
					_paint_node(snap_pos)
					_last_grid_pos = grid_pos
			
			# Freehand Mode: Distance Logic
			else:
				if raw_pos.distance_to(_last_pos) > PAINT_SPACING:
					_paint_node(raw_pos)
					_last_grid_pos = Vector2i(999999, 999999)
		
		_update_hover(raw_pos)

# --- HELPERS ---

func _get_paint_position(raw_pos: Vector2, is_snapped: bool) -> Vector2:
	if is_snapped:
		# Using GraphSettings.SNAP_GRID_SIZE to match your AddNode tool exactly
		return raw_pos.snapped(GraphSettings.SNAP_GRID_SIZE)
	return raw_pos

func _get_grid_coord(pos: Vector2) -> Vector2i:
	return Vector2i(round(pos.x / _cell_size), round(pos.y / _cell_size))

func _update_ghost(pos: Vector2, is_snapped: bool) -> void:
	# If we are freehand painting, we might want to hide the ghost 
	# OR show it at the cursor position. 
	# Your AddNode tool only shows it when Snapped. 
	# Let's show it ALWAYS for Paint so you see where the brush is.
	
	var target = _get_paint_position(pos, is_snapped)
	
	# Reuse the existing property on your renderer!
	if target != _renderer.snap_preview_pos:
		_renderer.snap_preview_pos = target
		_renderer.queue_redraw()

func _paint_node(pos: Vector2) -> void:
	# Use the API that returns the ID (from our previous fix)
	var new_id = _editor.create_node(pos)
	
	if not _last_node_id.is_empty():
		_graph.add_edge(_last_node_id, new_id)
	
	_last_node_id = new_id
	_last_pos = pos
	_renderer.queue_redraw()
