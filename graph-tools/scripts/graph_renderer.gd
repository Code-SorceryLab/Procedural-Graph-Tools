extends Node2D
class_name GraphRenderer

# Use GraphSettings for defaults, but keep exports so you can tweak per-instance if needed
@export var node_radius: float = GraphSettings.NODE_RADIUS
@export var edge_width: float = GraphSettings.EDGE_WIDTH
@export var default_color: Color = GraphSettings.COLOR_DEFAULT
@export var selected_color: Color = GraphSettings.COLOR_SELECTED
@export var path_color: Color = GraphSettings.COLOR_PATH
@export var hover_color: Color = GraphSettings.COLOR_HOVER
@export var dragged_color: Color = GraphSettings.COLOR_DRAGGED
@export var debug_show_depth: bool = false

# References injected by the Controller
var graph_ref: Graph
var selected_nodes_ref: Array[String] = []
var current_path_ref: Array[String] = []
var drag_start_id: String = ""
var hovered_id: String = ""
var snap_preview_pos: Vector2 = Vector2.INF
#Reference to the list of newly added nodes
var new_nodes_ref: Array[String] = []

func _draw() -> void:
	if not graph_ref:
		return

	# 1. Draw Edges
	# We use a Dictionary to track drawn pairs so we don't draw duplicates.
	# NOTE: We keep this method (instead of "id < neighbor") so that Directed edges
	# are still visible even if the direction is "backwards" lexicographically.
	var drawn_edges := {} 
	for id: String in graph_ref.nodes:
		var start_pos = graph_ref.get_node_pos(id)
		for neighbor: String in graph_ref.get_neighbors(id):
			var pair = [id, neighbor]
			pair.sort() 
			
			if drawn_edges.has(pair): continue
			drawn_edges[pair] = true
			
			var end_pos = graph_ref.get_node_pos(neighbor)
			draw_line(start_pos, end_pos, Color(0.8, 0.8, 0.8), edge_width)

	# 2. Draw A* Path
	if current_path_ref.size() > 1:
		var points = PackedVector2Array()
		for id in current_path_ref:
			points.append(graph_ref.get_node_pos(id))
		draw_polyline(points, path_color, edge_width + 2.0)

# 3. Draw Nodes
	for id: String in graph_ref.nodes:
		# CASTING: Access the NodeData resource to read custom properties like 'type'
		var node_data = graph_ref.nodes[id] as NodeData
		var pos = node_data.position
		
		# --- COLOR LOGIC START ---
		# 1. Base Semantic Color (The Room Type)
		var col = GraphSettings.COLOR_DEFAULT
		# Look up the color for this specific RoomType in your settings
		if GraphSettings.ROOM_COLORS.has(node_data.type):
			col = GraphSettings.ROOM_COLORS[node_data.type]
		
		# 2. Overrides (Highlights)
		# "New Generation" overrides the room color
		if new_nodes_ref.has(id):
			col = GraphSettings.COLOR_NEW_GENERATION
		
		# "Selection" has the highest priority of all
		if selected_nodes_ref.has(id):
			col = selected_color
			
		# --- COLOR LOGIC END ---
		
		# Draw
		draw_circle(pos, node_radius, col)
		draw_circle(pos, node_radius * 0.7, Color(0,0,0,0.1))
		
		if id == hovered_id:
			draw_arc(pos, node_radius + 4.0, 0, TAU, 32, hover_color, 2.0)
			
		# --- NEW: DEBUG DEPTH TEXT ---
		if debug_show_depth:
			var font = ThemeDB.fallback_font
			var font_size = 14
			var text = str(node_data.depth)
			
			# Calculate offset to center the text roughly
			# (draw_string draws from bottom-left baseline)
			var text_size = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
			var text_pos = pos + Vector2(-text_size.x / 2.0, text_size.y / 4.0)
			
			# Draw Outline (Black)
			draw_string_outline(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 3, Color.BLACK)
			# Draw Text (White)
			draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

	# 4. Draw Snap Preview (Ghost Node)
	if snap_preview_pos != Vector2.INF:
		# Draw a faint circle where the node will appear
		draw_circle(snap_preview_pos, node_radius, Color(1, 1, 1, 0.3))
		# Optional: Draw a little crosshair
		draw_line(snap_preview_pos - Vector2(5,0), snap_preview_pos + Vector2(5,0), Color(1,1,1,0.5), 1.0)
		draw_line(snap_preview_pos - Vector2(0,5), snap_preview_pos + Vector2(0,5), Color(1,1,1,0.5), 1.0)
	
	# 5. Draw Dragging Line
	if not drag_start_id.is_empty():
		draw_line(graph_ref.get_node_pos(drag_start_id), get_local_mouse_position(), Color(1, 1, 1, 0.5), 2.0)
