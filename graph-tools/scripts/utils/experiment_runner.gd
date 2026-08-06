class_name ExperimentRunner
extends RefCounted

signal progress_updated(completed: int, total: int)
signal experiment_finished(results: Array[Dictionary])

var is_running: bool = false 
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
	
	if _total_tasks == 0:
		push_error("ExperimentRunner: combinations array is empty!")
		_monitor_progress.call_deferred()
		return
	
	var safe_threads = max(1, OS.get_processor_count() - 2) 

	_group_task_id = WorkerThreadPool.add_group_task(
		_process_single_run.bind(strategy_script, combinations), 
		_total_tasks, 
		safe_threads, 
		true, 
		"Experiment Batch"
	)
	_monitor_progress.call_deferred()

func cancel() -> void:
	_mutex.lock()
	_cancel_flag = true
	_mutex.unlock()

# ==============================================================================
# THE THREADED WORKER (Runs concurrently on multiple CPU cores)
# ==============================================================================
func _process_single_run(idx: int, strategy_script: Script, combinations: Array) -> void:
	_mutex.lock()
	var cancelled = _cancel_flag
	_mutex.unlock()
	
	if cancelled:
		_mutex.lock()
		_completed_tasks += 1 
		_mutex.unlock()
		return
		
	var params = combinations[idx]
	
	# --- DIAGNOSTIC PRINTS ---
	# If a thread crashes, the console will show the last successful print!
	# print("[Task %d] Instantiating Strategy..." % idx)
	var strategy: GraphStrategy = strategy_script.new()
	var dummy_graph = Graph.new()
	var recorder = GraphRecorder.new(dummy_graph)
	
	# print("[Task %d] Executing Strategy..." % idx)
	strategy.execute(recorder, params)
	
	# print("[Task %d] Committing Commands..." % idx)
	for cmd in recorder.recorded_commands: 
		cmd.execute()
	
	# print("[Task %d] Checking Walkers..." % idx)
	if strategy is StrategyWalker:
		var active_agents = true
		var ticks = 0
		while active_agents and ticks < 5000:
			active_agents = false
			for agent in dummy_graph.agents:
				if not agent.is_finished: active_agents = true; agent.step(dummy_graph)
			ticks += 1
			
	# print("[Task %d] Validating Graph..." % idx)
	GraphValidator.validate(dummy_graph, true)
	
	# Pass params so the flattener knows which heavy metrics were toggled on
	var metrics = _extract_core_metrics(dummy_graph, params)
	
	_mutex.lock()
	_results[idx] = { "run_id": idx, "params": params, "metrics": metrics }
	_completed_tasks += 1
	_mutex.unlock()

# ==============================================================================
# DATA AGGREGATION & MONITORING
# ==============================================================================
func _monitor_progress() -> void:
	if _group_task_id != -1:
		while not WorkerThreadPool.is_group_task_completed(_group_task_id):
			_mutex.lock()
			var count = _completed_tasks
			_mutex.unlock()
			
			progress_updated.emit(count, _total_tasks)
			await Engine.get_main_loop().process_frame
			
		# [CRITICAL FIX] You MUST call this to free the thread pool memory!
		WorkerThreadPool.wait_for_group_task_completion(_group_task_id)
		
	# Check for silent thread crashes
	if _completed_tasks < _total_tasks and not _cancel_flag:
		push_error("CRITICAL: %d threads crashed silently during execution! Check console for errors." % (_total_tasks - _completed_tasks))
		
	var valid_results: Array[Dictionary] = []
	for r in _results:
		# Safer check: ensure it isn't null before calling is_empty()
		if r != null and not r.is_empty(): 
			valid_results.append(r)
			
	is_running = false
	progress_updated.emit(_completed_tasks, _total_tasks)
	experiment_finished.emit(valid_results)

# A synchronous metric extractor that flattens the GraphMetrics output for CSV export
func _extract_core_metrics(g: Graph, params: Dictionary) -> Dictionary:
	# Pre-allocate the dictionary keys so GraphMetrics doesn't crash!
	var report = {
		"_selection_data": {},
		"topological": {},
		"spatial": {},
		"agents": {},
		"markov_flow": {},
		"zones": {}
	}
	
	# 1. Run the massive synchronous suite!
	GraphMetrics._calculate_topology(g, report)
	GraphMetrics._calculate_spatial(g, report)
	GraphMetrics._calculate_agents(g, report)
	GraphMetrics._calculate_markov(g, report)
	GraphMetrics._calculate_zones(g, report)
	
	# ==========================================================================
	# 2. HEAVY METRICS (Synchronous Thread-Safe Execution)
	# Because we are ALREADY in a background thread, we instantiate the solvers 
	# and run their underlying calculate() methods directly, bypassing awaits.
	# ==========================================================================
	
	# Longest Path
	if params.get("do_longest_path", false):
		var path_solver = AnalysisLongestPath.new()
		if path_solver.has_method("calculate"): 
			var data = path_solver.calculate(g, params)
			report["max_exploration_path"] = { 
				"max_path_length": data.get("max_path_length", 0),
				"is_hamiltonian": data.get("is_hamiltonian", false)
			}

	# Louvain Community Detection
	if params.get("do_louvain", false):
		var louvain_solver = AnalysisLouvain.new()
		if louvain_solver.has_method("calculate"):
			var data = louvain_solver.calculate(g, params)
			report["community_detection"] = { 
				"modularity_score": data.get("modularity", 0.0),
				"detected_communities": data.get("communities", 0)
			}
			
	# Robertson-Seymour Tangles (Treewidth)
	if params.get("do_tangles", false):
		var tangle_solver = AnalysisTangle.new()
		if tangle_solver.has_method("calculate"):
			var data = tangle_solver.calculate(g, params)
			report["robertson_seymour_tangles"] = {
				"tangle_treewidth": data.get("treewidth", 0)
				# Skipping the "method" string so it doesn't clutter numeric CSV data, 
				# but you can add it if you want categorical columns.
			}
			
	# Chromatic Number
	if params.get("do_chromatic", false):
		var chromatic_solver = AnalysisChromatic.new()
		if chromatic_solver.has_method("calculate"):
			var data = chromatic_solver.calculate(g, params)
			report["chromatic_coloring"] = {
				"chromatic_number": data.get("chromatic_number", 0)
			}
			
	# Eulerian Edge Traversal
	if params.get("do_eulerian", false):
		var eulerian_solver = AnalysisEulerian.new()
		if eulerian_solver.has_method("calculate"):
			var data = eulerian_solver.calculate(g, params)
			var path_nodes = data.get("path_nodes", [])
			report["eulerian_edge_traversal"] = {
				"has_eulerian_circuit": data.get("has_circuit", false),
				"has_eulerian_path": data.get("has_path", false),
				"odd_degree_nodes": data.get("odd_nodes", 0),
				"full_traversal_route_length": path_nodes.size()
			}

	# ==========================================================================
	# 3. CSV & DASHBOARD FLATTENER
	# ==========================================================================
	var flat_metrics = {}
	
	for category in report:
		if category.begins_with("_") or category == "timestamp": continue
		
		var data = report[category]
		if typeof(data) == TYPE_DICTIONARY:
			for key in data:
				var val = data[key]
				
				# Handle specific nested structures like topological shapes
				if typeof(val) == TYPE_DICTIONARY:
					if key == "shapes":
						for sk in val: flat_metrics["shape_" + sk] = val[sk]
				elif typeof(val) == TYPE_ARRAY:
					continue # We cannot put raw arrays in a CSV cell cleanly, so skip them
				else:
					flat_metrics[key] = val
					
	return flat_metrics
