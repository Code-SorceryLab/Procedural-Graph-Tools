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
var node_labels_ref: Dictionary = {}
var selected_edges_ref: Array = []

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
	
	# 0. Draw Zones (Background layer)
	_draw_zones()
	
	# Layer 1: Connections
	_draw_edges()
	
	# Layer 2: A* Path
	_draw_current_path()
	
	# Layer 3: Nodes
	_draw_nodes()
	
	# [NEW] Layer 3.5: Custom Labels (Walker Trails)
	# We draw this separately so text always appears ON TOP of neighboring nodes
	_draw_custom_labels()
	
	# Layer 4: Interactive Elements
	_draw_interaction_overlays()

	# Layer 5: Selection Box
	_draw_selection_box()
	
	# Layer 6: Dynamic Depth Overlay (NEW)
	if debug_show_depth:
		_draw_depth_numbers()
# --- HELPER: ZONES ---
func _draw_zones() -> void:
	# --- DIAGNOSTIC PRINT ---
	#if graph_ref:
	#	print("RENDERER DIAGNOSTIC: Drawing Frame. Zone Count: %d" % graph_ref.zones.size())
	#	if not graph_ref.zones.is_empty():
	#		print(" - First Zone: %s | Bounds: %s" % [graph_ref.zones[0].zone_name, graph_ref.zones[0].bounds])
	#else:
	#	print("RENDERER DIAGNOSTIC: No Graph Ref!")
	# ------------------------

	if not graph_ref or graph_ref.zones.is_empty():
		return
		
	var spacing = GraphSettings.GRID_SPACING
	# Half-size for centering the rect on the node point
	var half_size = spacing / 2.0
	
	for zone in graph_ref.zones:
		# Draw every cell in the zone
		# (Optimized: In a real game we'd merge these into a polygon, but for an editor, drawing rects is fine)
		for cell in zone.cells:
			var world_pos = Vector2(cell.x * spacing.x, cell.y * spacing.y)
			var rect = Rect2(world_pos - half_size, spacing)
			draw_rect(rect, zone.zone_color, true) # Filled
			draw_rect(rect, zone.zone_color.lightened(0.2), false, 1.0) # Border

# --- HELPER: EDGES ---
func _draw_edges() -> void:
	# We use this to avoid drawing bi-directional edges twice
	var drawn_bidirectional := {} 
	
	for id: String in graph_ref.nodes:
		var start_pos = graph_ref.get_node_pos(id)
		
		for neighbor: String in graph_ref.get_neighbors(id):
			var end_pos = graph_ref.get_node_pos(neighbor)
			
			# Construct the sorted pair key for this connection
			var pair = [id, neighbor]
			pair.sort()
			
			# --- 1. DRAW SELECTION HIGHLIGHT ---
			# We draw this first so it appears "behind" the actual edge line
			# Note: We check 'has' on the Array. Since 'pair' is sorted, it matches the stored format.
			if selected_edges_ref.has(pair):
				draw_line(start_pos, end_pos, selected_color, edge_width + 4.0)
			
			# --- 2. DRAW ACTUAL EDGE ---
			
			# Check for return path using our Graph API
			var is_bidirectional = graph_ref.has_edge(neighbor, id)
			
			if is_bidirectional:
				# CASE A: Standard Two-Way Connection
				if drawn_bidirectional.has(pair):
					continue
				
				drawn_bidirectional[pair] = true
				
				draw_line(start_pos, end_pos, GraphSettings.COLOR_EDGE, edge_width)
				
			else:
				# CASE B: One-Way Connection
				draw_line(start_pos, end_pos, GraphSettings.COLOR_EDGE, edge_width)
				_draw_arrow_head(start_pos, end_pos)

# HELPER: Draws an arrow tip at the 'to' position
func _draw_arrow_head(from: Vector2, to: Vector2) -> void:
	var dir = (to - from).normalized()
	
	# Calculate the tip position
	# We back off from the node center by (radius + padding) so the arrow isn't hidden
	var tip_offset = node_radius + 6.0
	var tip = to - (dir * tip_offset)
	
	# Arrow Shape Configuration
	var arrow_size = 12.0
	var angle = PI / 5.0 # ~35 degrees
	
	# Calculate wing points
	var p1 = tip - dir.rotated(angle) * arrow_size
	var p2 = tip - dir.rotated(-angle) * arrow_size
	
	var color = GraphSettings.COLOR_EDGE
	var width = edge_width + 1.0 # Slightly thicker for visibility
	
	draw_line(tip, p1, color, width)
	draw_line(tip, p2, color, width)

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

# --- 3.5 HELPER: CUSTOM LABELS ---
func _draw_custom_labels() -> void:
	if node_labels_ref.is_empty():
		return
	
	#print("Renderer: Drawing %d labels." % node_labels_ref.size())
	
	# Draw text for every node in the dictionary
	for id in node_labels_ref:
		# Safety check: ensure the node actually exists in the graph
		if not graph_ref.nodes.has(id):
			continue
			
		var pos = graph_ref.get_node_pos(id)
		var text = node_labels_ref[id]
		
		# Position: Top Right, slightly higher than the Red End Marker
		# Red Marker is at Y = -radius + 8. We go up to Y = -radius - 8 to stack above it.
		var text_pos = pos + Vector2(node_radius + 4, -node_radius - 8)
		
		# Draw with high opacity for readability
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.9))

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
