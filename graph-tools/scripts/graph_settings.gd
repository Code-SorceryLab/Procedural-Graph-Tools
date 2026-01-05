class_name GraphSettings

# ==============================================================================
# 1. GRID & SPATIAL SETTINGS
# ==============================================================================
# Defines the coarse grid used for snapping nodes.
# Smaller values allow for more precise placement but can look cluttered.
# Larger values make it easier to align rooms perfectly.
const CELL_SIZE: float = 60.0

# The vector used by 'snap()' functions in tools.
const SNAP_GRID_SIZE: Vector2 = Vector2(CELL_SIZE, CELL_SIZE)


# ==============================================================================
# 2. RENDERER VISUALS (SIZES)
# ==============================================================================
# The radius of the node circle in pixels.
# NOTE: SpatialGrid uses this * 4 for bucket sizes, so changing this 
# significantly might require tweaking SpatialGrid optimization.
const NODE_RADIUS: float = 12.0

# The thickness of connection lines.
const EDGE_WIDTH: float = 3.0


# ==============================================================================
# 3. UI STATE COLORS
# ==============================================================================
# Standard state colors
const COLOR_DEFAULT: Color = Color(0.9, 0.9, 0.9)          # Normal node (White-ish)
const COLOR_HOVER: Color = Color(0.6, 0.8, 1.0)            # Mouse-over highlight (Light Blue)
const COLOR_SELECTED: Color = Color(1.0, 0.6, 0.2)         # Selection (Orange)
const COLOR_DRAGGED: Color = Color(1.0, 0.8, 0.2, 0.7)     # Dragging preview (Transparent Orange)
const COLOR_NEW_GENERATION: Color = Color(0.2, 1.0, 0.8)   # Newly generated nodes (Cyan)

const COLOR_SELECT_BOX_Fill: Color = Color(0.6, 0.8, 1.0, 0.2)  # Selection Box Fill (Transparent Light Blue)
const COLOR_SELECT_BOX_BORDER: Color = Color(0.6, 0.8, 1.0, 0.8)  # Selection Box Border (Transparent Light Blue)

# Pathfinding Analysis Colors
const COLOR_PATH: Color = Color(0.2, 0.8, 0.2)             # The line drawn for the path
const COLOR_PATH_START: Color = Color(0.2, 0.8, 0.2)       # Start Node Indicator (Green)
const COLOR_PATH_END: Color = Color(0.9, 0.2, 0.2)         # End Node Indicator (Red)

# Edge Colors
const COLOR_EDGE: Color = Color(0.8, 0.8, 0.8)             # Standard connection line

# UI Feedback Colors (Status Labels & Buttons)
const COLOR_UI_SUCCESS: Color = Color(0.2, 0.8, 0.2)       # Success messages (Green)
const COLOR_UI_ERROR: Color = Color(0.8, 0.3, 0.3)         # Error messages (Red)
const COLOR_UI_ACTIVE: Color = Color.WHITE                   # Enabled buttons (Standard)
const COLOR_UI_DISABLED: Color = Color(1, 1, 1, 0.5)       # Disabled/Dimmed buttons

# ==============================================================================
# 4. SEMANTIC ROOM COLORS
# ==============================================================================
# These match the 'type' field in NodeData.
# Used to visualize the dungeon's logical structure.
const ROOM_COLORS: Dictionary = {
	NodeData.RoomType.EMPTY:    Color(0.8, 0.8, 0.8), # Gray (Corridors)
	NodeData.RoomType.SPAWN:    Color(0.2, 0.8, 0.2), # Green (Start)
	NodeData.RoomType.ENEMY:    Color(0.8, 0.3, 0.3), # Red (Combat)
	NodeData.RoomType.TREASURE: Color(1.0, 0.8, 0.2), # Gold (Reward)
	NodeData.RoomType.BOSS:     Color(0.6, 0.0, 0.0), # Dark Red (Final Challenge)
	NodeData.RoomType.SHOP:     Color(0.4, 0.2, 0.6)  # Purple (Merchant)
}


# ==============================================================================
# 5. TOOL DEFINITIONS
# ==============================================================================
# Global Enum for the Tool State Machine.
# Used by Toolbar (UI) and GraphEditor (Logic) to stay in sync.
enum Tool {
	SELECT = 0,
	ADD_NODE = 1,
	CONNECT = 2,
	DELETE = 3,
	RECTANGLE = 4,
	MEASURE = 5,
	PAINT = 6,
	CUT = 7,
}
