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
	else:
		var direction = _old_data.get("direction", 0)
		var weight = _old_data.get("weight", _old_weight)
		var custom = _old_data.get("custom", {})

		if direction == 0:  # Bi‑directional
			_graph.add_edge(_u, _v, weight, false, custom)
		elif direction == 1:  # canonical u → v
			# Determine which endpoint is the canonical "u"
			var canonical_u = _old_data.get("u", _u)
			if canonical_u == _u:
				_graph.add_edge(_u, _v, weight, true, custom)
			else:
				_graph.add_edge(_v, _u, weight, true, custom)
		elif direction == 2:  # canonical v → u
			var canonical_u = _old_data.get("u", _u)
			if canonical_u == _u:
				_graph.add_edge(_v, _u, weight, true, custom)
			else:
				_graph.add_edge(_u, _v, weight, true, custom)

func get_name() -> String:
	return "Disconnect Nodes"
