extends Node2D
class_name GraphRenderer

# ==============================================================================
# 1. CONFIGURATION & STATE
# ==============================================================================

# --- VISUAL SETTINGS ---
@export_group("Dimensions")
@export var node_radius: float = GraphSettings.NODE_RADIUS
@export var edge_width: float = GraphSettings.EDGE_WIDTH

@export_group("Colors")
@export var default_color: Color = GraphSettings.COLOR_DEFAULT
@export var selected_color: Color = GraphSettings.COLOR_SELECTED
@export var path_color: Color = GraphSettings.COLOR_PATH
@export var hover_color: Color = GraphSettings.COLOR_HOVER
@export var dragged_color: Color = GraphSettings.COLOR_DRAGGED

@export_group("Debug")
@export var debug_show_depth: bool = false

# --- SHARED RESOURCES ---
var font: Font

# --- DATA REFERENCES (Injected by Editor) ---
var graph_ref: Graph
var selected_nodes_ref: Array[String] = []
var selected_edges_ref: Array = []
var selected_agent_ids_ref: Array = [] 
var selected_zones_ref: Array = []

# --- DYNAMIC DATA (Updated by Tools) ---
var current_path_ref: Array[String] = []
var new_nodes_ref: Array[String] = [] 
var node_labels_ref: Dictionary = {}
var pre_selection_ref: Array[String] = []
var pre_selected_agents_ref: Array = []

# --- INTERACTION STATE ---
var path_start_ids: Array = [] 
var path_end_ids: Array = []
var drag_start_id: String = ""
var hovered_id: String = ""
var snap_preview_pos: Vector2 = Vector2.INF
var selection_rect: Rect2 = Rect2()

var brush_preview_cells: Array[Vector2i] = []
var brush_preview_color: Color = Color.WHITE
var pending_stroke_cells: Array[Vector2i] = [] 
var pending_stroke_color: Color = Color.WHITE
var pending_stroke_is_erase: bool = false

# --- INTERNAL CACHE ---
var _depth_cache: Dictionary = {}
var _depth_cache_dirty: bool = true

# --- OVERLAY STATE ---
var tool_line_start: Vector2 = Vector2.INF
var tool_line_end: Vector2 = Vector2.INF

# ==============================================================================
# 2. LIFECYCLE & MAIN LOOP
# ==============================================================================

func _ready() -> void:
	font = ThemeDB.get_fallback_font()

func _draw() -> void:
	if not graph_ref: return
	
	# Render Order (Painter's Algorithm: Back to Front)
	_draw_layer_zones()
	_draw_layer_edges()
	_draw_layer_path()
	_draw_layer_brush()
	_draw_layer_nodes()
	_draw_layer_agents()
	_draw_layer_simulation()
	_draw_layer_labels()
	_draw_layer_interaction()
	_draw_layer_selection_box()
	
	if debug_show_depth:
		_draw_layer_debug_depth()

# ==============================================================================
# 3. DOMAIN: ZONES
# ==============================================================================

func _draw_layer_zones() -> void:
	if graph_ref.zones.is_empty(): return
		
	var spacing = GraphSettings.GRID_SPACING
	var half_size = spacing / 2.0
	var has_selection = not selected_zones_ref.is_empty()
	
	for zone in graph_ref.zones:
		var is_selected = selected_zones_ref.has(zone)
		var draw_color = zone.zone_color
		var border_color = zone.zone_color.lightened(0.2)
		var border_width = 1.0
		
		# Focus/Ghost Logic
		if has_selection:
			if is_selected:
				border_width = 3.0
				border_color = Color.WHITE
			else:
				draw_color.a *= 0.15 
				border_color.a *= 0.15
		
		# Render based on Type
		if zone.zone_type == GraphZone.ZoneType.GEOGRAPHICAL:
			for cell in zone.cells:
				var world_pos = Vector2(cell.x * spacing.x, cell.y * spacing.y)
				var rect = Rect2(world_pos - half_size, spacing)
				
				draw_rect(rect, draw_color, true)
				if not has_selection or is_selected:
					draw_rect(rect, border_color, false, border_width)

		elif zone.zone_type == GraphZone.ZoneType.LOGICAL:
			_draw_zone_logical_bounds(zone, draw_color, border_color, border_width, is_selected)

func _draw_zone_logical_bounds(zone: GraphZone, color: Color, border_color: Color, width: float, is_focused: bool) -> void:
	if zone.registered_nodes.is_empty(): return
	
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	var has_valid_node = false
	
	for id in zone.registered_nodes:
		if graph_ref.nodes.has(id):
			var pos = graph_ref.nodes[id].position
			min_pos.x = min(min_pos.x, pos.x)
			min_pos.y = min(min_pos.y, pos.y)
			max_pos.x = max(max_pos.x, pos.x)
			max_pos.y = max(max_pos.y, pos.y)
			has_valid_node = true
			
	if not has_valid_node: return
	
	var padding = GraphSettings.GRID_SPACING * 0.8
	var rect = Rect2(min_pos - padding, (max_pos - min_pos) + (padding * 2))
	
	color.a *= 0.5 
	draw_rect(rect, color, true)
	draw_rect(rect, border_color, false, width)
	
	if zone.is_grouped and is_focused:
		draw_circle(rect.get_center(), 4.0, Color.WHITE)

# ==============================================================================
# 4. DOMAIN: EDGES
# ==============================================================================

func _draw_layer_edges() -> void:
	var drawn_bidirectional := {} 
	
	for id: String in graph_ref.nodes:
		var start_pos = graph_ref.get_node_pos(id)
		
		for neighbor: String in graph_ref.get_neighbors(id):
			var end_pos = graph_ref.get_node_pos(neighbor)
			var pair = [id, neighbor]
			pair.sort()
			
			# Highlight Selection
			if selected_edges_ref.has(pair):
				draw_line(start_pos, end_pos, selected_color, edge_width + 4.0)
			
			# Check Bidirectionality
			var is_bidirectional = graph_ref.has_edge(neighbor, id)
			
			if is_bidirectional:
				if drawn_bidirectional.has(pair): continue
				drawn_bidirectional[pair] = true
				draw_line(start_pos, end_pos, GraphSettings.COLOR_EDGE, edge_width)
			else:
				draw_line(start_pos, end_pos, GraphSettings.COLOR_EDGE, edge_width)
				_draw_edge_arrow(start_pos, end_pos)

func _draw_edge_arrow(from: Vector2, to: Vector2) -> void:
	var dir = (to - from).normalized()
	var tip_offset = node_radius + 6.0
	var tip = to - (dir * tip_offset)
	var arrow_size = 12.0
	var angle = PI / 5.0
	
	var p1 = tip - dir.rotated(angle) * arrow_size
	var p2 = tip - dir.rotated(-angle) * arrow_size
	
	var color = GraphSettings.COLOR_EDGE
	var width = edge_width + 1.0
	
	draw_line(tip, p1, color, width)
	draw_line(tip, p2, color, width)

# ==============================================================================
# 5. DOMAIN: PATHFINDING
# ==============================================================================

func _draw_layer_path() -> void:
	if current_path_ref.size() > 1:
		var points = PackedVector2Array()
		for id in current_path_ref:
			points.append(graph_ref.get_node_pos(id))
		draw_polyline(points, path_color, edge_width + 2.0)

# ==============================================================================
# 6. DOMAIN: BRUSH / STROKE
# ==============================================================================

func _draw_layer_brush() -> void:
	_draw_brush_stroke_preview()
	_draw_brush_cursor_preview()

func _draw_brush_stroke_preview() -> void:
	if pending_stroke_cells.is_empty(): return
	
	var spacing = GraphSettings.GRID_SPACING
	var half_size = spacing / 2.0
	var draw_color = pending_stroke_color
	
	if pending_stroke_is_erase:
		draw_color = Color(1.0, 0.0, 0.0, 0.4) 
	else:
		draw_color.a = 0.6 
	
	for cell in pending_stroke_cells:
		var world_pos = Vector2(cell.x * spacing.x, cell.y * spacing.y)
		var rect = Rect2(world_pos - half_size, spacing)
		
		draw_rect(rect, draw_color, true)
		
		if pending_stroke_is_erase:
			draw_line(rect.position, rect.end, Color.RED, 2.0)
			draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), Color.RED, 2.0)

func _draw_brush_cursor_preview() -> void:
	if brush_preview_cells.is_empty(): return
	
	var spacing = GraphSettings.GRID_SPACING
	var half_size = spacing / 2.0
	
	for cell in brush_preview_cells:
		var world_pos = Vector2(cell.x * spacing.x, cell.y * spacing.y)
		var rect = Rect2(world_pos - half_size, spacing)
		
		draw_rect(rect, brush_preview_color, true)
		draw_rect(rect, Color.WHITE, false, 2.0)

# ==============================================================================
# 7. DOMAIN: NODES
# ==============================================================================

func _draw_layer_nodes() -> void:
	for id: String in graph_ref.nodes:
		var node_data = graph_ref.nodes[id] as NodeData
		var pos = node_data.position
		
		# Color & Body
		var col = GraphSettings.get_color(node_data.type)
		if new_nodes_ref.has(id):
			col = GraphSettings.COLOR_NEW_GENERATION
			
		draw_circle(pos, node_radius, col)
		draw_circle(pos, node_radius * 0.7, Color(0, 0, 0, 0.1))
		
		# Indicators
		_draw_node_indicators(id, pos)

func _draw_node_indicators(id: String, pos: Vector2) -> void:
	# Selection Rings
	if selected_nodes_ref.has(id) or pre_selection_ref.has(id):
		draw_arc(pos, node_radius + 4.0, 0, TAU, 32, selected_color, 3.0)
	elif id == hovered_id:
		draw_arc(pos, node_radius + 4.0, 0, TAU, 32, hover_color, 2.0)
	
	# Path Start (Green)
	var start_indices = []
	for i in range(path_start_ids.size()):
		if path_start_ids[i] == id: start_indices.append(str(i + 1))
			
	if not start_indices.is_empty():
		draw_circle(pos, node_radius * 0.5, GraphSettings.COLOR_PATH_START) 
		draw_arc(pos, node_radius + 9.0, 0, TAU, 32, GraphSettings.COLOR_PATH_START, 3.0) 
		
		var label = ",".join(start_indices)
		var text_pos = pos + Vector2(-node_radius - 24, -node_radius + 8)
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_RIGHT, -1, 16, GraphSettings.COLOR_PATH_START)

	# Path End (Red)
	var end_indices = []
	for i in range(path_end_ids.size()):
		if path_end_ids[i] == id: end_indices.append(str(i + 1))
			
	if not end_indices.is_empty():
		draw_circle(pos, node_radius * 0.5, GraphSettings.COLOR_PATH_END)
		draw_arc(pos, node_radius + 6.0, 0, TAU, 32, GraphSettings.COLOR_PATH_END, 3.0)
		
		var label = ",".join(end_indices)
		var text_pos = pos + Vector2(node_radius + 4, -node_radius + 8)
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GraphSettings.COLOR_PATH_END)

# ==============================================================================
# 8. DOMAIN: AGENTS
# ==============================================================================

func _draw_layer_agents() -> void:
	if not graph_ref or graph_ref.agents.is_empty(): return
	
	var agents_by_node = _group_agents_by_node()
	
	for node_id in agents_by_node:
		if not graph_ref.nodes.has(node_id): continue
		
		var node_agents = agents_by_node[node_id]
		var count = node_agents.size()
		var node_pos = graph_ref.get_node_pos(node_id)
		
		if count > GraphSettings.AGENT_STACK_THRESHOLD:
			_draw_agent_stack_icon(node_pos, count)
		else:
			for agent in node_agents:
				var draw_pos = _calculate_agent_offset(agent, node_agents)
				var is_selected = selected_agent_ids_ref.has(agent)
				
				_draw_agent_token(draw_pos, is_selected, agent)
				
				if is_selected:
					_draw_agent_brain_visuals(agent)

func _draw_agent_token(center: Vector2, is_selected: bool, agent_ref: Object) -> void:
	var radius = GraphSettings.AGENT_RADIUS
	var points = PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(radius, 0),
		center + Vector2(0, radius), center + Vector2(-radius, 0)
	])
	
	var fill_col = GraphSettings.COLOR_AGENT_SELECTED if is_selected else GraphSettings.COLOR_AGENT_NORMAL
	draw_colored_polygon(points, fill_col)
	
	var line_col = Color.BLACK
	var width = 1.0
	var selection_gold = Color(1, 0.8, 0.2) 
	
	if is_selected:
		line_col = selection_gold
		width = 3.0
	elif pre_selected_agents_ref.has(agent_ref):
		line_col = selection_gold
		line_col.a = 0.7 
		width = 3.0
		
	points.append(points[0]) 
	draw_polyline(points, line_col, width)

func _draw_agent_stack_icon(center: Vector2, count: int) -> void:
	var radius = GraphSettings.AGENT_RADIUS * 1.5
	var points = PackedVector2Array([
		center + Vector2(0, -radius), center + Vector2(radius, 0),
		center + Vector2(0, radius), center + Vector2(-radius, 0)
	])
	draw_colored_polygon(points, GraphSettings.COLOR_AGENT_STACK)
	var text_pos = center + Vector2(-4, 4) 
	draw_string(font, text_pos, str(count), HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.BLACK)

func _draw_agent_brain_visuals(agent) -> void:
	# 1. Random Walk / Paint Intent
	if agent.behavior_mode == 1 or (agent.behavior_mode == 3 and agent.movement_algo == 0):
		var neighbors = graph_ref.get_neighbors(agent.current_node_id)
		for n_id in neighbors:
			var n_pos = graph_ref.get_node_pos(n_id)
			var dir = (n_pos - agent.pos).normalized()
			var arrow_start = agent.pos + (dir * 10.0)
			var arrow_end = agent.pos + (dir * 25.0)
			_draw_visual_arrow(arrow_start, arrow_end, Color(1, 1, 0, 0.6))
			
	# 2. Targeted Seek Intent
	elif agent.behavior_mode == 3 and agent.target_node_id != "":
		if graph_ref.nodes.has(agent.target_node_id):
			var target_pos = graph_ref.get_node_pos(agent.target_node_id)
			draw_dashed_line(agent.pos, target_pos, Color(1, 1, 1, 0.5), 2.0, 10.0)
			draw_circle(target_pos, 4.0, Color(1, 0, 0, 0.5))
			draw_arc(target_pos, 8.0, 0, TAU, 16, Color(1, 0, 0, 0.5), 1.0)

# ==============================================================================
# 9. DOMAIN: SIMULATION FEEDBACK
# ==============================================================================

func _draw_layer_simulation() -> void:
	if not graph_ref: return
	for agent in graph_ref.agents:
		if agent.last_bump_pos != Vector2.INF:
			_draw_agent_bump_line(agent)

func _draw_agent_bump_line(agent) -> void:
	var start = Vector2(agent.pos)
	
	# Resolve stack offset
	if graph_ref:
		var neighbors = graph_ref.get_agents_at_node(agent.current_node_id)
		start = _calculate_agent_offset(agent, neighbors)

	var end = agent.last_bump_pos
	var direction = (end - start).normalized()
	var distance = start.distance_to(end)
	var stub_length = min(distance * 0.4, 30.0) 
	var stub_end = start + (direction * stub_length)
	
	draw_line(start, stub_end, Color(1.0, 0.2, 0.2, 0.8), 3.0)
	var perp = Vector2(-direction.y, direction.x) * 5.0
	draw_line(stub_end - perp, stub_end + perp, Color(1.0, 0.2, 0.2, 0.8), 3.0)

# ==============================================================================
# 10. DOMAIN: LABELS & OVERLAYS
# ==============================================================================

func _draw_layer_labels() -> void:
	if node_labels_ref.is_empty(): return
	
	for id in node_labels_ref:
		if not graph_ref.nodes.has(id): continue
		var pos = graph_ref.get_node_pos(id)
		var text = node_labels_ref[id]
		var text_pos = pos + Vector2(node_radius + 4, -node_radius - 8)
		
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.9))

func _draw_layer_interaction() -> void:
	if snap_preview_pos != Vector2.INF:
		draw_circle(snap_preview_pos, node_radius, Color(1, 1, 1, 0.3))
		draw_line(snap_preview_pos - Vector2(5,0), snap_preview_pos + Vector2(5,0), Color(1,1,1,0.5), 1.0)
		draw_line(snap_preview_pos - Vector2(0,5), snap_preview_pos + Vector2(0,5), Color(1,1,1,0.5), 1.0)
	
	if not drag_start_id.is_empty():
		var start_pos = graph_ref.get_node_pos(drag_start_id)
		var mouse_pos = get_local_mouse_position()
		draw_line(start_pos, mouse_pos, dragged_color, 2.0)
	
	if tool_line_start != Vector2.INF and tool_line_end != Vector2.INF:
		draw_line(tool_line_start, tool_line_end, Color.ORANGE_RED, 2.0)

func _draw_layer_selection_box() -> void:
	if selection_rect.has_area():
		draw_rect(selection_rect, GraphSettings.COLOR_SELECT_BOX_Fill, true)
		draw_rect(selection_rect, GraphSettings.COLOR_SELECT_BOX_BORDER, false, 1.0)

# ==============================================================================
# 11. DOMAIN: DEBUG (DEPTH)
# ==============================================================================

func _draw_layer_debug_depth() -> void:
	if _depth_cache_dirty: _recalculate_depth_cache()
	
	var font_size = 14
	var start_hue = 0.33 
	var hue_step = 0.05 
	
	for id in _depth_cache:
		if not graph_ref.nodes.has(id): continue
		var pos = graph_ref.get_node_pos(id)
		var depth_val = _depth_cache[id]
		var text = str(depth_val)
		
		var current_hue = fmod(start_hue + (depth_val * hue_step), 1.0)
		var depth_color = Color.from_hsv(current_hue, 0.55, 1.0)
		
		var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = pos + Vector2(-text_size.x / 2.0, text_size.y / 4.0)
		
		draw_string_outline(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 4, Color.BLACK)
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, depth_color)

func _recalculate_depth_cache() -> void:
	_depth_cache.clear()
	if graph_ref.nodes.is_empty(): return
		
	var seeds: Array[String] = []
	
	# 1. Selected Spawns
	for id in selected_nodes_ref:
		if graph_ref.nodes.has(id):
			if graph_ref.nodes[id].type == NodeData.RoomType.SPAWN: seeds.append(id)
	
	# 2. All Spawns
	if seeds.is_empty():
		for id in graph_ref.nodes:
			if graph_ref.nodes[id].type == NodeData.RoomType.SPAWN: seeds.append(id)
				
	# 3. Center Fallback
	if seeds.is_empty():
		var closest = ""
		var min_dist = INF
		for id in graph_ref.nodes:
			var d = graph_ref.get_node_pos(id).length_squared()
			if d < min_dist:
				min_dist = d
				closest = id
		if closest != "": seeds.append(closest)

	var queue: Array = []
	for seed_id in seeds:
		_depth_cache[seed_id] = 0
		queue.append(seed_id)
		
	while not queue.is_empty():
		var current = queue.pop_front()
		var current_depth = _depth_cache[current]
		
		for neighbor in graph_ref.get_neighbors(current):
			if not _depth_cache.has(neighbor):
				_depth_cache[neighbor] = current_depth + 1
				queue.append(neighbor)
	
	_depth_cache_dirty = false

# ==============================================================================
# 12. UTILITIES & HIT TESTING
# ==============================================================================

func _group_agents_by_node() -> Dictionary:
	var dict = {}
	for agent in graph_ref.agents: 
		var node_id = agent.current_node_id
		if not dict.has(node_id): dict[node_id] = []
		dict[node_id].append(agent)
	return dict

func _calculate_agent_offset(agent, all_at_node: Array) -> Vector2:
	if agent.current_node_id == "" or not graph_ref.nodes.has(agent.current_node_id):
		return agent.pos
		
	var node_pos = graph_ref.get_node_pos(agent.current_node_id)
	var count = all_at_node.size()
	
	if count > GraphSettings.AGENT_STACK_THRESHOLD:
		return node_pos 
		
	if count == 1:
		return node_pos + Vector2(10, -10)
		
	var index = all_at_node.find(agent)
	var angle = (TAU / count) * index
	var orbit_radius = GraphSettings.AGENT_RING_OFFSET
	return node_pos + (Vector2(cos(angle), sin(angle)) * orbit_radius)

func _draw_visual_arrow(from: Vector2, to: Vector2, color: Color) -> void:
	draw_line(from, to, color, 2.0)
	var dir = (to - from).normalized()
	var size = 6.0
	var angle = PI / 5.0
	draw_line(to, to - dir.rotated(angle) * size, color, 2.0)
	draw_line(to, to - dir.rotated(-angle) * size, color, 2.0)

# --- HIT TESTING ---

func get_agent_at_position(local_pos: Vector2) -> Object:
	if not graph_ref or graph_ref.agents.is_empty(): return null
		
	var agents_by_node = _group_agents_by_node()
	var best_agent = null
	var best_dist = INF
	var hit_radius = 10.0
	
	for node_id in agents_by_node:
		if not graph_ref.nodes.has(node_id): continue
		var node_pos = graph_ref.get_node_pos(node_id)
		if local_pos.distance_squared_to(node_pos) > 3600: continue
			
		var node_agents = agents_by_node[node_id]
		var count = node_agents.size()
		
		if count > GraphSettings.AGENT_STACK_THRESHOLD:
			if local_pos.distance_to(node_pos) < 20.0:
				return node_agents.back()
		else:
			for agent in node_agents:
				var visual_pos = _calculate_agent_offset(agent, node_agents)
				var dist = local_pos.distance_to(visual_pos)
				if dist < hit_radius and dist < best_dist:
					best_dist = dist
					best_agent = agent
					
	return best_agent

func get_agents_in_visual_rect(local_rect: Rect2) -> Array:
	if not graph_ref: return []
	var result = []
	var agents_by_node = _group_agents_by_node()
	
	for node_id in agents_by_node:
		if not graph_ref.nodes.has(node_id): continue
		var node_pos = graph_ref.get_node_pos(node_id)
		if not local_rect.grow(50).has_point(node_pos): continue
			
		var node_agents = agents_by_node[node_id]
		var count = node_agents.size()
		
		for i in range(count):
			var agent = node_agents[i]
			var visual_pos = node_pos
			
			if count > 1 and count <= GraphSettings.AGENT_STACK_THRESHOLD:
				var angle = (TAU / count) * i
				var offset = Vector2(cos(angle), sin(angle)) * GraphSettings.AGENT_RING_OFFSET
				visual_pos += offset
			
			if local_rect.has_point(visual_pos):
				result.append(agent)
				
	return result
