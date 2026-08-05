class_name GraphValidator
extends RefCounted

# Analyzes the graph for data corruption and optionally repairs it.
# Returns an array of diagnostic string messages detailing what it found.
static func validate(graph: Graph, auto_repair: bool = true) -> Array[String]:
	var diagnostics: Array[String] = []
	var start_time = Time.get_ticks_usec()
	
	if not graph:
		return ["Error: Provided Graph reference is null."]
		
	# --------------------------------------------------------------------------
	# 1. THE EDGE SWEEP (Topological Integrity)
	# --------------------------------------------------------------------------
	var invalid_edge_keys = []
	for key in graph.edge_store:
		var e = graph.edge_store[key]
		var u_exists = graph.nodes.has(e.u)
		var v_exists = graph.nodes.has(e.v)
		
		if not u_exists or not v_exists:
			var msg = "Edge Sweep: Found orphaned edge '%s' -> '%s'." % [e.u, e.v]
			if not u_exists: msg += " Node '%s' is missing." % e.u
			if not v_exists: msg += " Node '%s' is missing." % e.v
			diagnostics.append(msg)
			invalid_edge_keys.append(key)
			
		elif e.u == e.v:
			# Ghost loop detected
			diagnostics.append("Edge Sweep: Found self-intersecting ghost loop at Node '%s'." % e.u)
			invalid_edge_keys.append(key)

	if auto_repair and not invalid_edge_keys.is_empty():
		for key in invalid_edge_keys:
			graph.edge_store.erase(key)
		diagnostics.append("REPAIR: Purged %d invalid edges." % invalid_edge_keys.size())

	# --------------------------------------------------------------------------
	# 2. THE ADJACENCY SWEEP (Cache Synchronization)
	# --------------------------------------------------------------------------
	# The adjacency map MUST match the edge store perfectly, otherwise A* crashes.
	if auto_repair:
		graph._rebuild_adjacency_cache()
		diagnostics.append("REPAIR: Adjacency Cache forcefully synchronized.")
	else:
		# Just check if the counts loosely match
		var total_adjacency_edges = 0
		for u in graph._adjacency_map:
			total_adjacency_edges += graph._adjacency_map[u].size()
		if total_adjacency_edges != graph.edge_store.size():
			diagnostics.append("Cache Sweep: Adjacency map size (%d) out of sync with Edge Store (%d)." % [total_adjacency_edges, graph.edge_store.size()])

	# --------------------------------------------------------------------------
	# 3. THE ZONE SWEEP (Containment Integrity)
	# --------------------------------------------------------------------------
	if "zones" in graph:
		var zones_repaired = 0
		for zone in graph.zones:
			var invalid_roster_ids = []
			for node_id in zone.registered_nodes:
				if not graph.nodes.has(node_id):
					invalid_roster_ids.append(node_id)
					
			if not invalid_roster_ids.is_empty():
				diagnostics.append("Zone Sweep: Zone '%s' contains %d deleted nodes." % [zone.zone_name, invalid_roster_ids.size()])
				if auto_repair:
					for id in invalid_roster_ids:
						zone.unregister_node(id)
					zones_repaired += 1
					
		if auto_repair and zones_repaired > 0:
			diagnostics.append("REPAIR: Cleared ghost nodes from %d zones." % zones_repaired)

	# --------------------------------------------------------------------------
	# 4. THE AGENT SWEEP (Simulation Integrity)
	# --------------------------------------------------------------------------
	if "agents" in graph:
		var agents_repaired = 0
		for agent in graph.agents:
			var agent_needs_repair = false
			
			# A. Current Node Check
			if agent.current_node_id != "" and not graph.nodes.has(agent.current_node_id):
				diagnostics.append("Agent Sweep: Agent %d standing on deleted node '%s'." % [agent.display_id, agent.current_node_id])
				agent_needs_repair = true
				
			# B. Target Node Check
			if agent.target_node_id != "" and not graph.nodes.has(agent.target_node_id):
				diagnostics.append("Agent Sweep: Agent %d tracking deleted target '%s'." % [agent.display_id, agent.target_node_id])
				agent_needs_repair = true
				
			# C. History Check
			var invalid_history_count = 0
			for entry in agent.history:
				if not graph.nodes.has(entry.get("node", "")):
					invalid_history_count += 1
			if invalid_history_count > 0:
				diagnostics.append("Agent Sweep: Agent %d has %d deleted nodes in history." % [agent.display_id, invalid_history_count])
				agent_needs_repair = true

			# Execute Agent Repair
			if auto_repair and agent_needs_repair:
				agent.validate_state(graph) # Calls the built-in repair you wrote!
				agents_repaired += 1
				
		if auto_repair and agents_repaired > 0:
			diagnostics.append("REPAIR: Reset state for %d stranded agents." % agents_repaired)

	# --------------------------------------------------------------------------
	# 5. THE ID COUNTER SWEEP (Prevent Future Collisions)
	# --------------------------------------------------------------------------
	var highest_int_id = 0
	for id in graph.nodes:
		if id.is_valid_int():
			highest_int_id = max(highest_int_id, id.to_int())
			
	if graph._next_display_id <= highest_int_id:
		diagnostics.append("Counter Sweep: Display ID Counter (%d) is lagging behind highest node ID (%d)." % [graph._next_display_id, highest_int_id])
		if auto_repair:
			graph._next_display_id = highest_int_id + 1
			diagnostics.append("REPAIR: Synchronized Display ID Counter to %d." % graph._next_display_id)

	# --- FINISH ---
	var end_time = Time.get_ticks_usec()
	var ms_taken = (end_time - start_time) / 1000.0
	
	if diagnostics.is_empty():
		diagnostics.append("Validation passed successfully in %.2f ms. Graph is perfectly sound." % ms_taken)
	else:
		diagnostics.push_front("Validation completed in %.2f ms with findings:" % ms_taken)
		
	return diagnostics
