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

func enter() -> void:
	# Show ghost immediately upon entering
	_update_ghost(_editor.get_global_mouse_position(), Input.is_key_pressed(KEY_SHIFT))

func exit() -> void:
	_is_painting = false
	_last_node_id = ""
	# Cleanup: Hide the ghost
	_renderer.snap_preview_pos = Vector2.INF
	_renderer.queue_redraw()

func handle_input(event: InputEvent) -> void:
	# 1. Mouse Click (Start / Stop)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_painting = true
			_last_node_id = "" 
			
			# --- START TRANSACTION ---
			# We group the entire stroke into one Undo step.
			# 'false' = Don't recenter camera on undo (keep smooth feel)
			_editor.start_undo_transaction("Paint Nodes", false)
			
			# Paint immediately
			var target_pos = _get_paint_position(_editor.get_global_mouse_position(), Input.is_key_pressed(KEY_SHIFT))
			_paint_node(target_pos)
			
		else:
			# --- COMMIT TRANSACTION ---
			# The mouse is released, so the stroke is finished.
			# If Atomic Undo is ON, this does nothing (safe).
			# If Atomic Undo is OFF, this bundles all nodes/edges into one item.
			_editor.commit_undo_transaction()
			
			_is_painting = false
			_last_node_id = ""
			_last_grid_pos = Vector2i(999999, 999999)
			
	# 2. Mouse Motion (Ghost + Dragging)
	elif event is InputEventMouseMotion:
		# ... (Rest of logic is unchanged) ...
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

func _paint_node(pos: Vector2) -> void:
	# 1. Create Node (Facade handles Dirty + Redraw)
	var new_id = _editor.create_node(pos)
	
	# 2. Connect to previous (Facade handles Dirty + Redraw)
	if not _last_node_id.is_empty():
		_editor.connect_nodes(_last_node_id, new_id)
	
	_last_node_id = new_id
	_last_pos = pos
	
	# REMOVED: _renderer.queue_redraw() 
	# The editor calls triggered above ensure the view is up to date.
