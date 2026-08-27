class_name ValidatorVisualizer
extends Node2D

var cell_size: float = 50.0
var is_active: bool = true

# State 
var _puddle: Dictionary = {} # Vector2i -> Color
var _frontier: Array = []

func update_visualization(newly_visited: Array, frontier: Array, color_index: int) -> void:
	var hue = fmod(0.55 + (color_index * 0.0005), 1.0)
	var paint_color = Color.from_hsv(hue, 0.8, 1.0, 0.4)
	
	for pos in newly_visited:
		_puddle[pos] = paint_color
		
	_frontier = frontier.duplicate()
	queue_redraw() # Tells Godot to call _draw() on the next frame

func full_redraw(all_visited: Array, frontier: Array) -> void:
	_puddle.clear()
	for pos in all_visited:
		_puddle[pos] = Color.from_hsv(0.55, 0.8, 1.0, 0.4) # Base uniform color for redraws
		
	_frontier = frontier.duplicate()
	queue_redraw()

func clear() -> void:
	_puddle.clear()
	_frontier.clear()
	queue_redraw()

func set_visible_state(state: bool) -> void:
	is_active = state
	queue_redraw()

func _draw() -> void:
	if not is_active: return
	
	# 1. Draw the Puddle
	for pos in _puddle:
		draw_rect(Rect2(Vector2(pos.x * cell_size, pos.y * cell_size), Vector2(cell_size, cell_size)), _puddle[pos])
		
	# 2. Draw the Glowing Frontier
	for pos in _frontier:
		draw_rect(Rect2(Vector2(pos.x * cell_size, pos.y * cell_size), Vector2(cell_size, cell_size)), Color.CYAN, false, 3.0)


func intersects_rect(rect: Rect2i) -> bool:
	if not is_active: return false
	
	# Check the puddle
	for pt in _puddle:
		if rect.has_point(pt): return true
		
	# Check the glowing outline
	for pt in _frontier:
		if rect.has_point(pt): return true
		
	return false
