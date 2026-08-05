class_name BehaviorSolver
extends AgentBehavior

var visited_nodes: Array[String] = []
var explored_edges: Array = []
var path_stack: Array[String] = []

func enter(agent: AgentWalker, _graph: Graph) -> void:
	visited_nodes.clear()
	explored_edges.clear()
	path_stack.clear()
	
	if agent.current_node_id != "":
		visited_nodes.append(agent.current_node_id)
		path_stack.append(agent.current_node_id)

func step(agent: AgentWalker, graph: Graph, _context: Dictionary = {}) -> void:
	var current = agent.current_node_id
	if current == "": return
	
	# 1. Pick up Items at Current Node (Using Shared Rules)
	CapInventory.consume_items_at_node(agent, graph, current)

	# 2. Check for Victory
	if graph.nodes.has(current) and graph.nodes[current].type == "boss":
		agent.is_finished = true
		return

	# 3. Scan Outgoing Edges
	var valid_next = ""
	var out_edges = _get_outgoing_edges(graph, current)
	
	# Shuffle slightly so it feels like an explorer, not a robot reading alphabetically
	_shuffle_array(out_edges, agent.rng) 
	
	for e in out_edges:
		var v = e.v
		var pair = [current, v]
		if explored_edges.has(pair): continue # Already explored this specific edge
		
		# --- CONSTRAINT A: Locks (Using Shared Rules) ---
		if not CapInventory.can_unlock_edge(agent, graph, current, v):
			continue # We don't have the key!
			
		# --- CONSTRAINT B: Logic Gates ---
		var target_node = graph.nodes[v]
		var gate = target_node.custom_data.get("logic_gate", "OR")
		if gate == "AND":
			var can_enter = true
			for p in _get_incoming_nodes(graph, v):
				if not visited_nodes.has(p):
					can_enter = false
					break
			if not can_enter: continue # We haven't explored all incoming branches yet!
		
		valid_next = v
		explored_edges.append(pair)
		break
		
	# 4. Execute Move (or Backtrack)
	if valid_next != "":
		# Move Forward
		var motor = agent.get_capability("Motor") as CapMotor
		if motor: motor.move_to_node(valid_next, graph)
		else: agent.move_to_node(valid_next, graph)
		
		visited_nodes.append(valid_next)
		path_stack.append(valid_next)
	else:
		# Backtrack (Stuck or Dead End)
		if path_stack.size() > 1:
			path_stack.pop_back()
			var back_target = path_stack.back()
			var motor = agent.get_capability("Motor") as CapMotor
			if motor: motor.move_to_node(back_target, graph)
			else: agent.move_to_node(back_target, graph)
		else:
			print("AgentSolver %d: Failed to solve DAG. No valid moves left!" % agent.display_id)
			agent.is_finished = true

# --- Helpers ---
func _get_outgoing_edges(graph: Graph, node_id: String) -> Array:
	var edges = []
	for key in graph.edge_store:
		if graph.edge_store[key].u == node_id: edges.append(graph.edge_store[key])
	return edges

func _get_incoming_nodes(graph: Graph, node_id: String) -> Array[String]:
	var parents: Array[String] = []
	for key in graph.edge_store:
		if graph.edge_store[key].v == node_id: parents.append(graph.edge_store[key].u)
	return parents

func _shuffle_array(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp
