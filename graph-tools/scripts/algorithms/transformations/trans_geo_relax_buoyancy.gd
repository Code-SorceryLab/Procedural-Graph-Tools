class_name GeoRelaxBuoyancy extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Buoyancy Relax"
	category = Category.GEOMETRY

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "target_mask", "label": "Target Nodes", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "All Nodes,Affected by Previous Step" },
		{ "name": "iterations", "label": "Simulated Ticks", "type": TYPE_INT, "default": 60, "min": 1, "max": 500 },
		{ "name": "enable_fusing", "label": "Enable Node Fusing", "type": TYPE_BOOL, "default": false },
		{ "name": "enable_snapping", "label": "Enable Edge Snapping", "type": TYPE_BOOL, "default": false },
		{ "name": "crystallize", "label": "Auto-Crystallize", "type": TYPE_BOOL, "default": true }
	])
	return s

func execute(recorder: GraphRecorder) -> void:
	setup_rng()

	# Establish Mask
	var target_mask = local_settings.get("target_mask", 0)
	var node_pool = recorder.nodes.keys()

	if target_mask == 1:
		node_pool = []
		var context_nodes = get_context_nodes(false)
		for id in context_nodes:
			if recorder.nodes.has(id): node_pool.append(id)

	var masked_set = {}
	for id in node_pool: masked_set[id] = true

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
		var mode = node.custom_data.get("physics_mode", 0) if "custom_data" in node else 0
		pre_modes[id] = mode

		# Freeze the unmasked nodes so they act as solid boundaries!
		if target_mask == 1 and not masked_set.has(id):
			if not "custom_data" in node: node.custom_data = {}
			node.custom_data["physics_mode"] = 1

	# 2. Run simulation on Sandbox
	for i in range(ticks):
		var report = engine.step(recorder, delta)

		# Instantly apply destructive physics so next tick's math is correct
		for pair in report["snapped_edges"]:
			if recorder.has_edge(pair[0], pair[1]):
				# Only permit snapping if at least one of the nodes is allowed to move!
				if target_mask == 0 or masked_set.has(pair[0]) or masked_set.has(pair[1]):
					recorder.remove_edge(pair[0], pair[1])

		for pair in report["fused_nodes"]:
			var survivor = pair[0]
			var victim = pair[1]

			# If we are masking, NEVER let a frozen grid node be the victim!
			if target_mask == 1 and not masked_set.has(victim):
				if masked_set.has(survivor):
					# Swap them so the new DLA node gets deleted instead of the Grid node!
					victim = pair[0]
					survivor = pair[1]
				else:
					continue # Both are frozen, do nothing.

			if recorder.nodes.has(victim):
				recorder.remove_node(victim)
				engine._velocities.erase(victim)

	# 3. Diff Phase (Harvest Property Changes Only)
	for id in pre_pos:
		if not recorder.nodes.has(id): continue # Was fused/deleted

		# Unfreeze the unmasked nodes and ignore their diffs
		if target_mask == 1 and not masked_set.has(id):
			var node = recorder.nodes[id]
			var old_m = pre_modes[id]
			if old_m == 0: node.custom_data.erase("physics_mode")
			else: node.custom_data["physics_mode"] = old_m
			continue

		# Movement was already recorded by GraphRecorder.set_node_position
		# called from inside BuoyancyEngine.step.

		# Check for Crystallization changes
		var node = recorder.nodes[id]
		var new_mode = node.custom_data.get("physics_mode", 0) if "custom_data" in node else 0
		if pre_modes[id] != new_mode:
			if not recorder.touched_nodes.has(id): recorder.touched_nodes.append(id)
			recorder.recorded_commands.append(
				CmdSetProperty.new(recorder._target_graph, "NODE", id, "physics_mode", new_mode, pre_modes[id])
			)
