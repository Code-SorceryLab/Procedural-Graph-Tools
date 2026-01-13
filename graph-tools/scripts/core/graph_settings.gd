class_name GraphSettings

# ==============================================================================
# 1. GRID & SPATIAL SETTINGS
# ==============================================================================

static var GRID_SPACING: Vector2 = Vector2(60.0, 60.0)

const INSPECTOR_POS_STEP: float = 1.0
static var SHOW_GRID: bool = true

# Helper to update global grid settings safely
static func set_global_grid_spacing(new_spacing: Vector2) -> void:
	GRID_SPACING = new_spacing

# ==============================================================================
# 2. ALGORITHM & PARAMETER DEFINITIONS
# ==============================================================================

# Centralized definitions for UI Tooltips
const PARAM_TOOLTIPS = {
	"common": {
		"width": "The horizontal size of the generation area in grid cells.",
		"height": "The vertical size of the generation area in grid cells.",
		"steps": "The total number of steps or nodes to generate.",
		"merge": "If enabled, new nodes will connect to existing ones when they overlap.\nIf disabled, they will layer on top."
	},
	"ca": {
		"fill": "The percentage (0-100) of the grid that starts as solid walls.\n45% is the standard for cave generation.",
		"iter": "The number of smoothing passes to apply.\nMore iterations create smoother walls and larger chambers."
	},
	"dla": {
		"particles": "The total number of particles to spawn and aggregate.",
		"box_spawn": "If enabled, particles spawn from the bounding box edges.\nIf disabled, they spawn in a circle.",
		"gravity": "The strength of the pull towards the center (0.0 - 1.0).\nHigher values create dense, compact clusters.\nLower values create branching, coral-like structures. \nLower gravity is also less performant."
	},
	"polar": {
		"wedges": "The number of angular sectors to divide the circle into.\nExample: 6 creates a Hexagon, 4 creates a Square/Diamond.",
		"radius": "The number of concentric rings extending outward from the center.",
		"jitter": "Adds random noise to node positions, making the structure look more organic/ruined.",
		"amount": "The maximum pixel distance a node can be displaced from its perfect grid position."
	},
	"walker": {
		"steps": "The total number of nodes (steps) the agent will walk.",
		"branch": "If enabled when 'Growing', the walker picks a random starting point from existing nodes.\nIf disabled, it continues from the last created node.",
		"mode": "Grow: Creates new nodes in the void.\nPaint: Traverses existing nodes and changes their type.",
		"count": "Number of independent walkers simulating simultaneously.",
		"paint_type": "The RoomType applied to NEW walkers. Use the Inspector to modify existing active walkers.",
	},
	"analyze": {
		"auto": "If enabled, the algorithm runs a Breadth-First Search (BFS) to identify the network topology.\nIt marks the Start node (0,0), the furthest node (Boss), and dead ends (Treasure/Enemy)."
	},
"mst": {
		"range": "Multiplier for the search radius (relative to Cell Size).\n2.0 connects immediate neighbors.\n5.0 jumps gaps to connect distant islands.",
		"braid": "The percentage (0-100) of 'rejected' connections to restore.\n0% = Perfect Maze (One path).\n20% = Loopy dungeon with multiple routes.",
		"algo": "Choose the Algorithm:\n\nKRUSKAL (Default): Extremely fast. Connects shortest edges first globally.\n\nPRIM: Slower on large graphs. Grows radially from a single point. Can create more 'river-like' branching.",
		
	}
}

# ==============================================================================
# 3. RENDERER VISUALS (SIZES)
# ==============================================================================
const NODE_RADIUS: float = 12.0
const EDGE_WIDTH: float = 3.0

# [NEW] AGENT VISUALS
const AGENT_RADIUS: float = 5.0          # Smaller than nodes (12.0)
const AGENT_CLICK_RADIUS: float = 7.0    # Slightly larger hit-box for easier clicking
const AGENT_STACK_THRESHOLD: int = 5     # 6+ agents become a "Stack Icon"
const AGENT_RING_OFFSET: float = 16.0    # Distance from node center to agent token

# ==============================================================================
# 4. UI STATE COLORS
# ==============================================================================
const COLOR_DEFAULT: Color = Color(0.9, 0.9, 0.9)
const COLOR_HOVER: Color = Color(0.6, 0.8, 1.0)
const COLOR_SELECTED: Color = Color(1.0, 0.6, 0.2)
const COLOR_DRAGGED: Color = Color(1.0, 0.8, 0.2, 0.7)
const COLOR_NEW_GENERATION: Color = Color(0.2, 1.0, 0.8)

const COLOR_SELECT_BOX_Fill: Color = Color(0.6, 0.8, 1.0, 0.2)
const COLOR_SELECT_BOX_BORDER: Color = Color(0.6, 0.8, 1.0, 0.8)

const COLOR_PATH: Color = Color(0.2, 0.8, 0.2)
const COLOR_PATH_START: Color = Color(0.2, 0.8, 0.2)
const COLOR_PATH_END: Color = Color(0.9, 0.2, 0.2)

const COLOR_EDGE: Color = Color(0.8, 0.8, 0.8)

# AGENT COLORS
const COLOR_AGENT_NORMAL: Color = Color(0.5, 0.3, 0.9)   # Purple-ish
const COLOR_AGENT_SELECTED: Color = Color(1.0, 0.9, 0.2) # Gold
const COLOR_AGENT_STACK: Color = Color(1.0, 1.0, 1.0)    # White (for the text/icon)

const COLOR_UI_SUCCESS: Color = Color(0.2, 0.8, 0.2)
const COLOR_UI_ERROR: Color = Color(0.8, 0.3, 0.3)
const COLOR_UI_ACTIVE: Color = Color.WHITE
const COLOR_UI_DISABLED: Color = Color(1, 1, 1, 0.5)

# ==============================================================================
# 5. SEMANTIC ROOM COLORS (DYNAMIC LEGEND)
# ==============================================================================
# Separate Defaults from the Active State so we can restore later.

const DEFAULT_COLORS: Dictionary = {
	NodeData.RoomType.EMPTY:    Color(0.8, 0.8, 0.8),
	NodeData.RoomType.SPAWN:    Color(0.2, 0.8, 0.2),
	NodeData.RoomType.ENEMY:    Color(0.8, 0.3, 0.3),
	NodeData.RoomType.TREASURE: Color(1.0, 0.8, 0.2),
	NodeData.RoomType.BOSS:     Color(0.6, 0.0, 0.0),
	NodeData.RoomType.SHOP:     Color(0.4, 0.2, 0.6)
}

const DEFAULT_NAMES: Dictionary = {
	NodeData.RoomType.EMPTY:    "Empty",
	NodeData.RoomType.SPAWN:    "Spawn",
	NodeData.RoomType.ENEMY:    "Enemy",
	NodeData.RoomType.TREASURE: "Treasure",
	NodeData.RoomType.BOSS:     "Boss",
	NodeData.RoomType.SHOP:     "Shop"
}

# The Mutable Dictionary used by the Runtime
static var current_colors: Dictionary = DEFAULT_COLORS.duplicate()
static var current_names: Dictionary = DEFAULT_NAMES.duplicate()

# ==============================================================================
# 6. TOOL DEFINITIONS
# ==============================================================================
# Reordered to match Input Map Keys (1 through 7)
enum Tool { SELECT, ADD_NODE, DELETE, CONNECT, CUT, PAINT, TYPE_PAINT, SPAWN }

const ICON_PLACEHOLDER = "res://assets/icons/tool_placeholder.svg"

# 1. VISUAL ORDER (Can be changed anytime without breaking hotkeys)
static var TOOLBAR_LAYOUT: Array[Tool] = [
	Tool.SELECT,
	Tool.ADD_NODE,
	Tool.DELETE,
	Tool.CONNECT,
	Tool.CUT,
	Tool.PAINT,
	Tool.TYPE_PAINT,
	Tool.SPAWN
]

# 2. DEFINITIONS (Now includes the explicit 'action' again)
static var TOOL_DATA: Dictionary = {
	Tool.SELECT:     { "name": "Select",     "action": "tool_select",  "icon_path": "res://assets/icons/tool_select.png" },
	Tool.ADD_NODE:   { "name": "Add Node",   "action": "tool_add",     "icon_path": "res://assets/icons/tool_add.png" },
	Tool.DELETE:     { "name": "Delete",     "action": "tool_delete",  "icon_path": "res://assets/icons/tool_delete.png" },
	Tool.CONNECT:    { "name": "Connect",    "action": "tool_connect", "icon_path": "res://assets/icons/tool_connect.png" },
	Tool.CUT:        { "name": "Knife Cut",  "action": "tool_cut",     "icon_path": "res://assets/icons/tool_cut.png" },
	Tool.PAINT:      { "name": "Paint",      "action": "tool_paint",   "icon_path": "res://assets/icons/tool_paint.png" },
	Tool.TYPE_PAINT: { "name": "Type Brush", "action": "tool_type",    "icon_path": "res://assets/icons/tool_type.png" },
	Tool.SPAWN:      { "name": "Agent Spawner", "action": "tool_spawn", "icon_path": ""}
}

# ==============================================================================
# 7. DYNAMIC PROPERTY DEFINITIONS
# ==============================================================================

# --- DYNAMIC PROPERTY SCHEMA ---
# Stores definitions for custom data fields.
# Structure: { "property_name": { "target": "NODE", "type": TYPE_FLOAT, "default": 0.0 } }
static var property_definitions: Dictionary = {}

const TARGET_NODE = "NODE"
const TARGET_EDGE = "EDGE"
const TARGET_AGENT = "AGENT"

static func register_property(prop_name: String, target: String, type: int, default_val: Variant) -> void:
	property_definitions[prop_name] = {
		"target": target,
		"type": type,
		"default": default_val
	}

static func unregister_property(prop_name: String) -> void:
	if property_definitions.has(prop_name):
		property_definitions.erase(prop_name)

static func get_properties_for_target(target: String) -> Dictionary:
	var result = {}
	for key in property_definitions:
		if property_definitions[key]["target"] == target:
			result[key] = property_definitions[key]
	return result

static func clear_schema() -> void:
	property_definitions.clear()

# ==============================================================================
# 8. COMMAND DEFINITIONS
# ==============================================================================
static var MAX_HISTORY_STEPS: int = 50
static var USE_ATOMIC_UNDO: bool = false
static var MAX_ANALYSIS_COUNT: int = 200 # Max items before we skip deep analysis

# ==============================================================================
# 9. HELPER FUNCTIONS
# ==============================================================================

static func get_tool_icon(tool_id: int) -> Texture2D:
	var path = ""
	if TOOL_DATA.has(tool_id):
		path = TOOL_DATA[tool_id].get("icon_path", "")
	if path != "" and FileAccess.file_exists(path):
		return load(path)
	if FileAccess.file_exists(ICON_PLACEHOLDER):
		return load(ICON_PLACEHOLDER)
	return null

static func get_tool_name(tool_id: int) -> String:
	return TOOL_DATA.get(tool_id, {}).get("name", "Unknown")


# 3. SHORTCUT LOOKUP (Simplified again)
# We look up the specific action for this tool, not its slot index.
static func get_shortcut_string(tool_id: int) -> String:
	var action = TOOL_DATA.get(tool_id, {}).get("action", "")
	if action == "": return ""
	
	var events = InputMap.action_get_events(action)
	if events.is_empty(): return ""
	
	for event in events:
		if event is InputEventKey:
			var label = event.as_text_key_label()
			if label == "" or label == "(Unset)":
				label = OS.get_keycode_string(event.physical_keycode)
			return label
	return ""

static func get_shortcut_keycode(tool_id: int) -> int:
	return TOOL_DATA.get(tool_id, {}).get("shortcut", KEY_NONE)



# --- LEGEND HELPERS ---

static func get_color(type_id: int) -> Color:
	return current_colors.get(type_id, Color.MAGENTA) # Fallback if missing

static func get_type_name(type_id: int) -> String:
	return current_names.get(type_id, "Unknown")

static func register_custom_type(id: int, name: String, color: Color) -> void:
	current_colors[id] = color
	current_names[id] = name

static func reset_legend() -> void:
	current_colors = DEFAULT_COLORS.duplicate()
	current_names = DEFAULT_NAMES.duplicate()


	# Helper function to get custom method names
static func get_custom_method_names(object_instance: Object) -> PackedStringArray:
	var method_names := PackedStringArray()
	var script: Script = object_instance.get_script()
	if script:
		# Get methods defined in this script
		var script_methods: Array = script.get_script_method_list()
		for method_dict in script_methods:
			method_names.append(method_dict["name"] as StringName)
	
	return method_names
#Typical Use: GraphSettings.print_custom_method_names(self) in the ready of whatever object you want the functions of.
static func print_custom_method_names(object_instance: Object) -> void:
	print(get_custom_method_names(object_instance))
