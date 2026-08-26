class_name RealizerController
extends Node

@export_group("Core References")
@export var graph_editor: GraphEditor
@export var tile_map_layer: TileMapLayer
@export var ui_container: VBoxContainer

@export_group("Tile Mapping (Visuals)")
@export var floor_source_id: int = 0

var _realizer: GraphRealizer

# --- STATE ---
var _snapshots: Array[Dictionary] = []
var _active_mapping: Dictionary = {} 

# --- VIEWS ---
var _generator_tab: GeneratorTabView
var _timeline_tab: TimelineTabView
var _report_tab: ReportTabView
var _validation_tab: ValidationTabView

# --- MANAGERS ---
var _tooltip_manager: RealizerTooltipManager
var _renderer: RealizerOverlayRenderer
var _execution_manager: RealizerExecutionManager
var _config_manager: RealizerConfigManager

func _ready() -> void:
	# 1. Initialize Sub-Managers
	_renderer = RealizerOverlayRenderer.new()
	add_child(_renderer)
	_renderer.setup(tile_map_layer, floor_source_id)
	
	_tooltip_manager = RealizerTooltipManager.new()
	add_child(_tooltip_manager)
	_tooltip_manager.setup(tile_map_layer)
	_tooltip_manager.lock_hover_changed.connect(_renderer.draw_ghost_web)
	
	_execution_manager = RealizerExecutionManager.new()
	add_child(_execution_manager)
	_execution_manager.rasterization_started.connect(_on_rasterization_started)
	_execution_manager.snapshot_ready.connect(_on_snapshot_received)
	_execution_manager.rasterization_finished.connect(_on_rasterization_finished)
	
	_execution_manager.validation_started.connect(_on_validation_started)
	_execution_manager.validation_log.connect(func(msg): _validation_tab.append_log(msg))
	_execution_manager.validation_flood.connect(_on_validation_flood)
	_execution_manager.validation_finished.connect(func(): _validation_tab.set_running(false))

	_config_manager = RealizerConfigManager.new()
	_config_manager.btn_preview_regen_requested.connect( _on_preview_regen_pressed)
	add_child(_config_manager)
	_config_manager.setup()
	
	# 2. Connect Configuration Routing
	_config_manager.rasterize_requested.connect(_on_rasterize_pressed)
	_config_manager.regenerate_selection_requested.connect(_on_regenerate_selection_pressed)
	_config_manager.clear_requested.connect(_on_clear_pressed)
	_config_manager.mappings_changed.connect(func(): _active_mapping.clear())
	_config_manager.overlays_need_redraw.connect(func():
		if not _snapshots.is_empty() and tile_map_layer:
			_renderer.render_overlays(_realizer, _snapshots[-1]["entities"], _config_manager.global_params, _execution_manager.is_rasterizing)
	)
	
	# 3. Attach Dumb UI Views
	var tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ui_container.add_child(tabs)
	
	_generator_tab = GeneratorTabView.new()
	_generator_tab.interaction_triggered.connect(_config_manager.handle_interaction) # <--- Direct Routing!
	tabs.add_child(_generator_tab)
	
	_timeline_tab = TimelineTabView.new()
	_timeline_tab.snapshot_selected.connect(_on_step_list_selected)
	tabs.add_child(_timeline_tab)
	
	_report_tab = ReportTabView.new()
	tabs.add_child(_report_tab)
	
	_validation_tab = ValidationTabView.new()
	_validation_tab.run_requested.connect(_on_validation_run_requested)
	_validation_tab.stop_requested.connect(_on_validation_stop_requested)
	_validation_tab.visualize_toggled.connect(_on_visualize_toggled) 
	tabs.add_child(_validation_tab)
	
	_generator_tab.build(_config_manager.custom_structures, _config_manager.global_params)

# ==============================================================================
# EXECUTION ROUTING
# ==============================================================================
func _on_rasterize_pressed() -> void:
	if _execution_manager.is_rasterizing: return
	if not graph_editor or not "graph" in graph_editor: return
	if not tile_map_layer: return
	
	var exec_params = _config_manager.get_execution_params()
	_execution_manager.run_rasterization(graph_editor.graph, exec_params, _config_manager.biome_params)

func _on_rasterization_started() -> void:
	_snapshots.clear()
	_timeline_tab.clear()
	_active_mapping.clear() 
	_report_tab.set_loading()
	_validation_tab.clear_logs()
	
	_renderer.clear_overlays()
	_tooltip_manager.is_active = false
	_realizer = _execution_manager.current_realizer


func _on_regenerate_selection_pressed() -> void:
	if _execution_manager.is_rasterizing: return
	if not graph_editor or not "graph" in graph_editor: return
	
	if _realizer == null or _realizer.grid == null:
		print("Warning: Must perform a full Rasterization before regenerating a selection!")
		return
		
	var selected_nodes = graph_editor.selected_nodes
	var selected_edges_raw = graph_editor.selected_edges
	
	if selected_nodes.is_empty() and selected_edges_raw.is_empty():
		print("Warning: Select nodes or edges in the Graph Editor to regenerate them.")
		return
		
	# 1. Format the Input
	var inf_nodes_dict = {}
	var inf_edges_dict = {}
	
	for n in selected_nodes: inf_nodes_dict[n] = true
	for pair in selected_edges_raw:
		var sp = pair.duplicate(); sp.sort()
		inf_edges_dict[str(sp[0]) + "_" + str(sp[1])] = true
		
	var graph = graph_editor.graph
		
	# 2. TOPOLOGICAL INFECTION: If a Node is regenerating, its edges MUST regenerate,
	# otherwise it becomes an island!
	for edge_key in graph.edge_store:
		var edge = graph.edge_store[edge_key]
		if inf_nodes_dict.has(edge.u) or inf_nodes_dict.has(edge.v):
			var sp = [edge.u, edge.v]; sp.sort()
			inf_edges_dict[str(sp[0]) + "_" + str(sp[1])] = true
			
	# 3. SPATIAL INFECTION: If another room/corridor physically merged with our targets, 
	# they must be regenerated too to prevent visual shearing.
	var shared_infection = DynamicRegenUtils.get_exact_overlapping_topology(_realizer, inf_nodes_dict.keys(), inf_edges_dict.keys())
	for n in shared_infection["nodes"]: inf_nodes_dict[n] = true
	for e in shared_infection["edges"]: inf_edges_dict[e] = true
		
	# 4. TOPOLOGICAL INFECTION (Pass 2): Auto-infect edges of any newly discovered spatial nodes
	for edge_key in graph.edge_store:
		var edge = graph.edge_store[edge_key]
		if inf_nodes_dict.has(edge.u) or inf_nodes_dict.has(edge.v):
			var sp = [edge.u, edge.v]; sp.sort()
			inf_edges_dict[str(sp[0]) + "_" + str(sp[1])] = true
			
	var final_nodes = inf_nodes_dict.keys()
	var final_edges = inf_edges_dict.keys()
	
	# 5. Get the bounding box encompassing OLD raster and NEW graph positions
	var dirty_rect = DynamicRegenUtils.get_dirty_rect(_realizer, graph, final_nodes, final_edges)
	
	if dirty_rect.size == Vector2i.ZERO:
		print("Warning: The selected elements are not currently rendered on the grid.")
		return
		
	# 6. Pack Execution Params
	var exec_params = _config_manager.get_execution_params()
	exec_params["regen_dirty_rect"] = dirty_rect
	exec_params["regen_target_nodes"] = final_nodes
	exec_params["regen_target_edges"] = final_edges
	
	# 7. Execute! 
	_execution_manager.run_rasterization(graph, exec_params, _config_manager.biome_params, _realizer)

func _on_preview_regen_pressed() -> void:
	if _execution_manager.is_rasterizing: return
	if not graph_editor or _realizer == null: return
	
	_renderer.clear_debug_regen() # Clear old preview
	var selected_nodes = graph_editor.selected_nodes
	var selected_edges_raw = graph_editor.selected_edges
	if selected_nodes.is_empty() and selected_edges_raw.is_empty(): return
		
	var inf_nodes_dict = {}
	var inf_edges_dict = {}
	for n in selected_nodes: inf_nodes_dict[n] = true
	for pair in selected_edges_raw:
		var sp = pair.duplicate(); sp.sort()
		inf_edges_dict[str(sp[0]) + "_" + str(sp[1])] = true
		
	var graph = graph_editor.graph
	for edge_key in graph.edge_store:
		var edge = graph.edge_store[edge_key]
		if inf_nodes_dict.has(edge.u) or inf_nodes_dict.has(edge.v):
			var sp = [edge.u, edge.v]; sp.sort()
			inf_edges_dict[str(sp[0]) + "_" + str(sp[1])] = true
			
	var shared_infection = DynamicRegenUtils.get_exact_overlapping_topology(_realizer, inf_nodes_dict.keys(), inf_edges_dict.keys())
	for n in shared_infection["nodes"]: inf_nodes_dict[n] = true
	for e in shared_infection["edges"]: inf_edges_dict[e] = true
		
	for edge_key in graph.edge_store:
		var edge = graph.edge_store[edge_key]
		if inf_nodes_dict.has(edge.u) or inf_nodes_dict.has(edge.v):
			var sp = [edge.u, edge.v]; sp.sort()
			inf_edges_dict[str(sp[0]) + "_" + str(sp[1])] = true
			
	var final_nodes = inf_nodes_dict.keys()
	var final_edges = inf_edges_dict.keys()
	
	var dirty_rect = DynamicRegenUtils.get_dirty_rect(_realizer, graph, final_nodes, final_edges)
	if dirty_rect.size == Vector2i.ZERO: return
	
	# Fetch the theoretical wipe map!
	var wipe_map = DynamicRegenUtils.get_wipe_map(_realizer, dirty_rect, final_nodes, final_edges)
	
	# Draw it!
	_renderer.draw_regen_preview(dirty_rect, wipe_map)


func _on_snapshot_received(snapshot: Dictionary) -> void:
	_snapshots.append(snapshot)
	var idx = _snapshots.size() - 1
	_timeline_tab.add_snapshot(snapshot["name"])
	
	if _active_mapping.is_empty():
		_active_mapping = _renderer.rebuild_dynamic_tileset_and_mapping(_execution_manager.current_realizer, _config_manager.custom_rooms, _config_manager.atlas_mappings, _config_manager.tileset_image_path, _config_manager.tileset_tile_size, _config_manager.procedural_flags, _config_manager.palette_params)
	_jump_to_snapshot(idx)

func _on_rasterization_finished(realizer: GraphRealizer, report: Dictionary) -> void:
	_realizer = realizer
	_tooltip_manager.is_active = true
	_tooltip_manager.update_context(_realizer, _config_manager.biome_params)
	
	_report_tab.update_report(report) 
	_timeline_tab.set_buttons_active(true)
	
	if not _snapshots.is_empty():
		_renderer.render_overlays(_realizer, _snapshots[-1]["entities"], _config_manager.global_params, false)

func _on_validation_run_requested(visualize: bool, full_explore: bool, delay_doors: bool) -> void:
	if _execution_manager.is_rasterizing: return
	if not _realizer or not _realizer.grid:
		_validation_tab.append_log("[color=red]Error: Rasterize the graph first.[/color]")
		return
		
	_execution_manager.run_validation(_realizer.grid, visualize, full_explore, delay_doors)

func _on_validation_started() -> void:
	_validation_tab.clear_logs()
	_validation_tab.set_running(true)
	for child in tile_map_layer.get_children():
		if child.is_in_group("validator_overlay"): child.queue_free()

func _on_validation_flood(cells: Array, color_index: int) -> void:
	if not tile_map_layer or not tile_map_layer.tile_set: return
	var cell_size = float(tile_map_layer.tile_set.tile_size.x)
	var is_vis = _validation_tab.is_visualize_on()
	
	for pos in cells:
		var rect = ColorRect.new()
		var hue = fmod(0.55 + (color_index * 0.0005), 1.0)
		rect.color = Color.from_hsv(hue, 0.8, 1.0, 0.4) 
		rect.size = Vector2(cell_size, cell_size)
		rect.position = Vector2(pos.x * cell_size, pos.y * cell_size)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.visible = is_vis 
		rect.add_to_group("validator_overlay")
		tile_map_layer.add_child(rect)

func _on_validation_stop_requested() -> void:
	_execution_manager.cancel_validation()

func _on_visualize_toggled(is_on: bool) -> void:
	if tile_map_layer:
		for child in tile_map_layer.get_children():
			if child.is_in_group("validator_overlay"): child.visible = is_on

# ==============================================================================
# TIMELINE / VCR RENDERER
# ==============================================================================
func _on_step_list_selected(index: int) -> void:
	if _execution_manager.is_rasterizing: return 
	_jump_to_snapshot(index)

func _jump_to_snapshot(index: int) -> void:
	if _snapshots.is_empty() or _active_mapping.is_empty(): return
	
	_execution_manager.cancel_validation()
	_validation_tab.set_running(false)
	
	index = clampi(index, 0, _snapshots.size() - 1)
	
	_timeline_tab.select_index(index)
	var snapshot = _snapshots[index]
	var mock_grid = GridData.new(snapshot["w"], snapshot["h"], _realizer.palette)
	mock_grid.cells = snapshot["cells"]
	mock_grid.cell_atlas_overrides = snapshot.get("atlas_overrides", {}) 
	
	tile_map_layer.clear()
	TileMapAdapter.apply_to_layer(mock_grid, tile_map_layer, _active_mapping)
	
	if tile_map_layer.tile_set:
		var cell_size = float(tile_map_layer.tile_set.tile_size.x)
		var p = _config_manager.global_params # Use Config Manager's parameters!
		var visual_scale = p["grid_scale"] / cell_size
		tile_map_layer.scale = Vector2(visual_scale, visual_scale)
		var offset_x = _realizer._world_offset.x - (p["padding"] * p["grid_scale"])
		var offset_y = _realizer._world_offset.y - (p["padding"] * p["grid_scale"])
		tile_map_layer.position = Vector2(offset_x, offset_y)
		
	_renderer.render_overlays(_realizer, snapshot["entities"], _config_manager.global_params, _execution_manager.is_rasterizing)
	_tooltip_manager.update_context(_realizer, _config_manager.biome_params)

# ==============================================================================
# CLEANUP
# ==============================================================================
func _on_clear_pressed() -> void:
	if _execution_manager.is_rasterizing: return
	
	_execution_manager.cancel_validation()
	_validation_tab.set_running(false)
		
	if tile_map_layer:
		tile_map_layer.clear()
		_renderer.clear_overlays()
				
	_realizer = null
	_tooltip_manager.is_active = false
	_snapshots.clear()
	_timeline_tab.clear()
	_report_tab.clear()
	_validation_tab.clear_logs()
