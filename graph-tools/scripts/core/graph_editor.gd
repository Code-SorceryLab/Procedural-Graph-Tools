extends Node2D
class_name GraphEditor

# --- SIGNALS ---
signal graph_loaded(new_graph: Graph)
signal selection_changed(selected_nodes: Array[String])
signal trigger_mask_saved(trigger_id: String, nodes: Array, edges: Array)
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

# --- PHYSICS & LOGIC ENGINE ---
var simulation: Simulation
var buoyancy_engine: BuoyancyEngine

# --- STATE MANAGEMENT ---
var tool_manager: GraphToolManager
var is_picking_mode: bool = false
var _pick_callback: Callable
var _transaction_depth: int = 0
var is_masking_trigger: bool = false
var _active_mask_trigger_id: String = ""
var _masking_banner: PanelContainer

# File State
var current_file_path: String = "" # Tracks the active save file!

# Physics State
var is_buoyancy_active: bool = false
var _buoyancy_snapshot: Dictionary = {} # Stores starting positions to build Undo batch
var _buoyancy_transaction_open: bool = false
var _physics_accumulator: float = 0.0

const PHYSICS_TICK_RATE: float = 1.0 / 45.0 # 45 FPS target

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
	buoyancy_engine = BuoyancyEngine.new()
	
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
		
	# Connect the Observer
	# When History changes, tell Simulation to check its sanity
	history.history_changed.connect(simulation.validate_all_agents)
	clipboard = GraphClipboard.new(self)
	input_handler = GraphInputHandler.new(self, clipboard)
	
	set_active_tool(GraphSettings.Tool.SELECT)
	renderer.queue_redraw()

func _process(delta: float) -> void:
	if not is_buoyancy_active or not buoyancy_engine: return
	
	# --- TICK DECOUPLING ---
	_physics_accumulator += delta
	if _physics_accumulator < PHYSICS_TICK_RATE:
		return # Skip the math and the heavy redraw this frame!
		
	# Pass the accumulated time to the engine so the physics math stays mathematically accurate
	var destruction_report = buoyancy_engine.step(graph, _physics_accumulator)
	_physics_accumulator = 0.0 # Reset
	
	# Only queue a massive screen redraw when physics actually stepped!
	if renderer: renderer.queue_redraw()
	
	# --- PROCESS DESTRUCTIVE PHYSICS SAFELY ---
	var has_damage = destruction_report["snapped_edges"].size() > 0 or destruction_report["fused_nodes"].size() > 0
	
	if has_damage:
		start_undo_transaction("Physics Destruction")
		
		for pair in destruction_report["snapped_edges"]:
			disconnect_nodes(pair[0], pair[1])
			
		for pair in destruction_report["fused_nodes"]:
			var scrap_id = pair[1]
			delete_node(scrap_id)
			
			if _buoyancy_snapshot.has(scrap_id):
				_buoyancy_snapshot.erase(scrap_id)
			if buoyancy_engine._velocities.has(scrap_id):
				buoyancy_engine._velocities.erase(scrap_id)
				
		commit_undo_transaction()

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
# 4. TRIGGER MASKING OVERLAY
# ==============================================================================

func _setup_masking_banner() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100 # Float above absolutely everything
	add_child(canvas)
	
	_masking_banner = PanelContainer.new()
	_masking_banner.visible = false
	
	# Center it at the top of the screen
	_masking_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.8, 0.3, 0.0, 0.9) # Bright warning orange!
	style.set_corner_radius_all(8)
	_masking_banner.add_theme_stylebox_override("panel", style)
	
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var lbl = Label.new()
	lbl.text = "Recording Target Mask for Trigger... Select Nodes & Edges."
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_font_size_override("font_size", 16)
	hbox.add_child(lbl)
	
	var btn_save = Button.new()
	btn_save.text = "Save Mask"
	btn_save.pressed.connect(func(): _finish_trigger_masking(true))
	hbox.add_child(btn_save)
	
	var btn_cancel = Button.new()
	btn_cancel.text = "Cancel"
	btn_cancel.pressed.connect(func(): _finish_trigger_masking(false))
	hbox.add_child(btn_cancel)
	
	margin.add_child(hbox)
	_masking_banner.add_child(margin)
	canvas.add_child(_masking_banner)

func start_trigger_masking(trigger_id: String, existing_nodes: Array, existing_edges: Array) -> void:
	if not _masking_banner: _setup_masking_banner()
	
	is_masking_trigger = true
	_active_mask_trigger_id = trigger_id
	_masking_banner.visible = true
	
	# Force the active tool to Select so they don't accidentally delete things!
	set_active_tool(GraphSettings.Tool.SELECT)
	
	# Pre-load the trigger's existing selection into the editor!
	# We format the string array to match the editor's typed array requirement.
	var typed_nodes: Array[String] = []
	for n in existing_nodes: typed_nodes.append(str(n))
	set_selection_batch(typed_nodes, existing_edges)
	
	renderer.is_masking_trigger_ref = true
	renderer.queue_redraw()

func _finish_trigger_masking(save: bool) -> void:
	is_masking_trigger = false
	_masking_banner.visible = false
	renderer.is_masking_trigger_ref = false
	
	if save:
		trigger_mask_saved.emit(_active_mask_trigger_id, selected_nodes.duplicate(), selected_edges.duplicate())
		
	clear_selection()
	renderer.queue_redraw()

# ==============================================================================
# 5. PUBLIC API FOR TOOLS
# ==============================================================================

func set_path_starts(ids: Array) -> void:
	path_start_ids.assign(ids)
	renderer.path_start_ids = ids
	renderer.queue_redraw()

func set_path_ends(ids: Array) -> void:
	path_end_ids.assign(ids)
	renderer.path_end_ids = ids
	renderer.queue_redraw()

func set_action_edges(edges: Array) -> void:
	if renderer:
		renderer.highlighted_action_edges_ref = edges
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

func set_agent_breadcrumbs(paths: Array) -> void:
	if renderer:
		renderer.agent_breadcrumbs_ref = paths
		renderer.queue_redraw()

func set_solver_debug_overlay(enabled: bool) -> void:
	if renderer:
		renderer.show_solver_debug_overlay = enabled
		renderer.queue_redraw()

func set_solver_key_inventory_overlay(enabled: bool) -> void:
	if renderer:
		renderer.show_solver_key_inventory = enabled
		renderer.queue_redraw()

func set_agent_breadcrumbs_overlay(enabled: bool) -> void:
	if renderer:
		renderer.show_agent_breadcrumbs = enabled
		renderer.queue_redraw()

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

func clear_agents() -> void:
	if graph.agents.is_empty(): return
	start_undo_transaction("Clear Agents")
	for agent in graph.agents.duplicate():
		remove_agent(agent)
	commit_undo_transaction()

# Safe Accessor
func get_agents() -> Array:
	return graph.agents

# Undoable Agent Mutation
func set_agent_property(agent: Object, key: String, value: Variant) -> void:
	if not is_instance_valid(agent) or not graph.agents.has(agent): return
	
	var old_value = null
	if key in agent:
		old_value = agent.get(key)
	else:
		old_value = agent.custom_data.get(key)
		
	if str(value) == str(old_value): return
	
	var cmd = CmdSetProperty.new(graph, "AGENT", agent, key, value, old_value)
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

	selected_zones.clear()
	renderer.selected_zones_ref = selected_zones
	SignalManager.zone_selection_changed.emit(selected_zones)

# --- HOVER STATE API ---

func set_hovered_node(id: String) -> void:
	if not renderer: return
	if renderer.hovered_id != id:
		renderer.hovered_id = id
		renderer.queue_redraw()

func set_hovered_edge(pair: Array) -> void:
	if not renderer: return
	
	# Edges must be sorted to ensure [A, B] matches [B, A]
	var sorted_pair = pair.duplicate()
	sorted_pair.sort()
	
	if renderer.hovered_edge_ref != sorted_pair:
		renderer.hovered_edge_ref = sorted_pair
		renderer.queue_redraw()

func set_hovered_agent(agent: Object) -> void:
	if not renderer: return
	if renderer.hovered_agent_ref != agent:
		renderer.hovered_agent_ref = agent
		renderer.queue_redraw()

func set_hovered_zone(zone: Object) -> void:
	if not renderer: return
	if renderer.hovered_zone_ref != zone:
		renderer.hovered_zone_ref = zone
		renderer.queue_redraw()

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

# Safe Accessor
func get_zones() -> Array[GraphZone]:
	return graph.zones

# Undoable Zone Mutation
func set_zone_property(zone: GraphZone, key: String, value: Variant) -> void:
	if not is_instance_valid(zone) or not graph.zones.has(zone): return
	
	var old_value = null
	if key in zone:
		old_value = zone.get(key)
	else:
		old_value = zone.custom_data.get(key)
		
	if str(value) == str(old_value): return
	
	var cmd = CmdSetProperty.new(graph, "ZONE", zone, key, value, old_value)
	_commit_command(cmd)

# --- Connection Operations ---

func connect_nodes(id_a: String, id_b: String, weight: float = 1.0, directed: bool = false) -> void:
	if graph.has_edge(id_a, id_b): return
	var cmd = CmdConnect.new(graph, id_a, id_b, weight, directed)
	_commit_command(cmd)

func disconnect_nodes(id_a: String, id_b: String, directed: bool = false) -> void:
	if not graph.has_edge(id_a, id_b): return

	# Capture the full canonical edge record before removal
	var edge_key = graph.get_edge_key(id_a, id_b)
	var full_record = {}
	if graph.edge_store.has(edge_key):
		full_record = graph.edge_store[edge_key].duplicate(true)

	var weight = graph.get_edge_weight(id_a, id_b)
	var cmd = CmdDisconnect.new(graph, id_a, id_b, weight, directed, full_record)
	_commit_command(cmd)

# --- Modification Operations ---

func set_node_position(id: String, new_pos: Vector2, is_preview: bool = false) -> void:
	if is_preview:
		# Live mouse dragging: modify graph directly without spamming the undo stack
		graph.set_node_position(id, new_pos)
		renderer.queue_redraw()
	else:
		# Inspector edit: wrap in an undoable command!
		if not graph.nodes.has(id): return
		var old_pos = graph.get_node_pos(id)
		
		if old_pos.distance_squared_to(new_pos) > 0.1:
			var cmd = CmdMoveNode.new(graph, id, old_pos, new_pos)
			_commit_command(cmd)

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

func set_node_type(id: String, new_type: String) -> void:
	if not graph.nodes.has(id): return
	var old_type = graph.nodes[id].type
	if old_type == new_type: return
	
	var cmd = CmdSetProperty.new(graph, "NODE", id, "type", new_type, old_type)
	_commit_command(cmd)

func set_node_type_bulk(ids: Array[String], new_type: String) -> void:
	if GraphSettings.USE_ATOMIC_UNDO:
		for id in ids: set_node_type(id, new_type) 
		return

	var batch = CmdBatch.new(graph, "Bulk Type Change")
	var change_count = 0
	
	for id in ids:
		if not graph.nodes.has(id): continue
		var old_type = graph.nodes[id].type
		if old_type != new_type:
			var cmd = CmdSetProperty.new(graph, "NODE", id, "type", new_type, old_type)
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
	set_edge_property(id_a, id_b, "weight", weight)

func set_edge_directionality(id_a: String, id_b: String, mode: int) -> void:
	# mode: 0 = Bidir, 1 = Fwd (A->B), 2 = Rev (B->A)
	var w = graph.get_edge_weight(id_a, id_b)
	if w == INF: w = graph.get_edge_weight(id_b, id_a)
	if w == INF: w = 1.0

	# Wrap in a single transaction since we might be adding/removing multiple edges!
	start_undo_transaction("Set Edge Direction")

	if mode == 0:
		if not graph.has_edge(id_a, id_b): connect_nodes(id_a, id_b, w, true)
		if not graph.has_edge(id_b, id_a): connect_nodes(id_b, id_a, w, true)
	elif mode == 1:
		if not graph.has_edge(id_a, id_b): connect_nodes(id_a, id_b, w, true)
		if graph.has_edge(id_b, id_a): disconnect_nodes(id_b, id_a, true)
	elif mode == 2:
		if graph.has_edge(id_a, id_b): disconnect_nodes(id_a, id_b, true)
		if not graph.has_edge(id_b, id_a): connect_nodes(id_b, id_a, w, true)

	commit_undo_transaction()

func set_edge_property(id_a: String, id_b: String, key: String, value: Variant) -> void:
	var edge_key = graph.get_edge_key(id_a, id_b)
	if not graph.edge_store.has(edge_key): return
	
	var edge_record = graph.edge_store[edge_key]
	var old_value = null
	
	if key == "weight":
		old_value = edge_record.weight
	else:
		old_value = edge_record.custom.get(key)
		
	if str(value) == str(old_value): return
	
	var cmd = CmdSetProperty.new(graph, "EDGE", [id_a, id_b], key, value, old_value)
	_commit_command(cmd)

# Adds undo history support for both native variables AND custom node data!
func set_node_property(id: String, key: String, value: Variant) -> void:
	if not graph.nodes.has(id): return
	var node = graph.nodes[id]
	var old_value = null
	
	# 1. Intelligently route the lookup based on where the variable lives
	if key in node:
		old_value = node.get(key)
	else:
		old_value = node.custom_data.get(key)
		
	if str(value) == str(old_value): return
	
	# 2. Command handles the rest
	var cmd = CmdSetProperty.new(graph, "NODE", id, key, value, old_value)
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
	# Only start a new batch if we aren't already inside one
	if _transaction_depth == 0:
		history.start_transaction(action_name, refocus_camera)
	_transaction_depth += 1

func commit_undo_transaction() -> void:
	if _transaction_depth > 0:
		_transaction_depth -= 1
		
		# Only commit and redraw when the outermost transaction finally closes
		if _transaction_depth == 0:
			var batch = history.commit_transaction()
			if batch:
				# 1. Update UI
				mark_modified()
				# 2. Update Screen
				renderer.queue_redraw()

func _commit_command(cmd: GraphCommand) -> void:
	history.add_command(cmd)
	
	# [CRITICAL SPEED FIX] 
	# Only trigger heavy UI rebuilds and Canvas redraws if we are NOT 
	# in the middle of a bulk editing loop!
	if _transaction_depth == 0:
		mark_modified()
		renderer.queue_redraw()


# --- RENDERER / DISPLAY API ---

func request_redraw() -> void:
	if renderer: renderer.queue_redraw()

func clear_current_path() -> void:
	current_path.clear()
	if renderer: 
		renderer.current_path_ref = current_path
		renderer.queue_redraw()

func set_debug_depth(enabled: bool) -> void:
	if renderer:
		renderer.debug_show_depth = enabled
		renderer.queue_redraw()

# ==============================================================================
# 6. GENERAL API
# ==============================================================================
# Completely resets the editor context (Destroys Undo history, severs file connection)
func new_graph() -> void:
	# 1. Create a brand new Graph resource
	self.graph = Graph.new()
	
	# 2. Reinitialize the engines tied to the graph
	history = GraphHistory.new(graph)
	simulation = Simulation.new(graph)
	buoyancy_engine = BuoyancyEngine.new() # [FIXED] Fully recreate to match load behavior
	
	# 3. Sever the file binding and reset editor state
	current_file_path = ""
	_reset_local_state()
	_reconstruct_state_from_ids() # [FIXED] Reset counters
	
	# 4. Sync the Renderer
	renderer.graph_ref = graph
	renderer.selected_nodes_ref = selected_nodes
	renderer.current_path_ref = current_path
	renderer.new_nodes_ref = new_nodes
	renderer.selected_agent_ids_ref = selected_agent_ids
	
	# [CRITICAL FIX] Force the active tool to _exit() and _enter() so it fetches the NEW graph reference!
	if tool_manager:
		set_active_tool(tool_manager.active_tool_id)
	
	# 5. Emit signals to update the rest of the UI
	graph_loaded.emit(graph)
	history.history_changed.connect(simulation.validate_all_agents)
	
	_center_camera_on_graph()
	renderer.queue_redraw()
	send_status_message("Started a new graph.")

func clear_graph() -> void:
	if graph.nodes.is_empty() and graph.zones.is_empty(): return

	var batch = CmdBatch.new(graph, "Clear Graph")

	for id in graph.nodes:
		batch.add_command(CmdDeleteNode.new(graph, id))

	# Clear zones through commands so they are undoable
	for z in graph.zones:
		batch.add_command(CmdRemoveZone.new(graph, z))

	_commit_command(batch)
	_reset_local_state()
	camera.reset_view()

func mark_modified() -> void:
	graph_modified.emit()


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
	buoyancy_engine = BuoyancyEngine.new()
	
	_reset_local_state()
	_reconstruct_state_from_ids()
	
	graph_loaded.emit(graph)
	# [CRITICAL FIX] Re-connect history observer! (Otherwise agents wouldn't validate on Undo after loading a file)
	history.history_changed.connect(simulation.validate_all_agents)
	
	renderer.graph_ref = graph
	renderer.selected_nodes_ref = selected_nodes
	renderer.current_path_ref = current_path
	renderer.new_nodes_ref = new_nodes
	renderer.selected_agent_ids_ref = selected_agent_ids # [FIXED] Keep in sync
	
	if tool_manager:
		set_active_tool(tool_manager.active_tool_id)
		
	_center_camera_on_graph()
	renderer.queue_redraw()

# --- PHYSICS / BUOYANCY API ---

func set_buoyancy_active(active: bool) -> void:
	is_buoyancy_active = active
	
	if is_buoyancy_active:
		# 1. Start Transaction
		_buoyancy_snapshot.clear()
		_buoyancy_transaction_open = true
		buoyancy_engine.clear_velocities()
		
		for id in graph.nodes:
			_buoyancy_snapshot[id] = graph.nodes[id].position
			
		send_status_message("Buoyancy Physics: ENABLED")
		
	else:
		# 2. End Transaction & Push to Undo Stack
		send_status_message("Buoyancy Physics: DISABLED")
		if not _buoyancy_transaction_open: return
		
		var batch = CmdBatch.new(graph, "Physics Layout", false)
		
		for id in _buoyancy_snapshot:
			if not graph.nodes.has(id): continue
			
			var old_pos = _buoyancy_snapshot[id]
			var new_pos = graph.nodes[id].position
			
			if old_pos.distance_squared_to(new_pos) > 0.1:
				var cmd = CmdMoveNode.new(graph, id, old_pos, new_pos)
				batch.add_command(cmd)
				
		if batch.get_command_count() > 0:
			_commit_command(batch)
			
		_buoyancy_transaction_open = false
		_buoyancy_snapshot.clear()

func set_buoyancy_crystallize(is_active: bool) -> void:
	if buoyancy_engine:
		# Pass the active graph in so the engine can melt the nodes
		buoyancy_engine.set_auto_crystallize(is_active, graph)

func set_buoyancy_edge_snapping(is_active: bool) -> void:
	if buoyancy_engine:
		buoyancy_engine.global_edge_snapping = is_active

func set_buoyancy_node_fusing(is_active: bool) -> void:
	if buoyancy_engine:
		buoyancy_engine.global_node_fusing = is_active

# Fires exactly one discrete tick of physics (Without opening a continuous transaction)
func apply_buoyancy_step() -> void:
	if not buoyancy_engine: return
	
	# Take quick snapshot
	var pre_states = {}
	for id in graph.nodes: pre_states[id] = graph.nodes[id].position
	
	# Force a 1/60th of a second step
	buoyancy_engine.step(graph, 1.0 / 60.0)
	
	# Generate instant Undo block
	var batch = CmdBatch.new(graph, "Physics Step", false)
	for id in pre_states:
		if not graph.nodes.has(id): continue
		var old = pre_states[id]
		var new = graph.nodes[id].position
		if old.distance_squared_to(new) > 0.1:
			batch.add_command(CmdMoveNode.new(graph, id, old, new))
			
	if batch.get_command_count() > 0:
		_commit_command(batch)
		
	if renderer: renderer.queue_redraw()

# ==============================================================================
# 7. INTERNAL HELPERS
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
	selected_edges.clear()
	selected_zones.clear()
	
	renderer.selected_nodes_ref = selected_nodes
	renderer.current_path_ref = current_path
	renderer.selected_edges_ref = selected_edges
	renderer.selected_agent_ids_ref = selected_agent_ids
	renderer.selected_zones_ref = selected_zones
	renderer.path_start_ids = []
	renderer.path_end_ids = []
	
	# [CRITICAL FIX] Force the UI Inspector to acknowledge nothing is selected anymore!
	selection_changed.emit(selected_nodes)
	edge_selection_changed.emit(selected_edges)
	SignalManager.agent_selection_changed.emit(selected_agent_ids)
	SignalManager.zone_selection_changed.emit(selected_zones)
