class_name GraphToolPaint
extends GraphTool

# --- STATE ---
var _is_painting: bool = false
var _last_node_id: String = ""
var _last_pos: Vector2 = Vector2.ZERO
var _last_grid_pos: Vector2i = Vector2i(999999, 999999)

# --- SETTINGS ---
const PAINT_SPACING: float = 60.0
var _cell_size: float = GraphSettings.CELL_SIZE 

# NEW: Tool Options State
var _brush_size: int = 1
var _brush_shape: int = 0 # 0 = Circle, 1 = Square

# --- TOOL OPTIONS API (NEW) ---

func get_options_schema() -> Array:
	return [
		{
			"name": "brush_size",
			"label": "Size",
			"type": TYPE_INT,
			"default": _brush_size,
			"min": 1,
			"max": 10,
			"hint": "Controls spacing/radius (Cosmetic for now)"
		},
		{
			"name": "brush_shape",
			"label": "Shape",
			"type": TYPE_INT,
			"default": _brush_shape,
			"hint": "enum",
			"hint_string": "Circle,Square"
		}
	]

func apply_option(param_name: String, value: Variant) -> void:
	match param_name:
		"brush_size":
			_brush_size = int(value)
			_show_status("Brush Size: %d" % _brush_size)
		"brush_shape":
			_brush_shape = int(value)
			var shape_name = "Circle" if _brush_shape == 0 else "Square"
			_show_status("Brush Shape: %s" % shape_name)

# --- LIFECYCLE ---

func enter() -> void:
	# Show ghost immediately upon entering
	_update_ghost(_editor.get_global_mouse_position(), Input.is_key_pressed(KEY_SHIFT))
	
	# Initial status
	_show_status("Paint Tool: Drag to draw nodes.")

func exit() -> void:
	_is_painting = false
	_last_node_id = ""
	# Cleanup: Hide the ghost
	_renderer.snap_preview_pos = Vector2.INF
	_renderer.queue_redraw()
	_show_status("")

func handle_input(event: InputEvent) -> void:
	# 1. Mouse Click (Start / Stop)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_painting = true
			_last_node_id = "" 
			
			# --- START TRANSACTION ---
			_editor.start_undo_transaction("Paint Nodes", false)
			
			# Paint immediately
			var target_pos = _get_paint_position(_editor.get_global_mouse_position(), Input.is_key_pressed(KEY_SHIFT))
			_paint_node(target_pos)
			
		else:
			# --- COMMIT TRANSACTION ---
			_editor.commit_undo_transaction()
			
			_is_painting = false
			_last_node_id = ""
			_last_grid_pos = Vector2i(999999, 999999)
			
	# 2. Mouse Motion (Ghost + Dragging)
	elif event is InputEventMouseMotion:
		var raw_pos = _editor.get_global_mouse_position()
		var shift = Input.is_key_pressed(KEY_SHIFT) 
		
		# A. UPDATE GHOST
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
				# Scale spacing based on brush size if desired
				# var effective_spacing = PAINT_SPACING * max(1.0, _brush_size * 0.5) 
				if raw_pos.distance_to(_last_pos) > PAINT_SPACING:
					_paint_node(raw_pos)
					_last_grid_pos = Vector2i(999999, 999999)
		
		_update_hover(raw_pos)

# --- HELPERS ---

func _get_paint_position(raw_pos: Vector2, is_snapped: bool) -> Vector2:
	if is_snapped:
		return raw_pos.snapped(GraphSettings.SNAP_GRID_SIZE)
	return raw_pos

func _get_grid_coord(pos: Vector2) -> Vector2i:
	return Vector2i(round(pos.x / _cell_size), round(pos.y / _cell_size))

func _update_ghost(pos: Vector2, is_snapped: bool) -> void:
	var target = _get_paint_position(pos, is_snapped)
	
	if target != _renderer.snap_preview_pos:
		_renderer.snap_preview_pos = target
		_renderer.queue_redraw()

func _paint_node(center_pos: Vector2) -> void:
	# 1. Determine the range based on brush size
	# Size 1 = 0 offset (just center)
	# Size 2 = -1 to 1 (3x3 grid)
	# Size 3 = -2 to 2 (5x5 grid)
	var radius = _brush_size - 1
	var center_id = ""

	# 2. Iterate through the grid
	for x in range(-radius, radius + 1):
		for y in range(-radius, radius + 1):
			
			# CIRCLE SHAPE LOGIC
			# If shape is Circle (0) and point is outside radius, skip it
			if _brush_shape == 0:
				if Vector2(x, y).length() > radius + 0.5: # +0.5 smooths edges
					continue
			
			# Calculate actual world position
			var offset = Vector2(x, y) * _cell_size
			var paint_pos = center_pos + offset
			
			# 3. Spawn the node
			var new_id = _editor.create_node(paint_pos)
			
			# 4. Handle Connections (Only for the center node)
			# We only maintain the "chain" through the center of the brush stroke
			if x == 0 and y == 0:
				center_id = new_id
				if not _last_node_id.is_empty():
					_editor.connect_nodes(_last_node_id, new_id)

	# 5. Update State (Track the center for the next segment)
	if center_id != "":
		_last_node_id = center_id
	
	_last_pos = center_pos
