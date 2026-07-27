class_name CapBuilder
extends AgentCapability

# --- HELPER / SENSOR ---
# Checks if a specific coordinate is legally allowed to have a node
func can_build_at(graph: Graph, pos: Vector2, spacing: Vector2) -> bool:
	if not graph.has_method("get_zone_at"): return true
	
	var gx = round(pos.x / spacing.x)
	var gy = round(pos.y / spacing.y)
	
	var zone = graph.get_zone_at(Vector2i(gx, gy))
	if zone:
		# Grow MUST respect the "Building Permit"
		if not zone.allow_new_nodes: return false
		# Implies we probably shouldn't grow into walls either
		if not zone.is_traversable: return false
			
	return true

# --- ACTION ---
# Spawns a node, optionally merges, links it to the agent's current node, and returns the ID
func build_and_link(graph: Graph, target_pos: Vector2, merge_overlaps: bool) -> String:
	var new_id = ""
	var existing_id = graph.get_node_at_position(target_pos, -1.0)
	
	# 1. Spawn or Merge
	if merge_overlaps and not existing_id.is_empty():
		new_id = existing_id
	else:
		new_id = agent.generate_unique_id(graph)
		graph.add_node(new_id, target_pos) 
	
	# 2. Link Backwards (Create the Edge)
	var current = agent.current_node_id
	if current != "" and graph.nodes.has(current):
		if current != new_id:
			graph.add_edge(current, new_id)
			
	return new_id
