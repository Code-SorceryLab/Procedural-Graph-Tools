class_name GenerateGrid extends GraphModifier

func _init() -> void:
	super._init() # Essential to initialize the RNG
	modifier_name = "Generate Grid"
	category = Category.GENERATOR

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "width", "type": TYPE_INT, "default": 10, "min": 1, "max": 50 },
		{ "name": "height", "type": TYPE_INT, "default": 10, "min": 1, "max": 50 },
		{ "name": "spacing_x", "type": TYPE_INT, "default": 60, "min": 10, "max": 500, "step": 10 },
		{ "name": "spacing_y", "type": TYPE_INT, "default": 60, "min": 10, "max": 500, "step": 10 },
		{ "name": "use_zones", "label": "Group into Zone", "type": TYPE_BOOL, "default": false }
	])
	return s

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	
	var w = local_settings.get("width", 10)
	var h = local_settings.get("height", 10)
	var sp_x = local_settings.get("spacing_x", 60)
	var sp_y = local_settings.get("spacing_y", 60)
	var spacing = Vector2(sp_x, sp_y)
	var use_zones = local_settings.get("use_zones", false)
	
	GraphSettings.set_global_grid_spacing(spacing)
	
	if use_zones:
		recorder.start_zone("Grid Area", Color(0.2, 1.0, 0.2, 0.2))
	
	var start_x = -int(w / 2.0) * spacing.x
	var start_y = -int(h / 2.0) * spacing.y
	
	for x in range(w):
		for y in range(h):
			var pos_x = start_x + (x * spacing.x)
			var pos_y = start_y + (y * spacing.y)
			var id = "grid:%d:%d" % [x, y]
			
			recorder.add_node(id, Vector2(pos_x, pos_y))
			
			if x > 0: recorder.add_edge(id, "grid:%d:%d" % [x - 1, y])
			if y > 0: recorder.add_edge(id, "grid:%d:%d" % [x, y - 1])
	
	if use_zones:
		recorder.end_zone()
