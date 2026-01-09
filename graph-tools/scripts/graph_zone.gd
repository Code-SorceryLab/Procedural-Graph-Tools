class_name GraphZone
extends Resource

# --- IDENTITY ---
@export var zone_name: String = "Zone"
@export var zone_color: Color = Color(0.2, 0.2, 0.2, 0.3) 

# --- SHAPE DEFINITION ---
@export var cells: Dictionary = {} # Dictionary[Vector2i, bool]
@export var bounds: Rect2 = Rect2()

# --- RULES ---
@export var allow_new_nodes: bool = false
@export var traversal_cost: float = 1.0 

# --- PORTS ---
@export var ports: Array[String] = [] 

func _init(p_name: String = "Zone", p_color: Color = Color(0.5, 0.5, 0.5, 0.3)) -> void:
	zone_name = p_name
	zone_color = p_color

# --- HELPER: Shape Management ---
func add_cell(grid_pos: Vector2i, spacing: Vector2) -> void:
	cells[grid_pos] = true
	
	# Update Bounds
	var world_pos = Vector2(grid_pos.x * spacing.x, grid_pos.y * spacing.y)
	# We assume the cell is centered on the point, or top-left. 
	# For simplicity in this grid system, points are usually centers.
	# Let's define the bounds as covering the area around the point.
	var size = spacing
	var tl = world_pos - (size / 2.0)
	var rect = Rect2(tl, size)
	
	if bounds.has_area():
		bounds = bounds.merge(rect)
	else:
		bounds = rect

func has_cell(grid_pos: Vector2i) -> bool:
	return cells.has(grid_pos)
