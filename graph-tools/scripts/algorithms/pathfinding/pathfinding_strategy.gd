class_name PathfindingStrategy
extends RefCounted

# The contract every algorithm must fulfill
func find_path(graph: Graph, start_id: String, target_id: String) -> Array[String]:
	return []

# [NEW] Virtual function for the UI Builder
func get_settings() -> Array[Dictionary]:
	return [] 

# [NEW] Function to apply generic settings to this instance
func apply_settings(settings: Dictionary) -> void:
	pass
