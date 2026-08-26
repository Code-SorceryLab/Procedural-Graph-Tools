class_name RealizerExecutionManager
extends Node

signal rasterization_started()
signal snapshot_ready(snapshot: Dictionary)
signal rasterization_finished(realizer: GraphRealizer, report: Dictionary)

signal validation_started()
signal validation_log(msg: String)
signal validation_flood(cells: Array, color_index: int)
signal validation_finished()

var current_realizer: GraphRealizer
var is_rasterizing: bool = false

var _raster_thread: Thread
var _validator_thread: Thread
var _cancel_validation: bool = false
var _validator_paint_counter: int = 0

# ==============================================================================
# RASTERIZATION THREADING
# ==============================================================================
func run_rasterization(graph: Graph, params: Dictionary, raw_biome_params: Dictionary, old_realizer: GraphRealizer = null) -> void:
	if is_rasterizing: return
	if graph == null or graph.nodes.is_empty(): return
	
	cancel_validation()
	is_rasterizing = true
	
	if _raster_thread and _raster_thread.is_started():
		_raster_thread.wait_to_finish()
		
	current_realizer = GraphRealizer.new()
	rasterization_started.emit()
	
	var seed_str = str(params.get("realizer_seed", "default"))
	var global_room_decks = ConfigManager.load_room_decks()
	var room_lists = DistributionEngine.generate_shopping_lists(graph, global_room_decks, raw_biome_params, seed_str, "room_decks")
	params["room_shopping_lists"] = room_lists
	
	var global_spawn_decks = ConfigManager.load_spawn_decks()
	var spawn_lists = DistributionEngine.generate_shopping_lists(graph, global_spawn_decks, raw_biome_params, seed_str, "spawn_decks")
	
	_raster_thread = Thread.new()
	# --- [CHANGED] Pass old_realizer into the bind ---
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
# VALIDATION THREADING
# ==============================================================================
func cancel_validation() -> void:
	if _validator_thread and _validator_thread.is_started():
		_cancel_validation = true
		_validator_thread.wait_to_finish()

func run_validation(grid: GridData, visualize: bool, full_explore: bool, delay_doors: bool) -> void:
	if is_rasterizing or grid == null: return
	cancel_validation()
	
	_cancel_validation = false
	_validator_paint_counter = 0
	validation_started.emit()
	
	_validator_thread = Thread.new()
	_validator_thread.start(_run_validation_thread.bind(grid, visualize, full_explore, delay_doors))

func _run_validation_thread(grid: GridData, visualize: bool, full_explore: bool, delay_doors: bool) -> void:
	var emit_func = func(type: String, data: Variant = null):
		call_deferred("_on_validation_event", type, data)
	var cancel_func = func() -> bool: return _cancel_validation
	
	var result = GenerationValidator.run(grid, visualize, full_explore, delay_doors, emit_func, cancel_func)
	call_deferred("_on_validation_finished", result)

func _on_validation_event(type: String, data: Variant) -> void:
	if type == "log":
		validation_log.emit(data)
	elif type == "flood":
		validation_flood.emit(data, _validator_paint_counter)
		_validator_paint_counter += 1

func _on_validation_finished(result: Dictionary) -> void:
	if _validator_thread and _validator_thread.is_started():
		_validator_thread.wait_to_finish()
	validation_finished.emit()
