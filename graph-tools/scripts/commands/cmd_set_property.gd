class_name CmdSetProperty
extends GraphCommand

var _target_type: String
var _id: Variant # String for Node, Array for Edge, Object Ref for Agent/Zone
var _key: String
var _new_val: Variant
var _old_val: Variant

func _init(graph: Graph, target_type: String, id: Variant, key: String, new_val: Variant, old_val: Variant) -> void:
	_graph = graph
	_target_type = target_type
	_id = id
	_key = key
	_new_val = new_val
	_old_val = old_val

func execute() -> void:
	_apply(_new_val)

func undo() -> void:
	_apply(_old_val)

func _apply(val: Variant) -> void:
	match _target_type:
		SemanticRegistry.TARGET_NODE:
			if not _graph.nodes.has(_id): return
			var node = _graph.nodes[_id]
			
			# If the key is a hardcoded variable (like 'type'), set it directly.
			# Otherwise, it belongs in the custom_data dictionary.
			if _key in node:
				node.set(_key, val)
			else:
				if val == null: node.custom_data.erase(_key)
				else: node.custom_data[_key] = val
				
		SemanticRegistry.TARGET_EDGE:
			var u = _id[0]; var v = _id[1]
			if not _graph.has_edge(u, v): return
			var edge_dict = _graph.edge_data[u][v]
			
			if _key == "weight":
				edge_dict["weight"] = val
			else:
				if val == null: edge_dict.erase(_key)
				else: edge_dict[_key] = val
				
		SemanticRegistry.TARGET_AGENT, SemanticRegistry.TARGET_ZONE:
			var obj = _id
			if not is_instance_valid(obj): return
			
			if _key in obj:
				obj.set(_key, val)
			else:
				if val == null: obj.custom_data.erase(_key)
				else: obj.custom_data[_key] = val

func get_name() -> String:
	return "Set %s Property '%s'" % [_target_type.capitalize(), _key]
