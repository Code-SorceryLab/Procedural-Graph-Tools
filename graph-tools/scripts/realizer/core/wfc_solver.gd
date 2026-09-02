class_name WFCSolver
extends RefCounted

const SOCKET_SIZE = 3
const DIRS = {
	"N": Vector2i(0, -SOCKET_SIZE), "S": Vector2i(0, SOCKET_SIZE),
	"E": Vector2i(SOCKET_SIZE, 0),  "W": Vector2i(-SOCKET_SIZE, 0)
}
const OPPOSITE = {"N": "S", "S": "N", "E": "W", "W": "E"}

static func resolve(sockets: Array, rng: RandomNumberGenerator, modules: Dictionary, step_size: int = 3, fixed_pixels: Dictionary = {}) -> Dictionary:
	if modules.is_empty():
		return {}
	
	# Infer pattern size from module data (needed for logging)
	var n_size = 1
	if not modules.is_empty():
		var first_mod = modules.values()[0]
		if first_mod.has("exact_floors"):
			for pt in first_mod["exact_floors"].keys():
				n_size = max(n_size, max(abs(pt.x), abs(pt.y)) + 1)
	
	var get_fixed_snapshot = func(s_pos: Vector2i) -> Dictionary:
		var snap = {}
		for dy in range(n_size):
			for dx in range(n_size):
				var pt = s_pos + Vector2i(dx, dy)
				if fixed_pixels.has(pt):
					snap[pt] = fixed_pixels[pt]
		return snap
	
	
	var dirs = {
		"N": Vector2i(0, -step_size), "S": Vector2i(0, step_size),
		"E": Vector2i(step_size, 0),  "W": Vector2i(-step_size, 0)
	}

	# Convert sockets array to a dictionary for O(1) neighbor lookups.
	var socket_set: Dictionary = {}
	for s_pos in sockets:
		socket_set[s_pos] = true

	var domains = {}
	var collapsed = {}          # socket -> true once collapsed
	var entropy_cache = {}      # socket -> current Shannon entropy

	var initial_stack = []

	# 1. Initialize domains and apply fixed constraints
	for s_pos in socket_set.keys():
		var allowed = modules.keys().duplicate()
		var is_constrained = false

		for i in range(allowed.size() - 1, -1, -1):
			var m_id = allowed[i]
			var m_floors = modules[m_id].get("exact_floors", {})
			var conflict = false

			for pt in m_floors:
				var world_pt = s_pos + pt
				if fixed_pixels.has(world_pt):
					if m_floors[pt] != fixed_pixels[world_pt]:
						conflict = true
						break
				else:
					if m_floors[pt] == Vector2i(-2, -2):
						conflict = true
						break

			if conflict:
				allowed.remove_at(i)
				is_constrained = true

		# No immediate return on empty; we just leave the domain empty.
		domains[s_pos] = allowed
		if is_constrained and not allowed.is_empty():
			initial_stack.append(s_pos)
			
		if allowed.is_empty():
			var snap = get_fixed_snapshot.call(s_pos)
			#print("[WFC Contradiction] Socket %s has no valid modules during init. Fixed constraints: %s" % [s_pos, snap])
			domains[s_pos] = []
			continue

	# 2. Initial propagation
	for s_pos in initial_stack:
		_propagate_and_get_changed(s_pos, domains, socket_set, modules, dirs)

	# 3. Build the lazy min-heap with initial Shannon entropy
	var heap = []

	for s_pos in socket_set.keys():
		if domains[s_pos].is_empty():
			continue  # skip empty domains; they won't be collapsed
		var ent = _compute_entropy(s_pos, domains, modules)
		entropy_cache[s_pos] = ent
		_heap_push(heap, {"socket": s_pos, "entropy": ent})

	# 4. Main collapse loop
	while not heap.is_empty():
		var entry = _heap_pop(heap)
		var s_pos = entry["socket"]
		var current_entropy = entropy_cache.get(s_pos, -1.0)

		# Lazy deletion: skip stale entries
		if collapsed.has(s_pos) or entry["entropy"] != current_entropy:
			continue

		if domains[s_pos].is_empty():
			# Contradiction: stop collapsing further.
			var snap = get_fixed_snapshot.call(s_pos)
			#print("[WFC Contradiction] Socket %s became empty during collapse. Fixed constraints: %s" % [s_pos, snap])
			break

		# Weighted random collapse
		var valid_modules = domains[s_pos]
		var total_weight = 0.0
		for m in valid_modules:
			total_weight += float(modules[m].get("weight", 10.0))
		var roll = rng.randf() * total_weight
		var chosen = valid_modules[0]
		for m in valid_modules:
			roll -= float(modules[m].get("weight", 10.0))
			if roll <= 0:
				chosen = m
				break

		domains[s_pos] = [chosen]
		collapsed[s_pos] = true

		# Propagate constraints and collect changed neighbors
		var changed = _propagate_and_get_changed(s_pos, domains, socket_set, modules, dirs)

		# Update heap for changed sockets
		for n_pos in changed:
			if collapsed.has(n_pos):
				continue
			var new_ent = _compute_entropy(n_pos, domains, modules)
			entropy_cache[n_pos] = new_ent
			if new_ent >= 0.0:
				_heap_push(heap, {"socket": n_pos, "entropy": new_ent})

	# 5. Assemble final payload (only for collapsed sockets)
	var result = {"floors": [], "exact_floors": {}, "walls": [], "exact_walls": {}, "entities": []}
	for s_pos in socket_set.keys():
		if not collapsed.has(s_pos):
			continue
		var m_id = domains[s_pos][0]
		var m_data = modules[m_id]

		if step_size == 1:
			if m_data.has("exact_floors") and m_data["exact_floors"].has(Vector2i.ZERO):
				result["exact_floors"][s_pos] = m_data["exact_floors"][Vector2i.ZERO]
		else:
			for type in ["floors", "walls"]:
				if m_data.has(type):
					for pt in m_data[type]:
						result[type].append(s_pos + pt)
			for type in ["exact_floors", "exact_walls"]:
				if m_data.has(type):
					for pt in m_data[type]:
						result[type][s_pos + pt] = m_data[type][pt]
			if m_data.has("placed_entities"):
				for ent in m_data["placed_entities"]:
					var world_ent = ent.duplicate(true)
					world_ent["pos"] = s_pos + ent["pos"]
					result["entities"].append(world_ent)

	return result

# ---------------------------
# Static helper methods
# ---------------------------

static func _compute_entropy(s_pos: Vector2i, domains: Dictionary, modules: Dictionary) -> float:
	var valid_modules = domains.get(s_pos, [])
	if valid_modules.is_empty():
		return -1.0
	var sum_weight = 0.0
	var sum_wlogw = 0.0
	for m in valid_modules:
		var w = float(modules[m].get("weight", 1.0))
		if w > 0.0:
			sum_weight += w
			sum_wlogw += w * log(w)
	if sum_weight <= 0.0:
		return 0.0
	return log(sum_weight) - (sum_wlogw / sum_weight)

static func _heap_swap(heap: Array, i: int, j: int) -> void:
	var tmp = heap[i]
	heap[i] = heap[j]
	heap[j] = tmp

static func _heap_push(heap: Array, entry: Dictionary) -> void:
	heap.append(entry)
	var idx = heap.size() - 1
	while idx > 0:
		var parent = (idx - 1) >> 1
		if heap[parent]["entropy"] <= heap[idx]["entropy"]:
			break
		_heap_swap(heap, parent, idx)
		idx = parent

static func _heap_pop(heap: Array) -> Dictionary:
	if heap.is_empty():
		return {}
	var top = heap[0]
	var last = heap.pop_back()
	if not heap.is_empty():
		heap[0] = last
		var idx = 0
		while true:
			var left = (idx << 1) + 1
			var right = (idx << 1) + 2
			var smallest = idx
			if left < heap.size() and heap[left]["entropy"] < heap[smallest]["entropy"]:
				smallest = left
			if right < heap.size() and heap[right]["entropy"] < heap[smallest]["entropy"]:
				smallest = right
			if smallest == idx:
				break
			_heap_swap(heap, idx, smallest)
			idx = smallest
	return top

static func _propagate_and_get_changed(start_pos: Vector2i, domains: Dictionary, socket_set: Dictionary, modules: Dictionary, dirs: Dictionary) -> Array:
	var changed = {}
	var arc_queue = []

	# Seed the queue with arcs from start_pos to all its neighbors
	for dir_key in dirs:
		var neighbor = start_pos + dirs[dir_key]
		if socket_set.has(neighbor):
			arc_queue.append([start_pos, neighbor, dir_key])

	while not arc_queue.is_empty():
		var arc = arc_queue.pop_back()  # Using pop_back as stack; still AC-3 because we re-add arcs on change
		var from_pos = arc[0]
		var to_pos = arc[1]
		var dir_key = arc[2]

		# Skip if 'from_pos' domain is empty (contradiction already)
		if domains[from_pos].is_empty():
			continue

		# Build set of valid edge strings from 'from_pos' modules
		var valid_edges = {}
		for m in domains[from_pos]:
			var edge_str = modules[m].get("edges", {}).get(dir_key, "Open")
			valid_edges[edge_str] = true

		# Filter neighbor's domain
		var neighbor_modules = domains[to_pos]
		var next_modules = []
		var changed_here = false

		var op_key = OPPOSITE[dir_key]
		for nm in neighbor_modules:
			var opp_edge_str = modules[nm].get("edges", {}).get(op_key, "Open")
			if valid_edges.has(opp_edge_str):
				next_modules.append(nm)
			else:
				changed_here = true

		if changed_here:
			domains[to_pos] = next_modules
			changed[to_pos] = true

			# Re-add arcs from the changed socket to all its neighbors
			for other_dir in dirs:
				var nb = to_pos + dirs[other_dir]
				if socket_set.has(nb):
					arc_queue.append([to_pos, nb, other_dir])

	# Convert dictionary keys to array for return
	var result = []
	for s in changed.keys():
		result.append(s)
	return result
