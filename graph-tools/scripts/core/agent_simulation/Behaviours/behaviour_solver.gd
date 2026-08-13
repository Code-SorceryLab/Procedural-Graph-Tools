class_name BehaviorSolver
extends AgentBehavior

var visited_nodes: Dictionary = {}   # node_id -> true (unique)
var path_stack: Array[String] = []

# --- REVISITING BLOCKED EDGES STATE ---
var node_frontiers: Dictionary = {}   # node_id -> Array of outgoing edges
var node_cursor: Dictionary = {}      # node_id -> int (next edge index)
var visited_edges: Dictionary = {}    # canonical pair -> true (successful forward moves)

# Condition version increments when:
#   - the key inventory changes
#   - a new node is visited (AND‑gate prerequisites may become satisfied)
var condition_version: int = 0
var last_condition_version_at_node: Dictionary = {}
var last_key_count: int = 0
var last_visited_count: int = 0

func enter(agent: AgentWalker, _graph: Graph) -> void:
	visited_nodes.clear()
	path_stack.clear()
	node_frontiers.clear()
	node_cursor.clear()
	visited_edges.clear()
	condition_version = 0
	last_condition_version_at_node.clear()
	last_key_count = 0
	last_visited_count = 0

	if agent.current_node_id != "":
		path_stack.append(agent.current_node_id)
		visited_nodes[agent.current_node_id] = true
		last_visited_count = 1

	var inv = agent.get_capability("Inventory") as CapInventory
	if inv:
		last_key_count = inv._get_keys().size()

func get_debug_overlay_data() -> Dictionary:
	var visited_edge_list: Array = []
	for pair in visited_edges.keys():
		visited_edge_list.append([pair[0], pair[1]])

	return {
		"visited_nodes": visited_nodes.keys(),
		"path_stack": path_stack.duplicate(),
		"visited_edges": visited_edge_list
	}

func step(agent: AgentWalker, graph: Graph, _context: Dictionary = {}) -> void:
	var current = agent.current_node_id
	if current == "": return

	# 1. Pick up items and detect key changes
	var inv_before = last_key_count
	CapInventory.consume_items_at_node(agent, graph, current)
	var inv_after = 0
	var inv_cap = agent.get_capability("Inventory") as CapInventory
	if inv_cap:
		inv_after = inv_cap._get_keys().size()

	var condition_changed = false
	if inv_after != inv_before:
		condition_version += 1
		last_key_count = inv_after
		condition_changed = true

	# 2. Victory check
	if graph.nodes.has(current) and graph.nodes[current].type == "boss":
		agent.is_finished = true
		return

	# 3. If condition changed, reset exploration memory so locked edges can be retried
	if condition_changed:
		_reset_for_revisit()

	# 4. Ensure this node has a frontier and cursor
	_ensure_frontier(agent, graph, current)

	# 5. If condition version changed while away, reset cursor for THIS node
	if last_condition_version_at_node.get(current, -1) != condition_version:
		node_cursor[current] = 0
		last_condition_version_at_node[current] = condition_version

	var frontier: Array = node_frontiers[current]
	var idx: int = node_cursor[current]

	# 6. Try edges from the cursor onward
	while idx < frontier.size():
		var e = frontier[idx]
		idx += 1
		node_cursor[current] = idx

		var pair = [current, e.v]
		pair.sort()

		# Skip edges we've already successfully traversed in the current condition
		if visited_edges.has(pair):
			continue

		# Check locks and logic gates
		if _can_pass(agent, graph, current, e.v):
			# Move forward
			var motor = agent.get_capability("Motor") as CapMotor
			if motor: motor.move_to_node(e.v, graph)
			else: agent.move_to_node(e.v, graph)

			path_stack.append(e.v)
			visited_nodes[e.v] = true
			visited_edges[pair] = true
			last_visited_count = visited_nodes.size()

			# Visiting a new node may satisfy AND gates, so increment condition version
			condition_version += 1
			last_condition_version_at_node[current] = condition_version
			_ensure_frontier(agent, graph, e.v)
			return

	# 7. No valid edge: backtrack
	if path_stack.size() > 1:
		path_stack.pop_back()
		var back_target = path_stack.back()
		var motor = agent.get_capability("Motor") as CapMotor
		if motor: motor.move_to_node(back_target, graph)
		else: agent.move_to_node(back_target, graph)
	else:
		print("AgentSolver %d: Failed to solve DAG. No valid moves left!" % agent.display_id)
		agent.is_finished = true

# ------------------------------------------------------------------------------
# HELPERS
# ------------------------------------------------------------------------------

func _reset_for_revisit() -> void:
	# Clear visited edges so the agent can re-traverse paths to locked edges
	visited_edges.clear()
	# Reset all cursors so every node's outgoing edges are reconsidered
	for node in node_cursor.keys():
		node_cursor[node] = 0

func _ensure_frontier(agent: AgentWalker, graph: Graph, node_id: String) -> void:
	if not node_frontiers.has(node_id):
		var out_edges = _get_outgoing_edges(graph, node_id)
		_shuffle_array(out_edges, agent.rng)
		node_frontiers[node_id] = out_edges
		node_cursor[node_id] = 0
		last_condition_version_at_node[node_id] = condition_version

func _can_pass(agent: AgentWalker, graph: Graph, from_id: String, to_id: String) -> bool:
	# Lock constraint
	if not CapInventory.can_unlock_edge(agent, graph, from_id, to_id):
		return false

	# Logic gate constraint (AND gate requires all incoming nodes visited)
	var target_node = graph.nodes[to_id]
	var gate = target_node.custom_data.get("logic_gate", "OR")
	if gate == "AND":
		for p in _get_incoming_nodes(graph, to_id):
			if not visited_nodes.has(p):
				return false

	return true

func _get_outgoing_edges(graph: Graph, node_id: String) -> Array:
	var edges = []
	for key in graph.edge_store:
		if graph.edge_store[key].u == node_id:
			edges.append(graph.edge_store[key])
	return edges

func _get_incoming_nodes(graph: Graph, node_id: String) -> Array[String]:
	var parents: Array[String] = []
	for key in graph.edge_store:
		if graph.edge_store[key].v == node_id:
			parents.append(graph.edge_store[key].u)
	return parents

func _shuffle_array(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j = rng.randi() % (i + 1)
		var temp = arr[i]
		arr[i] = arr[j]
		arr[j] = temp
