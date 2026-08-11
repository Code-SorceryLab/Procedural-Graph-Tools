class_name GraphModifier
extends Resource

enum Category {
	GENERATOR, # Wipes the graph and creates new geometry
	TOPOLOGY,  # Adds/Removes nodes and edges
	GEOMETRY,  # Moves nodes physically
	SEMANTIC   # Modifies node/edge data and tags
}

var modifier_name: String = "Base Modifier"
var category: Category = Category.GENERATOR

# EVERY modifier instance has its own isolated parameter memory!
var local_settings: Dictionary = {}
var rng: RandomNumberGenerator

func _init() -> void:
	rng = RandomNumberGenerator.new()

# Returns the UI schema for this specific modifier
func get_settings() -> Array[Dictionary]:
	return [
		{
			"name": "modifier_seed",
			"type": TYPE_STRING,
			"default": "",
			"label": "Deterministic Seed",
			"hint_text": "Enter text to guarantee the same result. Leave blank for random."
		}
	]

# Bootstraps the local_settings dictionary with defaults from the schema
func apply_defaults() -> void:
	for s in get_settings():
		if not local_settings.has(s["name"]) and s.has("default"):
			local_settings[s["name"]] = s["default"]

# Call this at the start of execute() to ensure deterministic behavior
func setup_rng() -> void:
	var seed_str = local_settings.get("modifier_seed", "")
	if seed_str != "":
		rng.seed = SeedUtils.hash_seed(seed_str)
	else:
		rng.randomize()

# Virtual Function: All subclasses must override this.
func execute(_recorder: GraphRecorder) -> void:
	push_error("GraphModifier: execute() method not implemented.")
