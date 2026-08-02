class_name CmdDisconnect
extends GraphCommand

var _u: String
var _v: String
var _old_weight: float
var _old_data: Dictionary # Snapshot of the edge's semantic data

func _init(graph: Graph, u: String, v: String, weight: float) -> void:
	super(graph)
	_u = u
	_v = v
	_old_weight = weight
	
	# Capture the semantic data before the edge is deleted
	if _graph.has_edge(u, v):
		_old_data = _graph.get_edge_data(u, v).duplicate(true)
	else:
		_old_data = {}

func execute() -> void:
	_graph.remove_edge(_u, _v)

func undo() -> void:
	# Restore the edge with the exact weight it had before
	if _graph.nodes.has(_u) and _graph.nodes.has(_v):
		_graph.add_edge(_u, _v, _old_weight)
		
		# Restore the semantic data!
		# We merge it back in to preserve the weight key that add_edge just created
		if _graph.edge_data.has(_u) and _graph.edge_data[_u].has(_v):
			_graph.edge_data[_u][_v].merge(_old_data.duplicate(true), true)
			
		# If the graph defaulted to Bi-Directional and created the reverse edge,
		# ensure the custom data is mirrored there as well!
		if _graph.edge_data.has(_v) and _graph.edge_data[_v].has(_u):
			_graph.edge_data[_v][_u].merge(_old_data.duplicate(true), true)

func get_name() -> String:
	return "Disconnect Nodes"
