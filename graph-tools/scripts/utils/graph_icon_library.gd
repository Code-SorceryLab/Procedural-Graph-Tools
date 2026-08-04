class_name GraphIconLibrary
extends RefCounted

static func draw_icon(canvas: CanvasItem, icon_name: String, center: Vector2, size: float, color: Color) -> void:
	match icon_name.to_lower():
		"lock": _draw_lock(canvas, center, size, color)
		"key": _draw_key(canvas, center, size, color)
		"skull": _draw_skull(canvas, center, size, color)
		_: canvas.draw_circle(center, size * 0.4, color) # Fallback Dot

static func _draw_lock(canvas: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var bg = Color(0.15, 0.15, 0.15, 0.9) # Dark inner color
	# Shackle (Arc from PI to TAU draws a perfect top-half semi-circle)
	canvas.draw_arc(c + Vector2(0, -s*0.1), s*0.25, PI, TAU, 16, col, s*0.15, true)
	# Body
	canvas.draw_rect(Rect2(c.x - s*0.4, c.y - s*0.1, s*0.8, s*0.6), col, true)
	# Keyhole
	canvas.draw_circle(c + Vector2(0, s*0.2), s*0.1, bg)

static func _draw_key(canvas: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var bg = Color(0.15, 0.15, 0.15, 0.9)
	# Head & Hole
	canvas.draw_circle(c + Vector2(-s*0.3, 0), s*0.25, col)
	canvas.draw_circle(c + Vector2(-s*0.3, 0), s*0.1, bg)
	# Shaft
	canvas.draw_line(c + Vector2(-s*0.1, 0), c + Vector2(s*0.5, 0), col, s*0.15, true)
	# Teeth
	canvas.draw_line(c + Vector2(s*0.2, 0), c + Vector2(s*0.2, s*0.25), col, s*0.15, true)
	canvas.draw_line(c + Vector2(s*0.4, 0), c + Vector2(s*0.4, s*0.25), col, s*0.15, true)

static func _draw_skull(canvas: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var bg = Color(0.15, 0.15, 0.15, 0.9)
	# Cranium
	canvas.draw_circle(c + Vector2(0, -s*0.1), s*0.3, col)
	# Jaw
	canvas.draw_rect(Rect2(c.x - s*0.15, c.y + s*0.05, s*0.3, s*0.25), col, true)
	# Eyes
	canvas.draw_circle(c + Vector2(-s*0.12, -s*0.05), s*0.08, bg)
	canvas.draw_circle(c + Vector2(s*0.12, -s*0.05), s*0.08, bg)
