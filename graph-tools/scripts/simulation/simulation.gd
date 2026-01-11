class_name Simulation
extends RefCounted

# --- SIGNALS ---
signal step_completed(tick_index: int)

# --- STATE ---
var graph: Graph
var tick_count: int = 0
var _session_path: Array[String] = []

# --- INITIALIZATION ---
func _init(target_graph: Graph) -> void:
	self.graph = target_graph
	self.tick_count = 0
	self._session_path.clear()

# --- CORE API ---

# Advances the simulation by exactly one "turn"
# Returns TRUE if any agent performed an action (simulation is still alive)
# Returns FALSE if all agents are stopped/inactive
func step() -> GraphCommand:
	if not graph: return null
	
	var grid_spacing = GraphSettings.GRID_SPACING
	var any_active = false
	
	# 1. Setup Recorder (Captures new nodes/edges/paints)
	var recorder = GraphRecorder.new(graph)
	
	# 2. Snapshot Agent States (Captures movement)
	var pre_sim_states = {}
	for agent in graph.agents:
		if agent.active:
			pre_sim_states[agent.id] = _snapshot_agent(agent)
	
	# 3. Run Logic
	for agent in graph.agents:
		if agent.active:
			if agent.steps > 0 and agent.step_count >= agent.steps:
				agent.active = false
				continue
				
			any_active = true
			var visited_id = ""
			
			# PASS THE RECORDER, NOT THE GRAPH
			if agent.mode == 0: # Grow
				visited_id = agent.step_grow(recorder, grid_spacing, true)
			else: # Paint
				visited_id = agent.step_paint(recorder, false, _session_path)
			
			if visited_id != "":
				_session_path.append(visited_id)
				agent.step_count += 1
	
	if not any_active:
		return null
		
	tick_count += 1
	step_completed.emit(tick_count)
	
	# 4. Compile Undo Batch
	var batch = CmdBatch.new(graph, "Simulation Step %d" % tick_count)
	
	# A. Add Structural Changes (Nodes/Edges created during step)
	for cmd in recorder.recorded_commands:
		batch.add_command(cmd)
		
	# B. Add Agent Movement (Diff against snapshot)
	for agent in graph.agents:
		if pre_sim_states.has(agent.id):
			var start_state = pre_sim_states[agent.id]
			var end_state = _snapshot_agent(agent)
			
			# If agent changed position or active state, record it
			if start_state.hash() != end_state.hash():
				var move_cmd = CmdUpdateAgent.new(graph, agent, start_state, end_state)
				batch.add_command(move_cmd)
	
	# Only return batch if something actually happened
	if batch.get_command_count() > 0:
		return batch
		
	return null

# Helper to capture agent state for Diffing
func _snapshot_agent(agent) -> Dictionary:
	return {
		"pos": agent.pos,
		"node_id": agent.current_node_id,
		"step_count": agent.step_count,
		"history": agent.history.duplicate(),
		"active": agent.active
	}

# Resets the state without deleting the agents (Acts like "Rewind")
# Note: To fully clear the board, the Controller should call graph.agents.clear()
# [UPDATED] Now returns a Command for Undo/Redo
func reset_state() -> GraphCommand:
	var batch = CmdBatch.new(graph, "Reset Simulation")
	
	# 1. Snapshot Current State (Before Reset)
	var pre_reset_states = {}
	for agent in graph.agents:
		pre_reset_states[agent.id] = _snapshot_agent(agent)

	# 2. Reset Internal Sim State
	tick_count = 0
	_session_path.clear()
	
	# 3. Apply Reset & Record Differences
	for agent in graph.agents:
		var start_state = pre_reset_states[agent.id]
		
		# --- APPLY RESET LOGIC ---
		agent.step_count = 0
		agent.active = true
		agent.history.clear()
		
		# Logic to find start position
		var target_pos = agent.pos 
		var target_node = ""
		
		if agent.start_node_id != "" and graph.nodes.has(agent.start_node_id):
			target_node = agent.start_node_id
			target_pos = graph.get_node_pos(target_node)
			
		# Move Agent
		agent.warp(target_pos, target_node)
		
		# Re-add initial history entry
		if target_node != "":
			agent.history.append({ "node": target_node, "step": 0 })
			
		# --- END RESET LOGIC ---

		# 4. Snapshot New State & Create Command
		var end_state = _snapshot_agent(agent)
		
		# Only record if state actually changed
		if start_state.hash() != end_state.hash():
			var cmd = CmdUpdateAgent.new(graph, agent, start_state, end_state)
			batch.add_command(cmd)
			
	if batch.get_command_count() > 0:
		return batch
		
	return null

# --- HELPERS ---

func get_session_path() -> Array[String]:
	return _session_path
