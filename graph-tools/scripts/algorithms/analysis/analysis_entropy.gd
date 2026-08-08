class_name AnalysisEntropy
extends RefCounted

signal calculation_finished(result: Dictionary)
var _worker_thread: Thread

# ==============================================================================
# 1. ASYNC ENDPOINT (Used by the UI / GraphMetrics)
# ==============================================================================
func calculate_async(graph: Graph, params: Dictionary = {}) -> void:
	_worker_thread = Thread.new()
	_worker_thread.start(_thread_runner.bind(graph, params))

func _thread_runner(graph: Graph, params: Dictionary) -> void:
	var result = calculate(graph, params)
	call_deferred("_on_finished", result)

func _on_finished(result: Dictionary) -> void:
	if _worker_thread and _worker_thread.is_started():
		_worker_thread.wait_to_finish()
	calculation_finished.emit(result)

# ==============================================================================
# 2. SYNC ENDPOINT (Used directly by ExperimentRunner)
# ==============================================================================
func calculate(graph: Graph, params: Dictionary = {}) -> Dictionary:
	var nodes = graph.nodes.keys()
	var total_nodes = nodes.size()
	
	if total_nodes <= 1:
		return { "shannon_entropy": 0.0 }
		
	# Extract degrees safely
	var degrees = []
	for id in nodes:
		degrees.append(graph.get_neighbors(id).size())
		
	var degree_counts = {}
	for deg in degrees:
		if GraphMetrics._cancel_flag: 
			return {"_was_cancelled": true}
			
		if degree_counts.has(deg): degree_counts[deg] += 1
		else: degree_counts[deg] = 1
			
	var entropy = 0.0
	for deg in degree_counts:
		var count = degree_counts[deg]
		var probability = float(count) / float(total_nodes)
		var log2_p = log(probability) / log(2.0)
		entropy -= probability * log2_p
		
	return { "shannon_entropy": snapped(entropy, 0.001) }
