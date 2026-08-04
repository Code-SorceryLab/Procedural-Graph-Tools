class_name SemanticRegistry
extends Object

const TARGET_NODE = "NODE"
const TARGET_EDGE = "EDGE"
const TARGET_AGENT = "AGENT"
const TARGET_ZONE = "ZONE"

# ------------------------------------------------------------------------------
# 1. DATA STRUCTURES
# ------------------------------------------------------------------------------

# Categories (Types) - e.g., "enemy", "boss", "door_locked"
# Structure: { target: { key_string: { "name": String, "color": Color } } }
static var categories: Dictionary = {
	TARGET_NODE: {}, TARGET_EDGE: {}, TARGET_AGENT: {}, TARGET_ZONE: {}
}

# Properties (Variables) - e.g., "lock_level", "temperature"
# Structure: { target: { key_string: { "label": String, "type": int, "default": Variant } } }
static var properties: Dictionary = {
	TARGET_NODE: {}, TARGET_EDGE: {}, TARGET_AGENT: {}, TARGET_ZONE: {}
}

# ------------------------------------------------------------------------------
# 2. INITIALIZATION & ENUMS
# ------------------------------------------------------------------------------
enum DisplayMode { HIDDEN = 0, LABEL = 1, BADGE = 2 }

static func _static_init() -> void:
	# --- DEFAULT NODE CATEGORIES ---
	register_category(TARGET_NODE, "empty", "Empty", Color(0.8, 0.8, 0.8))
	register_category(TARGET_NODE, "spawn", "Spawn", Color(0.2, 0.8, 0.2))
	register_category(TARGET_NODE, "enemy", "Enemy", Color(0.8, 0.3, 0.3))
	register_category(TARGET_NODE, "treasure", "Treasure", Color(1.0, 0.8, 0.2))
	register_category(TARGET_NODE, "boss", "Boss", Color(0.6, 0.0, 0.0))
	register_category(TARGET_NODE, "shop", "Shop", Color(0.4, 0.2, 0.6))

	# --- DEFAULT EDGE CATEGORIES ---
	register_category(TARGET_EDGE, "corridor", "Corridor", Color(0.8, 0.8, 0.8))
	register_category(TARGET_EDGE, "door_open", "Door (Open)", Color(0.6, 0.4, 0.2))
	register_category(TARGET_EDGE, "door_locked", "Door (Locked)", Color(0.8, 0.2, 0.2))
	register_category(TARGET_EDGE, "secret", "Secret Passage", Color(0.4, 0.2, 0.8))
	register_category(TARGET_EDGE, "climbable", "Climbable", Color(0.8, 0.6, 0.2))

	# --- DEFAULT PROPERTIES ---
	register_property(TARGET_EDGE, "lock_level", "Lock Level", TYPE_INT, 0, DisplayMode.HIDDEN)
	
	# Physics Properties
	register_property(TARGET_NODE, "physics_repulsion", "Physics Repulsion", TYPE_FLOAT, 100.0, DisplayMode.HIDDEN)
	register_property(TARGET_EDGE, "physics_spring_length", "Spring Length", TYPE_FLOAT, 150.0, DisplayMode.HIDDEN)
	register_property(TARGET_EDGE, "physics_stiffness", "Spring Stiffness", TYPE_FLOAT, 0.5, DisplayMode.HIDDEN)
	register_property(TARGET_NODE, "physics_mode", "Physics Mode", TYPE_INT, 0, DisplayMode.HIDDEN)
	register_property(TARGET_EDGE, "physics_mode", "Physics Mode", TYPE_INT, 0, DisplayMode.HIDDEN)

# ------------------------------------------------------------------------------
# 3. CATEGORY API (Types & Tags)
# ------------------------------------------------------------------------------
static func register_category(target: String, key: String, display_name: String, color: Color) -> void:
	categories[target][key] = {
		"name": display_name,
		"color": color
	}

static func remove_category(target: String, key: String) -> void:
	if categories[target].has(key):
		categories[target].erase(key)

static func get_category_color(target: String, key: String) -> Color:
	if categories[target].has(key):
		return categories[target][key]["color"]
	return Color.MAGENTA # Error/Fallback color

static func get_category_name(target: String, key: String) -> String:
	if categories[target].has(key):
		return categories[target][key]["name"]
	return "Unknown"

# UI Helper: Generates the comma-separated string for OptionButton dropdowns!
static func get_category_ui_schema(target: String) -> Dictionary:
	var keys = []
	var names = []
	for key in categories[target]:
		keys.append(key)
		names.append(categories[target][key]["name"])
		
	return {
		"keys": keys, # We need this to map UI index back to the string key
		"hint_string": ",".join(names)
	}

# ------------------------------------------------------------------------------
# 4. PROPERTY API (Custom Variables)
# ------------------------------------------------------------------------------
static func register_property(target: String, key: String, label: String, type: int, default_val: Variant, display_mode: int = 0) -> void:
	properties[target][key] = {
		"label": label,
		"type": type,
		"default": default_val,
		"display": display_mode
	}

static func ensure_property(target: String, key: String, label: String, type: int, default_val: Variant, display_mode: int = 0) -> void:
	if not properties[target].has(key):
		register_property(target, key, label, type, default_val, display_mode)

static func remove_property(target: String, key: String) -> void:
	if properties[target].has(key):
		properties[target].erase(key)

static func get_properties_for_target(target: String) -> Dictionary:
	return properties[target]
	
# Safely registers a category only if it doesn't already exist.
# Prevents overwriting user-customized colors/names!
static func ensure_category(target: String, key: String, display_name: String, color: Color) -> void:
	if not categories[target].has(key):
		register_category(target, key, display_name, color)
