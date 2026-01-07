extends Resource
class_name GraphStrategy

# Metadata
var strategy_name: String = "Base Strategy"
var reset_on_generate: bool = true
var supports_grow: bool = false

# Legacy support 
var required_params = []
var toggle_text = ""
var toggle_key = ""

# --- NEW API ---
func get_settings() -> Array[Dictionary]:
	return []

# Virtual Function: All subclasses must override this.
# UPDATED: We now accept 'recorder' instead of 'graph'.
func execute(recorder: GraphRecorder, _params: Dictionary) -> void:
	push_error("GraphStrategy: execute() method not implemented.")
