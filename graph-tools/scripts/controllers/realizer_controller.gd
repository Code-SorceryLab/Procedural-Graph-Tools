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
var _validator_paint_counter: int = 0
var _active_triggers: Dictionary = {}

# --- VIEWS ---
var _generator_tab: GeneratorTabView
var _timeline_tab: TimelineTabView
var _report_tab: ReportTabView
var _validation_tab: ValidationTabView
var _triggers_tab: TriggersTabView

# --- MANAGERS ---
var _tooltip_manager: RealizerTooltipManager
var _renderer: RealizerOverlayRenderer
var _execution_manager: RealizerExecutionManager
var _config_manager: RealizerConfigManager
var _validator_visualizer: ValidatorVisualizer

func _ready() -> void:
	# 1. Initialize Sub-Managers
	_renderer = RealizerOverlayRenderer.new()
	_renderer.setup(tile_map_layer, floor_source_id)
	
	# --- ADD THE VISUALIZER ---
	_validator_visualizer = ValidatorVisualizer.new()
	_validator_visualizer.z_index = 2 # Float above the floor, below the entities
	tile_map_layer.add_child(_validator_visualizer)
	
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
	_execution_manager.validation_payload.connect(_on_validation_payload)
	_execution_manager.validation_finished.connect(func(analytics): 
		_validation_tab.set_state("IDLE")
	)

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

	# --- TRIGGERS TAB SETUP ---
	_active_triggers = ConfigManager.load_regen_triggers()
	_triggers_tab = TriggersTabView.new()
	_triggers_tab.trigger_created.connect(_on_trigger_created)
	_triggers_tab.trigger_deleted.connect(_on_trigger_deleted)
	_triggers_tab.trigger_name_changed.connect(_on_trigger_name_changed)
	_triggers_tab.trigger_edit_mask_requested.connect(_on_trigger_mask_requested)
	_triggers_tab.trigger_test_requested.connect(_on_trigger_test_requested)
	_triggers_tab.trigger_edit_settings_requested.connect(_on_trigger_edit_settings_requested)
	_config_manager.trigger_settings_saved.connect(_on_trigger_settings_saved)
	
	
	if graph_editor:
		graph_editor.trigger_mask_saved.connect(_on_trigger_mask_saved)
	
	tabs.add_child(_triggers_tab)
	_triggers_tab.build_list(_active_triggers)
	
	_generator_tab.build(_config_manager.custom_structures, _config_manager.global_params)
	
	# --- VCR ROUTING ---
	_validation_tab.play_requested.connect(func(): 
		if not _execution_manager.is_validation_running():
			_on_validation_run_requested()
		_execution_manager.set_val_state("PLAYING")
		_validation_tab.set_state("PLAYING")
	)
	_validation_tab.pause_requested.connect(func(): 
		_execution_manager.set_val_state("PAUSED")
		_validation_tab.set_state("PAUSED")
	)
	_validation_tab.step_requested.connect(func(): 
		if not _execution_manager.is_validation_running():
			_on_validation_run_requested()
		_execution_manager.set_val_state("STEP")
	)
	_validation_tab.skip_requested.connect(func(): 
		if not _execution_manager.is_validation_running():
			_on_validation_run_requested()
		_execution_manager.set_val_state("FAST_FORWARD")
	)
	
	_validation_tab.speed_changed.connect(func(v): _execution_manager.set_val_params(int(_validation_tab._slider_batch.value), int(v * 1000), _validation_tab.get_settings()["constant_speed"]))
	_validation_tab.batch_size_changed.connect(func(v): _execution_manager.set_val_params(v, int(_validation_tab._slider_speed.value * 1000), _validation_tab.get_settings()["constant_speed"]))
	
	# Add the live toggle connection:
	_validation_tab.constant_speed_toggled.connect(func(is_on): _execution_manager.set_val_params(int(_validation_tab._slider_batch.value), int(_validation_tab._slider_speed.value * 1000), is_on))
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

func _on_rasterization_started(is_partial: bool = false) -> void:
	_report_tab.set_loading()
	
	if is_partial:
		# --- PHASE 2 PRESERVATION ---
		# If we are regenerating, automatically PAUSE the validator instead of killing it!
		if _execution_manager.is_validation_running():
			_execution_manager.set_val_state("PAUSED")
			_validation_tab.set_state("PAUSED")
	else:
		# --- FULL WIPE ---
		_snapshots.clear()
		_timeline_tab.clear()
		_active_mapping.clear() 
		_validation_tab.clear_logs()
		_validation_tab.set_state("IDLE")
		_validator_visualizer.clear()
		_renderer.clear_overlays()
		
	_tooltip_manager.is_active = false
	_realizer = _execution_manager.current_realizer

# ==============================================================================
# REGENERATION PIPELINE (DRY REFACTOR)
# ==============================================================================

func _calculate_infected_topology(initial_nodes: Array, initial_edges: Array) -> Dictionary:
	var inf_nodes_dict = {}
	var inf_edges_dict = {}
	for n in initial_nodes: inf_nodes_dict[n] = true
	for e in initial_edges: inf_edges_dict[e] = true
	
	var graph = graph_editor.graph
	
	# Pass 1: Topological (Infect immediate edges)
	for edge_key in graph.edge_store:
		var edge = graph.edge_store[edge_key]
		if inf_nodes_dict.has(edge.u) or inf_nodes_dict.has(edge.v):
			var sp = [edge.u, edge.v]; sp.sort()
			inf_edges_dict[str(sp[0]) + "_" + str(sp[1])] = true
			
	# Pass 2: Spatial (Infect unselected nodes that physically overlap)
	var shared_infection = DynamicRegenUtils.get_exact_overlapping_topology(_realizer, inf_nodes_dict.keys(), inf_edges_dict.keys())
	for n in shared_infection["nodes"]: inf_nodes_dict[n] = true
	for e in shared_infection["edges"]: inf_edges_dict[e] = true
		
	# Pass 3: Topological (Infect edges of the newly discovered spatial nodes)
	for edge_key in graph.edge_store:
		var edge = graph.edge_store[edge_key]
		if inf_nodes_dict.has(edge.u) or inf_nodes_dict.has(edge.v):
			var sp = [edge.u, edge.v]; sp.sort()
			inf_edges_dict[str(sp[0]) + "_" + str(sp[1])] = true
			
	return {
		"nodes": inf_nodes_dict.keys(),
		"edges": inf_edges_dict.keys()
	}

func _execute_partial_regeneration(initial_nodes: Array, initial_edges: Array, trigger_data: Dictionary = {}) -> void:
	# 1. Expand the topology to find the true blast radius
	var infected = _calculate_infected_topology(initial_nodes, initial_edges)
	var final_nodes = infected["nodes"]
	var final_edges = infected["edges"]
	
	var graph = graph_editor.graph
	
	# 2. Get the Dirty Rect
	var dirty_rect = DynamicRegenUtils.get_dirty_rect(_realizer, graph, final_nodes, final_edges)
	if dirty_rect.size == Vector2i.ZERO:
		print("Warning: The targeted elements are not currently rendered on the grid.")
		return
		
	# 3. Pack Base Execution Params
	var exec_params = _config_manager.get_execution_params()
	exec_params["regen_dirty_rect"] = dirty_rect
	exec_params["regen_target_nodes"] = final_nodes
	exec_params["regen_target_edges"] = final_edges
	
	var raw_biomes = _config_manager.biome_params.duplicate(true)
	
	# 4. MERGE TRIGGER OVERRIDES (If provided)
	if not trigger_data.is_empty():
		var globals = trigger_data.get("global_overrides", {})
		for k in globals: exec_params[k] = globals[k]
			
		if trigger_data.has("global_spawn_decks"):
			exec_params["global_spawn_decks"] = trigger_data["global_spawn_decks"]
		if trigger_data.has("global_room_decks"):
			exec_params["global_room_decks"] = trigger_data["global_room_decks"]
			
		var trigger_biomes = trigger_data.get("biome_overrides", {})
		var base_biomes = exec_params.get("biomes", {})
		
		# Merge trigger sandbox edits into the engine's dictionaries!
		for b_key in trigger_biomes:
			base_biomes[b_key] = trigger_biomes[b_key]
			raw_biomes[b_key] = trigger_biomes[b_key] 
			
		exec_params["biomes"] = base_biomes
	
	# 5. Inject Temporal State (The Player's Memory)
	if _execution_manager.is_validation_running():
		exec_params["temporal_state"] = _execution_manager.get_temporal_snapshot()
		
	# 6. Validation Frontier Selection Warning (Oracle Warning)
	if _execution_manager.is_validation_running() and _validator_visualizer.intersects_rect(dirty_rect):
		var dialog = ConfirmationDialog.new()
		dialog.title = "Validator Relocation Warning"
		dialog.dialog_text = "The selected regeneration area physically overlaps the paused Validator's explored fluid.\n\nContinuing will force the Validator to evaporate the fluid inside the blast radius and relocate its frontier.\n\nDo you want to proceed?"
		dialog.get_ok_button().text = "Regenerate Anyway"
		
		dialog.confirmed.connect(func():
			_execution_manager.run_rasterization(graph, exec_params, raw_biomes, _realizer)
			dialog.queue_free()
		)
		dialog.canceled.connect(func(): dialog.queue_free())
		
		ui_container.add_child(dialog) 
		dialog.popup_centered()
		return 
		
	# 7. Execute Normally
	_execution_manager.run_rasterization(graph, exec_params, raw_biomes, _realizer)

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
		
	# Convert raw edge arrays to string keys
	var initial_edges = []
	for pair in selected_edges_raw:
		var sp = pair.duplicate(); sp.sort()
		initial_edges.append(str(sp[0]) + "_" + str(sp[1]))
		
	_execute_partial_regeneration(selected_nodes.duplicate(), initial_edges)

func _on_preview_regen_pressed() -> void:
	if _execution_manager.is_rasterizing: return
	if not graph_editor or _realizer == null: return
	
	_renderer.clear_debug_regen() # Clear old preview
	var selected_nodes = graph_editor.selected_nodes
	var selected_edges_raw = graph_editor.selected_edges
	if selected_nodes.is_empty() and selected_edges_raw.is_empty(): return
		
	var initial_edges = []
	for pair in selected_edges_raw:
		var sp = pair.duplicate(); sp.sort()
		initial_edges.append(str(sp[0]) + "_" + str(sp[1]))
		
	var infected = _calculate_infected_topology(selected_nodes, initial_edges)
	
	var dirty_rect = DynamicRegenUtils.get_dirty_rect(_realizer, graph_editor.graph, infected["nodes"], infected["edges"])
	if dirty_rect.size == Vector2i.ZERO: return
	
	var wipe_map = DynamicRegenUtils.get_wipe_map(_realizer, dirty_rect, infected["nodes"], infected["edges"])
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
		
	# --- [PHASE 2 INJECTION] ---
	if _execution_manager.is_validation_running():
		var dirty_rect = _realizer.get_meta("regen_dirty_rect") if _realizer.has_meta("regen_dirty_rect") else Rect2i()
		var re_explore = _validation_tab.get_settings().get("re_explore", false)
		_execution_manager.update_validation_grid(_realizer.grid, dirty_rect, re_explore)

func _on_validation_run_requested() -> void:
	if _execution_manager.is_rasterizing: return
	if not _realizer or not _realizer.grid: return
	
	var settings = _validation_tab.get_settings()
	_execution_manager.start_validation(
		_realizer.grid, 
		settings["full_explore"], 
		settings["delay_doors"], 
		settings["batch_size"], 
		int(settings["tick_speed"] * 1000),
		settings["constant_speed"]
	)

func _on_validation_started() -> void:
	_validation_tab.clear_logs()
	_validation_tab.set_state("PLAYING")
	_validator_paint_counter = 0
	
	# Pass the correct tile size to the visualizer
	if tile_map_layer.tile_set:
		_validator_visualizer.cell_size = float(tile_map_layer.tile_set.tile_size.x)
	_validator_visualizer.clear()

func _on_validation_payload(payload: Dictionary) -> void:
	for msg in payload["logs"]:
		_validation_tab.append_log(msg)
		
	if payload.get("is_redraw", false):
		_validator_paint_counter = 0
		_validator_visualizer.full_redraw(payload["newly_visited"], payload["frontier"])
	else:
		_validator_visualizer.update_visualization(payload["newly_visited"], payload["frontier"], _validator_paint_counter)
		
	if payload["newly_visited"].size() > 0:
		_validator_paint_counter += 1
		
	if payload["is_finished"]:
		_validation_tab.set_state("IDLE")


func _on_validation_stop_requested() -> void:
	_execution_manager.cancel_validation()

func _on_visualize_toggled(is_on: bool) -> void:
	_validator_visualizer.set_visible_state(is_on)

# ==============================================================================
# TIMELINE / VCR RENDERER
# ==============================================================================
func _on_step_list_selected(index: int) -> void:
	if _execution_manager.is_rasterizing: return 
	
	# --- [FIXED] Only assassinate the validator if the user MANUALLY clicks the timeline! ---
	_execution_manager.cancel_validation()
	_validation_tab.set_state("IDLE")
	_jump_to_snapshot(index)

func _jump_to_snapshot(index: int) -> void:
	if _snapshots.is_empty() or _active_mapping.is_empty(): return
	
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
# TRIGGERS COMMAND CENTER
# ==============================================================================
func _on_trigger_created() -> void:
	var new_id = "trig_" + str(Time.get_unix_time_from_system())
	_active_triggers[new_id] = {
		"name": "New Trigger",
		"target_nodes": [],
		"target_edges": [],
		"global_overrides": {},
		"biome_overrides": {}
	}
	ConfigManager.save_regen_triggers(_active_triggers)
	_triggers_tab.build_list(_active_triggers)

func _on_trigger_deleted(t_id: String) -> void:
	_active_triggers.erase(t_id)
	ConfigManager.save_regen_triggers(_active_triggers)
	_triggers_tab.build_list(_active_triggers)

func _on_trigger_name_changed(t_id: String, new_name: String) -> void:
	if _active_triggers.has(t_id):
		_active_triggers[t_id]["name"] = new_name
		ConfigManager.save_regen_triggers(_active_triggers)

func _on_trigger_mask_requested(t_id: String) -> void:
	if not graph_editor or not _active_triggers.has(t_id): return
	
	# Fetch existing data so the editor can pre-highlight it!
	var t_data = _active_triggers[t_id]
	var nodes = t_data.get("target_nodes", [])
	var edges = t_data.get("target_edges", [])
	
	graph_editor.start_trigger_masking(t_id, nodes, edges)

func _on_trigger_mask_saved(t_id: String, nodes: Array, edges: Array) -> void:
	if _active_triggers.has(t_id):
		_active_triggers[t_id]["target_nodes"] = nodes
		_active_triggers[t_id]["target_edges"] = edges
		ConfigManager.save_regen_triggers(_active_triggers)
		_triggers_tab.build_list(_active_triggers) # Refresh the UI label!

func _on_trigger_test_requested(t_id: String) -> void:
	if _execution_manager.is_rasterizing: return
	if not graph_editor or not _realizer or not _realizer.grid:
		print("Warning: Must perform a full Rasterization before testing a trigger!")
		return
		
	if not _active_triggers.has(t_id): return
	var t_data = _active_triggers[t_id]
	
	var initial_nodes = t_data.get("target_nodes", [])
	var initial_edges = t_data.get("target_edges", [])
	
	if initial_nodes.is_empty() and initial_edges.is_empty():
		print("Warning: Trigger has no assigned nodes or edges in its Mask.")
		return
		
	_execute_partial_regeneration(initial_nodes, initial_edges, t_data)

func _on_trigger_edit_settings_requested(t_id: String) -> void:
	if _active_triggers.has(t_id):
		_config_manager.open_trigger_designer(t_id, _active_triggers[t_id])

func _on_trigger_settings_saved(t_id: String, t_data: Dictionary) -> void:
	if _active_triggers.has(t_id):
		_active_triggers[t_id] = t_data
		ConfigManager.save_regen_triggers(_active_triggers)

# ==============================================================================
# CLEANUP
# ==============================================================================
func _on_clear_pressed() -> void:
	if _execution_manager.is_rasterizing: return
	
	_execution_manager.cancel_validation()
	_validation_tab.set_state("IDLE")
	_validator_visualizer.clear()
		
	if tile_map_layer:
		tile_map_layer.clear()
		_renderer.clear_overlays()
				
	_realizer = null
	_tooltip_manager.is_active = false
	_snapshots.clear()
	_timeline_tab.clear()
	_report_tab.clear()
	_validation_tab.clear_logs()
