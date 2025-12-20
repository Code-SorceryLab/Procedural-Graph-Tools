extends Node2D

signal graph_loaded(new_graph: Graph)

# The Brain of the operation
# Handles Input -> Updates Data -> Requests Redraw

@onready var renderer: GraphRenderer = $Renderer
@onready var camera: GraphCamera = $Camera



var graph: Graph = Graph.new()

# State
var _next_id_counter: int = 0
var _drag_start_id: String = "" 
var _selected_nodes: Array[String] = []
var _current_path: Array[String] = []
var _new_nodes: Array[String] = [] #Track the newest batch

func _ready() -> void:
	# Inject data references into the renderer so it knows what to draw
	renderer.graph_ref = graph
	renderer.selected_nodes_ref = _selected_nodes
	renderer.current_path_ref = _current_path
	renderer.new_nodes_ref = _new_nodes
	
	# Initial Render
	renderer.queue_redraw()

# PUBLIC API - Called by GamePlayer

func clear_graph() -> void:
	# Create a fresh instance
	graph = Graph.new()
	
	# Since we replaced the 'graph' object, we MUST re-connect the renderer
	renderer.graph_ref = graph
	
	# Reset state
	_reset_scene()
	_next_id_counter = 0 
	camera.reset_view()
	renderer.queue_redraw()

# Replaces generate_grid_map, generate_random_walk_map, etc.
func apply_strategy(strategy: GraphStrategy, params: Dictionary) -> void:
	# 1. Snapshot: Remember what nodes we already have
	var existing_ids = {}
	for id in graph.nodes:
		existing_ids[id] = true
	
	# 2. Reset Editor Selection/Path
	_reset_scene()
	
	# 3. Execute the Strategy
	strategy.execute(graph, params)
	
	# 4. Calculate Diff: Identify what is new
	_new_nodes.clear()
	
	# Only highlight "New" nodes if we are in Append mode.
	# If we just wiped the board (Fresh Gen), arguably everything is "New", 
	# but usually you want Fresh Gen to be white, and Grow to be Blue.
	
	var is_append = params.get("append", false)
	
	if is_append:
		for id in graph.nodes:
			# If this ID was NOT in our snapshot, it must be new!
			if not existing_ids.has(id):
				_new_nodes.append(id)
	
	# (If not append mode, _new_nodes stays empty, so everything is White)

	# 5. Update View
	_center_camera_on_graph()
	renderer.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	# Note: Camera handles its own inputs (Zoom/Pan) automatically!
	
	# --- Mouse Interactions ---
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_handle_click(get_global_mouse_position())
			else:
				_handle_release(get_global_mouse_position())
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click(get_global_mouse_position())
			
		renderer.queue_redraw()

# UPDATED: Handle Hovering Logic
	elif event is InputEventMouseMotion:
		if not _drag_start_id.is_empty():
			renderer.queue_redraw()
			
		# 1. Check what is under the mouse
		var mouse_pos = get_global_mouse_position()
		var new_hovered = _get_node_at_pos(mouse_pos)
		
		# 2. Check for "Ghost Snap" (Shift held + Empty space)
		var snap_pos = Vector2.INF
		if new_hovered.is_empty() and Input.is_key_pressed(KEY_SHIFT):
			snap_pos = mouse_pos.snapped(GraphSettings.SNAP_GRID_SIZE)
		
		# Only redraw if something changed
		if new_hovered != renderer.hovered_id or snap_pos != renderer.snap_preview_pos:
			renderer.hovered_id = new_hovered
			renderer.snap_preview_pos = snap_pos # We need to add this var to Renderer!
			renderer.queue_redraw()

	# --- Keyboard Commands ---
	elif event is InputEventKey and event.pressed:
		_handle_keyboard(event)

func _handle_keyboard(event: InputEventKey) -> void:
	# SPACE: Run A* Pathfinding
	if event.keycode == KEY_SPACE:
		if _selected_nodes.size() >= 2:
			# Update local data
			var path = graph.get_astar_path(_selected_nodes[0], _selected_nodes[1])
			_current_path.clear()
			_current_path.append_array(path)
			
			# Update renderer reference
			renderer.current_path_ref = _current_path
			renderer.queue_redraw()
	
	# F: to Frame All / Focus
	elif event.keycode == KEY_F:
		_center_camera_on_graph()

# --- Logic Helpers ---
func _handle_click(pos: Vector2) -> void:
	var clicked_id := _get_node_at_pos(pos)
	
	if clicked_id.is_empty():
		# Creating a NEW node
		var place_pos = pos
		
		# NEW: Check for Shift key to snap
		if Input.is_key_pressed(KEY_SHIFT):
			place_pos = pos.snapped(GraphSettings.SNAP_GRID_SIZE)
			
		_next_id_counter += 1
		graph.add_node(str(_next_id_counter), place_pos)
		
	else:
		# Interaction with EXISTING node
		_drag_start_id = clicked_id
		renderer.drag_start_id = clicked_id
		
		# Shift on an existing node still performs Selection Toggle
		if Input.is_key_pressed(KEY_SHIFT):
			_toggle_selection(clicked_id)
		
		_current_path.clear()
		renderer.current_path_ref = _current_path

func _handle_release(pos: Vector2) -> void:
	if _drag_start_id.is_empty():
		return
		
	var release_node := _get_node_at_pos(pos)
	if not release_node.is_empty() and release_node != _drag_start_id:
		graph.add_edge(_drag_start_id, release_node)
	
	_drag_start_id = ""
	renderer.drag_start_id = "" # Sync with renderer

func _handle_right_click(pos: Vector2) -> void:
	var clicked_id := _get_node_at_pos(pos)
	if not clicked_id.is_empty():
		graph.remove_node(clicked_id)
		_selected_nodes.erase(clicked_id)
		_current_path.clear()
		renderer.current_path_ref = _current_path

func _toggle_selection(id: String) -> void:
	if _selected_nodes.has(id):
		_selected_nodes.erase(id)
	else:
		_selected_nodes.append(id)
		if _selected_nodes.size() > 2:
			_selected_nodes.pop_front()
	
	# Update Renderer Ref
	renderer.selected_nodes_ref = _selected_nodes

func _reset_scene() -> void:
	_selected_nodes.clear()
	_current_path.clear()
	# Sync renderer
	renderer.selected_nodes_ref = _selected_nodes
	renderer.current_path_ref = _current_path

func _get_node_at_pos(pos: Vector2) -> String:
	# Accessing renderer export for consistency, or define constant
	var radius = renderer.node_radius 
	for id: String in graph.nodes:
		if graph.get_node_pos(id).distance_to(pos) <= radius:
			return id
	return ""


func _center_camera_on_graph() -> void:
	if graph.nodes.is_empty():
		return
		
	# 1. Calculate Bounding Box
	var min_pos := Vector2(INF, INF)
	var max_pos := Vector2(-INF, -INF)
	
	for id: String in graph.nodes:
		var pos = graph.get_node_pos(id)
		min_pos.x = min(min_pos.x, pos.x)
		min_pos.y = min(min_pos.y, pos.y)
		max_pos.x = max(max_pos.x, pos.x)
		max_pos.y = max(max_pos.y, pos.y)
	
	# 2. Create Rect2
	var rect = Rect2(min_pos, max_pos - min_pos)
	
	# 3. Tell Camera to frame it
	camera.center_on_rect(rect)


func load_new_graph(new_graph: Graph) -> void:
	# 1. Replace the data model
	self.graph = new_graph
	
	# 2. Reset editor state (selections, path)
	_reset_scene()
	
	# 3. SYNC ID COUNTER
	var max_id = 0
	for id: String in graph.nodes:
		if id.is_valid_int() and id.to_int() > max_id:
			max_id = id.to_int()
	_next_id_counter = max_id
	
	
	# 4. EMIT THE SIGNAL INSTEAD OF MANUAL UPDATES
	# We broadcast the change. Anyone listening will update themselves.
	graph_loaded.emit(graph)
	
	# 5. Re-inject references into Renderer
	# The renderer needs to know about the NEW graph object.
	renderer.graph_ref = graph
	renderer.selected_nodes_ref = _selected_nodes
	renderer.current_path_ref = _current_path
	renderer.new_nodes_ref = _new_nodes # If you implemented the blue node feature
	
	# 6. Refresh view
	_center_camera_on_graph()
	renderer.queue_redraw()
