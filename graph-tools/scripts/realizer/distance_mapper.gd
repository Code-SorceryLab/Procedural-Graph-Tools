class_name DistanceMapper
extends RefCounted

static func map(realizer: GraphRealizer) -> void:
	var grid = realizer.grid
	realizer.distance_field.clear()

	var queue: Array[Vector2i] = []
	var visited: Dictionary = {}
	
	var valid_floors = {}
	for id in grid.palette._definitions:
		if grid.palette.get_data(id).get("walkable", false):
			valid_floors[id] = true

	# 1. Initialize all non-walkable cells (Walls/Voids) as distance 0
	for y in range(grid.height):
		for x in range(grid.width):
			var pos = Vector2i(x, y)
			var cell_id = grid.get_cell(x, y)
			
			# If it's a wall or a void, it's our starting point
			if not valid_floors.has(cell_id):
				realizer.distance_field[pos] = 0
				queue.append(pos)
				visited[pos] = true

	# 2. Ripple outward (Multi-Source BFS)
	var head = 0
	var dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	
	while head < queue.size():
		var current = queue[head]
		head += 1
		var dist = realizer.distance_field[current]

		for d in dirs:
			var neighbor = current + d
			if grid.in_bounds_vec(neighbor) and not visited.has(neighbor):
				visited[neighbor] = true
				realizer.distance_field[neighbor] = dist + 1
				queue.append(neighbor)
