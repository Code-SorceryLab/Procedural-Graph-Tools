class_name StrategyCA
extends GraphStrategy

# ==============================================================================
# STRATEGY DEFINITION
# ==============================================================================
func _init() -> void:
	strategy_name = "Cellular Automata (Cave)"
	reset_on_generate = true

func get_settings() -> Array[Dictionary]:
	return [
		{ 
			"name": "width", 
			"type": TYPE_INT, 
			"default": 20, 
			"min": 5, "max": 50,
			# Reference the shared tooltip
			"hint": GraphSettings.PARAM_TOOLTIPS.common.width
		},
		{ 
			"name": "height", 
			"type": TYPE_INT, 
			"default": 15, 
			"min": 5, "max": 50,
			"hint": GraphSettings.PARAM_TOOLTIPS.common.height
		},
		{ 
			"name": "fill_percent", 
			"type": TYPE_INT, 
			"default": 45, 
			"min": 10, "max": 90, 
			# Reference the CA specific tooltip
			"hint": GraphSettings.PARAM_TOOLTIPS.ca.fill
		},
		{ 
			"name": "iterations", 
			"type": TYPE_INT, 
			"default": 4, 
			"min": 0, "max": 10, 
			"hint": GraphSettings.PARAM_TOOLTIPS.ca.iter 
		}
	]

# ==============================================================================
# EXECUTION LOGIC
# ==============================================================================
func execute(recorder: GraphRecorder, params: Dictionary) -> void:
	var w = params.get("width", 20)
	var h = params.get("height", 15)
	var fill = params.get("fill_percent", 45) / 100.0
	var steps = params.get("iterations", 4)
	
	# 1. Initialize Random Grid
	var grid = _initialize_grid(w, h, fill)
	
	# 2. Simulation Loop
	for i in steps:
		grid = _run_simulation_step(grid, w, h)
		
	# 3. Convert Grid to Graph Nodes
	var final_nodes = []
	var cell_size = GraphSettings.CELL_SIZE
	
	for x in range(w):
		for y in range(h):
			if grid[x][y]:
				var id = "ca:%d:%d" % [x, y]
				var pos = Vector2(x * cell_size, y * cell_size)
				
				# Add Node
				recorder.add_node(id, pos)
				final_nodes.append(id)
				
				# 4. Create Connections (Directly using Graph API)
				if x > 0 and grid[x-1][y]:
					recorder.add_edge(id, "ca:%d:%d" % [x-1, y])
				if y > 0 and grid[x][y-1]:
					recorder.add_edge(id, "ca:%d:%d" % [x, y-1])

	# 5. Output Highlight info
	params["out_highlight_nodes"] = final_nodes

# ==============================================================================
# INTERNAL SIMULATION HELPERS
# ==============================================================================

func _initialize_grid(w: int, h: int, fill_prob: float) -> Array:
	var grid = []
	for x in range(w):
		var col = []
		for y in range(h):
			col.append(randf() < fill_prob)
		grid.append(col)
	return grid

func _run_simulation_step(old_grid: Array, w: int, h: int) -> Array:
	var new_grid = []
	
	# Create fresh array structure
	for x in range(w):
		var col = []
		col.resize(h)
		new_grid.append(col)
		
	for x in range(w):
		for y in range(h):
			var neighbors = _count_neighbors(old_grid, x, y, w, h)
			var was_alive = old_grid[x][y]
			var is_alive = false
			
			# 4-5 Rule:
			if was_alive:
				is_alive = (neighbors >= 4)
			else:
				is_alive = (neighbors >= 5)
			
			new_grid[x][y] = is_alive
			
	return new_grid

func _count_neighbors(grid: Array, x: int, y: int, w: int, h: int) -> int:
	var count = 0
	for i in range(-1, 2):
		for j in range(-1, 2):
			if i == 0 and j == 0: continue
				
			var nx = x + i
			var ny = y + j
			
			if nx >= 0 and nx < w and ny >= 0 and ny < h:
				if grid[nx][ny]: count += 1
			else:
				count += 1 # Walls are alive
				
	return count
