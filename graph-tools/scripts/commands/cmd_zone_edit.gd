class_name CmdZoneEdit
extends GraphCommand

var _zone: GraphZone
var _cells_to_add: Array[Vector2i]
var _cells_to_remove: Array[Vector2i]

# We store the "Previous State" of removed cells in case they had custom data (future-proofing)
# For now, just existence is enough.

func _init(graph: Graph, zone: GraphZone, added: Array[Vector2i], removed: Array[Vector2i]) -> void:
	_graph = graph
	_zone = zone
	_cells_to_add = added
	_cells_to_remove = removed

func execute() -> void:
	# 1. Remove Cells
	for cell in _cells_to_remove:
		_zone.remove_cell(cell)
		
	# 2. Add Cells
	# We assume the spacing is consistent with the global settings
	var spacing = GraphSettings.GRID_SPACING 
	for cell in _cells_to_add:
		_zone.add_cell(cell, spacing)

func undo() -> void:
	# Reverse the operation
	var spacing = GraphSettings.GRID_SPACING
	
	# 1. Re-add the removed cells
	for cell in _cells_to_remove:
		_zone.add_cell(cell, spacing)
		
	# 2. Remove the added cells
	for cell in _cells_to_add:
		_zone.remove_cell(cell)
