extends Node2D
class_name GraphRenderer

# ==============================================================================
# 1. VISUAL CONFIGURATION
# ==============================================================================
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

# Depth Calculation State
var _depth_cache: Dictionary = {}
var _depth_cache_dirty: bool = true

# Tool Overlay Data
var tool_line_start: Vector2 = Vector2.INF
var tool_line_end: Vector2 = Vector2.INF

# NEW: Font reference for drawing walker numbers
var font: Font

# ==============================================================================
# 2. DATA REFERENCES
# ==============================================================================
var graph_ref: Graph
var selected_nodes_ref: Array[String] = []
var current_path_ref: Array[String] = []
var new_nodes_ref: Array[String] = [] 
var pre_selection_ref: Array[String] = []

# ==============================================================================
# 3. INTERACTION STATE
# ==============================================================================
var path_start_ids: Array = [] 
var path_end_ids: Array = []
var drag_start_id: String = ""
var hovered_id: String = ""
var snap_preview_pos: Vector2 = Vector2.INF
var selection_rect: Rect2 = Rect2()

# ==============================================================================
# 4. DRAWING LOOP
# ==============================================================================

func _ready() -> void:
	# Get default font for drawing numbers
	font = ThemeDB.get_fallback_font()

func _draw() -> void:
	if not graph_ref:
		return

	# Layer 1: Connections
	_draw_edges()
	
	# Layer 2: A* Path
	_draw_current_path()
	
	# Layer 3: Nodes
	_draw_nodes()
	
	# Layer 4: Interactive Elements
	_draw_interaction_overlays()

	# Layer 5: Selection Box
	_draw_selection_box()
	
	# Layer 6: Dynamic Depth Overlay (NEW)
	# Drawn last so numbers appear on top of nodes
	if debug_show_depth:
		_draw_depth_numbers()

# --- HELPER: EDGES ---
func _draw_edges() -> void:
	var drawn_edges := {} 
	
	for id: String in graph_ref.nodes:
		var start_pos = graph_ref.get_node_pos(id)
		
		for neighbor: String in graph_ref.get_neighbors(id):
			var pair = [id, neighbor]
			pair.sort() 
			
			if drawn_edges.has(pair):
				continue
				
			drawn_edges[pair] = true
			
			var end_pos = graph_ref.get_node_pos(neighbor)
			var color = GraphSettings.COLOR_EDGE
			var width = edge_width
			
			draw_line(start_pos, end_pos, color, width)

# --- HELPER: PATHFINDING LINE ---
func _draw_current_path() -> void:
	if current_path_ref.size() > 1:
		var points = PackedVector2Array()
		for id in current_path_ref:
			points.append(graph_ref.get_node_pos(id))
		draw_polyline(points, path_color, edge_width + 2.0)

# --- HELPER: NODES ---
func _draw_nodes() -> void:
	for id: String in graph_ref.nodes:
		var node_data = graph_ref.nodes[id] as NodeData
		var pos = node_data.position
		
		# 1. Determine Color Priority
		var col = _get_node_color(id, node_data)
		
		# 2. Draw Body
		draw_circle(pos, node_radius, col)
		draw_circle(pos, node_radius * 0.7, Color(0, 0, 0, 0.1))
		
		# 3. Draw Indicators
		_draw_node_indicators(id, pos)

# --- HELPER: INTERACTIVE OVERLAYS ---
func _draw_interaction_overlays() -> void:
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

func _draw_selection_box():
	if selection_rect.has_area():
		draw_rect(selection_rect, GraphSettings.COLOR_SELECT_BOX_Fill, true)
		draw_rect(selection_rect, GraphSettings.COLOR_SELECT_BOX_BORDER, false, 1.0)

# ==============================================================================
# 5. DYNAMIC DEPTH LOGIC (The New Brain)
# ==============================================================================

func _draw_depth_numbers() -> void:
	if _depth_cache_dirty:
		_recalculate_depth_cache()
	
	var default_font = ThemeDB.fallback_font
	var font_size = 14
	
	var start_hue = 0.33 
	var hue_step = 0.05 
	
	for id in _depth_cache:
		if not graph_ref.nodes.has(id): continue
		
		var pos = graph_ref.get_node_pos(id)
		var depth_val = _depth_cache[id]
		var text = str(depth_val)
		
		var current_hue = fmod(start_hue + (depth_val * hue_step), 1.0)
		
		# CHANGED: Saturation lowered from 0.85 to 0.55
		# Value kept at 1.0 (Maximum Brightness)
		var depth_color = Color.from_hsv(current_hue, 0.55, 1.0)
		
		var text_size = default_font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = pos + Vector2(-text_size.x / 2.0, text_size.y / 4.0)
		
		# Increased outline thickness to 4 for better contrast against the lighter text
		draw_string_outline(default_font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 4, Color.BLACK)
		draw_string(default_font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, depth_color)

func _recalculate_depth_cache() -> void:
	_depth_cache.clear()
	if graph_ref.nodes.is_empty():
		return
		
	# A. IDENTIFY SEEDS (Roots)
	var seeds: Array[String] = []
	
	# Priority 1: Selected Nodes (Context-Sensitive Depth)
	var selected_spawns: Array[String] = [] 
	
	for id in selected_nodes_ref:
		if graph_ref.nodes.has(id):
			var node = graph_ref.nodes[id]
			if node.type == NodeData.RoomType.SPAWN:
				selected_spawns.append(id)
	
	if not selected_spawns.is_empty():
		seeds = selected_spawns
	
	# Priority 2: All Spawns (Global Depth)
	# If nothing specific is selected, flow from ALL entrances.
	if seeds.is_empty():
		for id in graph_ref.nodes:
			if graph_ref.nodes[id].type == NodeData.RoomType.SPAWN:
				seeds.append(id)
				
	# Priority 3: Fallback (Center)
	# If the graph has NO spawns, pick the node closest to 0,0
	if seeds.is_empty():
		var closest = ""
		var min_dist = INF
		for id in graph_ref.nodes:
			var d = graph_ref.get_node_pos(id).length_squared()
			if d < min_dist:
				min_dist = d
				closest = id
		if closest != "":
			seeds.append(closest)

	# B. BREADTH-FIRST SEARCH (The "Flow")
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
# 6. UTILITY FUNCTIONS
# ==============================================================================

func _get_node_color(id: String, node_data: NodeData) -> Color:
	var col = GraphSettings.get_color(node_data.type)
	if new_nodes_ref.has(id):
		col = GraphSettings.COLOR_NEW_GENERATION
	return col

func _draw_node_indicators(id: String, pos: Vector2) -> void:
	# 1. Selection Rings
	if selected_nodes_ref.has(id) or pre_selection_ref.has(id):
		draw_arc(pos, node_radius + 4.0, 0, TAU, 32, selected_color, 3.0)
	elif id == hovered_id:
		draw_arc(pos, node_radius + 4.0, 0, TAU, 32, hover_color, 2.0)
	
	# 2. START INDICATORS (Green, Top-Left Text)
	var start_indices = []
	for i in range(path_start_ids.size()):
		if path_start_ids[i] == id:
			start_indices.append(str(i + 1)) # "1", "2"
			
	if not start_indices.is_empty():
		# Draw the Ring (Once)
		draw_circle(pos, node_radius * 0.5, GraphSettings.COLOR_PATH_START) 
		draw_arc(pos, node_radius + 9.0, 0, TAU, 32, GraphSettings.COLOR_PATH_START, 3.0) 
		
		# Draw the Numbers (Top Left)
		var label = ",".join(start_indices)
		# Position: Left and Up relative to the node
		var text_pos = pos + Vector2(-node_radius - 24, -node_radius + 8)
		# Align Right so text grows outward to the left
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_RIGHT, -1, 16, GraphSettings.COLOR_PATH_START)

	# 3. END INDICATORS (Red, Top-Right Text)
	var end_indices = []
	for i in range(path_end_ids.size()):
		if path_end_ids[i] == id:
			end_indices.append(str(i + 1))
			
	if not end_indices.is_empty():
		# Draw the Ring (Once)
		draw_circle(pos, node_radius * 0.5, GraphSettings.COLOR_PATH_END)
		draw_arc(pos, node_radius + 6.0, 0, TAU, 32, GraphSettings.COLOR_PATH_END, 3.0)
		
		# Draw the Numbers (Top Right)
		var label = ",".join(end_indices)
		# Position: Right and Up relative to the node
		var text_pos = pos + Vector2(node_radius + 4, -node_radius + 8)
		# Align Left so text grows outward to the right
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GraphSettings.COLOR_PATH_END)
