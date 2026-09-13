class_name RealizerExecutionManager
extends Node

signal rasterization_started(is_partial: bool)
signal snapshot_ready(snapshot: Dictionary)
signal rasterization_finished(realizer: GraphRealizer, report: Dictionary)


signal validation_started()
signal validation_payload(payload: Dictionary)
signal validation_finished(analytics: Dictionary)
signal validation_trigger_hit(trigger_id: String)

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
var _active_validator: GenerationValidator = null
var _current_params: Dictionary = {} # Cache for background testing

# ==============================================================================
# RASTERIZATION THREADING
# ==============================================================================
func run_rasterization(graph: Graph, params: Dictionary, raw_biome_params: Dictionary, old_realizer: GraphRealizer = null) -> void:
	if is_rasterizing: return
	if graph == null or graph.nodes.is_empty(): return
	
	# --- [FIXED] PRESERVE THE VALIDATOR ON PARTIAL REGEN ---
	var is_partial = (old_realizer != null)
	if not is_partial:
		cancel_validation() # Only kill it if we are starting from scratch
		
	is_rasterizing = true
	_current_params = params.duplicate(true) # Save for analytics later
	
	if _raster_thread and _raster_thread.is_started():
		_raster_thread.wait_to_finish()
		
	current_realizer = GraphRealizer.new()
	rasterization_started.emit(is_partial)
	
	var seed_str = str(params.get("realizer_seed", "default"))
	
	# --- Check for injected sandbox decks, fallback to disk ---
	var global_room_decks = params.get("global_room_decks", ConfigManager.load_room_decks())
	var room_lists = DistributionEngine.generate_shopping_lists(graph, global_room_decks, raw_biome_params, seed_str, "room_decks")
	params["room_shopping_lists"] = room_lists
	
	var global_spawn_decks = params.get("global_spawn_decks", ConfigManager.load_spawn_decks())
	var spawn_lists = DistributionEngine.generate_shopping_lists(graph, global_spawn_decks, raw_biome_params, seed_str, "spawn_decks")
	
	_raster_thread = Thread.new()
	_raster_thread.start(_run_rasterization_thread.bind(current_realizer, graph, params, spawn_lists, old_realizer))

func _run_rasterization_thread(realizer: GraphRealizer, graph: Graph, params: Dictionary, shopping_lists: Dictionary, old_realizer: GraphRealizer) -> void:
	realizer.realize(graph, params, shopping_lists, _on_snapshot_received, old_realizer)
	call_deferred("_on_rasterization_finished", realizer)

func _on_snapshot_received(step_name: String, cells: PackedInt32Array, entities: Dictionary, atlas_overrides: Dictionary, w: int, h: int, duration_ms: int = 0) -> void:
	var snap = { 
		"name": step_name, 
		"cells": cells, 
		"entities": entities, 
		"atlas_overrides": atlas_overrides, 
		"w": w, 
		"h": h,
		"duration": duration_ms
	}
	snapshot_ready.emit(snap)

func _on_rasterization_finished(realizer: GraphRealizer) -> void:
	if _raster_thread and _raster_thread.is_started():
		_raster_thread.wait_to_finish()
	is_rasterizing = false
	
	var report = realizer.get_meta("progression_report") if realizer.has_meta("progression_report") else {}
	
	# ==========================================================================
	# MULTI-POINT BACKGROUND VALIDATION
	# ==========================================================================
	if realizer.grid != null:
		var multi_report = []
		var t_state = _current_params.get("temporal_state", {})
		var starting_inv = t_state.get("inventory", [])
		
		# 1. BASE RUN (Spawn Point)
		var base_val = GenerationValidator.new(realizer.grid, true, false, Vector2i(-1, -1), true)
		if t_state.size() > 0: base_val.load_temporal_state(t_state)
		base_val.fast_forward()
		var base_analytics = base_val.get_final_analytics()
		base_analytics["checkpoint_name"] = "Spawn Point"
		base_analytics["initial_inventory"] = starting_inv
		multi_report.append(base_analytics)
		
		# 2. TEMPORAL ANCHOR
		var anchor = t_state.get("anchor", Vector2i(-1, -1))
		if anchor != Vector2i(-1, -1):
			var anchor_val = GenerationValidator.new(realizer.grid, true, false, anchor, true)
			anchor_val.load_temporal_state(t_state)
			anchor_val.fast_forward()
			var anchor_analytics = anchor_val.get_final_analytics()
			anchor_analytics["checkpoint_name"] = "Temporal Anchor (Post-Shift)"
			anchor_analytics["initial_inventory"] = starting_inv
			multi_report.append(anchor_analytics)
			
		# 3. SURVIVING CHECKPOINTS (All other pulled triggers)
		var consumed = t_state.get("consumed_triggers", {})
		for t_id in consumed:
			var trigger_pos = Vector2i(-1, -1)
			var trigger_name = t_id
			for pos in realizer.grid.entities:
				var e = realizer.grid.entities[pos]
				if e.get("type") == "trigger" and e.get("trigger_id") == t_id:
					trigger_pos = pos
					trigger_name = e.get("name", t_id)
					break
					
			if trigger_pos != Vector2i(-1, -1) and trigger_pos != anchor:
				var cp_val = GenerationValidator.new(realizer.grid, true, false, trigger_pos, true)
				cp_val.load_temporal_state(t_state)
				cp_val.fast_forward()
				var cp_analytics = cp_val.get_final_analytics()
				cp_analytics["checkpoint_name"] = "Checkpoint: " + trigger_name
				cp_analytics["initial_inventory"] = starting_inv
				multi_report.append(cp_analytics)
				
		report["multi_point_analytics"] = multi_report

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

func start_validation(grid: GridData, full_explore: bool, delay_doors: bool, batch_size: int, speed_ms: int, constant_speed: bool, override_start_pos: Vector2i = Vector2i(-1, -1), ignore_triggers: bool = false, use_memory: bool = true) -> void:
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
	_validator_thread.start(_run_validation_thread.bind(grid, full_explore, delay_doors, override_start_pos, ignore_triggers, use_memory))

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
	print("[DEBUG] update_validation_grid called. re_explore = ", re_explore, " dirty_rect = ", dirty_rect)
	_val_mutex.lock()
	if _val_state != "IDLE": 
		_pending_grid = new_grid
		_pending_dirty_rect = dirty_rect
		_pending_re_explore = re_explore
	_val_mutex.unlock()

# --- THE BACKGROUND LOOP ---
func _run_validation_thread(grid: GridData, full_explore: bool, delay_doors: bool, override_start: Vector2i, ignore_triggers: bool, use_memory: bool) -> void:
	var validator = GenerationValidator.new(grid, full_explore, delay_doors, override_start, ignore_triggers)
	
	_val_mutex.lock()
	_active_validator = validator
	var t_state = _current_params.get("temporal_state", {})
	_val_mutex.unlock()
	
	# --- INJECT PLAYER MEMORY ---
	if use_memory and t_state.size() > 0:
		validator.load_temporal_state(t_state)
		
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
			# --- AUTOMATIC PAUSE ON TRIGGER ---
			if payload.get("hit_trigger", "") != "":
				_val_mutex.lock()
				_val_state = "PAUSED" # Force the thread to pause
				_val_mutex.unlock()
				call_deferred("emit_signal", "validation_trigger_hit", payload["hit_trigger"])
			if state == "PLAYING": OS.delay_msec(speed)
			
		elif state == "FAST_FORWARD":
			var payload = validator.fast_forward()
			call_deferred("_dispatch_payload", payload)
			
		else:
			OS.delay_msec(50) # PAUSED: Sleep thread to save CPU
			
	_val_mutex.lock()
	_val_state = "IDLE"
	_active_validator = null
	_val_mutex.unlock()
	call_deferred("_on_validation_finished", validator.get_final_analytics())

func _dispatch_payload(payload: Dictionary) -> void:
	validation_payload.emit(payload)

func _on_validation_finished(analytics: Dictionary) -> void:
	validation_finished.emit(analytics)

# [PHASE 2] Fetch the temporal snapshot mid-run
func get_temporal_snapshot() -> Dictionary:
	_val_mutex.lock()
	var snap = {}
	if _active_validator != null:
		snap = _active_validator.get_temporal_snapshot()
	_val_mutex.unlock()
	return snap
