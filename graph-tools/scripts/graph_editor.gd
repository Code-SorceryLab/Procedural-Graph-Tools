extends Node2D

signal graph_loaded(new_graph: Graph)

# The Brain of the operation
# Handles Input -> Updates Data -> Requests Redraw

@onready var renderer: GraphRenderer = $Renderer
@onready var camera: GraphCamera = $Camera

var graph: Graph = Graph.new()

# USE GLOBAL SETTINGS NOW
var active_tool: int = GraphSettings.Tool.SELECT

# State
var _next_id_counter: int = 0
var _drag_start_id: String = "" 
var _selected_nodes: Array[String] = []
var _current_path: Array[String] = []
var _new_nodes: Array[String] = [] 

func _ready() -> void:
	# Inject data references into the renderer
	renderer.graph_ref = graph
	renderer.selected_nodes_ref = _selected_nodes
	renderer.current_path_ref = _current_path
	renderer.new_nodes_ref = _new_nodes
	
	renderer.queue_redraw()

# PUBLIC API - Called by GamePlayer

func set_active_tool(tool_id: int) -> void:
	active_tool = tool_id
	print("GraphEditor: Active tool set to ", tool_id)
	
	# Reset any tool-specific state
	_drag_start_id = ""
	_selected_nodes.clear()
	_current_path.clear()
	
	# Update renderer
	renderer.selected_nodes_ref = _selected_nodes
	renderer.current_path_ref = _current_path
	renderer.queue_redraw()

func clear_graph() -> void:
	graph = Graph.new()
	renderer.graph_ref = graph
	_reset_scene()
	_next_id_counter = 0 
	camera.reset_view()
	renderer.queue_redraw()

func apply_strategy(strategy: GraphStrategy, params: Dictionary) -> void:
	var existing_ids = {}
	for id in graph.nodes:
		existing_ids[id] = true
	
	_reset_scene()
	strategy.execute(graph, params)
	
	_new_nodes.clear()
	var is_append = params.get("append", false)
	
	if is_append:
		for id in graph.nodes:
			if not existing_ids.has(id):
				_new_nodes.append(id)
	
	_center_camera_on_graph()
	renderer.queue_redraw()

# --- INPUT ROUTER (THE FIX) ---
func _unhandled_input(event: InputEvent) -> void:
	# 1. Global Shortcuts (Space for Pathfinding, F for Focus)
	if event is InputEventKey and event.pressed:
		_handle_keyboard(event)
		return

	# 2. Route Mouse Inputs to the Active Tool
	match active_tool:
		GraphSettings.Tool.SELECT:
			_tool_select_input(event)
		GraphSettings.Tool.ADD_NODE:
			_tool_add_input(event)
		GraphSettings.Tool.CONNECT:
			_tool_connect_input(event)
		GraphSettings.Tool.DELETE:
			_tool_delete_input(event)
		GraphSettings.Tool.RECTANGLE:
			pass # Placeholder
		GraphSettings.Tool.MEASURE:
			pass # Placeholder
		GraphSettings.Tool.PAN:
			pass # Handled by camera usually, but placeholder here

# --- TOOL 1: SELECT & DRAG ---
func _tool_select_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_pos = get_global_mouse_position()
		
		# LEFT CLICK
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var clicked_id = _get_node_at_pos(mouse_pos)
				
				if not clicked_id.is_empty():
					# START DRAG / SELECT
					_drag_start_id = clicked_id
					renderer.drag_start_id = clicked_id
					
					# Toggle Selection logic
					if Input.is_key_pressed(KEY_SHIFT):
						_toggle_selection(clicked_id)
					elif not _selected_nodes.has(clicked_id):
						# If clicking a new node without shift, select only it
						_selected_nodes.clear()
						_selected_nodes.append(clicked_id)
						renderer.selected_nodes_ref = _selected_nodes
				else:
					# CLICKED EMPTY SPACE -> DESELECT ALL
					_selected_nodes.clear()
					renderer.selected_nodes_ref = _selected_nodes
					
			else:
				# RELEASE LEFT CLICK
				_drag_start_id = ""
				renderer.drag_start_id = ""

		# RIGHT CLICK (Context)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Optional: Right click in select mode could still delete, or open menu
			# For now, let's keep it safe (do nothing) or clear selection
			_selected_nodes.clear()
			renderer.selected_nodes_ref = _selected_nodes
			
		renderer.queue_redraw()

	elif event is InputEventMouseMotion:
		if not _drag_start_id.is_empty():
			# 1. Get raw position
			var move_pos = get_global_mouse_position()
			
			# 2. Apply Grid Snap if Shift is held
			if Input.is_key_pressed(KEY_SHIFT):
				move_pos = move_pos.snapped(GraphSettings.SNAP_GRID_SIZE)
			
			# 3. Update the node position
			graph.set_node_position(_drag_start_id, move_pos)
			renderer.queue_redraw()
		
		_update_hover(get_global_mouse_position())

# --- TOOL 2: ADD NODE ---
func _tool_add_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		var clicked_id = _get_node_at_pos(mouse_pos)
		
		# Only add if we clicked EMPTY SPACE
		if clicked_id.is_empty():
			var place_pos = mouse_pos
			if Input.is_key_pressed(KEY_SHIFT):
				place_pos = mouse_pos.snapped(GraphSettings.SNAP_GRID_SIZE)
			
			_next_id_counter += 1
			graph.add_node(str(_next_id_counter), place_pos)
			renderer.queue_redraw()

	elif event is InputEventMouseMotion:
		_update_hover(get_global_mouse_position())

# --- TOOL 3: CONNECT ---
func _tool_connect_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos = get_global_mouse_position()
		
		if event.pressed:
			var clicked_id = _get_node_at_pos(mouse_pos)
			if not clicked_id.is_empty():
				_drag_start_id = clicked_id
				renderer.drag_start_id = clicked_id
		else:
			# Release -> Create Connection
			if not _drag_start_id.is_empty():
				var release_id = _get_node_at_pos(mouse_pos)
				if not release_id.is_empty() and release_id != _drag_start_id:
					graph.add_edge(_drag_start_id, release_id)
			
			_drag_start_id = ""
			renderer.drag_start_id = ""
		
		renderer.queue_redraw()
		
	elif event is InputEventMouseMotion:
		# Force redraw if we are dragging a line
		if not _drag_start_id.is_empty():
			renderer.queue_redraw()
		
		_update_hover(get_global_mouse_position())

# --- TOOL 4: DELETE ---
func _tool_delete_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var clicked_id = _get_node_at_pos(get_global_mouse_position())
		if not clicked_id.is_empty():
			graph.remove_node(clicked_id)
			if _selected_nodes.has(clicked_id):
				_selected_nodes.erase(clicked_id)
			renderer.queue_redraw()
	
	elif event is InputEventMouseMotion:
		_update_hover(get_global_mouse_position())

# --- HELPER: Hover Logic ---
func _update_hover(mouse_pos: Vector2) -> void:
	var new_hovered = _get_node_at_pos(mouse_pos)
	var snap_pos = Vector2.INF
	
	# Only show snap preview if using ADD tool and holding shift
	if active_tool == GraphSettings.Tool.ADD_NODE and new_hovered.is_empty() and Input.is_key_pressed(KEY_SHIFT):
		snap_pos = mouse_pos.snapped(GraphSettings.SNAP_GRID_SIZE)
	
	if new_hovered != renderer.hovered_id or snap_pos != renderer.snap_preview_pos:
		renderer.hovered_id = new_hovered
		renderer.snap_preview_pos = snap_pos
		renderer.queue_redraw()

# --- SHARED HELPERS ---
func _handle_keyboard(event: InputEventKey) -> void:
	# SPACE: Run A* Pathfinding
	if event.keycode == KEY_SPACE:
		if _selected_nodes.size() >= 2:
			var start_time = Time.get_ticks_usec()
			var path = graph.get_astar_path(_selected_nodes[0], _selected_nodes[1])
			var end_time = Time.get_ticks_usec()
			
			_current_path.clear()
			_current_path.append_array(path)
			
			renderer.current_path_ref = _current_path
			renderer.queue_redraw()
			
			var duration_ms = (end_time - start_time) / 1000.0
			print("A* Path found: %d nodes in %.3f ms" % [path.size(), duration_ms])
	
	# F: to Frame All
	elif event.keycode == KEY_F:
		_center_camera_on_graph()

func _toggle_selection(id: String) -> void:
	if _selected_nodes.has(id):
		_selected_nodes.erase(id)
	else:
		_selected_nodes.append(id)
		if _selected_nodes.size() > 2:
			_selected_nodes.pop_front()
	renderer.selected_nodes_ref = _selected_nodes

func _reset_scene() -> void:
	_selected_nodes.clear()
	_current_path.clear()
	renderer.selected_nodes_ref = _selected_nodes
	renderer.current_path_ref = _current_path

func _get_node_at_pos(pos: Vector2) -> String:
	return graph.get_node_at_position(pos, renderer.node_radius)

func _center_camera_on_graph() -> void:
	if graph.nodes.is_empty():
		return
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	for id: String in graph.nodes:
		var pos = graph.get_node_pos(id)
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)
	var rect = Rect2(min_pos, max_pos - min_pos)
	camera.center_on_rect(rect)

func load_new_graph(new_graph: Graph) -> void:
	self.graph = new_graph
	_reset_scene()
	var max_id = 0
	for id: String in graph.nodes:
		if id.is_valid_int() and id.to_int() > max_id:
			max_id = id.to_int()
	_next_id_counter = max_id
	graph_loaded.emit(graph)
	renderer.graph_ref = graph
	renderer.selected_nodes_ref = _selected_nodes
	renderer.current_path_ref = _current_path
	renderer.new_nodes_ref = _new_nodes
	_center_camera_on_graph()
	renderer.queue_redraw()
