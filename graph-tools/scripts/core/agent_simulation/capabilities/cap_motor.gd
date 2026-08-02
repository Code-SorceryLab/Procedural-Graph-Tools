class_name CapMotor
extends AgentCapability

# --- ACTIONS ---

# The standard "Walk" action
func move_to_node(node_id: String, graph: Graph) -> void:
	if not graph.nodes.has(node_id): return
	
	# Update Agent State
	agent.pos = graph.get_node_pos(node_id)
	agent.current_node_id = node_id
	agent.step_count += 1
	
	# Update Memory (History)
	agent.history.append({ "node": node_id, "step": agent.step_count })

# The "Teleport" or "Spawn" action (No history recording)
func warp(new_pos: Vector2, new_node_id: String = "") -> void:
	agent.pos = new_pos
	agent.current_node_id = new_node_id
