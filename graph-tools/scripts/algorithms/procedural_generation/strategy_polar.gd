class_name StrategyPolar
extends GraphStrategy

func _init() -> void:
	strategy_name = "Polar Wedges"
	reset_on_generate = true
	supports_grow = false
	supports_zones = true # [NEW] Enable standardized zone support

func get_settings() -> Array[Dictionary]:
	var settings: Array[Dictionary] = [
		{ "name": "wedges", "type": TYPE_INT, "default": 6, "min": 3, "max": 32, "hint": GraphSettings.PARAM_TOOLTIPS.polar.wedges },
		{ "name": "radius", "type": TYPE_INT, "default": 8, "min": 2, "max": 50, "hint": GraphSettings.PARAM_TOOLTIPS.polar.radius },
		{ "name": "use_jitter", "type": TYPE_BOOL, "default": false, "hint": GraphSettings.PARAM_TOOLTIPS.polar.jitter },
		{ "name": "jitter_amount", "type": TYPE_FLOAT, "default": 10.0, "min": 0.0, "max": 50.0, "hint": GraphSettings.PARAM_TOOLTIPS.polar.amount }
	]
	
	# Use Standardized Helper
	if supports_zones:
		var zone_def = _get_zone_setting_def()
		zone_def["default"] = true 
		settings.append(zone_def)
		
	return settings

func execute(graph: GraphRecorder, params: Dictionary) -> void:
	var wedge_count = int(params.get("wedges", 6))
	var max_radius_steps = int(params.get("radius", 8))
	var use_jitter = params.get("use_jitter", false)
	var jitter_amount = float(params.get("jitter_amount", 10.0)) if use_jitter else 0.0
	var merge_overlaps = params.get("merge_overlaps", true)
	var use_zones = bool(params.get("use_zones", true)) 
	
	var spacing = GraphSettings.GRID_SPACING
	
	# 1. START ZONE CONTEXT
	if use_zones:
		graph.start_zone("Polar Area", Color(0.0, 0.8, 1.0, 0.2)) 
	
	# --- 2. GENERATE NODES ---
	var center_id = "polar:0:0:0"
	if not graph.nodes.has(center_id):
		# Automatic Registration happens inside add_node now!
		graph.add_node(center_id, Vector2.ZERO)
	
	for w in range(wedge_count):
		var wedge_angle = (TAU / wedge_count) * w
		
		for r in range(1, max_radius_steps + 1):
			for s in range(r):
				var center_offset = (r - 1) / 2.0
				var unit_lateral = (s - center_offset) * 0.8
				var unit_forward = float(r)
				
				var local_unit_pos = Vector2(unit_forward, unit_lateral).rotated(wedge_angle)
				var final_pos = Vector2(local_unit_pos.x * spacing.x, local_unit_pos.y * spacing.y)
				
				if jitter_amount > 0:
					final_pos += Vector2(randf_range(-jitter_amount, jitter_amount), randf_range(-jitter_amount, jitter_amount))
				
				var id = "polar:%d:%d:%d" % [w, r, s]
				
				if merge_overlaps and not graph.get_node_at_position(final_pos, 5.0).is_empty():
					continue 
				
				# Automatic Registration + Smart 2x2 Patch happens here
				graph.add_node(id, final_pos)
				

	# --- 3. GENERATE CONNECTIONS ---
	for w in range(wedge_count):
		for r in range(1, max_radius_steps + 1):
			for s in range(r):
				var id = "polar:%d:%d:%d" % [w, r, s]
				if not graph.nodes.has(id): continue
				
				if r == 1:
					graph.add_edge(id, center_id)
				else:
					var parent_ring = r - 1
					if s < parent_ring:
						var p_id = "polar:%d:%d:%d" % [w, parent_ring, s]
						if graph.nodes.has(p_id): graph.add_edge(id, p_id)
					if s > 0:
						var p_id = "polar:%d:%d:%d" % [w, parent_ring, s-1]
						if graph.nodes.has(p_id): graph.add_edge(id, p_id)
				if s > 0:
					var neighbor = "polar:%d:%d:%d" % [w, r, s-1]
					if graph.nodes.has(neighbor): graph.add_edge(id, neighbor)
				if s == r - 1:
					var next_wedge = (w + 1) % wedge_count
					var seam_neighbor = "polar:%d:%d:%d" % [next_wedge, r, 0]
					if graph.nodes.has(seam_neighbor):
						graph.add_edge(id, seam_neighbor)
						
	# 4. END ZONE CONTEXT
	if use_zones:
		graph.end_zone()
