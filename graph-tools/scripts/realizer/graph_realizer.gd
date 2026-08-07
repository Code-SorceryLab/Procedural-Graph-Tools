class_name GraphRealizer
extends RefCounted

var grid: GridData
var palette: TilePalette

# Coordinate mapping
var _world_offset: Vector2 = Vector2.ZERO
var _scale_factor: float = 50.0 
var _padding: int = 10

# Stashed IDs for external reference
var floor_id: int
var wall_id: int

var semantic_floor_ids: Dictionary = {} # Maps node_type string -> Tile ID
var semantic_wall_map: Dictionary = {} # Maps Floor ID -> Wall ID

func realize(graph: Graph, params: Dictionary = {}) -> GridData:
	_scale_factor = params.get("grid_scale", 50.0) 
	_padding = params.get("padding", 10)
	
	palette = TilePalette.new()
	floor_id = palette.register_tile("Floor", { "walkable": true })
	wall_id = palette.register_tile("Wall", { "walkable": false })
	
	# Register Floors AND Walls for Semantic Types
	var node_cats = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE]
	for cat_key in node_cats:
		var s_floor = palette.register_tile("Floor_" + cat_key, { "walkable": true })
		var s_wall = palette.register_tile("Wall_" + cat_key, { "walkable": false })
		
		semantic_floor_ids[cat_key] = s_floor
		semantic_wall_map[s_floor] = s_wall # Link them together!

	var stats = graph.get_spatial_stats()
	var bounds: Rect2 = stats.get("bounds", Rect2(0, 0, 100, 100))
	_world_offset = bounds.position
	
	var grid_w = int(bounds.size.x / _scale_factor) + (_padding * 2)
	var grid_h = int(bounds.size.y / _scale_factor) + (_padding * 2)
	grid_w = max(10, grid_w)
	grid_h = max(10, grid_h)
	
	grid = GridData.new(grid_w, grid_h, palette)
	
	# --- PIPELINE EXECUTION ---
	RoomAllocator.allocate(graph, self, floor_id, params)
	EdgeRouter.route(graph, self, floor_id, params)
	CellularSmoother.smooth(self, floor_id, params)
	
	# Pass the mapping to the generator so we get themed walls!
	WallGenerator.generate(grid, wall_id, semantic_wall_map) 
	
	return grid

# --- SPATIAL HELPERS ---

# Translates an abstract Graph Vector2 into a strict Grid Vector2i
func world_to_grid(world_pos: Vector2) -> Vector2i:
	var local_x = (world_pos.x - _world_offset.x) / _scale_factor
	var local_y = (world_pos.y - _world_offset.y) / _scale_factor
	
	return Vector2i(int(local_x) + _padding, int(local_y) + _padding)

# Translates a Grid index back into Godot world space (for spawning players/enemies later)
func grid_to_world(grid_pos: Vector2i) -> Vector2:
	var local_x = float(grid_pos.x - _padding) * _scale_factor
	var local_y = float(grid_pos.y - _padding) * _scale_factor
	
	return Vector2(local_x + _world_offset.x, local_y + _world_offset.y)
