class_name MutateWalker extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Walker Agents"
	category = Category.TOPOLOGY

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "count", "label": "Spawn Count", "type": TYPE_INT, "default": 1, "min": 1, "max": 10 },
		{ "name": "steps", "label": "Simulated Steps", "type": TYPE_INT, "default": 15, "min": 1, "max": 500 },
		{ "name": "auto_clear", "label": "Clear Agents After", "type": TYPE_BOOL, "default": true, "hint_text": "If true, agents are deleted after they carve the geometry, keeping the graph clean." },
		{ "name": "sep_template", "type": TYPE_NIL, "hint": "separator" }
	])
	
	# Append the raw agent template controls dynamically!
	var raw_template = AgentWalker.get_template_settings()
	for t in raw_template:
		var item = t.duplicate(true)
		if item.get("name") == "merge_overlaps": continue 
		
		if item.get("name") == "target_node":
			item["advanced"] = true
			item["label"] = "Target Node ID"
		elif item.get("name") == "use_geometric_fc":
			item["advanced"] = true
			item["label"] = "Forward Checking (Smart)"
		elif item.get("name") in ["movement_algo", "active", "snap_to_grid"]:
			item["advanced"] = true
		
		s.append(item)
		
	return s

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	
	var count = local_settings.get("count", 1)
	var max_ticks = local_settings.get("steps", 15)
	var auto_clear = local_settings.get("auto_clear", true)
	
	# 1. SPAWN INITIAL POPULATION
	var spawned_agents = []
	for i in range(count):
		var root_id = ""
		var root_pos = Vector2.ZERO
		
		if not recorder.nodes.is_empty():
			var keys = recorder.nodes.keys()
			root_id = SeedUtils.pick_random(keys, rng)
		else:
			root_id = "start_0"
			
		if not recorder.nodes.has(root_id):
			recorder.add_node(root_id, Vector2.ZERO)
			
		root_pos = recorder.get_node_pos(root_id)
		
		var ids = _generate_identity(recorder)
		var agent = AgentWalker.new(ids.uuid, ids.display_id, root_pos, root_id, max_ticks)
		
		# Ensure deterministic logic
		agent.set_seed(rng.randi())
		
		# Load the template variables from the pipeline's local settings!
		var template = AgentWalker.get_template_settings()
		for setting in template:
			var key = setting.get("name", "")
			if local_settings.has(key):
				agent.apply_setting(key, local_settings[key])
				
		recorder.add_agent(agent)
		spawned_agents.append(agent)

	# 2. RUN SIMULATION INSTANTLY
	for tick in range(max_ticks):
		for w in spawned_agents:
			if w.active and not w.is_finished and (w.steps == -1 or w.step_count < w.steps):
				# Because GraphRecorder subclasses Graph, w.step() transparently logs 
				# all add_node/add_edge actions directly to the Undo Command stack!
				
				# Force merge overlaps so pipelines don't generate massive stacked node clusters
				var step_params = local_settings.duplicate()
				step_params["merge_overlaps"] = true 
				
				w.step(recorder, step_params)
				
	# 3. CLEANUP
	if auto_clear:
		for w in spawned_agents:
			recorder.remove_agent(w)

func _generate_identity(recorder: GraphRecorder) -> Dictionary:
	var new_uuid = GraphSerializer.generate_uuid()
	var new_display_id = recorder.get_next_display_id()
	return { "uuid": new_uuid, "display_id": new_display_id }
