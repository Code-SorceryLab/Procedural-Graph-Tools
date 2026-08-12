class_name CmdDeleteNode
extends GraphCommand

# Node State
var _id: String
var _pos: Vector2
var _type: String
var _custom_data: Dictionary

# Edges State – now stores full canonical edge records
var _edges: Array[Dictionary] = []

var _is_valid: bool = false

func _init(graph: Graph, id: String) -> void:
	super(graph)
	_id = id

	if not _graph.nodes.has(id):
		_is_valid = false
		return

	_is_valid = true

	# 1. Capture node data
	var node_data = _graph.nodes[id]
	_pos = node_data.position
	_type = node_data.type
	_custom_data = node_data.custom_data.duplicate(true)

	# 2. Capture EVERY edge that touches this node
	# Iterate the canonical edge store directly to catch both directions.
	for key in _graph.edge_store:
		var record = _graph.edge_store[key]
		if record["u"] == id or record["v"] == id:
			_edges.append(record.duplicate(true))

func execute() -> void:
	if not _is_valid: return
	if not _graph.nodes.has(_id): return

	_graph.remove_node(_id)

func undo() -> void:
	if not _is_valid: return

	# 1. Restore the node body
	_graph.add_node(_id, _pos)

	if _graph.nodes.has(_id):
		_graph.nodes[_id].type = _type
		_graph.nodes[_id].custom_data = _custom_data.duplicate(true)

	# 2. Restore each edge with its exact direction and custom data
	for rec in _edges:
		var u = rec["u"]
		var v = rec["v"]
		var weight = rec.get("weight", 1.0)
		var direction = rec.get("direction", 0)
		var custom = rec.get("custom", {})

		if not _graph.nodes.has(u) or not _graph.nodes.has(v):
			continue

		match direction:
			0:  # Bi-directional
				_graph.add_edge(u, v, weight, false, custom)
			1:  # Canonical u -> v only
				_graph.add_edge(u, v, weight, true, custom)
			2:  # Canonical v -> u only
				_graph.add_edge(v, u, weight, true, custom)

func get_name() -> String:
	return "Delete Node"
