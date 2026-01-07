extends Node2D
class_name GraphEditor

# Signal to notify the rest of the game when a new graph is loaded or generated
signal graph_loaded(new_graph: Graph)
signal selection_changed(selected_nodes: Array[String])
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
	
	# Sync initial null state
	renderer.path_start_id = ""
	renderer.path_end_id = ""
	
	# Initialize History
	history = GraphHistory.new(graph)
	
	# Initialize Manager
	tool_manager = GraphToolManager.new(self)
	
	# Start with the default tool
	set_active_tool(GraphSettings.Tool.SELECT)
	
	renderer.queue_redraw()
	
	
	
# ==============================================================================
# 2. TOOL MANAGEMENT (The State Machine Factory)
# ==============================================================================
func set_active_tool(tool_id: int) -> void:
	tool_manager.set_active_tool(tool_id)

# Public API for tools to call
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
		
	# Ctrl+Z / Ctrl+Y
	if event.pressed and event.ctrl_pressed:
		if event.keycode == KEY_Z:
			if event.shift_pressed:
				redo() # Ctrl+Shift+Z
			else:
				undo() # Ctrl+Z
		elif event.keycode == KEY_Y:
			redo()     # Ctrl+Y

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
	
	# Safety check loop
	while graph.nodes.has(new_id):
		_manual_counter += 1
		new_id = "man:%d" % _manual_counter
		
	# --- NEW: Use Command Pattern ---
	# We pass the graph, the determined ID, and the position.
	# The command handles the actual graph.add_node() call.
	var cmd = CmdAddNode.new(graph, new_id, pos)
	_commit_command(cmd)
	
	return new_id

func delete_node(id: String) -> void:
	# 1. Validation
	if not graph.nodes.has(id):
		return
	
	# 2. Cleanup Editor State (Selection/Pathfinding)
	# We still do this manually because the Command only knows about Data, not Editor UI state.
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
	# Check if edge already exists to prevent duplicate stack entries
	if graph.has_edge(id_a, id_b):
		return

	var cmd = CmdConnect.new(graph, id_a, id_b, weight)
	_commit_command(cmd)

func disconnect_nodes(id_a: String, id_b: String) -> void:
	# 1. Validation: Does the edge exist?
	if not graph.has_edge(id_a, id_b):
		return
		
	# 2. Capture State: Get weight before destruction!
	var weight = graph.get_edge_weight(id_a, id_b)
	
	# 3. Create Command
	var cmd = CmdDisconnect.new(graph, id_a, id_b, weight)
	_commit_command(cmd)

# --- Modification Operations ---

# Existing function (Used for visual updates during drag)
func set_node_position(id: String, new_pos: Vector2) -> void:
	graph.set_node_position(id, new_pos)
	mark_modified()
	renderer.queue_redraw()

# NEW: Call this ONCE when the mouse is released
# move_data format: { "node_id": { "from": Vector2, "to": Vector2 } }
func commit_move_batch(move_data: Dictionary) -> void:
	if move_data.is_empty():
		return
		
	var batch = CmdBatch.new(graph, "Move Nodes", false) # False = Don't recenter camera
	
	for id in move_data:
		var data = move_data[id]
		var old = data["from"]
		var new = data["to"]
		
		# Optimization: Ignore microscopic moves (jitter)
		if old.distance_squared_to(new) < 0.1:
			continue
			
		var cmd = CmdMoveNode.new(graph, id, old, new)
		batch.add_command(cmd)
		
	if not batch._commands.is_empty():
		_commit_command(batch)

func set_node_type(id: String, type_index: int) -> void:
	if not graph.nodes.has(id):
		return
		
	# 1. Capture Old State
	var old_type = graph.nodes[id].type
	
	# Optimization: Don't clutter history if nothing changed
	if old_type == type_index:
		return
		
	# 2. Create & Commit Command
	var cmd = CmdSetType.new(graph, id, old_type, type_index)
	_commit_command(cmd)

func set_node_type_bulk(ids: Array[String], type_index: int) -> void:
	
	print("Bulk Update called with %d nodes. Atomic Mode: %s" % [ids.size(), GraphSettings.USE_ATOMIC_UNDO])
	
	# 1. ATOMIC MODE CHECK
	if GraphSettings.USE_ATOMIC_UNDO:
		for id in ids:
			set_node_type(id, type_index) # <--- This creates individual Undo steps
		return

	# 2. BATCH MODE (Default)
	var batch = CmdBatch.new(graph, "Bulk Type Change")
	var change_count = 0
	
	for id in ids:
		if not graph.nodes.has(id): continue
		
		var old_type = graph.nodes[id].type
		
		if old_type != type_index:
			# --- CRITICAL CHECK ---
			# Ensure you are creating the command manually:
			var cmd = CmdSetType.new(graph, id, old_type, type_index)
			batch.add_command(cmd) # <--- Add to batch, DO NOT execute/commit yet
			change_count += 1
			# DO NOT call set_node_type(id, type_index) here!
	
	# 3. Commit ONCE
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
# 5. GENERAL API (Called by GamePlayer / UI)
# ==============================================================================
func clear_graph() -> void:
	if graph.nodes.is_empty():
		return
		
	# 1. Create a Batch Command
	var batch = CmdBatch.new(graph, "Clear Graph")
	
	# 2. Add a Delete Command for EVERY node
	# We iterate through all IDs and queue them for deletion.
	# CmdDeleteNode handles the edge cleanup automatically.
	var all_ids = graph.nodes.keys()
	for id in all_ids:
		var cmd = CmdDeleteNode.new(graph, id)
		batch.add_command(cmd)
	
	# 3. Commit
	# This executes the batch immediately, clearing the graph visual and data.
	_commit_command(batch)
	
	# 4. Reset Local State
	# We clean up the Editor's "pointer" references, but we DO NOT reset 
	# the 'graph' variable itself. The object instance persists.
	_reset_local_state()
	
	# Note: We do NOT reset _manual_counter here. 
	# Why? If we Undo the Clear, we want to ensure new nodes don't collide 
	# with the restored ones (though create_node has safety checks for that anyway).
	
	camera.reset_view()
	# queue_redraw and mark_modified handled by _commit_command

# Call this whenever a strategy finishes or a tool commits an action
func mark_modified() -> void:
	graph_modified.emit()

# --- HISTORY MANAGEMENT ---

func _commit_command(cmd: GraphCommand) -> void:
	# Delegate logic to History class
	history.add_command(cmd)
	
	# UI Updates
	mark_modified()
	renderer.queue_redraw()
	# print("Command Executed: %s" % cmd.get_name())

# --- HISTORY MANAGEMENT (Undo/Redo) ---

func undo() -> void:
	# 1. Ask History to perform the logic
	var cmd = history.undo()
	
	# 2. If valid, update the UI
	if cmd:
		mark_modified()
		renderer.queue_redraw()
		print("Undo: %s" % cmd.get_name())
		
		# --- BATCH UI HANDLING ---
		if cmd is CmdBatch:
			if cmd.center_on_undo:
				_center_camera_on_graph()
			
			# Clear visual artifacts (Cyan nodes / Rings)
			new_nodes.clear()
			renderer.new_nodes_ref = new_nodes
			set_path_start("")
			set_path_end("")

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
			set_path_start("")
			set_path_end("")

func load_new_graph(new_graph: Graph) -> void:
	self.graph = new_graph
	
	# Re-initialize history with the new graph reference
	history = GraphHistory.new(graph)
	
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
	
	# Update Tool Manager
	tool_manager.update_tool_graph_reference(graph)
		
	_center_camera_on_graph()
	renderer.queue_redraw()

func apply_strategy(strategy: GraphStrategy, params: Dictionary) -> void:
	# 1. Snapshot state (for the Diff logic later)
	var existing_ids = {}
	for id in graph.nodes:
		existing_ids[id] = true
	
	_reset_local_state()

	# 2. Execute Strategy (Logic Phase)
	var batch = StrategyExecutor.execute(self, strategy, params)
	
	# 3. Commit (Data Phase)
	if batch:
		_commit_command(batch)
		
		# 4. Visualize (Visual Phase)
		# We pass the snapshot so the executor knows what is "new"
		StrategyExecutor.process_visualization(self, params, existing_ids)
		
		_center_camera_on_graph()

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
