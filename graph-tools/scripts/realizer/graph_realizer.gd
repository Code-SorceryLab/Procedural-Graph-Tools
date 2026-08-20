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
var debug_path_id: int

var semantic_floor_ids: Dictionary = {} 
var semantic_wall_map: Dictionary = {} 

#  The exact mathematical footprint of all corridors!
var critical_path_cells: Dictionary = {} 
var reserved_cells: Dictionary = {} # Tracks multi-tile structures!

var room_cells: Dictionary = {} # Protects room interiors from being eroded
var core_path_cells: Dictionary = {} # Protects the absolute center of the hallway
var floor_to_semantic: Dictionary = {} # Maps a Tile ID back to its Biome Key
var distance_field: Dictionary = {} # Stores Vector2i -> Int

func realize(graph: Graph, params: Dictionary, shopping_lists: Dictionary, progress_callback: Callable = Callable()) -> GridData:
	var start_time = Time.get_ticks_msec() 
	
	_scale_factor = params.get("grid_scale", 50.0) 
	_padding = params.get("padding", 10)
	
	palette = TilePalette.new()
	floor_id = palette.register_tile("Floor", { "walkable": true })
	wall_id = palette.register_tile("Wall", { "walkable": false })
	debug_path_id = palette.register_tile("DebugPath", { "walkable": true })
	
	critical_path_cells.clear()
	reserved_cells.clear()
	room_cells.clear()
	core_path_cells.clear()
	floor_to_semantic.clear()
	distance_field.clear()
	
	var node_cats = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE]
	for cat_key in node_cats:
		var s_floor = palette.register_tile("Floor_" + cat_key, { "walkable": true })
		var s_wall = palette.register_tile("Wall_" + cat_key, { "walkable": false })
		
		semantic_floor_ids[cat_key] = s_floor
		semantic_wall_map[s_floor] = s_wall 
		floor_to_semantic[s_floor] = cat_key
		
	var stats = graph.get_spatial_stats()
	var bounds: Rect2 = stats.get("bounds", Rect2(0, 0, 100, 100))
	_world_offset = bounds.position
	
	var grid_w = int(bounds.size.x / _scale_factor) + (_padding * 2)
	var grid_h = int(bounds.size.y / _scale_factor) + (_padding * 2)
	grid_w = max(10, grid_w)
	grid_h = max(10, grid_h)
	
	grid = GridData.new(grid_w, grid_h, palette)
	
	var emit = func(step_name: String):
		if progress_callback.is_valid():
			var cells_copy = grid.cells.duplicate()
			var entities_copy = grid.entities.duplicate(true)
			var atlas_copy = grid.cell_atlas_overrides.duplicate(true)
			
			# Add atlas_copy to the parameters
			progress_callback.call_deferred(step_name, cells_copy, entities_copy, atlas_copy, grid.width, grid.height)
			OS.delay_msec(150)
			
	# --- PIPELINE EXECUTION ---
	emit.call("Start: Base Initialization")
	
	RoomAllocator.allocate(graph, self, floor_id, params)
	emit.call("Room Allocation")
	
	EdgeRouter.route(graph, self, floor_id, params)
	emit.call("Edge Routing")
	
	CellularSmoother.smooth(self, floor_id, params)
	emit.call("Cellular Smoothing")
	
	PathEroder.erode(self, params)
	emit.call("Path Erosion")
	
	ZoneDecorator.decorate(self, params)
	emit.call("Applying Zone Decor")
	
	DistanceMapper.map(self)
	emit.call("Mapping Distance Fields")
	
	StructurePlacer.place(graph, self, params, shopping_lists)
	emit.call("Placing Structures")
	
	ProgressionSolver.analyze(self, params, emit) 
	emit.call("Progression Analysis Complete")
	
	EntityScatterer.scatter(graph, self, params, shopping_lists)
	emit.call("Scattering Props & Entities")
	
	WallGenerator.generate(self, wall_id, semantic_wall_map) 
	emit.call("Generating Outer Walls")
	
	# --- Run a headless validation pass (delay_doors = false) ---
	var val_results = GenerationValidator.run(grid, false, true, false, Callable(), Callable())
	
	var final_report = {}
	if self.has_meta("progression_report"):
		final_report = self.get_meta("progression_report")
		
	final_report["meta"] = {
		"seed": params.get("realizer_seed", "default"),
		"time_ms": Time.get_ticks_msec() - start_time
	}
	final_report["analytics"] = val_results
	
	self.set_meta("progression_report", final_report)
	emit.call("Finalizing Analytics Report")
	
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
