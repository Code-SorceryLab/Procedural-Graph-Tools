extends Resource
class_name GraphStrategy

# Metadata
var strategy_name: String = "Base Strategy"
var reset_on_generate: bool = true

# Legacy support (Optional: we can keep these to prevent crashing un-updated scripts temporarily)
var required_params = []
var toggle_text = ""
var toggle_key = ""

# --- NEW API ---
# Returns an Array of Dictionaries defining the UI
func get_settings() -> Array[Dictionary]:
	return []

# Virtual Function: All subclasses must override this.
# 'graph' is the data model to modify.
# 'params' is a dictionary of user inputs (e.g. {"width": 10, "steps": 50})
func execute(_graph: Graph, _params: Dictionary) -> void:
	push_error("GraphStrategy: execute() method not implemented.")
