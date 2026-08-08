extends Resource
class_name GraphStrategy

# Metadata
var strategy_name: String = "Base Strategy"
var reset_on_generate: bool = true
var supports_grow: bool = false
var supports_agents: bool = false
var supports_zones: bool = false

# Universal RNG State for ALL strategies
var my_seed: int = 0
var rng: RandomNumberGenerator

func _init() -> void:
	rng = RandomNumberGenerator.new()

# --- API ---
func get_settings() -> Array[Dictionary]:
	# Return a brand new array containing the universal Seed setting
	var settings: Array[Dictionary] = []
	settings.append({
		"name": "strategy_seed",
		"type": TYPE_STRING,
		"default": "",
		"label": "Generation Seed",
		"hint_text": "Enter text/numbers to guarantee the exact same generation every time. Leave blank for random."
	})
	return settings

# Virtual Function: All subclasses must override this.
func execute(_recorder: GraphRecorder, _params: Dictionary) -> void:
	push_error("GraphStrategy: execute() method not implemented.")

# Helper for standardized UI
func _get_zone_setting_def() -> Dictionary:
	return { 
		"name": "use_zones", 
		"type": TYPE_BOOL, 
		"default": false, 
		"label": "Generate Zone",
		"hint": "Wraps the generated nodes in a new Zone."
	}
