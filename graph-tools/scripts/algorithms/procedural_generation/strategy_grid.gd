class_name StrategyGrid
extends GraphStrategy

# --- PERSISTENCE CACHE ---
static var _cache_width: int = 10
static var _cache_height: int = 10
static var _cache_spacing_x: int = 60
static var _cache_spacing_y: int = 60
static var _cache_sync: bool = true

func _init() -> void:
	strategy_name = "Grid Layout"
	reset_on_generate = true
	supports_grow = false
	supports_zones = true # [NEW] Enable the zone architecture

func get_settings() -> Array[Dictionary]:
	# Initialize defaults from global if cache is untouched
	if _cache_spacing_x == 0: _cache_spacing_x = int(GraphSettings.GRID_SPACING.x)
	if _cache_spacing_y == 0: _cache_spacing_y = int(GraphSettings.GRID_SPACING.y)
	
	var settings: Array[Dictionary] = [
		{ "name": "width", "type": TYPE_INT, "default": _cache_width, "min": 1, "max": 50, "hint": GraphSettings.PARAM_TOOLTIPS.common.width },
		{ "name": "height", "type": TYPE_INT, "default": _cache_height, "min": 1, "max": 50, "hint": GraphSettings.PARAM_TOOLTIPS.common.height },
		
		# Spacing Controls
		{ "name": "spacing_x", "type": TYPE_INT, "default": _cache_spacing_x, "min": 10, "max": 500, "step": 10, "hint": "Horizontal distance between nodes." },
		{ "name": "spacing_y", "type": TYPE_INT, "default": _cache_spacing_y, "min": 10, "max": 500, "step": 10, "hint": "Vertical distance between nodes." },
		
		{ "name": "sync_global", "type": TYPE_BOOL, "default": _cache_sync, "hint": "Update editor grid to match." }
	]
	
	# [NEW] Add the standardized Zone Toggle (if supported)
	if supports_zones:
		settings.append(_get_zone_setting_def())

	return settings

func execute(graph: GraphRecorder, params: Dictionary) -> void:
	# 1. Extract
	var width = int(params.get("width", _cache_width))
	var height = int(params.get("height", _cache_height))
	
	var sp_x = int(params.get("spacing_x", _cache_spacing_x))
	var sp_y = int(params.get("spacing_y", _cache_spacing_y))
	var spacing = Vector2(sp_x, sp_y)
	
	var sync = params.get("sync_global", _cache_sync)
	var use_zones = bool(params.get("use_zones", false)) # [NEW]
	
	# 2. Update Cache
	_cache_width = width
	_cache_height = height
	_cache_spacing_x = sp_x
	_cache_spacing_y = sp_y
	_cache_sync = sync
	
	# 3. Sync & Generate
	if sync:
		GraphSettings.set_global_grid_spacing(spacing)
	
	# Start Zone Context
	if use_zones:
		graph.start_zone("Grid Area", Color(0.2, 1.0, 0.2, 0.2)) # Greenish tint
	
	# Use 2.0 to force float division, silencing the integer division warning
	var start_x = -int(width / 2.0) * spacing.x
	var start_y = -int(height / 2.0) * spacing.y
	
	for x in range(width):
		for y in range(height):
			var pos_x = start_x + (x * spacing.x)
			var pos_y = start_y + (y * spacing.y)
			var id = "grid:%d:%d" % [x, y]
			
			# Just call add_node. The Recorder handles registration & patching automatically.
			graph.add_node(id, Vector2(pos_x, pos_y))
			
			if x > 0:
				var left_id = "grid:%d:%d" % [x - 1, y]
				if graph.nodes.has(left_id): graph.add_edge(id, left_id)
			if y > 0:
				var up_id = "grid:%d:%d" % [x, y - 1]
				if graph.nodes.has(up_id): graph.add_edge(id, up_id)

	# End Zone Context
	if use_zones:
		graph.end_zone()
