class_name AnalysisMarkov
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
	# Execute the synchronous math on the background thread
	var result = calculate(graph, params)
	# Safely bounce the final dictionary back to the Main Thread
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
	if nodes.is_empty(): 
		return {"status": "Empty graph"}

	var absorbing = []
	var transient = []
	var transient_dict = {}
	var adj = {}

	# 1. Safely extract data
	for id in nodes:
		var neighbors = graph.get_neighbors(id)
		adj[id] = neighbors.duplicate()
		var deg = neighbors.size()
		
		if deg <= 1:
			absorbing.append(id)
		else:
			transient_dict[id] = transient.size()
			transient.append(id)

	if absorbing.is_empty():
		return {
			"status": "Skipped. No absorbing nodes (dead-ends/exits) found.",
			"transient_count": transient.size(),
			"absorbing_count": 0
		}

	var t = transient.size()
	if t == 0:
		return {"status": "Graph is entirely composed of absorbing states."}

	# 2. Build the Transition Matrix Q
	var Q = []
	Q.resize(t)
	for i in range(t):
		if GraphMetrics._cancel_flag: 
			return {"_was_cancelled": true}
			
		Q[i] = []
		Q[i].resize(t)
		for j in range(t): Q[i][j] = 0.0
			
		var u = transient[i]
		var neighbors = adj[u]
		var n_count = neighbors.size()
		
		if n_count > 0:
			var prob = 1.0 / float(n_count)
			for v in neighbors:
				var v_idx = transient_dict.get(v, -1)
				if v_idx != -1:
					Q[i][v_idx] = prob

	# 3. Build (I - Q)
	var I_minus_Q = []
	I_minus_Q.resize(t)
	for i in range(t):
		if GraphMetrics._cancel_flag: 
			return {"_was_cancelled": true}
			
		I_minus_Q[i] = []
		I_minus_Q[i].resize(t)
		for j in range(t):
			if i == j: I_minus_Q[i][j] = 1.0 - Q[i][j]
			else: I_minus_Q[i][j] = -Q[i][j]

	# 4. Invert (I - Q)
	var N = _invert_matrix(I_minus_Q)
	
	if GraphMetrics._cancel_flag: 
		return {"_was_cancelled": true}
		
	if N.is_empty():
		return {"status": "Mathematical error: Matrix is singular/not invertible"}

	# 5. Calculate Exact Metrics from N
	var expected_steps = []
	expected_steps.resize(t)
	var total_steps = 0.0
	
	for i in range(t):
		var steps = 0.0
		for j in range(t): steps += N[i][j]
		expected_steps[i] = steps
		total_steps += steps

	var avg_steps = total_steps / float(t)
	var max_traffic = 0.0
	var max_traffic_idx = -1

	for j in range(t):
		var traffic = 0.0
		for i in range(t): traffic += N[i][j]
		var normalized_traffic = traffic / float(t)
		if normalized_traffic > max_traffic:
			max_traffic = normalized_traffic
			max_traffic_idx = j

	var bottleneck_id = transient[max_traffic_idx] if max_traffic_idx != -1 else "None"

	return {
		"status": "Success",
		"absorbing_states": absorbing.size(),
		"transient_states": t,
		"average_expected_steps": snapped(avg_steps, 0.1),
		"max_expected_visits": snapped(max_traffic, 0.1),
		"flow_bottleneck_id": bottleneck_id
	}

# --- MATRIX MATH ---

func _invert_matrix(M: Array) -> Array:
	var n = M.size()
	var aug = []
	aug.resize(n)

	for i in range(n):
		aug[i] = []
		aug[i].resize(2 * n)
		for j in range(n):
			aug[i][j] = M[i][j]
			aug[i][j + n] = 1.0 if i == j else 0.0

	for i in range(n):
		if GraphMetrics._cancel_flag: return [] # Fast Abort
		
		var pivot_val = aug[i][i]
		if abs(pivot_val) < 0.000001:
			var swap_row = -1
			for k in range(i + 1, n):
				if abs(aug[k][i]) > 0.000001:
					swap_row = k
					break
			if swap_row == -1: return [] 
			
			var temp = aug[i]
			aug[i] = aug[swap_row]
			aug[swap_row] = temp
			pivot_val = aug[i][i]

		for j in range(2 * n): aug[i][j] /= pivot_val
		for k in range(n):
			if k != i:
				var factor = aug[k][i]
				for j in range(2 * n):
					aug[k][j] -= factor * aug[i][j]

	var inv = []
	inv.resize(n)
	for i in range(n):
		inv[i] = []
		inv[i].resize(n)
		for j in range(n): inv[i][j] = aug[i][j + n]

	return inv
