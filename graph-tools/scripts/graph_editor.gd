extends Node2D
class_name GraphEditor

# Signal to notify the rest of the game when a new graph is loaded or generated
signal graph_loaded(new_graph: Graph)

# --- REFERENCES ---
@onready var renderer: GraphRenderer = $Renderer
@onready var camera: GraphCamera = $Camera

# --- DATA MODEL ---
var graph: Graph = Graph.new()

# --- STATE MANAGEMENT ---
# The Active Tool (State Machine Pattern)
var current_tool: GraphTool

# Editor State (Public so tools can read/modify them safely)
var selected_nodes: Array[String] = []
var current_path: Array[String] = []
var new_nodes: Array[String] = [] 

# Internal counters
var _next_id_counter: int = 0

# ==============================================================================
# 1. INITIALIZATION & SETUP
# ==============================================================================
func _ready() -> void:
	# Inject references into the renderer
	renderer.graph_ref = graph
	renderer.selected_nodes_ref = selected_nodes
	renderer.current_path_ref = current_path
	renderer.new_nodes_ref = new_nodes
	
	# Start with the default tool
	set_active_tool(GraphSettings.Tool.SELECT)
	renderer.queue_redraw()

# ==============================================================================
# 2. TOOL MANAGEMENT (The State Machine Factory)
# ==============================================================================
func set_active_tool(tool_id: int) -> void:
	print("GraphEditor: Switching to tool ", tool_id)
	
	# 1. Cleanup the old tool
	if current_tool:
		current_tool.exit()
	
	# 2. Instantiate the new tool (Factory Pattern)
	match tool_id:
		GraphSettings.Tool.SELECT:
			current_tool = GraphToolSelect.new(self)
		GraphSettings.Tool.ADD_NODE:
			current_tool = GraphToolAddNode.new(self)
		GraphSettings.Tool.CONNECT:
			current_tool = GraphToolConnect.new(self)
		GraphSettings.Tool.DELETE:
			current_tool = GraphToolDelete.new(self)
		_:
			push_warning("Unknown tool ID: %d. Defaulting to Select." % tool_id)
			current_tool = GraphToolSelect.new(self)
			
	# 3. Initialize the new tool
	if current_tool:
		current_tool.enter()

# ==============================================================================
# 3. INPUT ROUTING
# ==============================================================================
func _unhandled_input(event: InputEvent) -> void:
	# 1. Handle Global Shortcuts first (Space, F, etc.)
	# We handle these here so they work regardless of which tool is active.
	if event is InputEventKey and event.pressed:
		_handle_global_shortcuts(event)
		# We don't 'return' here because a tool might also want to know about keys 
		# (e.g., Shift for snapping), though usually tools handle mouse events.

	# 2. Delegate everything else to the Active Tool
	if current_tool:
		current_tool.handle_input(event)

func _handle_global_shortcuts(event: InputEventKey) -> void:
	# SPACE: Run A* Pathfinding
	if event.keycode == KEY_SPACE:
		_run_pathfinding()
			
	# F: Focus Camera
	elif event.keycode == KEY_F:
		_center_camera_on_graph()

# ==============================================================================
# 4. PUBLIC API FOR TOOLS
# These functions allow GraphTools to modify the Editor state cleanly.
# ==============================================================================

# --- Node Operations ---
func create_node(pos: Vector2) -> void:
	_next_id_counter += 1
	graph.add_node(str(_next_id_counter), pos)

func delete_node(id: String) -> void:
	graph.remove_node(id)
	# Cleanup selection if the deleted node was selected
	if selected_nodes.has(id):
		selected_nodes.erase(id)
	# Cleanup path if deleted node was part of it
	if current_path.has(id):
		current_path.clear()
		renderer.current_path_ref = current_path

# --- Selection Operations ---
func toggle_selection(id: String) -> void:
	if selected_nodes.has(id):
		selected_nodes.erase(id)
	else:
		selected_nodes.append(id)
		# Limit selection to 2 nodes for A* pathfinding demo
		if selected_nodes.size() > 2:
			selected_nodes.pop_front()
	
	# Sync with renderer
	renderer.selected_nodes_ref = selected_nodes

func add_to_selection(id: String) -> void:
	if not selected_nodes.has(id):
		selected_nodes.append(id)
		# Limit check
		if selected_nodes.size() > 2:
			selected_nodes.pop_front()
		renderer.selected_nodes_ref = selected_nodes

func clear_selection() -> void:
	selected_nodes.clear()
	renderer.selected_nodes_ref = selected_nodes

# ==============================================================================
# 5. GENERAL API (Called by GamePlayer / UI)
# ==============================================================================
func clear_graph() -> void:
	# Create fresh graph instance
	graph = Graph.new()
	
	# Reset local state
	selected_nodes.clear()
	current_path.clear()
	new_nodes.clear()
	_next_id_counter = 0 
	
	# Update References
	renderer.graph_ref = graph
	
	# IMPORTANT: Update the current tool's reference to the new graph!
	if current_tool: 
		current_tool._graph = graph
	
	camera.reset_view()
	renderer.queue_redraw()

func load_new_graph(new_graph: Graph) -> void:
	self.graph = new_graph
	
	# Reset state
	_reset_local_state()
	
	# Sync ID counter so new nodes don't overwrite loaded ones
	var max_id = 0
	for id: String in graph.nodes:
		if id.is_valid_int() and id.to_int() > max_id:
			max_id = id.to_int()
	_next_id_counter = max_id
	
	# Broadcast change
	graph_loaded.emit(graph)
	
	# Update References
	renderer.graph_ref = graph
	renderer.selected_nodes_ref = selected_nodes
	renderer.current_path_ref = current_path
	renderer.new_nodes_ref = new_nodes
	
	if current_tool:
		current_tool._graph = graph
		
	_center_camera_on_graph()
	renderer.queue_redraw()

func apply_strategy(strategy: GraphStrategy, params: Dictionary) -> void:
	# 1. Snapshot existing nodes (to detect what's new later)
	var existing_ids = {}
	for id in graph.nodes:
		existing_ids[id] = true
	
	# 2. Reset selection/path visuals
	_reset_local_state()
	
	# 3. Execute
	strategy.execute(graph, params)
	
	# 4. Highlight new nodes (if appending)
	new_nodes.clear()
	var is_append = params.get("append", false)
	if is_append:
		for id in graph.nodes:
			if not existing_ids.has(id):
				new_nodes.append(id)
	
	# 5. Refresh View
	_center_camera_on_graph()
	renderer.queue_redraw()

# ==============================================================================
# 6. INTERNAL HELPERS
# ==============================================================================
func _run_pathfinding() -> void:
	if selected_nodes.size() >= 2:
		var start_time = Time.get_ticks_usec()
		var path = graph.get_astar_path(selected_nodes[0], selected_nodes[1])
		var end_time = Time.get_ticks_usec()
		
		current_path.clear()
		current_path.append_array(path)
		
		renderer.current_path_ref = current_path
		renderer.queue_redraw()
		
		var duration_ms = (end_time - start_time) / 1000.0
		print("A* Path found: %d nodes in %.3f ms" % [path.size(), duration_ms])

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

func _reset_local_state() -> void:
	selected_nodes.clear()
	current_path.clear()
	renderer.selected_nodes_ref = selected_nodes
	renderer.current_path_ref = current_path
