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
var hovered_edge_ref: Array = []
var hovered_agent_ref: Object = null
var hovered_zone_ref: Object = null
var snap_preview_pos: Vector2 = Vector2.INF
var selection_rect: Rect2 = Rect2()
var cut_preview_edges: Array = []
var highlighted_action_edges_ref: Array = []
var agent_breadcrumbs_ref: Array = []


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

func _process(_delta: float) -> void:
	# Only force continuous screen redraws if we actually have flowing edges to animate!
	if highlighted_action_edges_ref.size() > 0:
		queue_redraw()

func _draw() -> void:
	if not graph_ref: return
	
	# Render Order (Painter's Algorithm: Back to Front)
	_draw_layer_zones()
	_draw_layer_edges()
	_draw_breadcrumbs()
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
		elif zone == hovered_zone_ref: # Hover Feedback
			border_width = 2.0
			border_color = hover_color
		
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
	if graph_ref.edge_store.is_empty(): return
	
	var drawn_pairs = {}
	var edge_decorators = [] # Cache semantic text to draw AFTER lines so it stays on top
	
	for key in graph_ref.edge_store:
		var e = graph_ref.edge_store[key]
		
		# Validate nodes exist
		if not graph_ref.nodes.has(e.u) or not graph_ref.nodes.has(e.v):
			continue
			
		var pos_a = graph_ref.nodes[e.u].position
		var pos_b = graph_ref.nodes[e.v].position
		
		# Use the alphabetical pair to deduplicate and check selection
		var pair = [e.u, e.v]
		pair.sort()
		
		# --- Direction & Deduplication ---
		var key_rev = graph_ref.get_edge_key(e.v, e.u)
		var is_bidir = graph_ref.edge_store.has(key_rev)
		
		if is_bidir and drawn_pairs.has(pair):
			continue # We already drew the base line for this pair
			
		drawn_pairs[pair] = true
		
		# --- Determine Styling ---
		var draw_color = GraphSettings.COLOR_EDGE
		var current_width = edge_width
		
		if selected_edges_ref.has(pair):
			draw_color = selected_color
			current_width += 4.0
		elif hovered_edge_ref == pair:
			draw_color = hover_color
			current_width += 2.0
		elif cut_preview_edges.has(pair):
			draw_color = Color(1.0, 0.2, 0.2, 0.8)
			current_width += 2.0
			
		# --- 1. Handle Self-Loop (A -> A) ---
		var midpoint = Vector2.ZERO
		
		if e.u == e.v:
			var loop_radius = node_radius * 1.5
			var loop_center = pos_a + Vector2(node_radius, -node_radius)
			draw_arc(loop_center, loop_radius, -PI*0.8, PI*1.3, 32, draw_color, current_width)
			
			var arrow_pos = loop_center + Vector2(-loop_radius, 0)
			var fake_from = arrow_pos + Vector2(0, -10)
			_draw_edge_arrow(fake_from, arrow_pos, draw_color, current_width)
			
			midpoint = loop_center + Vector2(0, -loop_radius)
			
		# --- 2. Handle Normal Edge (A -> B) ---
		else:
			# Check if this line should be an animated Action Edge!
			var is_action_edge = false
			var flow_start = pos_a
			var flow_end = pos_b
			
			for act_pair in highlighted_action_edges_ref:
				# Since we deduplicate, check if the action edge matches this line in EITHER direction
				if (act_pair[0] == e.u and act_pair[1] == e.v):
					is_action_edge = true
					break
				elif (act_pair[0] == e.v and act_pair[1] == e.u):
					is_action_edge = true
					# Reverse the flow points so the animation marches the right way!
					flow_start = pos_b
					flow_end = pos_a
					break
			
			if is_action_edge:
				# Draw the animated green flowing line!
				var action_color = Color(0.2, 0.8, 0.2, 0.9)
				_draw_flowing_dashed_line(flow_start, flow_end, action_color, current_width + 1.0)
				if not is_bidir:
					_draw_edge_arrow(pos_a, pos_b, action_color, current_width + 1.0)
			else:
				# Draw standard solid line
				draw_line(pos_a, pos_b, draw_color, current_width)
				if not is_bidir:
					_draw_edge_arrow(pos_a, pos_b, draw_color, current_width)
					
			midpoint = (pos_a + pos_b) / 2.0
				
		# --- 3. Gather Semantic Decorators ---
		if not e.custom.is_empty():
			var props = SemanticRegistry.get_properties_for_target(SemanticRegistry.TARGET_EDGE)
			for prop_key in e.custom:
				if not props.has(prop_key): continue
				var mode = props[prop_key].get("display", 0)
				if mode != SemanticRegistry.DisplayMode.HIDDEN:
					edge_decorators.append({
						"pos": midpoint,
						"text": str(e.custom[prop_key]),
						"mode": mode
					})
					# Offset the midpoint slightly so multiple badges on one edge stack nicely
					midpoint += Vector2(0, -18) 

	# --- 4. Draw Gathered Decorators (On top of lines) ---
	for dec in edge_decorators:
		_draw_semantic_decorator(dec.pos, dec.text, dec.mode)


# Helper to draw the arrowhead at the end of the line
func _draw_edge_arrow(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var dir = (to - from).normalized()
	# Pull back from the exact center of the target node so the arrow doesn't disappear under it
	var tip_offset = node_radius + 6.0
	var tip = to - (dir * tip_offset)
	
	var arrow_size = 12.0
	var angle = PI / 5.0
	
	var p1 = tip - dir.rotated(angle) * arrow_size
	var p2 = tip - dir.rotated(-angle) * arrow_size
	
	draw_line(tip, p1, color, width)
	draw_line(tip, p2, color, width)

func _draw_flowing_dashed_line(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var vec = to - from
	var length = vec.length()
	var dir = vec.normalized()
	
	# Visual Tuning
	var dash_len = 10.0
	var gap_len = 8.0
	var pattern_len = dash_len + gap_len
	var speed = 40.0 # Pixels per second
	
	# Use Godot's internal clock to calculate the flowing offset
	var time_sec = Time.get_ticks_msec() / 1000.0
	var offset = fmod(time_sec * speed, pattern_len)
	
	var current_dist = offset - pattern_len
	while current_dist < length:
		var start_d = max(current_dist, 0.0)
		var end_d = min(current_dist + dash_len, length)
		
		if start_d < end_d:
			var p1 = from + dir * start_d
			var p2 = from + dir * end_d
			draw_line(p1, p2, color, width, true)
			
		current_dist += pattern_len

func _draw_breadcrumbs() -> void:
	for path in agent_breadcrumbs_ref:
		if path.size() < 2: continue
		
		# Vibrant, high-contrast Golden Orange with full opacity
		var trail_color = Color(1.0, 0.65, 0.1, 1.0) 
		
		# Draw the path line (crisp and solid)
		draw_polyline(path, trail_color, 4.0, true)
		
		# Draw distinct waypoint dots with a dark inner core (looks like a tracker!)
		for i in range(path.size() - 1):
			draw_circle(path[i], 6.0, trail_color)
			draw_circle(path[i], 3.0, Color(0.15, 0.15, 0.15, 1.0))

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
		var col = SemanticRegistry.get_category_color(SemanticRegistry.TARGET_NODE, node_data.type)
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

	# --- Semantic Decorators ---
	var node_data = graph_ref.nodes[id] as NodeData
	if not node_data.custom_data.is_empty():
		var props = SemanticRegistry.get_properties_for_target(SemanticRegistry.TARGET_NODE)
		var dec_offset = pos + Vector2(0, -node_radius - 12) # Start drawing above the node
		
		for prop_key in node_data.custom_data:
			if not props.has(prop_key): continue
			var mode = props[prop_key].get("display", 0)
			if mode != SemanticRegistry.DisplayMode.HIDDEN:
				var text = str(node_data.custom_data[prop_key])
				_draw_semantic_decorator(dec_offset, text, mode)
				dec_offset += Vector2(0, -18) # Stack upwards

func _draw_semantic_decorator(pos: Vector2, text: String, mode: int) -> void:
	if text == "": return
	
	# --- 1. PARSE TAGS: e.g., "[key:#FF0000] Alpha" ---
	var icon_name = ""
	var icon_color = Color.WHITE
	var display_text = text
	
	if text.begins_with("[") and text.find("]") > 0:
		var end_idx = text.find("]")
		var tag = text.substr(1, end_idx - 1)
		display_text = text.substr(end_idx + 1).strip_edges()
		
		var parts = tag.split(":")
		if parts.size() > 0: icon_name = parts[0].strip_edges()
		if parts.size() > 1 and parts[1].is_valid_html_color(): 
			icon_color = Color(parts[1].strip_edges())
	
	# --- 2. CALCULATE LAYOUT ---
	var font_size = 12
	var text_size = font.get_string_size(display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var icon_size = 14.0 if icon_name != "" else 0.0
	var spacing = 4.0 if icon_name != "" else 0.0
	var total_width = text_size.x + icon_size + spacing
	
	# --- 3. DRAW ---
	if mode == SemanticRegistry.DisplayMode.LABEL:
		var start_x = pos.x - (total_width / 2.0)
		if icon_name != "":
			GraphIconLibrary.draw_icon(self, icon_name, Vector2(start_x + icon_size/2.0, pos.y - 2), icon_size, icon_color)
			start_x += icon_size + spacing
		
		var text_pos = Vector2(start_x, pos.y + text_size.y/3.0)
		draw_string(font, text_pos + Vector2(1, 1), display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.5))
		draw_string(font, text_pos, display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
		
	elif mode == SemanticRegistry.DisplayMode.BADGE:
		var padding = Vector2(8, 4)
		var bg_rect = Rect2(pos - Vector2(total_width/2.0, text_size.y/2.0) - padding, Vector2(total_width, text_size.y) + (padding * 2.0))
		
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.15, 0.9)
		style.border_color = icon_color if icon_name != "" else Color(0.6, 0.6, 0.6, 0.8)
		style.set_border_width_all(1) # [FIXED] Uses the Godot 4 setter method!
		style.set_corner_radius_all(int(bg_rect.size.y / 2.0))
		style.anti_aliasing = true
		style.draw(get_canvas_item(), bg_rect)
		
		var start_x = pos.x - (total_width / 2.0)
		if icon_name != "":
			GraphIconLibrary.draw_icon(self, icon_name, Vector2(start_x + icon_size/2.0, pos.y), icon_size, icon_color)
			start_x += icon_size + spacing
			
		var text_pos = Vector2(start_x, pos.y + text_size.y/3.0)
		draw_string(font, text_pos, display_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

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
				
				# Draw Semantic Decorators (like the Inventory!) over the Agent
				_draw_agent_decorators(draw_pos, agent)
				
				if is_selected:
					_draw_agent_brain_visuals(agent)

# Helper function to draw agent semantic data
func _draw_agent_decorators(pos: Vector2, agent: Object) -> void:
	if not "custom_data" in agent or agent.custom_data.is_empty(): return
	
	var props = SemanticRegistry.get_properties_for_target(SemanticRegistry.TARGET_AGENT)
	var dec_offset = pos + Vector2(0, -GraphSettings.AGENT_RADIUS - 12)
	
	for prop_key in agent.custom_data:
		if not props.has(prop_key): continue
		var mode = props[prop_key].get("display", 0)
		if mode != SemanticRegistry.DisplayMode.HIDDEN:
			var text = str(agent.custom_data[prop_key])
			_draw_semantic_decorator(dec_offset, text, mode)
			dec_offset += Vector2(0, -18)

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
	elif agent_ref == hovered_agent_ref: # Hover Feedback
		line_col = hover_color
		width = 2.5
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
	
	# 1. Selected Spawns [UPDATED TO STRING]
	for id in selected_nodes_ref:
		if graph_ref.nodes.has(id):
			if graph_ref.nodes[id].type == "spawn": seeds.append(id)
	
	# 2. All Spawns [UPDATED TO STRING]
	if seeds.is_empty():
		for id in graph_ref.nodes:
			if graph_ref.nodes[id].type == "spawn": seeds.append(id)
				
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
