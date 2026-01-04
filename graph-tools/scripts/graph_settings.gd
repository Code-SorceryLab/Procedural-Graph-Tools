class_name GraphSettings

# Grid & Generation Constants
const CELL_SIZE: float = 60.0
const SNAP_GRID_SIZE: Vector2 = Vector2(CELL_SIZE, CELL_SIZE)

# Visual Constants
const NODE_RADIUS: float = 12.0
const EDGE_WIDTH: float = 3.0

# Colors
const COLOR_DEFAULT: Color = Color(0.9, 0.9, 0.9)
const COLOR_SELECTED: Color = Color(1.0, 0.6, 0.2)
const COLOR_PATH: Color = Color(0.2, 0.8, 0.2)
const COLOR_HOVER: Color = Color(0.6, 0.8, 1.0)
const COLOR_EDGE: Color = Color(0.8, 0.8, 0.8)
const COLOR_NEW_GENERATION: Color = Color(0.2, 1.0, 0.8) # Cyan / Light Blue
const COLOR_DRAGGED: Color = Color(1.0, 0.8, 0.2, 0.7)  # Semi-transparent orange

# Room Type Colors
const ROOM_COLORS: Dictionary = {
	NodeData.RoomType.EMPTY:    Color(0.8, 0.8, 0.8), # Gray
	NodeData.RoomType.SPAWN:    Color(0.2, 0.8, 0.2), # Green
	NodeData.RoomType.ENEMY:    Color(0.8, 0.3, 0.3), # Red
	NodeData.RoomType.TREASURE: Color(1.0, 0.8, 0.2), # Gold
	NodeData.RoomType.BOSS:     Color(0.6, 0.0, 0.0), # Dark Red
	NodeData.RoomType.SHOP:     Color(0.4, 0.2, 0.6)  # Purple
}

# SHARED TOOL DEFINITIONS
enum Tool {
	SELECT = 0,
	ADD_NODE = 1,
	CONNECT = 2,
	DELETE = 3,
	RECTANGLE = 4,
	MEASURE = 5,
	PAN = 6
}
