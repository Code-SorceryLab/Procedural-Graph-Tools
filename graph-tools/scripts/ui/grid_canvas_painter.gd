class_name GridCanvasPainter
extends VBoxContainer

signal cell_painted(grid_pos: Vector2i, is_erase: bool, is_drag: bool)
signal cell_hovered(grid_pos: Vector2i)

enum OriginMode { CENTERED, TOP_LEFT }

# --- CONFIGURATION ---
var origin_mode: OriginMode = OriginMode.CENTERED
var zoom_level: float = 2.0
var tile_size: float = 16.0
var grid_bounds: Vector2i = Vector2i(9, 9) # Only strictly enforced in TOP_LEFT mode

# --- STATE ---
var canvas: Control
var _mouse_grid_pos: Vector2i = Vector2i(-9999, -9999)
var _draw_mask: int = 0 

# Hover Highlight State
var highlighted_cells: Array[Vector2i] = []
var highlight_color: Color = Color(1.0, 1.0, 1.0, 0.3)

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# --- TOOLBAR ---
	var top_tools = HBoxContainer.new()
	add_child(top_tools)
	
	var lbl_help = Label.new()
	lbl_help.text = " Left Click: Draw   |   Right Click: Erase"
	lbl_help.modulate = Color(1, 1, 1, 0.6)
	top_tools.add_child(lbl_help)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_tools.add_child(spacer)
	
	var btn_zoom_out = Button.new()
	btn_zoom_out.text = " - Zoom "
	btn_zoom_out.pressed.connect(func(): set_zoom(zoom_level - 0.25))
	top_tools.add_child(btn_zoom_out)
	
	var btn_zoom_in = Button.new()
	btn_zoom_in.text = " + Zoom "
	btn_zoom_in.pressed.connect(func(): set_zoom(zoom_level + 0.25))
	top_tools.add_child(btn_zoom_in)
	
	# --- CANVAS ---
	var canvas_bg = ColorRect.new()
	canvas_bg.color = Color(0.1, 0.1, 0.12)
	canvas_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_bg.clip_contents = true
	add_child(canvas_bg)
	
	canvas = Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	canvas_bg.add_child(canvas)
	
	canvas.draw.connect(_on_canvas_draw)
	canvas.gui_input.connect(_on_canvas_input)
	
	# Clear highlights when leaving the canvas
	canvas.mouse_exited.connect(func():
		_mouse_grid_pos = Vector2i(-9999, -9999)
		highlighted_cells.clear()
		canvas.queue_redraw()
	)

# ==============================================================================
# MATH & LOGIC HELPERS
# ==============================================================================
func set_zoom(new_zoom: float) -> void:
	zoom_level = clamp(new_zoom, 0.5, 5.0)
	canvas.queue_redraw()

func get_actual_tile_size() -> float:
	return tile_size * zoom_level

func get_grid_origin() -> Vector2:
	if origin_mode == OriginMode.CENTERED:
		return canvas.size / 2.0
	return Vector2.ZERO # TOP_LEFT

func is_in_bounds(grid_pos: Vector2i) -> bool:
	if origin_mode == OriginMode.CENTERED:
		return true # Infinite canvas
	return grid_pos.x >= 0 and grid_pos.x < grid_bounds.x and grid_pos.y >= 0 and grid_pos.y < grid_bounds.y

func get_pixel_rect(grid_pos: Vector2i) -> Rect2:
	var ts = get_actual_tile_size()
	var origin = get_grid_origin()
	return Rect2(origin.x + (grid_pos.x * ts), origin.y + (grid_pos.y * ts), ts, ts)

func rotate_point(pt: Vector2i, rot_idx: int) -> Vector2i:
	match rot_idx % 4:
		1: return Vector2i(-pt.y, pt.x) # 90 deg CW
		2: return Vector2i(-pt.x, -pt.y) # 180 deg
		3: return Vector2i(pt.y, -pt.x) # 270 deg CW
		_: return pt # 0 deg

# ==============================================================================
# INPUT HANDLING
# ==============================================================================
func _on_canvas_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var ts = get_actual_tile_size()
		var offset = event.position - get_grid_origin()
		var gx = floor(offset.x / ts)
		var gy = floor(offset.y / ts)
		var new_pos = Vector2i(gx, gy)
		
		if new_pos != _mouse_grid_pos:
			_mouse_grid_pos = new_pos
			cell_hovered.emit(_mouse_grid_pos)
			
	var is_click = event is InputEventMouseButton and event.pressed
	var is_drag = event is InputEventMouseMotion and _draw_mask != 0
	
	if is_click:
		if event.button_index == MOUSE_BUTTON_LEFT: _draw_mask = 1
		elif event.button_index == MOUSE_BUTTON_RIGHT: _draw_mask = 2
		else: _draw_mask = 0
	elif event is InputEventMouseButton and not event.pressed:
		_draw_mask = 0

	if (is_click and _draw_mask != 0) or is_drag:
		if is_in_bounds(_mouse_grid_pos):
			cell_painted.emit(_mouse_grid_pos, _draw_mask == 2, is_drag)

# ==============================================================================
# BASE GRID RENDERING
# ==============================================================================
func _on_canvas_draw() -> void:
	var ts = get_actual_tile_size()
	var grid_color = Color(1, 1, 1, 0.1)
	
	if origin_mode == OriginMode.CENTERED:
		var center = get_grid_origin()
		canvas.draw_line(Vector2(center.x, 0), Vector2(center.x, canvas.size.y), Color(0.4, 0.4, 0.4, 0.8), 2.0)
		canvas.draw_line(Vector2(0, center.y), Vector2(canvas.size.x, center.y), Color(0.4, 0.4, 0.4, 0.8), 2.0)
		
		var steps_x = int((canvas.size.x / 2.0) / ts) + 1
		var steps_y = int((canvas.size.y / 2.0) / ts) + 1
		
		for i in range(-steps_x, steps_x + 1):
			var px = center.x + (i * ts)
			canvas.draw_line(Vector2(px, 0), Vector2(px, canvas.size.y), grid_color, 1.0)
		for i in range(-steps_y, steps_y + 1):
			var py = center.y + (i * ts)
			canvas.draw_line(Vector2(0, py), Vector2(canvas.size.x, py), grid_color, 1.0)
			
	else:
		# TOP_LEFT Strict Bounds
		var w = grid_bounds.x
		var h = grid_bounds.y
		canvas.draw_rect(Rect2(0, 0, w * ts, h * ts), Color(0.1, 0.1, 0.15))
		for y in range(h + 1): canvas.draw_line(Vector2(0, y * ts), Vector2(w * ts, y * ts), grid_color, 1.0)
		for x in range(w + 1): canvas.draw_line(Vector2(x * ts, 0), Vector2(x * ts, h * ts), grid_color, 1.0)

# ==============================================================================
# DRAWING API (Called by Parent's _on_canvas_draw)
# ==============================================================================
func draw_cell_rect(grid_pos: Vector2i, fill_color: Color, border_color: Color = Color.TRANSPARENT, border_width: float = 2.0) -> void:
	if not is_in_bounds(grid_pos): return
	var rect = get_pixel_rect(grid_pos)
	canvas.draw_rect(rect, fill_color)
	if border_color != Color.TRANSPARENT:
		canvas.draw_rect(rect, border_color, false, border_width)

func draw_atlas_cell(grid_pos: Vector2i, texture: Texture2D, atlas_coord: Vector2i, original_tile_size: Vector2i) -> void:
	if not is_in_bounds(grid_pos) or not texture: return
	var dest_rect = get_pixel_rect(grid_pos)
	var src_rect = Rect2(atlas_coord.x * original_tile_size.x, atlas_coord.y * original_tile_size.y, original_tile_size.x, original_tile_size.y)
	canvas.draw_texture_rect_region(texture, dest_rect, src_rect)

func draw_normalized_sprite(grid_pos: Vector2i, texture: Texture2D, offset: Vector2, scale: Vector2, rot_idx: int, alpha: float) -> void:
	if not texture: return
	var ts = get_actual_tile_size()
	var rect = get_pixel_rect(grid_pos)
	var center = rect.position + (rect.size / 2.0)
	
	var normalized_size = Vector2(ts * scale.x, ts * scale.y)
	
	# Keep visual offset anchored properly across rotations
	var rot_offset = Vector2(rotate_point(Vector2i(round(offset.x * 10), round(offset.y * 10)), rot_idx)) / 10.0
	var draw_pos = center - (normalized_size / 2.0) + (rot_offset * ts)
	
	canvas.draw_texture_rect(texture, Rect2(draw_pos, normalized_size), false, Color(1, 1, 1, alpha))

func draw_facing_arrow(grid_pos: Vector2i, footprint: Array, front_dir: Vector2i, rot_idx: int, color: Color) -> void:
	if footprint.is_empty(): return
	var ts = get_actual_tile_size()
	var origin = get_grid_origin()
	
	var min_c = footprint[0]
	var max_c = footprint[0]
	for c in footprint:
		var rotated_c = rotate_point(c, rot_idx)
		if rotated_c.x < min_c.x: min_c.x = rotated_c.x
		if rotated_c.y < min_c.y: min_c.y = rotated_c.y
		if rotated_c.x > max_c.x: max_c.x = rotated_c.x
		if rotated_c.y > max_c.y: max_c.y = rotated_c.y
		
	var abs_min = grid_pos + min_c
	var abs_max = grid_pos + max_c
	
	var center_x = origin.x + ((abs_min.x + abs_max.x + 1) / 2.0) * ts
	var center_y = origin.y + ((abs_min.y + abs_max.y + 1) / 2.0) * ts
	
	var arrow_start = Vector2.ZERO
	var arrow_end = Vector2.ZERO
	var actual_front = rotate_point(front_dir, rot_idx)
	
	if actual_front == Vector2i.UP:
		arrow_start = Vector2(center_x, origin.y + (abs_min.y * ts))
		arrow_end = arrow_start + Vector2(0, -ts)
	elif actual_front == Vector2i.DOWN:
		arrow_start = Vector2(center_x, origin.y + ((abs_max.y + 1) * ts))
		arrow_end = arrow_start + Vector2(0, ts)
	elif actual_front == Vector2i.LEFT:
		arrow_start = Vector2(origin.x + (abs_min.x * ts), center_y)
		arrow_end = arrow_start + Vector2(-ts, 0)
	elif actual_front == Vector2i.RIGHT:
		arrow_start = Vector2(origin.x + ((abs_max.x + 1) * ts), center_y)
		arrow_end = arrow_start + Vector2(ts, 0)
		
	# Draw arrow shaft
	canvas.draw_line(arrow_start, arrow_end, color, 4.0)
	var dir = (arrow_end - arrow_start).normalized()
	canvas.draw_line(arrow_end, arrow_end + dir.rotated(PI * 0.75) * 15.0, color, 4.0)
	canvas.draw_line(arrow_end, arrow_end + dir.rotated(-PI * 0.75) * 15.0, color, 4.0)


# ==============================================================================
# GRID UTILITIES
# ==============================================================================
func perform_flood_fill(grid: Dictionary, start_pos: Vector2i, erase: bool, new_val: Variant) -> void:
	if not is_in_bounds(start_pos): return
	
	var target_val = grid.get(start_pos, null)
	
	# Prevent infinite loops if trying to fill with the exact same value!
	if typeof(target_val) == typeof(new_val) and target_val == new_val:
		if not erase and target_val != null: return
		if erase and target_val == null: return
		
	var queue = [start_pos]
	var visited = {start_pos: true}
	var iteration_cap = 10000 # Safety net for infinite CENTERED canvases!
	
	while queue.size() > 0 and visited.size() < iteration_cap:
		var cur = queue.pop_back()
		
		if erase: grid.erase(cur)
		else: grid[cur] = new_val
		
		var neighbors = [
			cur + Vector2i(1, 0), cur + Vector2i(-1, 0),
			cur + Vector2i(0, 1), cur + Vector2i(0, -1)
		]
		
		for n in neighbors:
			if not is_in_bounds(n): continue
			
			if not visited.has(n):
				var n_val = grid.get(n, null)
				if typeof(n_val) == typeof(target_val) and n_val == target_val:
					visited[n] = true
					queue.append(n)
					
	canvas.queue_redraw()

func get_flood_fill_area(grid: Dictionary, start_pos: Vector2i) -> Array[Vector2i]:
	if not is_in_bounds(start_pos): return []
	
	var target_val = grid.get(start_pos, null)
	var queue = [start_pos]
	var visited = {start_pos: true}
	var iteration_cap = 10000 
	
	while queue.size() > 0 and visited.size() < iteration_cap:
		var cur = queue.pop_back()
		
		var neighbors = [
			cur + Vector2i(1, 0), cur + Vector2i(-1, 0),
			cur + Vector2i(0, 1), cur + Vector2i(0, -1)
		]
		
		for n in neighbors:
			if not is_in_bounds(n): continue
			
			if not visited.has(n):
				var n_val = grid.get(n, null)
				if typeof(n_val) == typeof(target_val) and n_val == target_val:
					visited[n] = true
					queue.append(n)
					
	var result: Array[Vector2i] = []
	for v in visited.keys(): result.append(v)
	return result

func draw_highlights() -> void:
	if highlighted_cells.is_empty(): return
	for cell in highlighted_cells:
		draw_cell_rect(cell, highlight_color)
