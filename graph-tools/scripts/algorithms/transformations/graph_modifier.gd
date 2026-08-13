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

# Stores the footprint passed down from the previous modifier in the pipeline
var pipeline_context: Dictionary = {} 

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

# ==============================================================================
# PIPELINE CONTEXT UTILITIES
# ==============================================================================

# Safely extracts all node IDs touched by the previous step.
# If include_edge_endpoints is true, it also returns the nodes attached to any touched edges.
func get_context_nodes(include_edge_endpoints: bool = false) -> Array[String]:
	var result_set = {}
	
	if pipeline_context.has("touched_nodes"):
		for id in pipeline_context["touched_nodes"]:
			result_set[id] = true
			
	if include_edge_endpoints and pipeline_context.has("touched_edges"):
		for pair in pipeline_context["touched_edges"]:
			result_set[pair[0]] = true
			result_set[pair[1]] = true
			
	var final_array: Array[String] = []
	final_array.assign(result_set.keys())
	return final_array

# Safely extracts all edges touched by the previous step.
func get_context_edges() -> Array:
	if pipeline_context.has("touched_edges"):
		return pipeline_context["touched_edges"]
	return []

# ==============================================================================
# SEMANTIC PREREGISTRATION
# ==============================================================================

# Returns a list of semantic registrations required by this modifier.
# This is called on the MAIN THREAD by both PipelineController and ExperimentController
# before any background worker is dispatched.
#
# Each entry is a Dictionary with either:
#   { "type": "category", "target": SemanticRegistry.TARGET_*, "key": "...", "name": "...", "color": Color(...), "is_core": bool }
# or
#   { "type": "property", "target": SemanticRegistry.TARGET_*, "key": "...", "label": "...", "var_type": TYPE_*, "default": value, "display": SemanticRegistry.DisplayMode.*, "is_core": bool }
func get_required_semantics() -> Array[Dictionary]:
	return []

# Shared static helper that both controllers call exactly once before launching threads.
static func preregister_semantics(modifiers: Array) -> void:
	for mod in modifiers:
		if not mod: continue
		var reqs = mod.get_required_semantics()
		for req in reqs:
			match req.get("type", "property"):
				"category":
					SemanticRegistry.ensure_category(
						req["target"],
						req["key"],
						req["name"],
						req["color"],
						req.get("is_core", false)
					)
				"property":
					SemanticRegistry.ensure_property(
						req["target"],
						req["key"],
						req["label"],
						req["var_type"],
						req.get("default", null),
						req.get("display", 0),
						req.get("is_core", false)
					)
