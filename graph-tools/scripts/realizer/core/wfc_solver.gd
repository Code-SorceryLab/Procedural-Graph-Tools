class_name WFCSolver
extends RefCounted

const SOCKET_SIZE = 3
const DIRS = {
	"N": Vector2i(0, -SOCKET_SIZE), "S": Vector2i(0, SOCKET_SIZE),
	"E": Vector2i(SOCKET_SIZE, 0),  "W": Vector2i(-SOCKET_SIZE, 0)
}
const OPPOSITE = {"N": "S", "S": "N", "E": "W", "W": "E"}

static func resolve(sockets: Array, rng: RandomNumberGenerator, modules: Dictionary, step_size: int = 3, fixed_pixels: Dictionary = {}) -> Dictionary:
	if modules.is_empty(): return {}
	
	#print("\n--- [WFC] STARTING SOLVE (Step Size: ", step_size, ") ---")
	
	var dirs = {
		"N": Vector2i(0, -step_size), "S": Vector2i(0, step_size),
		"E": Vector2i(step_size, 0),  "W": Vector2i(-step_size, 0)
	}
	
	var domains = {}
	var uncollapsed = {}
	var initial_stack = [] # Tracks constrained sockets for early propagation
	
	# 1. Initialize Superposition & Apply Fixed Constraints
	for s_pos in sockets:
		var allowed = modules.keys().duplicate()
		var is_constrained = false
		
		# --- [FIXED] CONSTRAINT PRUNING & WALL BANISHMENT ---
		for i in range(allowed.size() - 1, -1, -1):
			var m_id = allowed[i]
			var m_floors = modules[m_id].get("exact_floors", {})
			var conflict = false
			
			for pt in m_floors:
				var world_pt = s_pos + pt
				if fixed_pixels.has(world_pt):
					# If there is a fixed constraint here, it MUST match perfectly
					if m_floors[pt] != fixed_pixels[world_pt]:
						conflict = true; break 
				else:
					# --- [NEW] PREVENT HALLUCINATIONS ---
					# If there is NO wall constraint here, the solver is 
					# strictly forbidden from placing a Boundary (-2, -2) here!
					if m_floors[pt] == Vector2i(-2, -2): 
						conflict = true; break
			
			if conflict:
				allowed.remove_at(i)
				is_constrained = true
					
		domains[s_pos] = allowed
		uncollapsed[s_pos] = true
		if is_constrained: initial_stack.append(s_pos)
		
	# --- [NEW] INITIAL PROPAGATION ---
	# Ripple the wall constraints inward before we make our first random guess!
	for s_pos in initial_stack:
		_propagate(s_pos, domains, sockets, modules, dirs)
		
	# 2. Main Collapse Loop
	while not uncollapsed.is_empty():
		var best_socket = Vector2i.ZERO
		var min_entropy = 99999.0 # [CHANGED] Now a float for Shannon math
		
		for s_pos in uncollapsed:
			var valid_modules = domains[s_pos]
			var count = valid_modules.size()
			
			if count == 0:
				min_entropy = -1.0 # Force contradiction to trigger
				best_socket = s_pos
				break
				
			# --- [NEW] TRUE SHANNON ENTROPY CALCULATION ---
			var sum_weight = 0.0
			var sum_weight_log_weight = 0.0
			
			for m in valid_modules:
				var w = float(modules[m].get("weight", 1.0))
				sum_weight += w
				sum_weight_log_weight += w * log(w)
				
			var entropy = log(sum_weight) - (sum_weight_log_weight / sum_weight)
			
			# Add microscopic noise to break ties organically (uses deterministic RNG)
			var noise = rng.randf() * 0.00001
			entropy += noise
			
			if entropy < min_entropy:
				min_entropy = entropy
				best_socket = s_pos
				
		if min_entropy < 0.0:
			# push_error("[WFC] CONTRADICTION at socket: ", best_socket, ". No valid modules fit here!")
			return {} 
			
		# Weighted Random Collapse
		var valid_modules = domains[best_socket]
		var total_weight = 0.0
		for m in valid_modules: total_weight += float(modules[m].get("weight", 10.0))
		
		var roll = rng.randf() * total_weight
		var chosen_module = valid_modules[0]
		for m in valid_modules:
			roll -= float(modules[m].get("weight", 10.0))
			if roll <= 0:
				chosen_module = m; break
				
		domains[best_socket] = [chosen_module]
		uncollapsed.erase(best_socket)
		
		# Propagate constraints to neighbors
		_propagate(best_socket, domains, sockets, modules, dirs)

	#print("--- [WFC] SOLVE COMPLETE ---\n")

	# 3. Assemble Final Payload
	var result = {"floors": [], "exact_floors": {}, "walls": [], "exact_walls": {}, "entities": []}
	for s_pos in sockets:
		var m_id = domains[s_pos][0]
		var m_data = modules[m_id]
		
		if step_size == 1:
			# --- [FIXED] OVERLAPPING WFC ---
			# We only stamp the origin pixel! The mathematical overlap guarantees 
			# the neighboring sockets will perfectly paint the rest. No overwriting!
			if m_data.has("exact_floors") and m_data["exact_floors"].has(Vector2i.ZERO):
				result["exact_floors"][s_pos] = m_data["exact_floors"][Vector2i.ZERO]
		else:
			# --- [ORIGINAL] CHUNK SET-PIECES ---
			for type in ["floors", "walls"]:
				if m_data.has(type):
					for pt in m_data[type]: result[type].append(s_pos + pt)
			for type in ["exact_floors", "exact_walls"]:
				if m_data.has(type):
					for pt in m_data[type]: result[type][s_pos + pt] = m_data[type][pt]
					
			if m_data.has("placed_entities"):
				for ent in m_data["placed_entities"]:
					var world_ent = ent.duplicate(true)
					world_ent["pos"] = s_pos + ent["pos"]
					result["entities"].append(world_ent)
				
	return result

static func _propagate(start_pos: Vector2i, domains: Dictionary, all_sockets: Array, modules: Dictionary, dirs: Dictionary) -> void:
	var stack = [start_pos]
	while not stack.is_empty():
		var current = stack.pop_back()
		var current_modules = domains[current]
		
		for dir_key in dirs:
			var neighbor = current + dirs[dir_key]
			if not all_sockets.has(neighbor): continue 
			
			var valid_edges = {}
			for m in current_modules:
				var edge_str = modules[m].get("edges", {}).get(dir_key, "Open")
				valid_edges[edge_str] = true
				
			var neighbor_modules = domains[neighbor]
			var next_modules = []
			var changed = false
			
			var op_key = OPPOSITE[dir_key]
			for nm in neighbor_modules:
				var opp_edge_str = modules[nm].get("edges", {}).get(op_key, "Open")
				if valid_edges.has(opp_edge_str):
					next_modules.append(nm)
				else:
					changed = true
					
			if changed:
				domains[neighbor] = next_modules
				stack.append(neighbor)
