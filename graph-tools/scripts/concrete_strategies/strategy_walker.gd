extends GraphStrategy
class_name StrategyWalker

# MEMORY: Remember where we finished last time
var _last_added_id: String = ""

func _init() -> void:
	strategy_name = "Random Walker"
	required_params = ["steps"]
	toggle_text = "Random Branching" 
	toggle_key = "random_start"

func execute(graph: Graph, params: Dictionary) -> void:
	var steps = params.get("steps", 50)
	var append_mode = params.get("append", false)
	var random_start = params.get("random_start", false)
	var cell_size = GraphSettings.CELL_SIZE
	
	# Track where our "Walker" currently stands
	var current_grid_pos: Vector2i
	var current_id: String = "" # <--- We need to track the ID explicitly
	
	# --- SETUP PHASE ---
	if not append_mode or graph.nodes.is_empty():
		# FRESH START
		graph.nodes.clear()
		current_grid_pos = Vector2i(0, 0)
		current_id = _vec_to_id(current_grid_pos) # Calculate standard ID for 0,0
		
		_add_node_safe(graph, current_grid_pos)
		
	else:
		# GROW MODE
		var start_id = ""
		
		# LOGIC: Decide where to start
		if random_start:
			start_id = graph.nodes.keys().pick_random()
		else:
			if _last_added_id != "" and graph.nodes.has(_last_added_id):
				start_id = _last_added_id
			else:
				start_id = graph.nodes.keys().pick_random()
		
		# FIX: Use the ACTUAL ID of the start node. 
		# Do not recalculate it, or we lose track of Manual Nodes (e.g. "1")
		current_id = start_id 
		
		# Reverse engineer grid pos so math works for the NEXT step
		var world_pos = graph.get_node_pos(start_id)
		var gx = round(world_pos.x / cell_size)
		var gy = round(world_pos.y / cell_size)
		current_grid_pos = Vector2i(gx, gy)

	# --- WALKING PHASE ---
	# (Removed the line: var current_id = ... because we set it above)
	
	for i in range(steps):
		var directions = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
		var dir = directions.pick_random()
		
		var next_grid_pos = current_grid_pos + dir
		var next_id = _vec_to_id(next_grid_pos)
		
		# 1. Add Node
		_add_node_safe(graph, next_grid_pos)
		
		# 2. Add Edge
		# FIX: Verify both nodes exist before connecting to avoid race conditions
		if graph.nodes.has(current_id) and graph.nodes.has(next_id):
			if graph.get_edge_weight(current_id, next_id) == INF:
				graph.add_edge(current_id, next_id)
		
		# 3. Step forward
		current_grid_pos = next_grid_pos
		current_id = next_id
		
	# MEMORY: Save where we stopped
	_last_added_id = current_id

# --- HELPERS ---
func _vec_to_id(v: Vector2i) -> String:
	return "%d_%d" % [v.x, v.y]

func _add_node_safe(graph: Graph, grid_pos: Vector2i) -> void:
	var id = _vec_to_id(grid_pos)
	if not graph.nodes.has(id):
		var world_pos = Vector2(grid_pos.x * GraphSettings.CELL_SIZE, grid_pos.y * GraphSettings.CELL_SIZE)
		graph.add_node(id, world_pos)
