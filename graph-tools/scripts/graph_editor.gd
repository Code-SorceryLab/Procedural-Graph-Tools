extends Node2D
class_name GraphEditor

# Signal to notify the rest of the game when a new graph is loaded or generated
signal graph_loaded(new_graph: Graph)
signal selection_changed(selected_nodes: Array[String])
signal request_save_graph(graph: Graph)

# Signal to notify UI (e.g. StatusBar) when a tool wants to display info
signal status_message_changed(message: String)
signal graph_modified

# --- REFERENCES ---
@onready var renderer: GraphRenderer = $Renderer
@onready var camera: GraphCamera = $Camera

# --- DATA MODEL ---
var graph: Graph = Graph.new()

# --- STATE MANAGEMENT ---
# Tool Manager
var tool_manager: GraphToolManager

# Editor State (Public so tools can read/modify them safely)
var selected_nodes: Array[String] = []

# CHANGED: Now Arrays to support Multiple Walkers
var path_start_ids: Array[String] = []
var path_end_ids: Array[String] = []

var current_path: Array[String] = []
var new_nodes: Array[String] = [] 

# Internal counters
var _next_id_counter: int = 0
var _manual_counter: int = 0

# --- HISTORY STATE ---
var history: GraphHistory

# ==============================================================================
# 1. INITIALIZATION & SETUP
# ==============================================================================
func _ready() -> void:
	# Inject references into the renderer
	renderer.graph_ref = graph
	renderer.selected_nodes_ref = selected_nodes
	renderer.current_path_ref = current_path
	renderer.new_nodes_ref = new_nodes
	
	# --- Connect Signals for Reactive Renderer ---
	graph_modified.connect(func(): 
		renderer._depth_cache_dirty = true
		if renderer.debug_show_depth:
			renderer.queue_redraw()
	)
	
	selection_changed.connect(func(_selected_nodes):
		renderer._depth_cache_dirty = true
		if renderer.debug_show_depth:
			renderer.queue_redraw()
	)
	
	# Sync initial null state
	renderer.path_start_ids = []
	renderer.path_end_ids = []
	
	# Initialize History
	history = GraphHistory.new(graph)
	
	# Initialize Manager
	tool_manager = GraphToolManager.new(self)
	
	# Start with the default tool
	set_active_tool(GraphSettings.Tool.SELECT)
	
	renderer.queue_redraw()
	
# ==============================================================================
# 2. TOOL MANAGEMENT
# ==============================================================================
func set_active_tool(tool_id: int) -> void:
	tool_manager.set_active_tool(tool_id)

func send_status_message(message: String) -> void:
	status_message_changed.emit(message)
	
# ==============================================================================
# 3. INPUT ROUTING
# ==============================================================================
func _unhandled_input(event: InputEvent) -> void:
	# 1. Handle Global Shortcuts first
	if event is InputEventKey and event.pressed:
		_handle_global_shortcuts(event)

	# 2. Delegate to Manager
	tool_manager.handle_input(event)

func _handle_global_shortcuts(event: InputEventKey) -> void:
	# F: Focus Camera
	if event.keycode == KEY_F:
		_center_camera_on_graph()
	
	# Ctrl+S: Save
	if event.keycode == KEY_S and event.ctrl_pressed:
		request_save_graph.emit(graph)
		get_viewport().set_input_as_handled() 
		
	# Ctrl+Z / Ctrl+Y
	if event.pressed and event.ctrl_pressed:
		if event.keycode == KEY_Z:
			if event.shift_pressed:
				redo() 
			else:
				undo() 
		elif event.keycode == KEY_Y:
			redo()     

# ==============================================================================
# 4. PUBLIC API FOR TOOLS
# ==============================================================================

# CHANGED: Supports Array input for Multi-Walker
func set_path_starts(ids: Array) -> void:
	path_start_ids.assign(ids)
	renderer.path_start_ids = ids
	renderer.queue_redraw()

# CHANGED: Supports Array input
func set_path_ends(ids: Array) -> void:
	path_end_ids.assign(ids)
	renderer.path_end_ids = ids
	renderer.queue_redraw()

func _refresh_path() -> void:
	# Only pathfind if we have exactly 1 start and 1 end
	if path_start_ids.size() == 1 and path_end_ids.size() == 1:
		var start = path_start_ids[0]
		var end = path_end_ids[0]
		
		if not graph.nodes.has(start) or not graph.nodes.has(end):
			return
		
		var path = graph.get_astar_path(start, end)
		current_path = path
		renderer.current_path_ref = current_path
	else:
		current_path.clear()
		renderer.current_path_ref = current_path
		
# --- Node Operations ---
func create_node(pos: Vector2) -> String:
	_manual_counter += 1
	var new_id = "man:%d" % _manual_counter
	
	while graph.nodes.has(new_id):
		_manual_counter += 1
		new_id = "man:%d" % _manual_counter
		
	var cmd = CmdAddNode.new(graph, new_id, pos)
	_commit_command(cmd)
	
	return new_id

func delete_node(id: String) -> void:
	# 1. Validation
	if not graph.nodes.has(id):
		return
	
	# 2. Cleanup Editor State
	if selected_nodes.has(id):
		selected_nodes.erase(id)
		selection_changed.emit(selected_nodes)
	
	if current_path.has(id):
		current_path.clear()
		renderer.current_path_ref = current_path
	
	# CHANGED: Check arrays for the ID
	if path_start_ids.has(id):
		path_start_ids.erase(id)
		renderer.path_start_ids = path_start_ids
		renderer.queue_redraw()

	if path_end_ids.has(id):
		path_end_ids.erase(id)
		renderer.path_end_ids = path_end_ids
		renderer.queue_redraw()
	
	# 3. EXECUTE COMMAND
	var cmd = CmdDeleteNode.new(graph, id)
	_commit_command(cmd)

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

# --- Connection Operations ---

func connect_nodes(id_a: String, id_b: String, weight: float = 1.0) -> void:
	if graph.has_edge(id_a, id_b):
		return

	var cmd = CmdConnect.new(graph, id_a, id_b, weight)
	_commit_command(cmd)

func disconnect_nodes(id_a: String, id_b: String) -> void:
	if not graph.has_edge(id_a, id_b):
		return
		
	var weight = graph.get_edge_weight(id_a, id_b)
	
	var cmd = CmdDisconnect.new(graph, id_a, id_b, weight)
	_commit_command(cmd)

# --- Modification Operations ---

func set_node_position(id: String, new_pos: Vector2) -> void:
	graph.set_node_position(id, new_pos)
	mark_modified()
	renderer.queue_redraw()

func commit_move_batch(move_data: Dictionary) -> void:
	if move_data.is_empty():
		return
		
	var batch = CmdBatch.new(graph, "Move Nodes", false) 
	
	for id in move_data:
		var data = move_data[id]
		var old = data["from"]
		var new = data["to"]
		
		if old.distance_squared_to(new) < 0.1:
			continue
			
		var cmd = CmdMoveNode.new(graph, id, old, new)
		batch.add_command(cmd)
		
	if not batch._commands.is_empty():
		_commit_command(batch)

func set_node_type(id: String, type_index: int) -> void:
	if not graph.nodes.has(id):
		return
		
	var old_type = graph.nodes[id].type
	
	if old_type == type_index:
		return
		
	var cmd = CmdSetType.new(graph, id, old_type, type_index)
	_commit_command(cmd)

func set_node_type_bulk(ids: Array[String], type_index: int) -> void:
	print("Bulk Update called with %d nodes. Atomic Mode: %s" % [ids.size(), GraphSettings.USE_ATOMIC_UNDO])
	
	if GraphSettings.USE_ATOMIC_UNDO:
		for id in ids:
			set_node_type(id, type_index) 
		return

	var batch = CmdBatch.new(graph, "Bulk Type Change")
	var change_count = 0
	
	for id in ids:
		if not graph.nodes.has(id): continue
		
		var old_type = graph.nodes[id].type
		
		if old_type != type_index:
			var cmd = CmdSetType.new(graph, id, old_type, type_index)
			batch.add_command(cmd) 
			change_count += 1
	
	if change_count > 0:
		_commit_command(batch)

# --- TRANSACTION MANAGEMENT ---

func start_undo_transaction(action_name: String, refocus_camera: bool = true) -> void:
	history.start_transaction(action_name, refocus_camera)

func commit_undo_transaction() -> void:
	var batch = history.commit_transaction()
	if batch:
		mark_modified()

# ==============================================================================
# 5. GENERAL API
# ==============================================================================
func clear_graph() -> void:
	if graph.nodes.is_empty():
		return
		
	var batch = CmdBatch.new(graph, "Clear Graph")
	var all_ids = graph.nodes.keys()
	for id in all_ids:
		var cmd = CmdDeleteNode.new(graph, id)
		batch.add_command(cmd)
	
	_commit_command(batch)
	_reset_local_state()
	
	camera.reset_view()

func mark_modified() -> void:
	graph_modified.emit()

# --- HISTORY MANAGEMENT ---

func _commit_command(cmd: GraphCommand) -> void:
	history.add_command(cmd)
	mark_modified()
	renderer.queue_redraw()

# --- HISTORY MANAGEMENT (Undo/Redo) ---

func undo() -> void:
	var cmd = history.undo()
	
	if cmd:
		mark_modified()
		renderer.queue_redraw()
		print("Undo: %s" % cmd.get_name())
		
		if cmd is CmdBatch:
			if cmd.center_on_undo:
				_center_camera_on_graph()
			
			new_nodes.clear()
			renderer.new_nodes_ref = new_nodes
			
			# CHANGED: Clear array markers
			set_path_starts([])
			set_path_ends([])

func redo() -> void:
	var cmd = history.redo()
	
	if cmd:
		mark_modified()
		renderer.queue_redraw()
		print("Redo: %s" % cmd.get_name())
		
		if cmd is CmdBatch:
			if cmd.center_on_undo:
				_center_camera_on_graph()
				
			new_nodes.clear()
			renderer.new_nodes_ref = new_nodes
			
			# CHANGED: Clear array markers
			set_path_starts([])
			set_path_ends([])

func load_new_graph(new_graph: Graph) -> void:
	self.graph = new_graph
	history = GraphHistory.new(graph)
	_reset_local_state()
	_reconstruct_state_from_ids()
	graph_loaded.emit(graph)
	
	renderer.graph_ref = graph
	renderer.selected_nodes_ref = selected_nodes
	renderer.current_path_ref = current_path
	renderer.new_nodes_ref = new_nodes
	
	tool_manager.update_tool_graph_reference(graph)
		
	_center_camera_on_graph()
	renderer.queue_redraw()

func apply_strategy(strategy: GraphStrategy, params: Dictionary) -> void:
	var existing_ids = {}
	for id in graph.nodes:
		existing_ids[id] = true
	
	_reset_local_state()

	var batch = StrategyExecutor.execute(self, strategy, params)
	
	if batch:
		_commit_command(batch)
		StrategyExecutor.process_visualization(self, params, existing_ids)
		_center_camera_on_graph()

# ==============================================================================
# 6. INTERNAL HELPERS
# ==============================================================================

func _reconstruct_state_from_ids() -> void:
	_manual_counter = 0
	_next_id_counter = 0
	
	for id: String in graph.nodes:
		if id.is_valid_int():
			var val = id.to_int()
			if val > _next_id_counter:
				_next_id_counter = val
				
		var parts = id.split(":")
		if parts.size() >= 2:
			var id_namespace = parts[0]
			var index_part = parts[1]
			
			if id_namespace == "man" and index_part.is_valid_int():
				var val = index_part.to_int()
				if val > _manual_counter:
					_manual_counter = val
					
	print("GraphEditor: State Reconstructed. Manual Counter reset to: ", _manual_counter)

func run_pathfinding() -> void:
	_refresh_path()
	
	if not current_path.is_empty():
		print("A* Path found: %d nodes" % [current_path.size()])

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
	
	# CHANGED: Clear array markers
	path_start_ids.clear()
	path_end_ids.clear()
	
	renderer.selected_nodes_ref = selected_nodes
	renderer.current_path_ref = current_path
	renderer.path_start_ids = []
	renderer.path_end_ids = []
