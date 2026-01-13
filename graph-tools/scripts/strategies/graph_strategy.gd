extends Resource
class_name GraphStrategy

# Metadata
var strategy_name: String = "Base Strategy"
var reset_on_generate: bool = true
var supports_grow: bool = false
var supports_agents: bool = false

# --- API ---
func get_settings() -> Array[Dictionary]:
	return []

# Virtual Function: All subclasses must override this.
func execute(_recorder: GraphRecorder, _params: Dictionary) -> void:
	push_error("GraphStrategy: execute() method not implemented.")
