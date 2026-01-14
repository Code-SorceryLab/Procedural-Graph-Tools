class_name CmdZoneEdit
extends GraphCommand

var _zone: GraphZone
var _cells_to_add: Array[Vector2i]
var _cells_to_remove: Array[Vector2i]

func _init(graph: Graph, zone: GraphZone, added: Array[Vector2i], removed: Array[Vector2i]) -> void:
	_graph = graph
	_zone = zone
	_cells_to_add = added
	_cells_to_remove = removed

func execute() -> void:
	# 1. Update Geometry
	_apply_cell_changes(_cells_to_add, _cells_to_remove)
	
	# 2. Update Residents (The crucial fix)
	# We check ALL cells changed in this transaction
	_refresh_roster(_cells_to_add + _cells_to_remove)

func undo() -> void:
	# 1. Revert Geometry
	_apply_cell_changes(_cells_to_remove, _cells_to_add) # Swapped
	
	# 2. Revert Residents
	# We check the same set of affected cells. 
	# Since geometry is now back to old state, re-running the check 
	# will restore the roster to the old state too.
	_refresh_roster(_cells_to_add + _cells_to_remove)

# --- HELPERS ---

func _apply_cell_changes(adding: Array[Vector2i], removing: Array[Vector2i]) -> void:
	var spacing = GraphSettings.GRID_SPACING
	
	for cell in removing:
		_zone.remove_cell(cell)
		
	for cell in adding:
		_zone.add_cell(cell, spacing)

func _refresh_roster(affected_cells: Array[Vector2i]) -> void:
	# Only Geographic zones care about cell overlap
	if _zone.zone_type != GraphZone.ZoneType.GEOGRAPHICAL: return
	if affected_cells.is_empty(): return
	
	var spacing = GraphSettings.GRID_SPACING
	
	# Optimization: Build a lookup for the affected grid area
	var changed_lookup = {}
	for cell in affected_cells:
		changed_lookup[cell] = true
	
	# Check all nodes in the graph
	# (Since we don't have a spatial hash, we iterate all nodes. 
	# This is safe for < 1000 nodes. For 10k+, we'd need a spatial structure.)
	for id in _graph.nodes:
		var pos = _graph.nodes[id].position
		var grid_pos = Vector2i(round(pos.x / spacing.x), round(pos.y / spacing.y))
		
		# Only re-evaluate if this node sits on a cell we just touched
		if changed_lookup.has(grid_pos):
			if _zone.has_cell(grid_pos):
				# It should be IN
				if not _zone.registered_nodes.has(id):
					_zone.register_node(id)
			else:
				# It should be OUT
				if _zone.registered_nodes.has(id):
					_zone.unregister_node(id)
