class_name ExperimentRunner
extends RefCounted

signal progress_updated(completed: int, total: int)
signal experiment_finished(results: Array[Dictionary])

var is_running: bool = false # Used by UI to toggle button text
var _results: Array[Dictionary] = []
var _group_task_id: int = -1
var _total_tasks: int = 0
var _completed_tasks: int = 0
var _mutex: Mutex
var _cancel_flag: bool = false

func run_batch(strategy_script: Script, combinations: Array[Dictionary]) -> void:
	_total_tasks = combinations.size()
	_completed_tasks = 0
	_results.resize(_total_tasks)
	_mutex = Mutex.new()
	_cancel_flag = false
	is_running = true
	
	# CPU Throttling: Leave 1 or 2 cores free so the PC doesn't freeze
	var safe_threads = max(1, OS.get_processor_count() - 2) 

	_group_task_id = WorkerThreadPool.add_group_task(
		_process_single_run.bind(strategy_script, combinations), 
		_total_tasks, 
		safe_threads, # Tell Godot not to use 100% of the CPU
		true, 
		"Experiment Batch"
	)
	# We need a tiny background loop to monitor completion and emit signals
	_monitor_progress.call_deferred()

# Public Cancellation Hook
func cancel() -> void:
	_mutex.lock()
	_cancel_flag = true
	_mutex.unlock()

# ==============================================================================
# THE THREADED WORKER (Runs concurrently on multiple CPU cores)
# ==============================================================================
func _process_single_run(idx: int, strategy_script: Script, combinations: Array) -> void:
	# Check for Cancellation before doing any heavy lifting
	_mutex.lock()
	var cancelled = _cancel_flag
	_mutex.unlock()
	
	if cancelled:
		_mutex.lock()
		_completed_tasks += 1 # We must increment this so the group task properly finishes!
		_mutex.unlock()
		return
	
	var params = combinations[idx]
	var strategy: GraphStrategy = strategy_script.new()
	var dummy_graph = Graph.new()
	var recorder = GraphRecorder.new(dummy_graph)
	
	strategy.execute(recorder, params)
	for cmd in recorder.recorded_commands: cmd.execute()
	
	if strategy is StrategyWalker:
		var active_agents = true
		var ticks = 0
		while active_agents and ticks < 5000:
			active_agents = false
			for agent in dummy_graph.agents:
				if not agent.is_finished: active_agents = true; agent.step(dummy_graph)
			ticks += 1
			
	GraphValidator.validate(dummy_graph, true)
	var metrics = _extract_core_metrics(dummy_graph)
	
	_mutex.lock()
	_results[idx] = { "run_id": idx, "params": params, "metrics": metrics }
	_completed_tasks += 1
	_mutex.unlock()
	
	# The dummy_graph goes out of scope here and is safely garbage collected by RAM!

# ==============================================================================
# DATA AGGREGATION & MONITORING
# ==============================================================================

func _monitor_progress() -> void:
	while not WorkerThreadPool.is_group_task_completed(_group_task_id):
		_mutex.lock()
		var count = _completed_tasks
		_mutex.unlock()
		
		progress_updated.emit(count, _total_tasks)
		await Engine.get_main_loop().process_frame
		
	# Complete! Filter out the empty slots from cancelled tasks
	var valid_results: Array[Dictionary] = []
	for r in _results:
		if not r.is_empty(): valid_results.append(r)
		
	is_running = false
	progress_updated.emit(_completed_tasks, _total_tasks)
	experiment_finished.emit(valid_results)

# A lightweight synchronous metric extractor for the background threads
func _extract_core_metrics(g: Graph) -> Dictionary:
	var dead_ends = 0
	var corridors = 0
	var intersections = 0
	
	for id in g.nodes:
		var degree = g.get_neighbors(id).size()
		if degree == 1: dead_ends += 1
		elif degree == 2: corridors += 1
		elif degree > 2: intersections += 1
		
	return {
		"node_count": g.nodes.size(),
		"edge_count": g.edge_store.size(),
		"dead_ends": dead_ends,
		"corridors": corridors,
		"intersections": intersections
	}
