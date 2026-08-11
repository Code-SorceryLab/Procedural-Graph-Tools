class_name MutateBraid extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Braid Dead-Ends"
	category = Category.TOPOLOGY

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "braid_chance", "label": "Braid Chance (%)", "type": TYPE_INT, "default": 50, "min": 0, "max": 100 },
		{ "name": "search_range", "label": "Search Radius Multiplier", "type": TYPE_FLOAT, "default": 2.5, "min": 1.0, "max": 5.0, "step": 0.5 }
	])
	return s

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	
	var chance = float(local_settings.get("braid_chance", 50)) / 100.0
	if chance <= 0.0: return
	
	var radius = max(GraphSettings.GRID_SPACING.x, GraphSettings.GRID_SPACING.y) * local_settings.get("search_range", 2.5)
	
	# Find all dead ends (nodes with exactly 1 edge)
	var dead_ends = []
	for id in recorder.nodes:
		if recorder.get_neighbors(id).size() == 1:
			dead_ends.append(id)
			
	for u_id in dead_ends:
		if rng.randf() > chance: continue
		
		var u_pos = recorder.get_node_pos(u_id)
		var neighbors = recorder.get_neighbors(u_id)
		var parent_id = neighbors[0] if neighbors.size() > 0 else ""
		
		var nearby = recorder.get_nodes_near_position(u_pos, radius)
		var best_cand = ""
		var best_dist = INF
		
		for v_id in nearby:
			if v_id == u_id or v_id == parent_id: continue
			var dist = u_pos.distance_squared_to(recorder.get_node_pos(v_id))
			if dist < best_dist:
				best_dist = dist
				best_cand = v_id
				
		if best_cand != "":
			recorder.add_edge(u_id, best_cand)
