class_name StrategyPolar
extends GraphStrategy

func _init() -> void:
	strategy_name = "Polar Wedges"
	reset_on_generate = true

# --- NEW DYNAMIC UI DEFINITION ---
func get_settings() -> Array[Dictionary]:
	return [
		{ 
			"name": "wedges", 
			"type": TYPE_INT, 
			"default": 6, 
			"min": 3, 
			"max": 32 
		},
		{ 
			"name": "radius", 
			"type": TYPE_INT, 
			"default": 8, 
			"min": 2, 
			"max": 50 
		},
		{ 
			"name": "use_jitter", 
			"type": TYPE_BOOL, 
			"default": false 
		},
		{ 
			"name": "jitter_amount", 
			"type": TYPE_FLOAT, 
			"default": 10.0, 
			"min": 0.0, 
			"max": 50.0 
		}
	]

func execute(graph: Graph, params: Dictionary) -> void:
	# 1. Extract params safely
	# We use the exact keys defined in 'name' above
	var wedge_count = int(params.get("wedges", 6))
	var max_radius = int(params.get("radius", 8))
	var use_jitter = params.get("use_jitter", false)
	
	# Note: The UI returns floats for spinboxes, so cast if needed
	var jitter_val = float(params.get("jitter_amount", 10.0))
	
	var jitter_amount = 0.0
	if use_jitter:
		jitter_amount = jitter_val
	
	var merge_overlaps = params.get("merge_overlaps", true)
	var cell_size = GraphSettings.CELL_SIZE
	
	# --- PASS 1: CREATE ALL NODES ---
	var center_id = "polar:0:0:0"
	if not graph.nodes.has(center_id):
		graph.add_node(center_id, Vector2.ZERO)
	
	for w in range(wedge_count):
		var wedge_angle = (TAU / wedge_count) * w
		
		for r in range(1, max_radius + 1):
			for s in range(r):
				var center_offset = (r - 1) / 2.0
				var lateral_pos = (s - center_offset) * (cell_size * 0.8)
				var forward_pos = r * cell_size
				
				var local_pos = Vector2(forward_pos, lateral_pos)
				
				if jitter_amount > 0:
					local_pos += Vector2(
						randf_range(-jitter_amount, jitter_amount), 
						randf_range(-jitter_amount, jitter_amount)
					)
				
				var final_pos = local_pos.rotated(wedge_angle)
				var id = "polar:%d:%d:%d" % [w, r, s]
				
				if merge_overlaps and not graph.get_node_at_position(final_pos, 5.0).is_empty():
					continue 
					
				graph.add_node(id, final_pos)

	# --- PASS 2: CREATE CONNECTIONS ---
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
