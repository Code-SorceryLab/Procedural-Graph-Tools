class_name CapInventory
extends AgentCapability

func setup(graph: Graph) -> void:
	# If the simulation is resetting, restore the looted items to the graph!
	var looted = agent.custom_data.get("_looted_memory", {})
	if graph != null and not looted.is_empty():
		for node_id in looted:
			if graph.nodes.has(node_id):
				graph.set_node_property(node_id, "items", looted[node_id])
	
	# Clear out the backpack
	agent.custom_data["inventory"] = ""
	agent.custom_data["_looted_memory"] = {}

func add_key(key: String, node_id: String = "", original_node_items: String = "") -> void:
	var keys = _get_keys()
	if not keys.has(key): 
		keys.append(key)
		agent.custom_data["inventory"] = ", ".join(keys)
		
		# Remember what the node used to have so we can put it back on reset!
		var looted = agent.custom_data.get("_looted_memory", {})
		if node_id != "" and not looted.has(node_id):
			looted[node_id] = original_node_items
			agent.custom_data["_looted_memory"] = looted

static func extract_raw_name(tagged_string: String) -> String:
	if tagged_string.begins_with("[") and tagged_string.find("]") > 0:
		return tagged_string.substr(tagged_string.find("]") + 1).strip_edges()
	return tagged_string.strip_edges()

func has_key(req_name: String) -> bool:
	var clean_req = CapInventory.extract_raw_name(req_name)
	for k in _get_keys():
		if CapInventory.extract_raw_name(k) == clean_req: return true
	return false

# Safe helper to parse the backpack string
func _get_keys() -> Array[String]:
	var s = agent.custom_data.get("inventory", "")
	if s == "": return []
	
	var arr: Array[String] = []
	for k in s.split(","):
		var clean = k.strip_edges()
		if clean != "": arr.append(clean)
	return arr
