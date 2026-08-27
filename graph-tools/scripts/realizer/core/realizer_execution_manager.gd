class_name RealizerExecutionManager
extends Node

signal rasterization_started(is_partial: bool)
signal snapshot_ready(snapshot: Dictionary)
signal rasterization_finished(realizer: GraphRealizer, report: Dictionary)

signal validation_started()
signal validation_payload(payload: Dictionary)
signal validation_finished(analytics: Dictionary)

var current_realizer: GraphRealizer
var is_rasterizing: bool = false
var _raster_thread: Thread

# --- VALIDATION VCR STATE ---
var _validator_thread: Thread
var _val_mutex: Mutex = Mutex.new()
var _val_state: String = "IDLE" # PLAYING, PAUSED, STEP, FAST_FORWARD
var _val_batch: int = 10
var _val_speed_ms: int = 50
var _val_constant_speed: bool = false
var _pending_grid: GridData = null
var _pending_dirty_rect: Rect2i = Rect2i()
var _pending_re_explore: bool = false
var _cancel_validation: bool = false

# ==============================================================================
# RASTERIZATION THREADING
# ==============================================================================
func run_rasterization(graph: Graph, params: Dictionary, raw_biome_params: Dictionary, old_realizer: GraphRealizer = null) -> void:
	if is_rasterizing: return
	if graph == null or graph.nodes.is_empty(): return
	
	# --- [FIXED] PRESERVE THE VALIDATOR ON PARTIAL REGEN ---
	var is_partial = (old_realizer != null)
	if not is_partial:
		cancel_validation() # Only kill it if we are starting from scratch!
		
	is_rasterizing = true
	
	if _raster_thread and _raster_thread.is_started():
		_raster_thread.wait_to_finish()
		
	current_realizer = GraphRealizer.new()
	rasterization_started.emit(is_partial)
	
	var seed_str = str(params.get("realizer_seed", "default"))
	var global_room_decks = ConfigManager.load_room_decks()
	var room_lists = DistributionEngine.generate_shopping_lists(graph, global_room_decks, raw_biome_params, seed_str, "room_decks")
	params["room_shopping_lists"] = room_lists
	
	var global_spawn_decks = ConfigManager.load_spawn_decks()
	var spawn_lists = DistributionEngine.generate_shopping_lists(graph, global_spawn_decks, raw_biome_params, seed_str, "spawn_decks")
	
	_raster_thread = Thread.new()
	_raster_thread.start(_run_rasterization_thread.bind(current_realizer, graph, params, spawn_lists, old_realizer))

func _run_rasterization_thread(realizer: GraphRealizer, graph: Graph, params: Dictionary, shopping_lists: Dictionary, old_realizer: GraphRealizer) -> void:
	realizer.realize(graph, params, shopping_lists, _on_snapshot_received, old_realizer)
	call_deferred("_on_rasterization_finished", realizer)

func _on_snapshot_received(step_name: String, cells: PackedInt32Array, entities: Dictionary, atlas_overrides: Dictionary, w: int, h: int) -> void:
	var snap = { "name": step_name, "cells": cells, "entities": entities, "atlas_overrides": atlas_overrides, "w": w, "h": h }
	snapshot_ready.emit(snap)

func _on_rasterization_finished(realizer: GraphRealizer) -> void:
	if _raster_thread and _raster_thread.is_started():
		_raster_thread.wait_to_finish()
	is_rasterizing = false
	
	var report = realizer.get_meta("progression_report") if realizer.has_meta("progression_report") else {}
	rasterization_finished.emit(realizer, report)

# ==============================================================================
# THREADED VALIDATION (VCR ENGINE)
# ==============================================================================
func is_validation_running() -> bool:
	return _val_state != "IDLE"

func cancel_validation() -> void:
	_val_mutex.lock()
	_cancel_validation = true
	_val_mutex.unlock()
	
	if _validator_thread and _validator_thread.is_started():
		_validator_thread.wait_to_finish()
	_val_state = "IDLE"

func start_validation(grid: GridData, full_explore: bool, delay_doors: bool, batch_size: int, speed_ms: int, constant_speed: bool) -> void:
	if is_rasterizing or grid == null: return
	cancel_validation()
	
	_val_mutex.lock()
	_cancel_validation = false
	_val_state = "PLAYING"
	_val_batch = batch_size
	_val_speed_ms = speed_ms
	_val_constant_speed = constant_speed
	_pending_grid = null
	_pending_dirty_rect = Rect2i()
	_val_mutex.unlock()
	
	validation_started.emit()
	
	_validator_thread = Thread.new()
	_validator_thread.start(_run_validation_thread.bind(grid, full_explore, delay_doors))

# --- VCR CONTROLS (Thread Safe) ---
func set_val_state(new_state: String) -> void:
	_val_mutex.lock()
	if not _cancel_validation and _val_state != "IDLE": _val_state = new_state
	_val_mutex.unlock()

func set_val_params(batch: int, speed_ms: int, constant_speed: bool) -> void:
	_val_mutex.lock()
	_val_batch = batch
	_val_speed_ms = speed_ms
	_val_constant_speed = constant_speed
	_val_mutex.unlock()

# [PHASE 2] Inject a new grid mid-validation!
func update_validation_grid(new_grid: GridData, dirty_rect: Rect2i, re_explore: bool) -> void:
	_val_mutex.lock()
	if _val_state != "IDLE": 
		_pending_grid = new_grid
		_pending_dirty_rect = dirty_rect
		_pending_re_explore = re_explore # <--- Store it
	_val_mutex.unlock()

# --- THE BACKGROUND LOOP ---
func _run_validation_thread(grid: GridData, full_explore: bool, delay_doors: bool) -> void:
	var validator = GenerationValidator.new(grid, full_explore, delay_doors)
	
	while true:
		_val_mutex.lock()
		if _cancel_validation: 
			_val_mutex.unlock(); break
			
		var state = _val_state
		var batch = _val_batch
		var speed = _val_speed_ms
		var is_const = _val_constant_speed
		var p_grid = _pending_grid
		var p_rect = _pending_dirty_rect
		var p_re_explore = _pending_re_explore
		_pending_grid = null
		
		# Auto-pause after single-fire commands
		if state == "STEP" or state == "FAST_FORWARD": 
			_val_state = "PAUSED"
		_val_mutex.unlock()
		
		# Apply Dimensional Shift if requested
		if p_grid != null:
			validator.update_world(p_grid, p_rect, p_re_explore)
			call_deferred("_dispatch_payload", validator.get_redraw_payload())
			
		if validator.is_finished:
			break
			
		# Process Execution
		if state == "PLAYING" or state == "STEP":
			var payload = validator.step(batch, is_const)
			call_deferred("_dispatch_payload", payload)
			if state == "PLAYING": OS.delay_msec(speed)
			
		elif state == "FAST_FORWARD":
			var payload = validator.fast_forward()
			call_deferred("_dispatch_payload", payload)
			
		else:
			OS.delay_msec(50) # PAUSED: Sleep thread to save CPU
			
	_val_mutex.lock()
	_val_state = "IDLE"
	_val_mutex.unlock()
	call_deferred("_on_validation_finished", validator.get_final_analytics())

func _dispatch_payload(payload: Dictionary) -> void:
	validation_payload.emit(payload)

func _on_validation_finished(analytics: Dictionary) -> void:
	validation_finished.emit(analytics)
