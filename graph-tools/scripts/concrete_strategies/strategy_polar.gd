class_name StrategyPolar
extends GraphStrategy

func _init() -> void:
	strategy_name = "Polar Wedges"
	reset_on_generate = true
	supports_grow = false

# --- NEW DYNAMIC UI DEFINITION ---
func get_settings() -> Array[Dictionary]:
	return [
		{ 
			"name": "wedges", 
			"type": TYPE_INT, 
			"default": 6, 
			"min": 3, 
			"max": 32,
			"hint": GraphSettings.PARAM_TOOLTIPS.polar.wedges
		},
		{ 
			"name": "radius", 
			"type": TYPE_INT, 
			"default": 8, 
			"min": 2, 
			"max": 50,
			"hint": GraphSettings.PARAM_TOOLTIPS.polar.radius
		},
		{ 
			"name": "use_jitter", 
			"type": TYPE_BOOL, 
			"default": false,
			"hint": GraphSettings.PARAM_TOOLTIPS.polar.jitter
		},
		{ 
			"name": "jitter_amount", 
			"type": TYPE_FLOAT, 
			"default": 10.0, 
			"min": 0.0, 
			"max": 50.0,
			"hint": GraphSettings.PARAM_TOOLTIPS.polar.amount
		}
	]

func execute(graph: GraphRecorder, params: Dictionary) -> void:
	# 1. Extract params
	var wedge_count = int(params.get("wedges", 6))
	var max_radius = int(params.get("radius", 8))
	var use_jitter = params.get("use_jitter", false)
	var jitter_val = float(params.get("jitter_amount", 10.0))
	var jitter_amount = jitter_val if use_jitter else 0.0
	
	var merge_overlaps = params.get("merge_overlaps", true)
	
	# [REFACTOR] Get Vector Spacing
	var spacing = GraphSettings.GRID_SPACING
	
	# --- PASS 1: CREATE ALL NODES ---
	var center_id = "polar:0:0:0"
	if not graph.nodes.has(center_id):
		graph.add_node(center_id, Vector2.ZERO)
	
	for w in range(wedge_count):
		var wedge_angle = (TAU / wedge_count) * w
		
		for r in range(1, max_radius + 1):
			for s in range(r):
				var center_offset = (r - 1) / 2.0
				
				# [LOGIC CHANGE] 
				# 1. Calculate in "Unit Space" first (as if grid was 1x1)
				# 0.8 is the packing density factor
				var unit_lateral = (s - center_offset) * 0.8
				var unit_forward = float(r)
				
				# 2. Rotate the Unit Vector
				var local_unit_pos = Vector2(unit_forward, unit_lateral).rotated(wedge_angle)
				
				# 3. Apply Ellipse Scaling (Multiply by Grid Spacing)
				var final_pos = Vector2(local_unit_pos.x * spacing.x, local_unit_pos.y * spacing.y)
				
				# 4. Apply Jitter (in pixels)
				if jitter_amount > 0:
					final_pos += Vector2(
						randf_range(-jitter_amount, jitter_amount), 
						randf_range(-jitter_amount, jitter_amount)
					)
				
				var id = "polar:%d:%d:%d" % [w, r, s]
				
				if merge_overlaps and not graph.get_node_at_position(final_pos, 5.0).is_empty():
					continue 
					
				graph.add_node(id, final_pos)

	# --- PASS 2: CREATE CONNECTIONS (Unchanged) ---
	# The topology logic relies on indices (w, r, s), so it works 
	# perfectly regardless of whether the shape is a circle or ellipse.
	
	for w in range(wedge_count):
		for r in range(1, max_radius + 1):
			for s in range(r):
				var id = "polar:%d:%d:%d" % [w, r, s]
				if not graph.nodes.has(id): continue
				
				# Connect Inward
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
				
				# Connect Sideways
				if s > 0:
					var neighbor = "polar:%d:%d:%d" % [w, r, s-1]
					if graph.nodes.has(neighbor): graph.add_edge(id, neighbor)
				
				# Connect Seam
				if s == r - 1:
					var next_wedge = (w + 1) % wedge_count
					var seam_neighbor = "polar:%d:%d:%d" % [next_wedge, r, 0]
					if graph.nodes.has(seam_neighbor):
						graph.add_edge(id, seam_neighbor)
