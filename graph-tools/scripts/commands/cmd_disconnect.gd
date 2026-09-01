class_name CmdDisconnect
extends GraphCommand

var _u: String
var _v: String
var _old_weight: float
var _old_data: Dictionary # Snapshot of the edge's semantic data
var _was_directed: bool

func _init(graph, u, v, weight, directed = false, full_record: Dictionary = {}) -> void:
	super(graph)
	_u = u; _v = v
	_old_weight = weight
	_was_directed = directed
	_old_data = full_record.duplicate(true)  # includes "u","v","weight","direction","custom"

func execute() -> void:
	_graph.remove_edge(_u, _v, _was_directed)

func undo() -> void:
	if not _graph.nodes.has(_u) or not _graph.nodes.has(_v): return

	if _old_data.is_empty():
		_graph.add_edge(_u, _v, _old_weight, _was_directed)
		return

	var weight = _old_data.get("weight", _old_weight)
	var custom = _old_data.get("custom", {})

	if _was_directed:
		# Restore the exact one-way edge that was removed
		var u = _old_data.get("u", _u)
		var v = _old_data.get("v", _v)
		_graph.add_edge(u, v, weight, true, custom)
	else:
		# Restore the original bidirectional edge
		_graph.add_edge(_u, _v, weight, false, custom)

func get_name() -> String:
	return "Disconnect Nodes"
