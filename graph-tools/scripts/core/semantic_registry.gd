class_name SemanticRegistry
extends Object

const TARGET_NODE = "NODE"
const TARGET_EDGE = "EDGE"
const TARGET_AGENT = "AGENT"
const TARGET_ZONE = "ZONE"

static var categories: Dictionary = {
	TARGET_NODE: {}, TARGET_EDGE: {}, TARGET_AGENT: {}, TARGET_ZONE: {}
}
static var properties: Dictionary = {
	TARGET_NODE: {}, TARGET_EDGE: {}, TARGET_AGENT: {}, TARGET_ZONE: {}
}

enum DisplayMode { HIDDEN = 0, LABEL = 1, BADGE = 2 }

static func _static_init() -> void:
	# --- DEFAULT NODE CATEGORIES (CORE) ---
	register_category(TARGET_NODE, "empty", "Empty", Color(0.8, 0.8, 0.8), true)
	register_category(TARGET_NODE, "spawn", "Spawn", Color(0.2, 0.8, 0.2), true)
	register_category(TARGET_NODE, "enemy", "Enemy", Color(0.8, 0.3, 0.3), true)
	register_category(TARGET_NODE, "treasure", "Treasure", Color(1.0, 0.8, 0.2), true)
	register_category(TARGET_NODE, "boss", "Boss", Color(0.6, 0.0, 0.0), true)
	register_category(TARGET_NODE, "shop", "Shop", Color(0.4, 0.2, 0.6), true)
	
	# --- SCP FACILITY CATEGORIES (CUSTOM / USER DATA) ---
	# Note: No 'true' flag at the end, meaning the user can delete or rename these!
	register_category(TARGET_NODE, "scp_light", "Light Containment", Color(0.9, 0.9, 0.9))
	register_category(TARGET_NODE, "scp_heavy", "Heavy Containment", Color(0.4, 0.4, 0.4))
	register_category(TARGET_NODE, "scp_office", "Research Office", Color(0.6, 0.7, 0.9))
	register_category(TARGET_NODE, "scp_breach", "Breached Sector", Color(0.8, 0.2, 0.2))
	register_property(TARGET_NODE, "clearance_req", "Clearance Required", TYPE_INT, 1, DisplayMode.BADGE)
	
	# --- DEFAULT EDGE CATEGORIES (CORE) ---
	register_category(TARGET_EDGE, "corridor", "Corridor", Color(0.8, 0.8, 0.8), true)
	register_category(TARGET_EDGE, "door_open", "Door (Open)", Color(0.6, 0.4, 0.2), true)
	register_category(TARGET_EDGE, "door_locked", "Door (Locked)", Color(0.8, 0.2, 0.2), true)
	register_category(TARGET_EDGE, "secret", "Secret Passage", Color(0.4, 0.2, 0.8), true)
	register_category(TARGET_EDGE, "climbable", "Climbable", Color(0.8, 0.6, 0.2), true)

	# --- DEFAULT PROPERTIES (CORE) ---
	register_property(TARGET_EDGE, "lock_level", "Lock Level", TYPE_INT, 0, DisplayMode.HIDDEN, true)
	
	# Physics Properties (CORE)
	register_property(TARGET_NODE, "physics_repulsion", "Physics Repulsion", TYPE_FLOAT, 100.0, DisplayMode.HIDDEN, true)
	register_property(TARGET_NODE, "physics_mode", "Physics Mode", TYPE_INT, 0, DisplayMode.HIDDEN, true)
	register_property(TARGET_NODE, "physics_fusable", "Can Fuse (Collision)", TYPE_BOOL, false, DisplayMode.HIDDEN, true)
	
	# --- EDGE PHYSICS PROPERTIES (Ensure these all have 'true' at the end!) ---
	register_property(TARGET_EDGE, "physics_mode", "Physics Mode", TYPE_INT, 0, DisplayMode.HIDDEN, true)
	register_property(TARGET_EDGE, "physics_spring_length", "Spring Length", TYPE_FLOAT, 150.0, DisplayMode.HIDDEN, true)
	register_property(TARGET_EDGE, "physics_stiffness", "Spring Stiffness", TYPE_FLOAT, 0.5, DisplayMode.HIDDEN, true)
	
	# Add the two snappable properties from InspectorEdge so they lock properly
	register_property(TARGET_EDGE, "physics_snappable", "Can Snap (Tension)", TYPE_BOOL, false, DisplayMode.HIDDEN, true)
	register_property(TARGET_EDGE, "physics_snap_threshold", "Snap Threshold", TYPE_FLOAT, 400.0, DisplayMode.HIDDEN, true)
	
	# Load user-created semantic fields from disk
	ConfigManager.load_semantic_data(categories, properties)

# ------------------------------------------------------------------------------
# 3. CATEGORY API
# ------------------------------------------------------------------------------
static func register_category(target: String, key: String, display_name: String, color: Color, is_core: bool = false) -> void:
	if categories[target].has(key) and categories[target][key].get("is_core", false):
		return # Protect existing core variables from being overwritten
	categories[target][key] = { "name": display_name, "color": color, "is_core": is_core }

static func remove_category(target: String, key: String) -> void:
	if categories[target].has(key):
		if categories[target][key].get("is_core", false):
			push_error("SemanticRegistry: Cannot delete core category '%s'." % key)
			return
		categories[target].erase(key)

static func get_category_color(target: String, key: String) -> Color:
	if categories[target].has(key): return categories[target][key]["color"]
	return Color.MAGENTA

static func get_category_name(target: String, key: String) -> String:
	if categories[target].has(key): return categories[target][key]["name"]
	return "Unknown"

static func get_category_ui_schema(target: String) -> Dictionary:
	var keys = []
	var names = []
	for key in categories[target]:
		keys.append(key)
		names.append(categories[target][key]["name"])
	return { "keys": keys, "hint_string": ",".join(names) }

static func ensure_category(target: String, key: String, display_name: String, color: Color, is_core: bool = false) -> void:
	if not categories[target].has(key):
		register_category(target, key, display_name, color, is_core)

# ------------------------------------------------------------------------------
# 4. PROPERTY API
# ------------------------------------------------------------------------------
static func register_property(target: String, key: String, label: String, type: int, default_val: Variant, display_mode: int = 0, is_core: bool = false) -> void:
	if properties[target].has(key) and properties[target][key].get("is_core", false):
		return # Protect existing core variables
	properties[target][key] = { "label": label, "type": type, "default": default_val, "display": display_mode, "is_core": is_core }

static func ensure_property(target: String, key: String, label: String, type: int, default_val: Variant, display_mode: int = 0, is_core: bool = false) -> void:
	if not properties[target].has(key):
		register_property(target, key, label, type, default_val, display_mode, is_core)

static func remove_property(target: String, key: String) -> void:
	if properties[target].has(key):
		if properties[target][key].get("is_core", false):
			push_error("SemanticRegistry: Cannot delete core property '%s'." % key)
			return
		properties[target].erase(key)

static func get_properties_for_target(target: String) -> Dictionary:
	return properties[target]

static func save_user_data() -> void:
	ConfigManager.save_semantic_data(categories, properties)
