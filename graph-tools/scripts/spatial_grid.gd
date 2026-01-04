# spatial_grid.gd
class_name SpatialGrid
extends RefCounted

# Uniform grid spatial partition for fast spatial queries
var _grid: Dictionary = {}  # Dictionary[Vector2i, Array[String]]
var _cell_size: float
var _node_to_cells: Dictionary = {}  # node_id -> Array[Vector2i] (cells the node occupies)
var _bounds: Rect2 = Rect2()

func _init(cell_size: float) -> void:
	_cell_size = max(cell_size, 1.0)

# Convert world position to grid cell coordinates
func _world_to_cell(pos: Vector2) -> Vector2i:
	return Vector2i(floor(pos.x / _cell_size), floor(pos.y / _cell_size))

# Get all cells that intersect with a circle
func _get_cells_for_circle(center: Vector2, radius: float) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var min_cell = _world_to_cell(center - Vector2(radius, radius))
	var max_cell = _world_to_cell(center + Vector2(radius, radius))
	
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			cells.append(Vector2i(x, y))
	
	return cells

# Add a node to the spatial grid
func add_node(node_id: String, position: Vector2, radius: float) -> void:
	# Remove if already exists (update case)
	if _node_to_cells.has(node_id):
		remove_node(node_id)
	
	# Calculate which cells this node occupies
	var cells = _get_cells_for_circle(position, radius)
	_node_to_cells[node_id] = cells
	
	# Add node to each cell
	for cell in cells:
		if not _grid.has(cell):
			_grid[cell] = []
		
		if not _grid[cell].has(node_id):
			_grid[cell].append(node_id)
	
	# Update bounds
	_update_bounds(position)

# Remove a node from the spatial grid
func remove_node(node_id: String) -> void:
	if not _node_to_cells.has(node_id):
		return
	
	var cells = _node_to_cells[node_id]
	for cell in cells:
		if _grid.has(cell):
			_grid[cell].erase(node_id)
			if _grid[cell].is_empty():
				_grid.erase(cell)
	
	_node_to_cells.erase(node_id)

# Update node position
func update_node(node_id: String, new_position: Vector2, radius: float) -> void:
	remove_node(node_id)
	add_node(node_id, new_position, radius)

# Find all nodes within a circle
func query_circle(center: Vector2, radius: float) -> Array[String]:
	var result: Array[String] = []
	var checked_nodes: Dictionary = {}
	var cells = _get_cells_for_circle(center, radius)
	
	for cell in cells:
		if _grid.has(cell):
			for node_id in _grid[cell]:
				if not checked_nodes.has(node_id):
					checked_nodes[node_id] = true
					result.append(node_id)
	
	return result

# Find all nodes within a rectangle
func query_rect(rect: Rect2) -> Array[String]:
	var result: Array[String] = []
	var checked_nodes: Dictionary = {}
	
	var min_cell = _world_to_cell(rect.position)
	var max_cell = _world_to_cell(rect.position + rect.size)
	
	for x in range(min_cell.x, max_cell.x + 1):
		for y in range(min_cell.y, max_cell.y + 1):
			var cell = Vector2i(x, y)
			if _grid.has(cell):
				for node_id in _grid[cell]:
					if not checked_nodes.has(node_id):
						checked_nodes[node_id] = true
						result.append(node_id)
	
	return result

# Find the closest node to a position (for mouse picking)
func find_closest_node(pos: Vector2, max_distance: float = INF) -> String:
	var candidates = query_circle(pos, max_distance)
	
	var closest_id: String = ""
	var closest_dist: float = INF
	
	for node_id in candidates:
		# Note: We'd need node positions to compute actual distance
		# This requires external position lookup
		# We'll handle this in the Graph class
		pass
	
	return closest_id

# Get statistics for debugging
func get_stats() -> Dictionary:
	var total_nodes = _node_to_cells.size()
	var total_cells = _grid.size()
	var avg_nodes_per_cell = 0.0
	if total_cells > 0:
		var total_cell_entries = 0
		for cell in _grid:
			total_cell_entries += _grid[cell].size()
		avg_nodes_per_cell = float(total_cell_entries) / total_cells
	
	return {
		"total_nodes": total_nodes,
		"total_cells": total_cells,
		"avg_nodes_per_cell": avg_nodes_per_cell,
		"bounds": _bounds
	}

func clear() -> void:
	_grid.clear()
	_node_to_cells.clear()
	_bounds = Rect2()

func _update_bounds(position: Vector2) -> void:
	if !_bounds.has_area():
		_bounds = Rect2(position, Vector2.ZERO)
	else:
		_bounds = _bounds.expand(position)
