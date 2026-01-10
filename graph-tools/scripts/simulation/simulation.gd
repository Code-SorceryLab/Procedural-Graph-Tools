class_name Simulation
extends RefCounted

# --- SIGNALS ---
# Emitted when a step completes (useful for the Controller to know when to refresh UI)
signal step_completed(tick_index: int)

# --- STATE ---
var graph: Graph
var tick_count: int = 0
var is_active: bool = false
var _session_path: Array[String] = [] # Tracks visited nodes for this session

# --- INITIALIZATION ---
func _init(target_graph: Graph) -> void:
	self.graph = target_graph
	self.tick_count = 0
	self._session_path.clear()

# --- CORE API ---

# Advances the simulation by exactly one "turn"
# Returns TRUE if any agent performed an action (simulation is still alive)
# Returns FALSE if all agents are stopped/inactive
func step() -> bool:
	if not graph: return false
	
	var grid_spacing = GraphSettings.GRID_SPACING
	var any_active = false
	var agents_moved = 0
	
	# We iterate over all agents in the graph
	for agent in graph.agents:
		if agent.active:
			# 1. Check Limits (Optional: Move this logic to AgentWalker later)
			if agent.steps >= agent.get("step_count"):
				agent.active = false
				continue
			
			any_active = true
			var visited_id = ""
			
			# 2. Execute Behavior
			# Currently hardcoded to the Agent's internal 'step' functions.
			# In Phase 3, we will call `agent.update_behavior(graph)` here.
			if agent.mode == 0: # Grow Mode
				visited_id = agent.step_grow(graph, grid_spacing, true)
			else: # Paint Mode
				visited_id = agent.step_paint(graph, false, _session_path)
			
			# 3. Record Result
			if visited_id != "":
				_session_path.append(visited_id)
				agent.steps += 1
				agents_moved += 1
				
	if any_active:
		tick_count += 1
		step_completed.emit(tick_count)
		
	return any_active

# Resets the state without deleting the agents (Acts like "Rewind")
# Note: To fully clear the board, the Controller should call graph.agents.clear()
func reset_state() -> void:
	tick_count = 0
	_session_path.clear()
	# Reset agent internal counters
	for agent in graph.agents:
		agent.steps = 0
		agent.active = true
		agent.history.clear()
		agent.history.append(agent.current_node_id)
		
		# Teleport back to start if possible
		if agent.start_node_id != "" and graph.nodes.has(agent.start_node_id):
			agent.jump_to_node(agent.start_node_id, graph.get_node_pos(agent.start_node_id))

# --- HELPERS ---

func get_session_path() -> Array[String]:
	return _session_path
