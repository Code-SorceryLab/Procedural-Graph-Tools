class_name CmdSetEdgeProperty
extends GraphCommand

var _id_a: String
var _id_b: String
var _key: String
var _new_value: Variant
var _old_value: Variant

func _init(graph: Graph, id_a: String, id_b: String, key: String, new_val: Variant, old_val: Variant) -> void:
	_graph = graph
	_id_a = id_a
	_id_b = id_b
	_key = key
	_new_value = new_val
	_old_value = old_val

func execute() -> void:
	_apply(_new_value)

func undo() -> void:
	_apply(_old_value)

func _apply(val: Variant) -> void:
	# Safety Check: Ensure the edge still exists
	# (It might have been deleted by a later command if we are undoing/redoing)
	if not _graph.has_edge(_id_a, _id_b):
		return
	
	# Access edge_data directly
	if _graph.edge_data.has(_id_a) and _graph.edge_data[_id_a].has(_id_b):
		var data_dict = _graph.edge_data[_id_a][_id_b]
		
		if val == null:
			# If the value is null, we erase the key (restore to 'undefined')
			if data_dict.has(_key):
				data_dict.erase(_key)
		else:
			# Otherwise, update/set the value
			data_dict[_key] = val

func get_name() -> String:
	return "Set Edge %s='%s'" % [_key, str(_new_value)]
