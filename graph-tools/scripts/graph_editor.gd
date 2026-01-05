extends Node2D
class_name GraphEditor

# Signal to notify the rest of the game when a new graph is loaded or generated
signal graph_loaded(new_graph: Graph)
signal selection_changed(selected_nodes: Array[String])

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
var path_start_id: String = ""
var path_end_id: String = ""
var current_path: Array[String] = []
var new_nodes: Array[String] = [] 

# Internal counters
# _next_id_counter is legacy/unused now that we switched to Namespaced IDs, 
# but kept just in case of fallback.
var _next_id_counter: int = 0
# Track manual IDs separately to prevent collisions (e.g. "man:1", "man:2")
var _manual_counter: int = 0

# ==============================================================================
# 1. INITIALIZATION & SETUP
# ==============================================================================
func _ready() -> void:
	# Inject references into the renderer
	renderer.graph_ref = graph
	renderer.selected_nodes_ref = selected_nodes
	renderer.current_path_ref = current_path
	renderer.new_nodes_ref = new_nodes
	
	# Sync initial null state
	renderer.path_start_id = ""
	renderer.path_end_id = ""
	
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
		GraphSettings.Tool.PAINT:
			current_tool = GraphToolPaint.new(self)
		GraphSettings.Tool.CUT:
			current_tool = GraphToolCut.new(self)
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
	# 1. Handle Global Shortcuts first (F, etc.)
	if event is InputEventKey and event.pressed:
		_handle_global_shortcuts(event)

	# 2. Delegate everything else to the Active Tool
	if current_tool:
		current_tool.handle_input(event)

func _handle_global_shortcuts(event: InputEventKey) -> void:
	# F: Focus Camera
	if event.keycode == KEY_F:
		_center_camera_on_graph()

# ==============================================================================
# 4. PUBLIC API FOR TOOLS
# ==============================================================================

func set_path_start(id: String) -> void:
	path_start_id = id
	renderer.path_start_id = id
	renderer.queue_redraw()

func set_path_end(id: String) -> void:
	path_end_id = id
	renderer.path_end_id = id
	renderer.queue_redraw()

func _refresh_path() -> void:
	if not path_start_id.is_empty() and not path_end_id.is_empty():
		if not graph.nodes.has(path_start_id) or not graph.nodes.has(path_end_id):
			return
		
		var path = graph.get_astar_path(path_start_id, path_end_id)
		current_path = path
		renderer.current_path_ref = current_path
	else:
		current_path.clear()
		renderer.current_path_ref = current_path
		
# --- Node Operations ---
func create_node(pos: Vector2) -> String:
	_manual_counter += 1
	var new_id = "man:%d" % _manual_counter
	
	# Safety check for collisions
	while graph.nodes.has(new_id):
		_manual_counter += 1
		new_id = "man:%d" % _manual_counter
		
	graph.add_node(new_id, pos)
	
	# Return the new ID so tools can use it!
	return new_id

func delete_node(id: String) -> void:
	graph.remove_node(id)
	
	if selected_nodes.has(id):
		selected_nodes.erase(id)
		selection_changed.emit(selected_nodes)
	
	if current_path.has(id):
		current_path.clear()
		renderer.current_path_ref = current_path
	
	if id == path_start_id:
		path_start_id = ""
		renderer.path_start_id = ""
	if id == path_end_id:
		path_end_id = ""
		renderer.path_end_id = ""
	
	renderer.queue_redraw()

# --- Selection Operations ---
func toggle_selection(id: String) -> void:
	if selected_nodes.has(id):
		selected_nodes.erase(id)
	else:
		selected_nodes.append(id)
	
	renderer.selected_nodes_ref = selected_nodes
	selection_changed.emit(selected_nodes)

func add_to_selection(id: String) -> void:
	if not selected_nodes.has(id):
		selected_nodes.append(id)

	renderer.selected_nodes_ref = selected_nodes
	selection_changed.emit(selected_nodes)

func clear_selection() -> void:
	selected_nodes.clear()
	renderer.selected_nodes_ref = selected_nodes
	selection_changed.emit(selected_nodes)

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
	
	# Reset ID Counters
	_next_id_counter = 0 
	_manual_counter = 0 
	
	# Update References
	renderer.graph_ref = graph
	
	if current_tool: 
		current_tool._graph = graph
	
	camera.reset_view()
	renderer.queue_redraw()

func load_new_graph(new_graph: Graph) -> void:
	self.graph = new_graph
	
	# Reset state
	_reset_local_state()
	
	# IMPORTANT: Reconstruct the ID state from the file
	# This ensures that if the file has "man:5", our counter starts at 5.
	_reconstruct_state_from_ids()
	
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
	var existing_ids = {}
	for id in graph.nodes:
		existing_ids[id] = true
	
	_reset_local_state()
	
	strategy.execute(graph, params)
	
	new_nodes.clear()
	var is_append = params.get("append", false)
	if is_append:
		for id in graph.nodes:
			if not existing_ids.has(id):
				new_nodes.append(id)
	
	_center_camera_on_graph()
	renderer.queue_redraw()

# ==============================================================================
# 6. INTERNAL HELPERS
# ==============================================================================

# Scans the graph for Namespaced IDs and restores the editor's counters
func _reconstruct_state_from_ids() -> void:
	# Reset to safe defaults
	_manual_counter = 0
	_next_id_counter = 0
	
	for id: String in graph.nodes:
		# 1. Handle Legacy/Fallback Integers (Just in case)
		if id.is_valid_int():
			var val = id.to_int()
			if val > _next_id_counter:
				_next_id_counter = val
				
		# 2. Handle Namespaced IDs (e.g., "man:5")
		var parts = id.split(":")
		if parts.size() >= 2:
			var id_namespace = parts[0]
			var index_part = parts[1]
			
			if id_namespace == "man" and index_part.is_valid_int():
				var val = index_part.to_int()
				if val > _manual_counter:
					_manual_counter = val
					
	# Log the restoration for debugging
	print("GraphEditor: State Reconstructed. Manual Counter reset to: ", _manual_counter)

func run_pathfinding() -> void:
	if path_start_id.is_empty() or path_end_id.is_empty():
		print("Pathfinding failed: Missing Start or End node.")
		return
		
	if not graph.nodes.has(path_start_id) or not graph.nodes.has(path_end_id):
		print("Pathfinding failed: Start or End node no longer exists.")
		return
		
	var start_time = Time.get_ticks_usec()
	var path = graph.get_astar_path(path_start_id, path_end_id)
	var end_time = Time.get_ticks_usec()
	
	current_path = path
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
