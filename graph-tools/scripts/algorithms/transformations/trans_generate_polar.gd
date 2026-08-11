class_name GeneratePolar extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Generate Polar"
	category = Category.GENERATOR

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "wedges", "type": TYPE_INT, "default": 6, "min": 3, "max": 32 },
		{ "name": "radius", "type": TYPE_INT, "default": 8, "min": 2, "max": 50 },
		{ "name": "use_zones", "label": "Group into Zone", "type": TYPE_BOOL, "default": true }
	])
	return s

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	
	var wedges = local_settings.get("wedges", 6)
	var rad_steps = local_settings.get("radius", 8)
	var use_zones = local_settings.get("use_zones", true)
	var spacing = GraphSettings.GRID_SPACING

	if use_zones:
		recorder.start_zone("Polar Area", Color(0.0, 0.8, 1.0, 0.2))

	var center_id = "polar:0:0:0"
	recorder.add_node(center_id, Vector2.ZERO)

	for w in range(wedges):
		var wedge_angle = (TAU / wedges) * w
		for r in range(1, rad_steps + 1):
			for s in range(r):
				var center_offset = (r - 1) / 2.0
				var unit_lateral = (s - center_offset) * 0.8
				var unit_forward = float(r)
				
				var local_unit_pos = Vector2(unit_forward, unit_lateral).rotated(wedge_angle)
				var final_pos = Vector2(local_unit_pos.x * spacing.x, local_unit_pos.y * spacing.y)
				
				var id = "polar:%d:%d:%d" % [w, r, s]
				recorder.add_node(id, final_pos)

	for w in range(wedges):
		for r in range(1, rad_steps + 1):
			for s in range(r):
				var id = "polar:%d:%d:%d" % [w, r, s]
				if not recorder.nodes.has(id): continue

				if r == 1:
					recorder.add_edge(id, center_id)
				else:
					var p_ring = r - 1
					if s < p_ring: recorder.add_edge(id, "polar:%d:%d:%d" % [w, p_ring, s])
					if s > 0: recorder.add_edge(id, "polar:%d:%d:%d" % [w, p_ring, s-1])
				if s > 0:
					recorder.add_edge(id, "polar:%d:%d:%d" % [w, r, s-1])
				if s == r - 1:
					var next_wedge = (w + 1) % wedges
					var seam = "polar:%d:%d:%d" % [next_wedge, r, 0]
					if recorder.nodes.has(seam): recorder.add_edge(id, seam)

	if use_zones:
		recorder.end_zone()
