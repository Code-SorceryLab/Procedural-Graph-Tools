class_name StrategyGrid
extends GraphStrategy

func _init() -> void:
	strategy_name = "Grid Layout"
	reset_on_generate = true # Wipes previous work
	# Define which UI inputs should be visible for this strategy
	required_params = ["width", "height"]

func execute(graph: Graph, params: Dictionary) -> void:
	# 1. Parse Params
	var width = params.get("width", 5)
	var height = params.get("height", 5)
	var append_mode = params.get("append", false)
	# Note: Grid usually ignores "merge_overlaps" because its IDs are coordinates,
	# so "overlapping" implies "same ID" anyway.
	
	if not append_mode:
		graph.clear()
		
	# 2. Generate Grid
	for x in range(width):
		for y in range(height):
			# Calculate position
			var pos = Vector2(x * GraphSettings.CELL_SIZE, y * GraphSettings.CELL_SIZE)
			
			# --- ID LOGIC START ---
			
			# Deterministic ID based on logic (Origin Coordinates)
			var new_id = "grid:%d:%d" % [x, y]
			
			# If the node doesn't exist, create it.
			# If it does exist (e.g. running grid gen on top of grid gen), we preserve the old one.
			if not graph.nodes.has(new_id):
				graph.add_node(new_id, pos)
				
			# --- ID LOGIC END ---
			
			# Connect Neighbors (Deterministic)
			# We check if neighbors exist before connecting.
			if x > 0:
				var neighbor_id = "grid:%d:%d" % [x - 1, y]
				if graph.nodes.has(neighbor_id):
					graph.add_edge(new_id, neighbor_id)
			if y > 0:
				var neighbor_id = "grid:%d:%d" % [x, y - 1]
				if graph.nodes.has(neighbor_id):
					graph.add_edge(new_id, neighbor_id)
