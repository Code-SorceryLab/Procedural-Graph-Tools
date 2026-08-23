class_name WFCSolver
extends RefCounted

const SOCKET_SIZE = 3
const DIRS = {
	"N": Vector2i(0, -SOCKET_SIZE), "S": Vector2i(0, SOCKET_SIZE),
	"E": Vector2i(SOCKET_SIZE, 0),  "W": Vector2i(-SOCKET_SIZE, 0)
}
const OPPOSITE = {"N": "S", "S": "N", "E": "W", "W": "E"}

static func resolve(sockets: Array, rng: RandomNumberGenerator, modules: Dictionary) -> Dictionary:
	if modules.is_empty(): return {}
	
	#print("\n--- [WFC] STARTING SOLVE ---")
	#print("[WFC] Sockets detected at: ", sockets)
	
	var domains = {}
	var uncollapsed = {}
	
	# 1. Initialize Superposition
	for s_pos in sockets:
		domains[s_pos] = modules.keys()
		uncollapsed[s_pos] = true
		
	# 2. Main Collapse Loop
	while not uncollapsed.is_empty():
		var best_socket = Vector2i.ZERO
		var min_entropy = 99999
		for s_pos in uncollapsed:
			var entropy = domains[s_pos].size()
			if entropy < min_entropy:
				min_entropy = entropy
				best_socket = s_pos
				
		if min_entropy == 0:
			push_error("[WFC] CONTRADICTION at socket: ", best_socket, ". No valid modules fit here!")
			return {} 
			
		#print("[WFC] Collapsing Socket ", best_socket, " | Valid Options: ", domains[best_socket])
		
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
				
		#print("[WFC] -> Chose Module: '", chosen_module, "'")
		domains[best_socket] = [chosen_module]
		uncollapsed.erase(best_socket)
		
		# Propagate constraints to neighbors
		_propagate(best_socket, domains, sockets, modules)

	#print("--- [WFC] SOLVE COMPLETE ---\n")

	# 3. Assemble Final Payload
	var result = {"floors": [], "exact_floors": {}, "walls": [], "exact_walls": {}, "entities": []}
	for s_pos in sockets:
		var m_id = domains[s_pos][0]
		var m_data = modules[m_id]
		
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

static func _propagate(start_pos: Vector2i, domains: Dictionary, all_sockets: Array, modules: Dictionary) -> void:
	var stack = [start_pos]
	while not stack.is_empty():
		var current = stack.pop_back()
		var current_modules = domains[current]
		
		for dir_key in DIRS:
			var neighbor = current + DIRS[dir_key]
			if not all_sockets.has(neighbor): continue # No neighbor in this direction
			
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
					#print("[WFC]   -> Socket ", neighbor, " rejecting '", nm, "' (Edge '", opp_edge_str, "' incompatible with ", valid_edges.keys(), ")")
					changed = true
					
			if changed:
				#print("[WFC]   -> Socket ", neighbor, " domain reduced to: ", next_modules)
				domains[neighbor] = next_modules
				stack.append(neighbor)
