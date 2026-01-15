class_name PathfinderRandom
extends PathfindingStrategy

# [FIX 1] Define the variable (Default to 500 if no settings passed)
var _max_steps: int = 500 

var _allow_vibrate: bool = true
var _use_backtracking: bool = false

# UI Definition
func get_settings() -> Array[Dictionary]:
	return [
		{ 
			"name": "rw_vibrate", 
			"label": "Allow Vibration", 
			"type": TYPE_BOOL, 
			"default": true, 
			"hint": "If true, can immediately return to previous node."
		},
		{ 
			"name": "rw_backtrack", 
			"label": "Smart Backtrack", 
			"type": TYPE_BOOL, 
			"default": false, 
			"hint": "Rewind to intersection on dead end."
		}
	]

# Configuration Logic
func apply_settings(settings: Dictionary) -> void:
	if settings.has("rw_vibrate"): _allow_vibrate = settings.rw_vibrate
	if settings.has("rw_backtrack"): _use_backtracking = settings.rw_backtrack
	
	# [FIX 2] Update the internal variable from the settings
	if settings.has("max_steps"): 
		var budget = int(settings.max_steps)
		if budget > 0:
			_max_steps = budget
		else:
			_max_steps = 500 # Fallback for infinite mode

func find_path(graph: Graph, start_id: String, target_id: String) -> Array[String]:
	if _use_backtracking:
		return _solve_recursive_backtracker(graph, start_id, target_id)
	else:
		return _solve_drunkards_walk(graph, start_id, target_id)

# --- MODE 1: CHAOTIC ---
func _solve_drunkards_walk(graph: Graph, start_id: String, target_id: String) -> Array[String]:
	var path: Array[String] = [start_id]
	var current = start_id
	
	# [FIX 3] Use the dynamic variable, NOT the constant
	for i in range(_max_steps):
		if current == target_id: return path
		
		var neighbors = graph.get_neighbors(current)
		if neighbors.is_empty(): break
		
		var next = ""
		
		if not _allow_vibrate and path.size() > 1:
			var previous = path[-2]
			var candidates = []
			for n in neighbors:
				if n != previous: candidates.append(n)
			
			if not candidates.is_empty():
				next = candidates.pick_random()
			else:
				next = previous 
		else:
			next = neighbors.pick_random()
			
		current = next
		path.append(current)
		
	return [] 

# --- MODE 2: SMART ---
func _solve_recursive_backtracker(graph: Graph, start_id: String, target_id: String) -> Array[String]:
	var stack = [start_id]
	var visited = { start_id: true }
	var parent = {} 
	
	var steps = 0
	# [FIX 4] Use the dynamic variable here too
	while not stack.is_empty() and steps < _max_steps:
		steps += 1
		var current = stack[-1] 
		
		if current == target_id:
			return _reconstruct_path(parent, target_id)
		
		var candidates = []
		for n in graph.get_neighbors(current):
			if not visited.has(n):
				candidates.append(n)
		
		if not candidates.is_empty():
			var next = candidates.pick_random()
			visited[next] = true
			parent[next] = current
			stack.append(next) 
		else:
			stack.pop_back() 
			
	return [] 

# Helper
func _reconstruct_path(parent_map: Dictionary, end: String) -> Array[String]:
	var path: Array[String] = []
	var curr = end
	while curr != null:
		path.append(curr)
		curr = parent_map.get(curr)
	path.reverse()
	return path
