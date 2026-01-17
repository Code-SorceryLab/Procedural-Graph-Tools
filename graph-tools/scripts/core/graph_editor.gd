extends Node2D
class_name GraphEditor

# --- SIGNALS ---
signal graph_loaded(new_graph: Graph)
signal selection_changed(selected_nodes: Array[String])
signal edge_selection_changed(selected_edges: Array)
signal request_save_graph(graph: Graph)
signal graph_modified

# UI Focus Requests
signal request_inspector_view
signal request_agent_tab_view(filter_node_id: String)

# --- REFERENCES ---
@onready var grid_renderer: GridRenderer = $Grid
@onready var renderer: GraphRenderer = $Renderer
@onready var camera: GraphCamera = $Camera

# --- DATA MODEL ---
var graph: Graph = Graph.new()

# --- PHYSICS/LOGIC ENGINE ---
var simulation: Simulation

# --- STATE MANAGEMENT ---
var tool_manager: GraphToolManager
var is_picking_mode: bool = false
var _pick_callback: Callable

# Editor State (Public)
var selected_nodes: Array[String] = []
var selected_edges: Array = []
var selected_agent_ids: Array = []
var selected_zones: Array = [] # Stores Objects

# Tool Visualization Proxy
var tool_overlay_rect: Rect2 = Rect2():
	set(value):
		tool_overlay_rect = value
		if renderer:
			renderer.selection_rect = value
			renderer.queue_redraw()

# Arrays to support Multiple Walkers
var path_start_ids: Array[String] = []
var path_end_ids: Array[String] = []
var current_path: Array[String] = []
var new_nodes: Array[String] = [] 
var node_labels: Dictionary = {}

# Internal counters
var _next_id_counter: int = 0
var _manual_counter: int = 0

# --- HISTORY STATE ---
var history: GraphHistory
var clipboard: GraphClipboard
var input_handler: GraphInputHandler

# ==============================================================================
# 1. INITIALIZATION & SETUP
# ==============================================================================

func _init() -> void:
	tool_manager = GraphToolManager.new(self)

func _ready() -> void:
	# Inject references into the renderer
	renderer.graph_ref = graph
	renderer.selected_nodes_ref = selected_nodes
	renderer.selected_edges_ref = selected_edges
	renderer.current_path_ref = current_path
	renderer.new_nodes_ref = new_nodes
	renderer.node_labels_ref = node_labels
	renderer.selected_agent_ids_ref = selected_agent_ids
	
	# Initialize the Simulation Engine
	simulation = Simulation.new(graph)
	
	if grid_renderer:
		grid_renderer.camera_ref = camera
	
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
	
	edge_selection_changed.connect(func(_edges):
		renderer.queue_redraw()
	)
	
	# Sync initial null state
	renderer.path_start_ids = []
	renderer.path_end_ids = []
	
	history = GraphHistory.new(graph)
	clipboard = GraphClipboard.new(self)
	input_handler = GraphInputHandler.new(self, clipboard)
	
	set_active_tool(GraphSettings.Tool.SELECT)
	renderer.queue_redraw()

# ==============================================================================
# 2. TOOL MANAGEMENT
# ==============================================================================

func set_active_tool(tool_id: int) -> void:
	tool_manager.set_active_tool(tool_id)
	SignalManager.active_tool_changed.emit(tool_id)

func send_status_message(message: String) -> void:
	SignalManager.status_message_changed.emit(message)
	
# ==============================================================================
# 3. INPUT ROUTING
# ==============================================================================

func _unhandled_input(event: InputEvent) -> void:
	# 1. Global Shortcuts (Undo/Redo)
	input_handler.handle_input(event)
	if get_viewport().is_input_handled(): return

	# 2. Picking Mode Interception (Prioritize this over Tools)
	if is_picking_mode:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var mouse_pos = get_global_mouse_position() 
			if camera:
				mouse_pos = camera.get_global_mouse_position()
				
			var hit_id = graph.get_node_at_position(mouse_pos, GraphSettings.NODE_RADIUS * 1.5)
			
			if hit_id != "":
				_handle_node_picked(hit_id)
				get_viewport().set_input_as_handled()
				return
			else:
				is_picking_mode = false
				send_status_message("Picking cancelled.")
				get_viewport().set_input_as_handled()
				return

	# 3. Tool Logic (Normal operation)
	tool_manager.handle_input(event)

# ==============================================================================
# 4. PUBLIC API FOR TOOLS
# ==============================================================================

func set_path_starts(ids: Array) -> void:
	path_start_ids.assign(ids)
	renderer.path_start_ids = ids
	renderer.queue_redraw()

func set_path_ends(ids: Array) -> void:
	path_end_ids.assign(ids)
	renderer.path_end_ids = ids
	renderer.queue_redraw()

func _refresh_path(algo_index: int = 3) -> void:
	if path_start_ids.size() == 1 and path_end_ids.size() == 1:
		var start = path_start_ids[0]
		var end = path_end_ids[0]
		
		if not graph.nodes.has(start) or not graph.nodes.has(end):
			return
		
		current_path = AgentNavigator.get_projected_path(start, end, algo_index, graph)
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
	if not graph.nodes.has(id): return
	
	# 2. Cleanup Editor State
	if selected_nodes.has(id):
		selected_nodes.erase(id)
		selection_changed.emit(selected_nodes)
	
	if current_path.has(id):
		current_path.clear()
		renderer.current_path_ref = current_path
	
	if path_start_ids.has(id):
		path_start_ids.erase(id)
		renderer.path_start_ids = path_start_ids
		renderer.queue_redraw()

	if path_end_ids.has(id):
		path_end_ids.erase(id)
		renderer.path_end_ids = path_end_ids
		renderer.queue_redraw()
	
	# 3. EXECUTE COMMAND (BATCH)
	var batch = CmdBatch.new(graph, "Delete Node & Agents")
	
	var agents_on_node = []
	if "agents" in graph:
		for agent in graph.agents:
			if agent.current_node_id == id:
				agents_on_node.append(agent)
	
	for agent in agents_on_node:
		var cmd_agent = CmdRemoveAgent.new(graph, agent)
		batch.add_command(cmd_agent)
	
	var cmd_node = CmdDeleteNode.new(graph, id)
	batch.add_command(cmd_node)
	
	_commit_command(batch)

# --- Agent Operations ---

func add_agent(agent) -> void:
	var cmd = CmdAddAgent.new(graph, agent)
	_commit_command(cmd)

func remove_agent(agent) -> void:
	var cmd = CmdRemoveAgent.new(graph, agent)
	_commit_command(cmd)

# --- Selection Operations ---

func set_selection_batch(nodes: Array[String], edges: Array, clear_existing: bool = true) -> void:
	if clear_existing:
		selected_nodes.clear()
		selected_edges.clear()
		
		# Selecting nodes implies clearing Agent selection
		selected_agent_ids.clear()
		renderer.selected_agent_ids_ref = selected_agent_ids
		SignalManager.agent_selection_changed.emit([])
		
	selected_nodes.append_array(nodes)
	
	# Defensive sorting logic: Ensure keys match Graph format [A, B]
	for pair in edges:
		pair.sort()
		selected_edges.append(pair)
	
	renderer.selected_nodes_ref = selected_nodes
	renderer.selected_edges_ref = selected_edges
	
	# [CRITICAL ORDER] Emit Edges FIRST to prevent Inspector race conditions
	edge_selection_changed.emit(selected_edges)
	selection_changed.emit(selected_nodes)
	
	renderer.queue_redraw()

func request_node_pick(callback: Callable) -> void:
	is_picking_mode = true
	_pick_callback = callback
	send_status_message("Pick a target node...")

func _handle_node_picked(id: String) -> void:
	if is_picking_mode:
		is_picking_mode = false
		if _pick_callback.is_valid():
			_pick_callback.call(id)
		send_status_message("Target Set: " + id)
		return

func toggle_selection(id: String) -> void:
	if is_picking_mode:
		_handle_node_picked(id)
		return
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

func add_edge_selection(edge_pair: Array) -> void:
	edge_pair.sort()
	if not selected_edges.has(edge_pair):
		selected_edges.append(edge_pair)
		renderer.selected_edges_ref = selected_edges
		edge_selection_changed.emit(selected_edges)

func is_edge_selected(pair: Array) -> bool:
	pair.sort() 
	return selected_edges.has(pair)

# AGENT SELECTION API

func set_agent_selection(agents: Array, clear_nodes: bool = true) -> void:
	if clear_nodes:
		selected_nodes.clear()
		selected_edges.clear()
		
		renderer.selected_nodes_ref = selected_nodes
		renderer.selected_edges_ref = selected_edges
		
		selection_changed.emit(selected_nodes)
		edge_selection_changed.emit(selected_edges)
		
	selected_agent_ids = agents
	renderer.selected_agent_ids_ref = selected_agent_ids
	
	SignalManager.agent_selection_changed.emit(selected_agent_ids)
	renderer.queue_redraw()

func clear_selection() -> void:
	selected_nodes.clear()
	renderer.selected_nodes_ref = selected_nodes
	selection_changed.emit(selected_nodes)
	
	selected_edges.clear()
	renderer.selected_edges_ref = selected_edges
	edge_selection_changed.emit(selected_edges)
	
	selected_agent_ids.clear()
	renderer.selected_agent_ids_ref = selected_agent_ids
	SignalManager.agent_selection_changed.emit(selected_agent_ids)

# Edge Selection API

func toggle_edge_selection(edge_pair: Array) -> void:
	edge_pair.sort()
	if selected_edges.has(edge_pair):
		selected_edges.erase(edge_pair)
	else:
		selected_edges.append(edge_pair)
	
	renderer.selected_edges_ref = selected_edges
	edge_selection_changed.emit(selected_edges)

func set_edge_selection(edge_pair: Array) -> void:
	edge_pair.sort()
	
	# Do NOT re-assign the variable. Clear and Append to maintain reference.
	selected_edges.clear()
	selected_edges.append(edge_pair)
	
	renderer.selected_edges_ref = selected_edges 
	edge_selection_changed.emit(selected_edges)
	renderer.queue_redraw()

# --- ZONE API ---

func add_zone(zone: GraphZone) -> void:
	var cmd = CmdAddZone.new(graph, zone)
	_commit_command(cmd)

func remove_zone(zone: GraphZone) -> void:
	if not graph.zones.has(zone): return
	
	var cmd = CmdRemoveZone.new(graph, zone)
	_commit_command(cmd)
	
	# Handle Side Effects (Deselection)
	if selected_zones.has(zone):
		selected_zones.erase(zone)
		set_zone_selection(selected_zones)

func set_zone_selection(zones: Array, clear_others: bool = true) -> void:
	if clear_others:
		selected_nodes.clear()
		selected_edges.clear()
		renderer.selected_nodes_ref = []
		renderer.selected_edges_ref = []
		
		var empty_nodes: Array[String] = []
		selection_changed.emit(empty_nodes)
		edge_selection_changed.emit([])
		
		selected_agent_ids.clear()
		renderer.selected_agent_ids_ref = []
		SignalManager.agent_selection_changed.emit([])
		
	selected_zones = zones
	
	if renderer:
		renderer.selected_zones_ref = selected_zones
	
	SignalManager.zone_selection_changed.emit(selected_zones)
	renderer.queue_redraw()

# --- Connection Operations ---

func connect_nodes(id_a: String, id_b: String, weight: float = 1.0) -> void:
	if graph.has_edge(id_a, id_b): return
	var cmd = CmdConnect.new(graph, id_a, id_b, weight)
	_commit_command(cmd)

func disconnect_nodes(id_a: String, id_b: String) -> void:
	if not graph.has_edge(id_a, id_b): return
	var weight = graph.get_edge_weight(id_a, id_b)
	var cmd = CmdDisconnect.new(graph, id_a, id_b, weight)
	_commit_command(cmd)

# --- Modification Operations ---

func set_node_position(id: String, new_pos: Vector2, is_preview: bool = false) -> void:
	graph.set_node_position(id, new_pos)
	
	if is_preview:
		renderer.queue_redraw()
	else:
		mark_modified()
		renderer.queue_redraw()

func modify_zone_cells(zone: GraphZone, cells_to_add: Array[Vector2i], cells_to_remove: Array[Vector2i]) -> void:
	if not graph.zones.has(zone): return
	
	var valid_adds: Array[Vector2i] = []
	var valid_removes: Array[Vector2i] = []
	
	if not cells_to_add.is_empty():
		for cell in cells_to_add:
			if not zone.has_cell(cell): valid_adds.append(cell)
				
	if not cells_to_remove.is_empty():
		for cell in cells_to_remove:
			if zone.has_cell(cell): valid_removes.append(cell)
	
	if valid_adds.is_empty() and valid_removes.is_empty(): return
	
	var cmd = CmdZoneEdit.new(graph, zone, valid_adds, valid_removes)
	_commit_command(cmd)

func _refresh_nodes_in_modified_zone_area(zone: GraphZone, changed_cells: Array[Vector2i]) -> void:
	if zone.zone_type != GraphZone.ZoneType.GEOGRAPHICAL: return
	if changed_cells.is_empty(): return

	var spacing = GraphSettings.GRID_SPACING
	var changed_lookup = {}
	for cell in changed_cells:
		changed_lookup[cell] = true
		
	for id in graph.nodes:
		var pos = graph.nodes[id].position
		var grid_pos = Vector2i(round(pos.x / spacing.x), round(pos.y / spacing.y))
		
		if changed_lookup.has(grid_pos):
			if zone.has_cell(grid_pos):
				if not zone.registered_nodes.has(id):
					zone.register_node(id)
			else:
				if zone.registered_nodes.has(id):
					zone.unregister_node(id)

func commit_move_batch(move_data: Dictionary) -> void:
	if move_data.is_empty(): return
	var batch = CmdBatch.new(graph, "Move Nodes", false) 
	
	for id in move_data:
		var data = move_data[id]
		var old = data["from"]
		var new = data["to"]
		if old.distance_squared_to(new) < 0.1: continue
		var cmd = CmdMoveNode.new(graph, id, old, new)
		batch.add_command(cmd)
		
	if not batch._commands.is_empty():
		_commit_command(batch)

func set_node_type(id: String, type_index: int) -> void:
	if not graph.nodes.has(id): return
	var old_type = graph.nodes[id].type
	if old_type == type_index: return
	var cmd = CmdSetType.new(graph, id, old_type, type_index)
	_commit_command(cmd)

func set_node_type_bulk(ids: Array[String], type_index: int) -> void:
	if GraphSettings.USE_ATOMIC_UNDO:
		for id in ids: set_node_type(id, type_index) 
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

func set_node_labels(labels: Dictionary) -> void:
	node_labels = labels
	if renderer:
		renderer.node_labels_ref = node_labels
		renderer.queue_redraw()

func set_edge_weight(id_a: String, id_b: String, weight: float) -> void:
	if not graph.has_edge(id_a, id_b): return
	var current_w = graph.get_edge_weight(id_a, id_b)
	if is_equal_approx(current_w, weight): return
	var cmd = CmdSetEdgeWeight.new(graph, id_a, id_b, weight)
	_commit_command(cmd)

func set_edge_directionality(id_a: String, id_b: String, mode: int) -> void:
	var has_ab = graph.has_edge(id_a, id_b)
	var has_ba = graph.has_edge(id_b, id_a)
	
	var current_mode = 0 # Bi-Dir
	if has_ab and not has_ba: current_mode = 1
	if not has_ab and has_ba: current_mode = 2
	
	if current_mode == mode: return
	var cmd = CmdSetEdgeDirection.new(graph, id_a, id_b, mode)
	_commit_command(cmd)

func set_edge_property(id_a: String, id_b: String, key: String, value: Variant) -> void:
	if not graph.has_edge(id_a, id_b): return
	
	var current_data = graph.get_edge_data(id_a, id_b)
	var old_value = current_data.get(key)
	
	if str(value) == str(old_value): return
	
	var cmd = CmdSetEdgeProperty.new(graph, id_a, id_b, key, value, old_value)
	_commit_command(cmd)

func get_edge_property(id_a: String, id_b: String, key: String, default: Variant = null) -> Variant:
	if graph.has_edge(id_a, id_b):
		var d = graph.get_edge_data(id_a, id_b)
		return d.get(key, default)
	elif graph.has_edge(id_b, id_a):
		var d = graph.get_edge_data(id_b, id_a)
		return d.get(key, default)
	return default

# --- TRANSACTION MANAGEMENT ---

func start_undo_transaction(action_name: String, refocus_camera: bool = true) -> void:
	history.start_transaction(action_name, refocus_camera)

func commit_undo_transaction() -> void:
	var batch = history.commit_transaction()
	if batch: mark_modified()

# ==============================================================================
# 5. GENERAL API
# ==============================================================================
func clear_graph() -> void:
	if graph.nodes.is_empty() and graph.zones.is_empty(): return
	var batch = CmdBatch.new(graph, "Clear Graph")
	for id in graph.nodes:
		var cmd = CmdDeleteNode.new(graph, id)
		batch.add_command(cmd)
	graph.zones.clear() 
	_commit_command(batch)
	_reset_local_state()
	camera.reset_view()

func mark_modified() -> void:
	graph_modified.emit()

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
		if cmd is CmdBatch:
			if cmd.center_on_undo:
				_center_camera_on_graph()
			new_nodes.clear()
			renderer.new_nodes_ref = new_nodes
			set_path_starts([])
			set_path_ends([])

func redo() -> void:
	var cmd = history.redo()
	if cmd:
		mark_modified()
		renderer.queue_redraw()
		if cmd is CmdBatch:
			if cmd.center_on_undo:
				_center_camera_on_graph()
			new_nodes.clear()
			renderer.new_nodes_ref = new_nodes
			set_path_starts([])
			set_path_ends([])

func load_new_graph(new_graph: Graph) -> void:
	self.graph = new_graph
	history = GraphHistory.new(graph)
	simulation = Simulation.new(graph)
	
	_reset_local_state()
	_reconstruct_state_from_ids()
	
	graph_loaded.emit(graph)
	
	renderer.graph_ref = graph
	renderer.selected_nodes_ref = selected_nodes
	renderer.current_path_ref = current_path
	renderer.new_nodes_ref = new_nodes
	
	if tool_manager:
		tool_manager.set_active_tool(tool_manager.active_tool_id)
		
	_center_camera_on_graph()
	renderer.queue_redraw()

func apply_strategy(strategy: GraphStrategy, params: Dictionary) -> void:
	var existing_ids = {}
	for id in graph.nodes: existing_ids[id] = true
	_reset_local_state()

	var batch = StrategyExecutor.execute(self, strategy, params)
	
	if batch and not batch._commands.is_empty():
		_commit_command(batch)
		_center_camera_on_graph()
	
	StrategyExecutor.process_visualization(self, params, existing_ids)

# ==============================================================================
# 6. INTERNAL HELPERS
# ==============================================================================

func _reconstruct_state_from_ids() -> void:
	_manual_counter = 0
	_next_id_counter = 0
	
	for id: String in graph.nodes:
		if id.is_valid_int():
			var val = id.to_int()
			if val > _next_id_counter: _next_id_counter = val
				
		var parts = id.split(":")
		if parts.size() >= 2:
			var id_namespace = parts[0]
			var index_part = parts[1]
			
			if id_namespace == "man" and index_part.is_valid_int():
				var val = index_part.to_int()
				if val > _manual_counter: _manual_counter = val
					
	print("GraphEditor: State Reconstructed. Manual Counter reset to: ", _manual_counter)

func run_pathfinding(algo_index: int = 3) -> void:
	_refresh_path(algo_index)

func _center_camera_on_graph() -> void:
	if graph.nodes.is_empty(): return
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
	path_start_ids.clear()
	path_end_ids.clear()
	selected_agent_ids.clear()
	selected_edges.clear() # Correctly clear edges too
	
	renderer.selected_nodes_ref = selected_nodes
	renderer.current_path_ref = current_path
	renderer.selected_edges_ref = selected_edges # Sync this!
	renderer.selected_agent_ids_ref = selected_agent_ids
	renderer.path_start_ids = []
	renderer.path_end_ids = []
