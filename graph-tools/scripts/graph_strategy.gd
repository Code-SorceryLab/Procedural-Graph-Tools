extends Resource
class_name GraphStrategy

# Display name for the UI dropdown
@export var strategy_name: String = "Base Strategy"

# Defines which inputs the UI should show. 
# Options: "width", "height", "steps", etc.
@export var required_params: Array[String] = []

# Defines if this strategy requires a blank canvas.
# True = Generators (Grid, Walker, DLA)
# False = Decorators/Analyzers (MST, Analyze Rooms)
# Legacy support (we will remove 'reset_on_generate' later if we want, 
# but for now let's keep it or move it to a setting)
var reset_on_generate: bool = true

# Toggle Configuration
# If toggle_text is not empty, the UI will show a checkbox.
@export var toggle_text: String = "" 
@export var toggle_key: String = ""   # The key to use in the params dictionary (e.g. "use_box")


# Virtual Function: All subclasses must override this.
# 'graph' is the data model to modify.
# 'params' is a dictionary of user inputs (e.g. {"width": 10, "steps": 50})
func execute(_graph: Graph, _params: Dictionary) -> void:
	push_error("GraphStrategy: execute() method not implemented.")

# NEW: The Strategy defines its own UI requirements
# Returns an Array of Dictionaries. Each Dict describes one input.
# Format: { "name": "radius", "type": TYPE_INT, "default": 5, "min": 1, "max": 100 }
func get_settings() -> Array[Dictionary]:
	return []
