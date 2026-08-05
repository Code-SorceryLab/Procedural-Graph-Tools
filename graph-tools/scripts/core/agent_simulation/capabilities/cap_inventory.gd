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

# --- SHARED RULE VALIDATION ---

# Checks if the agent is legally allowed to traverse this edge
static func can_unlock_edge(agent: AgentWalker, graph: Graph, from_id: String, to_id: String) -> bool:
	var custom_edge_data = graph.get_edge_data(from_id, to_id)
	var req = custom_edge_data.get("requires", "")
	if req == "": return true # No lock
	
	var inv = agent.get_capability("Inventory") as CapInventory
	if not inv: return false
	
	var clean_req = CapInventory.extract_raw_name(req)
	return inv.has_key(clean_req)

# Consumes any items at the given node and puts them in the backpack
static func consume_items_at_node(agent: AgentWalker, graph: Graph, node_id: String) -> void:
	var inv = agent.get_capability("Inventory") as CapInventory
	if not inv or not graph.nodes.has(node_id): return
	
	var node_data = graph.nodes[node_id]
	
	# [FIXED] Safely extract the items string whether it is a native variable or custom data
	var items_str = ""
	if "items" in node_data:
		var raw_val = node_data.get("items")
		if raw_val != null: items_str = str(raw_val)
	elif "custom_data" in node_data:
		items_str = str(node_data.custom_data.get("items", ""))
	
	if items_str != "":
		for item in items_str.split(","):
			var clean_item = item.strip_edges()
			if clean_item != "": 
				inv.add_key(clean_item, node_id, items_str)
		
		# Safely consume from the graph
		graph.set_node_property(node_id, "items", "")
