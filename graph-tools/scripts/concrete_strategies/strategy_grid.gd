class_name StrategyGrid
extends GraphStrategy

func _init() -> void:
	strategy_name = "Grid Layout"
	reset_on_generate = true

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
	var width = int(params.get("width", 10))
	var height = int(params.get("height", 10))
	
	var cell_size = GraphSettings.CELL_SIZE
	
	# 2. Calculate Start Position (Top-Left)
	# We use integer division to ensure we stay on the grid lines.
	# Example: Width 10 / 2 = 5. Start at -5.
	# Range will be -5 to +4. (0,0) will be one of the nodes.
	var start_x = -int(width / 2) * cell_size
	var start_y = -int(height / 2) * cell_size
	
	for x in range(width):
		for y in range(height):
			# Simple integer steps from the start position
			var pos_x = start_x + (x * cell_size)
			var pos_y = start_y + (y * cell_size)
			
			var id = "grid:%d:%d" % [x, y]
			
			# Add Node
			graph.add_node(id, Vector2(pos_x, pos_y))
			
			# 3. Add Connections (Look Backwards)
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
