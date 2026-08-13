class_name MutateConnectComponents
extends GraphModifier

class UnionFind:
	var parent: Dictionary = {}

	func _init(ids: Array) -> void:
		for id in ids:
			parent[id] = id

	func find(i) -> int:
		if parent[i] != i:
			parent[i] = find(parent[i])
		return parent[i]

	func union(i, j) -> void:
		var root_i = find(i)
		var root_j = find(j)
		if root_i != root_j:
			parent[root_i] = root_j

func _init() -> void:
	super._init()
	modifier_name = "Connect Components"
	category = Category.TOPOLOGY

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "target_mask", "label": "Target Nodes", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "All Nodes,Affected by Previous Step" },
		{ "name": "connect_mode", "label": "Connection Strategy", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "Nearest Pair,Random Pair,Centroid Pair" },
		{ "name": "edge_direction", "label": "Edge Direction", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "Undirected,Directed (A→B),Directed (B→A)" },
		{ "name": "max_components", "label": "Max Components to Connect", "type": TYPE_INT, "default": -1, "min": -1, "max": 100, "hint_text": "-1 = connect all. Positive value stops after merging this many components." }
	])
	return s

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	if recorder.nodes.is_empty(): return

	var target_mask = local_settings.get("target_mask", 0)
	var connect_mode = local_settings.get("connect_mode", 0)
	var edge_direction = local_settings.get("edge_direction", 0)
	var max_components = local_settings.get("max_components", -1)

	# --- 1. Build node pool and mask ---
	var context_set = {}
	if target_mask == 1:
		var context_nodes = get_context_nodes(false)
		for id in context_nodes:
			if recorder.nodes.has(id):
				context_set[id] = true
	else:
		for id in recorder.nodes.keys():
			context_set[id] = true

	# --- 2. Find connected components (undirected) ---
	var components = _find_components(recorder)
	if components.size() <= 1: return

	# Filter components that contain at least one masked node when target_mask==1
	var filtered_components = []
	for comp in components:
		var has_context = false
		for id in comp:
			if context_set.has(id):
				has_context = true
				break
		if target_mask == 0 or has_context:
			filtered_components.append(comp)

	if filtered_components.size() <= 1: return

	# Assign component indices
	var comp_ids = []
	for i in range(filtered_components.size()):
		comp_ids.append(i)

	# --- 3. Generate candidate edges ---
	var candidates = []

	if connect_mode == 2:
		# Precompute centroid representative for each component
		var rep_nodes = []
		for comp in filtered_components:
			var center = Vector2.ZERO
			for id in comp:
				center += recorder.get_node_pos(id)
			center /= comp.size()
			var best_id = ""
			var best_dist_sq = INF
			for id in comp:
				var p = recorder.get_node_pos(id)
				var d = p.distance_squared_to(center)
				if d < best_dist_sq:
					best_dist_sq = d
					best_id = id
			rep_nodes.append(best_id)

		for i in range(filtered_components.size()):
			for j in range(i + 1, filtered_components.size()):
				var u = rep_nodes[i]
				var v = rep_nodes[j]
				var dist_sq = recorder.get_node_pos(u).distance_squared_to(recorder.get_node_pos(v))
				candidates.append({ "u": u, "v": v, "dist": dist_sq, "comp_a": i, "comp_b": j })

	elif connect_mode == 1:
		# Random pair per component pair
		for i in range(filtered_components.size()):
			for j in range(i + 1, filtered_components.size()):
				var comp_a = filtered_components[i]
				var comp_b = filtered_components[j]
				var u = comp_a[rng.randi() % comp_a.size()]
				var v = comp_b[rng.randi() % comp_b.size()]
				var dist_sq = recorder.get_node_pos(u).distance_squared_to(recorder.get_node_pos(v))
				candidates.append({ "u": u, "v": v, "dist": dist_sq, "comp_a": i, "comp_b": j })
		# Shuffle candidate order for randomness
		for i in range(candidates.size() - 1, 0, -1):
			var j = rng.randi() % (i + 1)
			var temp = candidates[i]
			candidates[i] = candidates[j]
			candidates[j] = temp

	else: # connect_mode == 0 (Nearest Pair)
		for i in range(filtered_components.size()):
			for j in range(i + 1, filtered_components.size()):
				var comp_a = filtered_components[i]
				var comp_b = filtered_components[j]
				var best_u = ""
				var best_v = ""
				var best_dist_sq = INF
				for u in comp_a:
					var pos_u = recorder.get_node_pos(u)
					for v in comp_b:
						var d = pos_u.distance_squared_to(recorder.get_node_pos(v))
						if d < best_dist_sq:
							best_dist_sq = d
							best_u = u
							best_v = v
				candidates.append({ "u": best_u, "v": best_v, "dist": best_dist_sq, "comp_a": i, "comp_b": j })

	# Sort by distance for nearest/centroid modes
	if connect_mode != 1:
		candidates.sort_custom(func(a, b): return a.dist < b.dist)

	# --- 4. Connect components using UnionFind ---
	var uf = UnionFind.new(comp_ids)
	var edges_added = 0

	for cand in candidates:
		if max_components > 0 and edges_added >= max_components:
			break

		var root_a = uf.find(cand.comp_a)
		var root_b = uf.find(cand.comp_b)
		if root_a == root_b:
			continue

		uf.union(cand.comp_a, cand.comp_b)
		var u = cand.u
		var v = cand.v

		match edge_direction:
			0: # Undirected
				recorder.add_edge(u, v, 1.0, false)
			1: # Directed A→B
				recorder.add_edge(u, v, 1.0, true)
			2: # Directed B→A
				recorder.add_edge(v, u, 1.0, true)

		edges_added += 1

# ------------------------------------------------------------------------------
# CONNECTIVITY HELPERS
# ------------------------------------------------------------------------------

# Returns an array of components, each component is an Array[String] of node IDs.
func _find_components(recorder: GraphRecorder) -> Array:
	var adjacency = {}
	for key in recorder.edge_store:
		var e = recorder.edge_store[key]
		if not recorder.nodes.has(e.u) or not recorder.nodes.has(e.v):
			continue
		if not adjacency.has(e.u): adjacency[e.u] = {}
		if not adjacency.has(e.v): adjacency[e.v] = {}
		adjacency[e.u][e.v] = true
		adjacency[e.v][e.u] = true

	var visited = {}
	var components = []

	for id in recorder.nodes.keys():
		if visited.has(id): continue

		var comp = []
		var queue = [id]
		visited[id] = true

		while not queue.is_empty():
			var current = queue.pop_front()
			comp.append(current)

			if adjacency.has(current):
				for neighbor in adjacency[current]:
					if not visited.has(neighbor):
						visited[neighbor] = true
						queue.append(neighbor)

		components.append(comp)

	return components
