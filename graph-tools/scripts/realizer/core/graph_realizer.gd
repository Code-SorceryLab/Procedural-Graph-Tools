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

#  The exact mathematical footprint of all corridors
var critical_path_cells: Dictionary = {} 
var reserved_cells: Dictionary = {} # Tracks multi-tile structures

# --- TOPOLOGY TRACKING ---
var cell_to_nodes: Dictionary = {} # Vector2i -> Dictionary[String, bool] (Supports multiple nodes per cell)
var cell_to_edges: Dictionary = {} # Vector2i -> Dictionary[String, bool]

var room_cells: Dictionary = {} # Protects room interiors from being eroded
var core_path_cells: Dictionary = {} # Protects the absolute center of the hallway
var floor_to_semantic: Dictionary = {} # Maps a Tile ID back to its Biome Key
var distance_field: Dictionary = {} # Stores Vector2i -> Int

func realize(graph: Graph, params: Dictionary, shopping_lists: Dictionary, progress_callback: Callable = Callable(), old_realizer: GraphRealizer = null) -> GridData:
	var start_time = Time.get_ticks_msec() 
	
	_scale_factor = params.get("grid_scale", 50.0) 
	_padding = params.get("padding", 10)
	
	palette = TilePalette.new()
	floor_id = palette.register_tile("Floor", { "walkable": true })
	wall_id = palette.register_tile("Wall", { "walkable": false })
	debug_path_id = palette.register_tile("DebugPath", { "walkable": true })
	
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
	
	# ==========================================================================
	# STATE INITIALIZATION (Blank vs. Regeneration)
	# ==========================================================================
	if old_realizer == null:
		# --- FULL RASTERIZATION (Start from Scratch) ---
		critical_path_cells.clear()
		reserved_cells.clear()
		room_cells.clear()
		core_path_cells.clear()
		distance_field.clear()
		cell_to_nodes.clear()
		cell_to_edges.clear()
		
		var grid_w = int(bounds.size.x / _scale_factor) + (_padding * 2)
		var grid_h = int(bounds.size.y / _scale_factor) + (_padding * 2)
		grid_w = max(10, grid_w)
		grid_h = max(10, grid_h)
		
		grid = GridData.new(grid_w, grid_h, palette)
	else:
		# --- DYNAMIC REGENERATION (Clone the old state!) ---
		# Stash the vital entities BEFORE the wipe map deletes them!
		for pos in old_realizer.grid.entities:
			var type = old_realizer.grid.entities[pos].get("type", "")
			if type == "start_point": params["_archived_start_pos"] = pos
			elif type == "end_point": params["_archived_end_pos"] = pos
			
		grid = GridData.new(old_realizer.grid.width, old_realizer.grid.height, palette)
		grid.cells = old_realizer.grid.cells.duplicate()
		grid.cell_atlas_overrides = old_realizer.grid.cell_atlas_overrides.duplicate(true)
		grid.entities = old_realizer.grid.entities.duplicate(true)
		
		critical_path_cells = old_realizer.critical_path_cells.duplicate()
		reserved_cells = old_realizer.reserved_cells.duplicate()
		room_cells = old_realizer.room_cells.duplicate()
		core_path_cells = old_realizer.core_path_cells.duplicate()
		distance_field = old_realizer.distance_field.duplicate()
		cell_to_nodes = old_realizer.cell_to_nodes.duplicate(true)
		cell_to_edges = old_realizer.cell_to_edges.duplicate(true)
		
		if old_realizer.has_meta("custom_room_cells"):
			self.set_meta("custom_room_cells", old_realizer.get_meta("custom_room_cells").duplicate())
			
		# Carve out the exact Dirty Rect provided by the params
		if params.has("regen_dirty_rect"):
			var inf_nodes = params.get("regen_target_nodes", [])
			var inf_edges = params.get("regen_target_edges", [])
			# [FIXED] Pass the params dictionary so it can read the toggles!
			DynamicRegenUtils.carve_dirty_rect(self, params, params["regen_dirty_rect"], inf_nodes, inf_edges)
	# ==========================================================================
	
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
	
	# Fetch execution toggles 
	# (If this is a fresh initial generation, force ALL layers to build!)
	var is_regen = (old_realizer != null)
	var do_geo = not is_regen or params.get("regen_layer_geometry", true)
	var do_prog = not is_regen or params.get("regen_layer_progression", true)
	var do_struct = not is_regen or params.get("regen_layer_structures", true)
	var do_ents = not is_regen or params.get("regen_layer_entities", true)
	var do_tex = not is_regen or params.get("regen_layer_textures", true)
	
	if do_geo:
		RoomAllocator.allocate(graph, self, floor_id, params, emit)
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
		
	if do_struct:
		StructurePlacer.place(graph, self, params, shopping_lists)
		emit.call("Placing Structures")
		
	if do_prog:
		print("[GraphRealizer] Progression pass triggered. is_regen = ", is_regen)
		ProgressionSolver.analyze(self, params, emit)
	else:
		print("[GraphRealizer] Progression pass SKIPPED. regen_layer_progression = ", params.get("regen_layer_progression", true))
		
	if do_ents:
		EntityScatterer.scatter(graph, self, params, shopping_lists)
		emit.call("Scattering Props & Entities")
		TriggerPlacer.place(graph, self, params)
		emit.call("Placing Temporal Triggers")
		
	if do_geo:
		WallGenerator.generate(graph, self, params, wall_id, semantic_wall_map) 
		emit.call("Generating Outer Walls")
		
	if do_tex:
		TexturalWFCPass.apply(self, params, emit)
		emit.call("Applying Organic Textural WFC")
	
	# --- Run a headless validation pass (full_explore = true, delay_doors = false) ---
	var headless_validator = GenerationValidator.new(grid, true, false)
	headless_validator.fast_forward()
	var val_results = headless_validator.get_final_analytics()
	
	var final_report = {}
	if self.has_meta("progression_report"):
		final_report = self.get_meta("progression_report")
		
	final_report["meta"] = {
		"seed": params.get("realizer_seed", "default"),
		"time_ms": Time.get_ticks_msec() - start_time,
		"custom_rooms_placed": self.get_meta("metric_custom_rooms") if self.has_meta("metric_custom_rooms") else 0,
		"rejected_custom_rooms": self.get_meta("metric_rejected_custom_rooms") if self.has_meta("metric_rejected_custom_rooms") else 0,
		"sealed_doorways": self.get_meta("metric_doors_sealed") if self.has_meta("metric_doors_sealed") else 0,
		"failed_routes": self.get_meta("metric_failed_routes") if self.has_meta("metric_failed_routes") else 0,
		"wfc_contradictions": self.get_meta("metric_wfc_contradictions") if self.has_meta("metric_wfc_contradictions") else 0,
	}
	final_report["analytics"] = val_results
	
	# --- STASH THE BLAST RADIUS FOR THE VALIDATOR ---
	self.set_meta("regen_dirty_rect", params.get("regen_dirty_rect", Rect2i()))
	
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
