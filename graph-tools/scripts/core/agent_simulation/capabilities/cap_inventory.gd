class_name CapInventory
extends AgentCapability

var keys: Array[String] = []

func setup(_graph: Graph) -> void:
	keys.clear()
	agent.custom_data["inventory"] = "" # Expose to Inspector

func add_key(key: String) -> void:
	if not keys.has(key): 
		keys.append(key)
		agent.custom_data["inventory"] = ", ".join(keys) # Update Inspector

func has_key(key: String) -> bool:
	return keys.has(key)
