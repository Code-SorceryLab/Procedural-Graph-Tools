class_name StrategyPolar
extends GraphStrategy

func _init() -> void:
	strategy_name = "Polar Wedges"
	# Wedges, Radius. "Organic Jitter" is mapped to the toggle.
	required_params = ["wedges", "radius"]
	toggle_text = "Organic Jitter"
	toggle_key = "use_jitter"
	
	reset_on_generate = true

func execute(graph: Graph, params: Dictionary) -> void:
	var wedge_count = params.get("wedges", 6)
	var max_radius = params.get("radius", 8)
	var use_jitter = params.get("use_jitter", false)
	var jitter_amount = 0.0
	if use_jitter:
		jitter_amount = 10.0
	
	var merge_overlaps = params.get("merge_overlaps", true)
	var cell_size = GraphSettings.CELL_SIZE
	
	# --- PASS 1: CREATE ALL NODES ---
	var center_id = "polar:0:0:0"
	# Only add center if it doesn't exist (safety)
	if not graph.nodes.has(center_id):
		graph.add_node(center_id, Vector2.ZERO)
	
	for w in range(wedge_count):
		var wedge_angle = (TAU / wedge_count) * w
		
		for r in range(1, max_radius + 1):
			for s in range(r):
				# Calculate Position
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
				
				# Create Node
				var id = "polar:%d:%d:%d" % [w, r, s]
				
				if merge_overlaps and not graph.get_node_at_position(final_pos, 5.0).is_empty():
					continue 
					
				graph.add_node(id, final_pos)

	# --- PASS 2: CREATE CONNECTIONS ---
	# Now that all nodes exist, we can safely link them.
	
	for w in range(wedge_count):
		for r in range(1, max_radius + 1):
			for s in range(r):
				var id = "polar:%d:%d:%d" % [w, r, s]
				if not graph.nodes.has(id): continue
				
				# 1. Connect Inward (To Parent Ring)
				if r == 1:
					graph.add_edge(id, center_id)
				else:
					var parent_ring = r - 1
					# Parent A (Same index)
					if s < parent_ring:
						var p_id = "polar:%d:%d:%d" % [w, parent_ring, s]
						if graph.nodes.has(p_id): graph.add_edge(id, p_id)
					# Parent B (Previous index)
					if s > 0:
						var p_id = "polar:%d:%d:%d" % [w, parent_ring, s-1]
						if graph.nodes.has(p_id): graph.add_edge(id, p_id)
				
				# 2. Connect Sideways (Same Ring)
				if s > 0:
					var neighbor = "polar:%d:%d:%d" % [w, r, s-1]
					if graph.nodes.has(neighbor): graph.add_edge(id, neighbor)
				
				# 3. Connect SEAM (Stitch Wedges)
				# Connect the LAST node of this row to the FIRST node of the next wedge
				if s == r - 1:
					var next_wedge = (w + 1) % wedge_count
					# Target is always index 0 of the same ring in the next wedge
					var seam_neighbor = "polar:%d:%d:%d" % [next_wedge, r, 0]
					
					if graph.nodes.has(seam_neighbor):
						graph.add_edge(id, seam_neighbor)
