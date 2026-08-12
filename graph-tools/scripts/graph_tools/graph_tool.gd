class_name GraphTool
extends RefCounted

# References to the main systems
var _editor: GraphEditor
var _graph: Graph
var _renderer: GraphRenderer

func _init(editor: Node2D) -> void:
	_editor = editor
	_graph = editor.graph
	_renderer = editor.renderer

# Virtual methods to be overridden
func enter() -> void: pass

func exit() -> void:
	_show_status("")
	_clear_all_hovers() # Ensure no ghost highlights remain when switching tools

func handle_input(_event: InputEvent) -> void: pass

# --- TOOL OPTIONS API ---

func get_options_schema() -> Array: return []
func apply_option(_param_name: String, _value: Variant) -> void: pass

func _show_status(message: String) -> void:
	if _editor.has_method("send_status_message"):
		_editor.send_status_message(message)

# ==============================================================================
# HOVER HELPERS (Visual Feedback)
# ==============================================================================

func _update_hover(mouse_pos: Vector2) -> void:
	# Default behavior for standard tools (Add Node, Connect, etc.)
	# We clear all other systems and only highlight nodes.
	# Advanced tools (like Universal Paint) override this to target specific systems.
	var new_hovered = _get_node_at_pos(mouse_pos)
	if _editor.has_method("set_hovered_node"): _editor.set_hovered_node(new_hovered)
	if _editor.has_method("set_hovered_edge"): _editor.set_hovered_edge([])
	if _editor.has_method("set_hovered_agent"): _editor.set_hovered_agent(null)
	if _editor.has_method("set_hovered_zone"): _editor.set_hovered_zone(null)

func _clear_all_hovers() -> void:
	if _editor.has_method("set_hovered_node"): _editor.set_hovered_node("")
	if _editor.has_method("set_hovered_edge"): _editor.set_hovered_edge([])
	if _editor.has_method("set_hovered_agent"): _editor.set_hovered_agent(null)
	if _editor.has_method("set_hovered_zone"): _editor.set_hovered_zone(null)


# ==============================================================================
# POINT HIT DETECTION (For Clicks & Hovering)
# ==============================================================================

func _get_node_at_pos(pos: Vector2) -> String:
	return _graph.get_node_at_position(pos, _renderer.node_radius)

func _get_edge_at_pos(pos: Vector2) -> Array:
	#Radius of 20 pixels.
	return _graph.get_edge_at_position(pos, 20.0)

func _get_agent_at_pos(pos: Vector2) -> Object:
	if _renderer and _renderer.has_method("get_agent_at_position"):
		return _renderer.get_agent_at_position(pos)
	return null

func _get_zone_at_pos(pos: Vector2) -> Object:
	var spacing = Vector2(64, 64)
	if GraphSettings: spacing = GraphSettings.GRID_SPACING
		
	var grid_pos = Vector2i(round(pos.x / spacing.x), round(pos.y / spacing.y))
	if "zones" in _graph:
		for z in _graph.zones:
			if z.has_cell(grid_pos): return z
	return null


# ==============================================================================
# RECTANGLE HIT DETECTION (For GraphDragHandler Selection Boxes)
# ==============================================================================

func _get_nodes_in_rect(rect: Rect2) -> Array[String]:
	var result: Array[String] = []
	for id in _graph.nodes:
		if rect.has_point(_graph.nodes[id].position):
			result.append(id)
	return result

func _get_edges_in_rect(rect: Rect2) -> Array:
	# Delegates to the Graph's highly accurate segment-intersection logic
	return _graph.get_edges_in_rect(rect)

func _get_agents_in_rect(rect: Rect2) -> Array:
	var result = []
	if "agents" in _graph:
		for agent in _graph.agents:
			if rect.has_point(agent.pos):
				result.append(agent)
	return result

func _get_zones_in_rect(rect: Rect2) -> Array:
	var result = []
	if "zones" in _graph:
		var spacing = Vector2(64, 64)
		if GraphSettings: spacing = GraphSettings.GRID_SPACING
			
		for z in _graph.zones:
			for cell in z.cells:
				var cell_pos = Vector2(cell.x * spacing.x, cell.y * spacing.y)
				# If even one cell of the zone is caught in the rectangle, select the zone
				if rect.has_point(cell_pos):
					if not result.has(z): result.append(z)
					break 
	return result

# ==============================================================================
# LASSO HIT DETECTION (For Freeform Selection)
# ==============================================================================

func _get_nodes_in_lasso(polygon: PackedVector2Array) -> Array[String]:
	var result: Array[String] = []
	if polygon.size() < 3: return result
	for id in _graph.nodes:
		if Geometry2D.is_point_in_polygon(_graph.nodes[id].position, polygon):
			result.append(id)
	return result

func _get_edges_in_lasso(polygon: PackedVector2Array) -> Array:
	var result = []
	if polygon.size() < 3: return result
	for key in _graph.edge_store:
		var e = _graph.edge_store[key]
		var u_pos = _graph.nodes[e.u].position
		var v_pos = _graph.nodes[e.v].position
		# If either end of the edge is caught in the lasso, select it
		if Geometry2D.is_point_in_polygon(u_pos, polygon) or Geometry2D.is_point_in_polygon(v_pos, polygon):
			result.append([e.u, e.v])
	return result

func _get_agents_in_lasso(polygon: PackedVector2Array) -> Array:
	var result = []
	if polygon.size() < 3: return result
	if "agents" in _graph:
		for agent in _graph.agents:
			if Geometry2D.is_point_in_polygon(agent.pos, polygon):
				result.append(agent)
	return result

func _get_zones_in_lasso(polygon: PackedVector2Array) -> Array:
	var result = []
	if polygon.size() < 3: return result
	if "zones" in _graph:
		var spacing = Vector2(64, 64)
		if GraphSettings: spacing = GraphSettings.GRID_SPACING
		for z in _graph.zones:
			for cell in z.cells:
				var cell_pos = Vector2(cell.x * spacing.x, cell.y * spacing.y)
				if Geometry2D.is_point_in_polygon(cell_pos, polygon):
					if not result.has(z): result.append(z)
					break 
	return result
