class_name GeoRelaxBuoyancy extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Buoyancy Relax"
	category = Category.GEOMETRY

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "iterations", "label": "Simulated Ticks", "type": TYPE_INT, "default": 60, "min": 1, "max": 500 },
		{ "name": "enable_fusing", "label": "Enable Node Fusing", "type": TYPE_BOOL, "default": false },
		{ "name": "enable_snapping", "label": "Enable Edge Snapping", "type": TYPE_BOOL, "default": false },
		{ "name": "crystallize", "label": "Auto-Crystallize", "type": TYPE_BOOL, "default": true }
	])
	return s

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	
	var engine = BuoyancyEngine.new()
	engine.global_node_fusing = local_settings.get("enable_fusing", false)
	engine.global_edge_snapping = local_settings.get("enable_snapping", false)
	
	# Pass the recorder as the Graph so the engine operates purely inside the Sandbox!
	engine.set_auto_crystallize(local_settings.get("crystallize", true), recorder)
	
	var ticks = local_settings.get("iterations", 60)
	var delta = 1.0 / 45.0 
	
	# 1. Snapshot BEFORE physics
	var pre_pos = {}
	var pre_modes = {}
	for id in recorder.nodes:
		pre_pos[id] = recorder.get_node_pos(id)
		var node = recorder.nodes[id]
		pre_modes[id] = node.custom_data.get("physics_mode", 0) if "custom_data" in node else 0
		
	# 2. Run simulation on Sandbox (Quiet mutation, no Undo spam)
	for i in range(ticks):
		var report = engine.step(recorder, delta)
		
		# Instantly apply destructive physics so next tick's math is correct
		for pair in report["snapped_edges"]:
			if recorder.has_edge(pair[0], pair[1]):
				# The recorder automatically captures this in recorded_commands!
				recorder.remove_edge(pair[0], pair[1]) 
				
		for pair in report["fused_nodes"]:
			if recorder.nodes.has(pair[1]):
				# The recorder automatically captures this in recorded_commands!
				recorder.remove_node(pair[1]) 
				engine._velocities.erase(pair[1])
				
	# 3. Diff Phase (Harvest Positional Changes)
	var target = recorder._target_graph
	
	for id in pre_pos:
		if not recorder.nodes.has(id): continue # Was fused/deleted
		
		# A. Check for Movement
		var old_pos = pre_pos[id]
		var new_pos = recorder.get_node_pos(id)
		if old_pos.distance_squared_to(new_pos) > 0.1:
			recorder.recorded_commands.append(CmdMoveNode.new(target, id, old_pos, new_pos))
			
		# B. Check for Crystallization (Engine might have set physics_mode = 1)
		var node = recorder.nodes[id]
		var new_mode = node.custom_data.get("physics_mode", 0) if "custom_data" in node else 0
		if pre_modes[id] != new_mode:
			recorder.recorded_commands.append(CmdSetProperty.new(target, "NODE", id, "physics_mode", new_mode, pre_modes[id]))
