class_name GraphToolZoneBrush
extends GraphTool

# --- CONFIGURATION ---
var brush_radius: int = 0:          # 0 = 1x1, 1 = 3x3, 2 = 5x5
	set(val):
		brush_radius = val
		_update_preview() # Refresh visual immediately if size changes

var is_erasing: bool = false:
	set(val):
		is_erasing = val
		_update_preview() # Refresh visual color

# --- STATE ---
var _is_stroking: bool = false
var _pending_cells: Dictionary = {} # Set { Vector2i: true }
var _target_zone: GraphZone

# ==============================================================================
# 1. INITIALIZATION & OPTIONS
# ==============================================================================
func _init(editor: Node2D) -> void:
	super(editor) # Initialize base GraphTool

func get_options_schema() -> Array:
	return [
		{ 
			"name": "radius", 
			"label": "Brush Size", 
			"type": TYPE_INT, 
			"default": 0, 
			"min": 0, "max": 5, 
			"hint": "Size of the brush (0=Single, 1=3x3, etc)" 
		},
		{ 
			"name": "erase", 
			"label": "Eraser Mode", 
			"type": TYPE_BOOL, 
			"default": false, 
			"hint": "Toggle to remove cells instead of adding them." 
		}
	]

func apply_option(param_name: String, value: Variant) -> void:
	match param_name:
		"radius": brush_radius = int(value)
		"erase": is_erasing = bool(value)

func enter() -> void:
	_show_status("Zone Brush: Left Click to Paint, Right Click to Erase.")
	_update_preview()

# Ensure clean exit
func exit() -> void:
	_is_stroking = false
	_pending_cells.clear()
	_clear_preview()
	
	# Clear stroke buffer
	if _renderer:
		_renderer.pending_stroke_cells.clear()
		_renderer.queue_redraw()
		
	super.exit()

# ==============================================================================
# 2. INPUT HANDLING
# ==============================================================================
func handle_input(event: InputEvent) -> void:
	# A. PREVIEW UPDATE (Motion)
	if event is InputEventMouseMotion:
		_update_preview()
		if _is_stroking:
			_paint_at_cursor()
			
	# B. STROKE HANDLING (Buttons)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_stroke(is_erasing) # Use UI setting
			else:
				_end_stroke()
				
		# Quality of Life: Right Click always Erases
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				_start_stroke(true) # Force Erase
			else:
				_end_stroke()

# ==============================================================================
# 3. PAINTING LOGIC
# ==============================================================================
func _start_stroke(erase_override: bool) -> void:
	# 1. Validate Selection
	var selected_zones = _editor.selected_zones
	if selected_zones.is_empty():
		_show_status("⚠️ No Zone Selected! Select a zone to paint.")
		return
		
	# 2. Setup State
	_target_zone = selected_zones[0]
	_is_stroking = true
	# We store the mode for this specific stroke (so holding R-Click doesn't flicker)
	# But for simplicity, we'll check the override or global flag at commit time.
	# Actually, better to store if THIS stroke is destructive.
	# Re-using the class property `is_erasing` might be confusing if we used Right Click override.
	# Let's trust the override passed in.
	
	# To handle the override cleanly, we can temporarily flip the flag, 
	# OR simpler: check the mouse button at the end? 
	# Let's just pass the override intent to the paint function if needed.
	
	# For consistency with the `is_erasing` UI toggle, let's update it locally 
	# if right click is held, or just track `_current_stroke_is_erase`.
	self.set_meta("_current_stroke_is_erase", erase_override)
	
	_pending_cells.clear()
	_paint_at_cursor() 

func _paint_at_cursor() -> void:
	if not _target_zone: return
	
	var mouse_pos = _get_snapped_mouse_pos()
	var spacing = GraphSettings.GRID_SPACING
	
	# Grid Coordinates
	var gx = round(mouse_pos.x / spacing.x)
	var gy = round(mouse_pos.y / spacing.y)
	
	var changed = false
	
	# Accumulate Cells
	for x in range(-brush_radius, brush_radius + 1):
		for y in range(-brush_radius, brush_radius + 1):
			var cell = Vector2i(gx + x, gy + y)
			if not _pending_cells.has(cell):
				_pending_cells[cell] = true
				changed = true

	# Update Live Feedback
	if changed:
		_sync_stroke_visuals()

# Helper to push data to renderer
func _sync_stroke_visuals() -> void:
	# Convert Dict Keys -> Array
	var cell_list: Array[Vector2i] = []
	for cell in _pending_cells:
		cell_list.append(cell)
		
	var stroke_is_erase = self.get_meta("_current_stroke_is_erase", is_erasing)
	
	_renderer.pending_stroke_cells = cell_list
	_renderer.pending_stroke_color = _target_zone.zone_color
	_renderer.pending_stroke_is_erase = stroke_is_erase
	_renderer.queue_redraw()

func _end_stroke() -> void:
	if not _is_stroking: return
	_is_stroking = false
	
	if _pending_cells.is_empty(): return
	
	# 1. Convert Set to Array
	var cell_list: Array[Vector2i] = []
	for cell in _pending_cells:
		cell_list.append(cell)
	
	# 2. Determine Mode
	var stroke_is_erase = self.get_meta("_current_stroke_is_erase", is_erasing)
	
	# 3. Commit Transaction
	if stroke_is_erase:
		# Remove list
		_editor.modify_zone_cells(_target_zone, [], cell_list)
	else:
		# Add list
		_editor.modify_zone_cells(_target_zone, cell_list, [])
	
	# Cleanup Visuals
	_renderer.pending_stroke_cells.clear()
	_renderer.queue_redraw()
	
	# Cleanup State
	_pending_cells.clear()
	_target_zone = null

# ==============================================================================
# 4. VISUALIZATION HELPERS
# ==============================================================================
func _update_preview() -> void:
	var mouse_pos = _get_snapped_mouse_pos()
	var spacing = GraphSettings.GRID_SPACING
	
	var gx = round(mouse_pos.x / spacing.x)
	var gy = round(mouse_pos.y / spacing.y)
	
	# Calculate Preview Cells
	var preview: Array[Vector2i] = []
	for x in range(-brush_radius, brush_radius + 1):
		for y in range(-brush_radius, brush_radius + 1):
			preview.append(Vector2i(gx + x, gy + y))
			
	# Push to Renderer
	_renderer.brush_preview_cells = preview
	
	# Color Logic: Red for Erase, Green for Paint
	# Check if Right Click is held OR global erase is on
	var right_click_held = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if is_erasing or right_click_held:
		_renderer.brush_preview_color = Color(1.0, 0.2, 0.2, 0.5) # Red
	else:
		_renderer.brush_preview_color = Color(0.2, 1.0, 0.2, 0.5) # Green
		
	_renderer.queue_redraw()

func _clear_preview() -> void:
	if _renderer:
		_renderer.brush_preview_cells = []
		_renderer.queue_redraw()

func _get_snapped_mouse_pos() -> Vector2:
	var raw = _editor.get_global_mouse_position()
	# Use Camera if available for accuracy
	if _editor.camera:
		raw = _editor.camera.get_global_mouse_position()
	return raw
