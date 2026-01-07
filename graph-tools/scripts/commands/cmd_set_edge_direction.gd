class_name CmdSetEdgeDirection
extends GraphCommand

enum Dir { BI_DIR = 0, FWD = 1, REV = 2 }

var _id_a: String
var _id_b: String
var _target_mode: int

# Undo State (Capture everything about the connection)
var _old_ab_exists: bool
var _old_ba_exists: bool
var _old_ab_weight: float = 1.0
var _old_ba_weight: float = 1.0

func _init(graph: Graph, id_a: String, id_b: String, mode: int) -> void:
	_graph = graph
	_id_a = id_a
	_id_b = id_b
	_target_mode = mode
	
	# Capture Snapshot
	_old_ab_exists = _graph.has_edge(id_a, id_b)
	_old_ba_exists = _graph.has_edge(id_b, id_a)
	
	if _old_ab_exists: _old_ab_weight = _graph.get_edge_weight(id_a, id_b)
	if _old_ba_exists: _old_ba_weight = _graph.get_edge_weight(id_b, id_a)

func execute() -> void:
	_apply(_target_mode)

func undo() -> void:
	# Restore A->B
	if _old_ab_exists:
		_graph.add_edge(_id_a, _id_b, _old_ab_weight, true)
	else:
		_graph.remove_edge(_id_a, _id_b, true)
		
	# Restore B->A
	if _old_ba_exists:
		_graph.add_edge(_id_b, _id_a, _old_ba_weight, true)
	else:
		_graph.remove_edge(_id_b, _id_a, true)

func _apply(mode: int) -> void:
	# Determine weights to use (preserve existing if possible, else default to 1.0)
	var w_ab = _old_ab_weight if _old_ab_exists else (_old_ba_weight if _old_ba_exists else 1.0)
	var w_ba = _old_ba_weight if _old_ba_exists else (_old_ab_weight if _old_ab_exists else 1.0)

	match mode:
		Dir.BI_DIR:
			_graph.add_edge(_id_a, _id_b, w_ab, true)
			_graph.add_edge(_id_b, _id_a, w_ba, true)
			
		Dir.FWD: # A -> B
			_graph.add_edge(_id_a, _id_b, w_ab, true)
			_graph.remove_edge(_id_b, _id_a, true)
			
		Dir.REV: # A <- B
			_graph.remove_edge(_id_a, _id_b, true)
			_graph.add_edge(_id_b, _id_a, w_ba, true)

func get_name() -> String:
	return "Set Edge Direction %s <-> %s" % [_id_a, _id_b]
