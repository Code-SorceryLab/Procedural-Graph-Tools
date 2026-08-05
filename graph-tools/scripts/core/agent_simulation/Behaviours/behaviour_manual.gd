class_name BehaviorManual
extends AgentBehavior

func step(agent: AgentWalker, graph: Graph, _context: Dictionary = {}) -> void:
	var intent = agent.custom_data.get("manual_intent", "")
	if intent == "": return # Idle Tick
	
	var current = agent.current_node_id
	print("[BehaviorManual] Evaluating move: '%s' -> '%s'" % [current, intent])
	
	# 1. Validate Geometry
	var neighbors = graph.get_neighbors(current)
	if not neighbors.has(intent):
		print(" -> FAILED: Not a valid outgoing neighbor.")
		agent.custom_data["manual_intent"] = "" 
		return
		
	# 2. Validate Locks
	if not CapInventory.can_unlock_edge(agent, graph, current, intent):
		print(" -> FAILED: Edge is locked and agent lacks the key.")
		agent.custom_data["manual_intent"] = ""
		agent.last_bump_pos = graph.get_node_pos(intent) # Bump!
		return
		
	print(" -> SUCCESS: Executing Move.")
	
	# 3. Execute Move
	var motor = agent.get_capability("Motor") as CapMotor
	if motor: motor.move_to_node(intent, graph)
	else: agent.move_to_node(intent, graph)
	
	# 4. Pick up Items
	CapInventory.consume_items_at_node(agent, graph, intent)
	
	# 5. Clear intent
	agent.custom_data["manual_intent"] = ""
