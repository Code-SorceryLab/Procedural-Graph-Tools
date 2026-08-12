class_name MutatePruneLeaves extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Prune Leaves"
	category = Category.TOPOLOGY

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "target_mask", "label": "Target Nodes", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "All Nodes,Affected by Previous Step" },
		{ "name": "iterations", "label": "Prune Iterations", "type": TYPE_INT, "default": 1, "min": 1, "max": 10, "hint_text": "How many layers of dead-ends to strip away." },
		{ "name": "protect_spawns", "label": "Protect Special Rooms", "type": TYPE_BOOL, "default": true, "hint_text": "Prevents pruning nodes that aren't 'empty' or 'corridor'." }
	])
	return s

func execute(recorder: GraphRecorder) -> void:
	var target_mask = local_settings.get("target_mask", 0)
	var passes = local_settings.get("iterations", 1)
	var protect = local_settings.get("protect_spawns", true)

	var node_pool = recorder.nodes.keys()
	if target_mask == 1:
		node_pool = []
		var context = get_context_nodes(false)
		for id in context:
			if recorder.nodes.has(id): node_pool.append(id)

	var node_set = {}
	for id in node_pool: node_set[id] = true

	for iter in range(passes):
		var to_delete = []

		for id in node_set:
			if not recorder.nodes.has(id): continue

			if protect:
				var t = recorder.nodes[id].type
				if t != "empty" and t != "corridor": continue

			# Compute undirected degree from the directed edge store,
			# counting each unique neighbouring node once.
			var degree = 0
			var seen_neighbors = {}

			for key in recorder.edge_store:
				var e = recorder.edge_store[key]
				var other_id = ""

				if e.u == id:
					other_id = e.v
				elif e.v == id:
					other_id = e.u
				else:
					continue

				if not seen_neighbors.has(other_id):
					seen_neighbors[other_id] = true
					degree += 1

			if degree <= 1:
				to_delete.append(id)

		if to_delete.is_empty(): break

		for id in to_delete:
			recorder.remove_node(id)
			node_set.erase(id)
