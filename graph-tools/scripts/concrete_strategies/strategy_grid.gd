extends GraphStrategy
class_name StrategyGrid

func _init() -> void:
	strategy_name = "Grid Map"
	required_params = ["width", "height"]

func execute(graph: Graph, params: Dictionary) -> void:
	var rows = params.get("height", 10)
	var cols = params.get("width", 10)
	var cell_size = GraphSettings.CELL_SIZE
	
	# Clear previous data
	graph.nodes.clear()
	
	# 1. Create Nodes
	for y in range(rows):
		for x in range(cols):
			var id := "%d_%d" % [x, y]
			var pos := Vector2(x * cell_size, y * cell_size)
			graph.add_node(id, pos)
	
	# 2. Create Edges
	for y in range(rows):
		for x in range(cols):
			var current_id := "%d_%d" % [x, y]
			# Connect Right and Down
			var directions = [Vector2i(1, 0), Vector2i(0, 1)]
			for dir in directions:
				var nx = x + dir.x
				var ny = y + dir.y
				if nx >= 0 and nx < cols and ny >= 0 and ny < rows:
					var neighbor_id := "%d_%d" % [nx, ny]
					graph.add_edge(current_id, neighbor_id, 1.0)
