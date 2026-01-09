class_name GridRenderer
extends Node2D

var camera_ref: Camera2D
var grid_color: Color = Color(1, 1, 1, 0.05) # Faint lines
var axis_color: Color = Color(0, 0, 0, 0.2)  # Darker 0,0 axes

func _ready() -> void:
	# Ensure this node is behind everything else
	z_index = -100 

func _process(_delta: float) -> void:
	# Efficiently redraw only when visible to match camera movement
	if visible and GraphSettings.SHOW_GRID:
		queue_redraw()

func _draw() -> void:
	if not GraphSettings.SHOW_GRID or not camera_ref:
		return
		
	var viewport_rect = get_viewport_rect()
	
	# 1. Calculate the Visible World Area
	var cam_pos = camera_ref.position
	var zoom = camera_ref.zoom.x 
	var view_size = viewport_rect.size / zoom
	var view_tl = cam_pos - (view_size / 2.0)
	var view_br = cam_pos + (view_size / 2.0)
	
	# 2. Get Spacing [REFACTORED]
	# Use the new global Vector2 setting
	var space_x = GraphSettings.GRID_SPACING.x
	var space_y = GraphSettings.GRID_SPACING.y
	
	# Safety check to prevent infinite loops if spacing is somehow 0
	if space_x <= 0.1: space_x = 60.0
	if space_y <= 0.1: space_y = 60.0
	
	# 3. Calculate Start Points (Snapped)
	var start_x = floor(view_tl.x / space_x) * space_x
	var start_y = floor(view_tl.y / space_y) * space_y
	
	# 4. Draw Vertical Lines
	var current_x = start_x
	while current_x < view_br.x:
		var col = grid_color
		if is_equal_approx(current_x, 0.0): col = axis_color
		
		draw_line(Vector2(current_x, view_tl.y), Vector2(current_x, view_br.y), col, 1.0 / zoom)
		current_x += space_x

	# 5. Draw Horizontal Lines
	var current_y = start_y
	while current_y < view_br.y:
		var col = grid_color
		if is_equal_approx(current_y, 0.0): col = axis_color
		
		draw_line(Vector2(view_tl.x, current_y), Vector2(view_br.x, current_y), col, 1.0 / zoom)
		current_y += space_y
