extends Node2D
class_name GraphRenderer

# ==============================================================================
# 1. VISUAL CONFIGURATION
# ==============================================================================
# Defaults are pulled from GraphSettings, but Exports allow per-instance overrides.

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

# Tool Overlay Data
var tool_line_start: Vector2 = Vector2.INF
var tool_line_end: Vector2 = Vector2.INF

# ==============================================================================
# 2. DATA REFERENCES
# ==============================================================================
# These are injected by the GraphEditor (Controller) during _ready().
# The Renderer is "dumb" and only reads this data; it never modifies it.

var graph_ref: Graph
var selected_nodes_ref: Array[String] = []
var current_path_ref: Array[String] = []
var new_nodes_ref: Array[String] = [] # Highlight for "Grow" operations
# Nodes currently under the drag box (Temporary Highlight)
var pre_selection_ref: Array[String] = []

# ==============================================================================
# 3. INTERACTION STATE
# ==============================================================================
# Temporary visual state managed by Tools.

# Pathfinding Markers
var path_start_id: String = ""
var path_end_id: String = ""

# Mouse Interaction
var drag_start_id: String = ""
var hovered_id: String = ""
var snap_preview_pos: Vector2 = Vector2.INF
var selection_rect: Rect2 = Rect2()

# ==============================================================================
# 4. DRAWING LOOP
# ==============================================================================

func _draw() -> void:
	if not graph_ref:
		return

	# Layer 1: Connections (Behind nodes)
	_draw_edges()
	
	# Layer 2: A* Path (On top of edges, behind nodes)
	_draw_current_path()
	
	# Layer 3: Nodes (The main content)
	_draw_nodes()
	
	# Layer 4: Interactive Elements (Ghosts, Drag lines)
	_draw_interaction_overlays()

	# Layer 5: Selection Box (Transparent Blue Box)
	_draw_selection_box()

# --- HELPER: EDGES ---
func _draw_edges() -> void:
	# We use a Dictionary to track drawn pairs so we don't draw duplicates.
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
			draw_line(start_pos, end_pos, GraphSettings.COLOR_EDGE, edge_width)


# --- HELPER: PATHFINDING LINE ---
func _draw_current_path() -> void:
	if current_path_ref.size() > 1:
		var points = PackedVector2Array()
		for id in current_path_ref:
			points.append(graph_ref.get_node_pos(id))
		
		# Draw the path slightly thicker than normal edges
		draw_polyline(points, path_color, edge_width + 2.0)


# --- HELPER: NODES & LABELS ---
func _draw_nodes() -> void:
	for id: String in graph_ref.nodes:
		# Access the NodeData resource to read custom properties like 'type'
		var node_data = graph_ref.nodes[id] as NodeData
		var pos = node_data.position
		
		# 1. Determine Color Priority
		var col = _get_node_color(id, node_data)
		
		# 2. Draw Body
		# Main colored circle
		draw_circle(pos, node_radius, col)
		# Inner shadow for a bit of depth
		draw_circle(pos, node_radius * 0.7, Color(0, 0, 0, 0.1))
		
		# 3. Draw Debug Text (if enabled)
		if debug_show_depth:
			_draw_debug_label(pos, str(node_data.depth))
			
		# 4. Draw Status Indicators (Start/End/Hover)
		_draw_node_indicators(id, pos)


# --- HELPER: INTERACTIVE OVERLAYS ---
func _draw_interaction_overlays() -> void:
	# 1. Snap Preview (Ghost Node)
	if snap_preview_pos != Vector2.INF:
		# Draw a faint circle where the node will appear
		draw_circle(snap_preview_pos, node_radius, Color(1, 1, 1, 0.3))
		# Draw a little crosshair for precision
		draw_line(snap_preview_pos - Vector2(5,0), snap_preview_pos + Vector2(5,0), Color(1,1,1,0.5), 1.0)
		draw_line(snap_preview_pos - Vector2(0,5), snap_preview_pos + Vector2(0,5), Color(1,1,1,0.5), 1.0)
	
	# 2. Dragging Line (Connection Preview)
	if not drag_start_id.is_empty():
		var start_pos = graph_ref.get_node_pos(drag_start_id)
		# NOTE: Must use local mouse position to account for Camera zoom/pan!
		var mouse_pos = get_local_mouse_position()
		
		draw_line(start_pos, mouse_pos, dragged_color, 2.0)
	
	# 3. Draw Tool Overlay (The Knife Line)
	if tool_line_start != Vector2.INF and tool_line_end != Vector2.INF:
		draw_line(tool_line_start, tool_line_end, Color.ORANGE_RED, 2.0)

# --- HELPER: SELECTION BOX ---
func _draw_selection_box():
# NEW: Draw the Selection Box on top of everything
	if selection_rect.has_area():
		# Fill (Low Opacity Blue)
		draw_rect(selection_rect, GraphSettings.COLOR_SELECT_BOX_Fill, true)
		# Border (High Opacity Blue)
		draw_rect(selection_rect, GraphSettings.COLOR_SELECT_BOX_BORDER, false, 1.0)

# ==============================================================================
# 5. UTILITY FUNCTIONS
# ==============================================================================

func _get_node_color(id: String, node_data: NodeData) -> Color:
	# 1. Resolve Base Color via Legend (Safe Lookup)
	var col = GraphSettings.get_color(node_data.type)
	
	# 2. Apply "New Generation" highlight (Walker Path / Cellular Growth)
	if new_nodes_ref.has(id):
		col = GraphSettings.COLOR_NEW_GENERATION
	
	return col

func _draw_node_indicators(id: String, pos: Vector2) -> void:
	# --- SELECTION RING (Prioritized) ---
	# We use 'selected_color' (Orange) but draw it as a ring.
	if selected_nodes_ref.has(id) or pre_selection_ref.has(id):
		# Thicker ring than hover to show importance
		draw_arc(pos, node_radius + 4.0, 0, TAU, 32, selected_color, 3.0)
		
	# --- HOVER RING ---
	# Only show hover if it's NOT selected (prevents double rings)
	elif id == hovered_id:
		draw_arc(pos, node_radius + 4.0, 0, TAU, 32, hover_color, 2.0)
	
	# Path Start Indicator (Green Ring)
	if id == path_start_id:
		draw_circle(pos, node_radius * 0.5, GraphSettings.COLOR_PATH_START) # Inner dot
		draw_arc(pos, node_radius + 6.0, 0, TAU, 32, GraphSettings.COLOR_PATH_START, 3.0) # Outer ring
		
	# Path End Indicator (Red Ring)
	if id == path_end_id:
		draw_circle(pos, node_radius * 0.5, GraphSettings.COLOR_PATH_END) # Inner dot
		draw_arc(pos, node_radius + 6.0, 0, TAU, 32, GraphSettings.COLOR_PATH_END, 3.0) # Outer ring

func _draw_debug_label(pos: Vector2, text: String) -> void:
	var font = ThemeDB.fallback_font
	var font_size = 14
	
	# Calculate offset to center the text roughly
	# (draw_string draws from bottom-left baseline)
	var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos = pos + Vector2(-text_size.x / 2.0, text_size.y / 4.0)
	
	# Draw Outline (Black) for readability against any background
	draw_string_outline(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 3, Color.BLACK)
	# Draw Text (White)
	draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)
