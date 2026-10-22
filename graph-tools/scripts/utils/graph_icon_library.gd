class_name GraphIconLibrary
extends RefCounted

static func draw_icon(canvas: CanvasItem, icon_name: String, center: Vector2, size: float, color: Color) -> void:
	match icon_name.to_lower():
		"lock": _draw_lock(canvas, center, size, color)
		"key": _draw_key(canvas, center, size, color)
		"skull": _draw_skull(canvas, center, size, color)
		"blueprint": _draw_blueprint(canvas, center, size, color)
		"pivot": _draw_pivot(canvas, center, size, color)
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

static func _draw_blueprint(canvas: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	# A tiny grid icon representing a floorplan
	var tl = c - Vector2(s*0.35, s*0.35)
	var w = s*0.7
	canvas.draw_rect(Rect2(tl, Vector2(w, w)), col, false, max(1.0, s*0.1))
	canvas.draw_line(tl + Vector2(w*0.5, 0), tl + Vector2(w*0.5, w), col, max(1.0, s*0.1))
	canvas.draw_line(tl + Vector2(0, w*0.5), tl + Vector2(w, w*0.5), col, max(1.0, s*0.1))

static func _draw_pivot(canvas: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	# A circular arrow indicating rotation
	var r = s * 0.4
	# Draw the main arc (leaving a gap for the arrow head)
	canvas.draw_arc(c, r, PI*0.1, PI*1.8, 16, col, max(2.0, s*0.1), true)
	
	# Draw the arrow head at the end of the arc (PI*1.8)
	var head_pos = c + Vector2(cos(PI*1.8), sin(PI*1.8)) * r
	var head_dir = Vector2(cos(PI*1.8 + PI/2), sin(PI*1.8 + PI/2)) # Tangent to the arc
	var arrow_size = s * 0.2
	
	var p1 = head_pos - head_dir.rotated(PI/4) * arrow_size
	var p2 = head_pos - head_dir.rotated(-PI/4) * arrow_size
	canvas.draw_line(head_pos, p1, col, max(2.0, s*0.1))
	canvas.draw_line(head_pos, p2, col, max(2.0, s*0.1))
