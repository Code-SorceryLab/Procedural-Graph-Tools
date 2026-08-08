class_name GridData
extends RefCounted

var width: int
var height: int
var cells: PackedInt32Array
var palette: TilePalette

var entities: Dictionary = {} # Maps Vector2i(x, y) -> Dictionary (Entity Data)

func _init(w: int, h: int, p_palette: TilePalette = null) -> void:
	width = max(1, w)
	height = max(1, h)
	
	# PackedInt32Array is highly optimized for contiguous CPU cache
	cells = PackedInt32Array()
	cells.resize(width * height)
	cells.fill(0) # Fill with VOID_ID
	
	palette = p_palette if p_palette != null else TilePalette.new()

# --- 1D to 2D MATH WRAPPERS ---

# Inline helper to convert X/Y into the 1D array index
func _get_index(x: int, y: int) -> int:
	return y * width + x

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < width and y >= 0 and y < height

func in_bounds_vec(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < width and pos.y >= 0 and pos.y < height

# --- CORE API ---

func set_cell(x: int, y: int, id: int) -> void:
	if in_bounds(x, y):
		cells[_get_index(x, y)] = id

func get_cell(x: int, y: int) -> int:
	if in_bounds(x, y):
		return cells[_get_index(x, y)]
	return 0 # VOID_ID

# Fetches the semantic data directly from the coordinate
func get_cell_data(x: int, y: int) -> Dictionary:
	var id = get_cell(x, y)
	return palette.get_data(id)

# --- BULK OPERATIONS ---

func fill(id: int) -> void:
	cells.fill(id)

# This will be the workhorse function for stamping abstract Graph nodes 
# down as physical 2D room footprints!
func fill_rect(rect: Rect2i, id: int) -> void:
	var start_x = max(0, rect.position.x)
	var start_y = max(0, rect.position.y)
	var end_x = min(width, rect.end.x)
	var end_y = min(height, rect.end.y)
	
	for y in range(start_y, end_y):
		for x in range(start_x, end_x):
			cells[_get_index(x, y)] = id

# Stamps a rasterized circle using the distance squared formula
func fill_circle(center_x: int, center_y: int, radius: int, id: int) -> void:
	var r_squared = radius * radius
	
	var start_x = max(0, center_x - radius)
	var start_y = max(0, center_y - radius)
	var end_x = min(width - 1, center_x + radius)
	var end_y = min(height - 1, center_y + radius)
	
	for y in range(start_y, end_y + 1):
		for x in range(start_x, end_x + 1):
			# Distance squared check
			var dx = x - center_x
			var dy = y - center_y
			if (dx * dx) + (dy * dy) <= r_squared:
				cells[_get_index(x, y)] = id
