class_name StrategyGrid
extends GraphStrategy

func _init() -> void:
	strategy_name = "Grid Layout"
	reset_on_generate = true

# --- NEW DYNAMIC UI DEFINITION ---
func get_settings() -> Array[Dictionary]:
	return [
		{ 
			"name": "width", 
			"type": TYPE_INT, 
			"default": 10, 
			"min": 1, 
			"max": 50 
		},
		{ 
			"name": "height", 
			"type": TYPE_INT, 
			"default": 10, 
			"min": 1, 
			"max": 50 
		}
	]

func execute(graph: Graph, params: Dictionary) -> void:
	# 1. Extract Params
	# We trust these keys exist because get_settings() defined them
	var width = int(params.get("width", 10))
	var height = int(params.get("height", 10))
	
	var cell_size = GraphSettings.CELL_SIZE
	
	# 2. Generate Grid
	# Center the grid around (0,0) by calculating offset
	var offset_x = (width - 1) * cell_size * 0.5
	var offset_y = (height - 1) * cell_size * 0.5
	
	for x in range(width):
		for y in range(height):
			var pos_x = (x * cell_size) - offset_x
			var pos_y = (y * cell_size) - offset_y
			
			var id = "grid:%d:%d" % [x, y]
			
			# Add Node
			# Grid implicitly merges overlaps by using deterministic IDs
			graph.add_node(id, Vector2(pos_x, pos_y))
			
			# 3. Add Connections (Right and Down)
			# We only look 'back' or 'up' to avoid duplicates, 
			# or we can look 'forward' if we are sure nodes exist.
			# Since we are iterating X then Y, let's look Back and Up.
			
			# Connect Left (x-1)
			if x > 0:
				var left_id = "grid:%d:%d" % [x - 1, y]
				if graph.nodes.has(left_id):
					graph.add_edge(id, left_id)
					
			# Connect Up (y-1)
			if y > 0:
				var up_id = "grid:%d:%d" % [x, y - 1]
				if graph.nodes.has(up_id):
					graph.add_edge(id, up_id)
