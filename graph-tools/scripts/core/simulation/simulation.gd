class_name Simulation
extends RefCounted

# --- STATE ---
var graph: Graph
var tick_count: int = 0

# --- INITIALIZATION ---
func _init(target_graph: Graph) -> void:
	self.graph = target_graph
	self.tick_count = 0

# --- CORE API ---

# Advances the simulation by exactly one "turn"
func step() -> GraphCommand:
	if not graph: return null
	
	var any_active = false
	
	# 1. Create a Recorder wrapper around the LIVE graph
	var recorder = GraphRecorder.new(graph)
	
	# 2. Snapshot Movement State (Pre-step)
	var pre_sim_states = {}
	for agent in graph.agents:
		if agent.active:
			pre_sim_states[agent.id] = _snapshot_agent(agent)
	
	# 3. Execution Loop
	for agent in graph.agents:
		# Check: Active AND Not Finished
		if agent.active and not agent.is_finished:
			
			# Check limits (if -1, infinite)
			if agent.steps != -1 and agent.step_count >= agent.steps:
				agent.is_finished = true 
				continue
			
			# If we get here, the simulation is NOT over yet
			any_active = true
			
			# Step the agent (Delegates to Brain)
			# If blocked, this might not produce any recorder commands,
			# BUT it updates agent.last_bump_pos internal state.
			agent.step(recorder)
			
	# [CRITICAL CHECK] 
	# If no agents are active, we are truly done. Return null to stop Controller.
	if not any_active:
		return null
		
	tick_count += 1
	
	SignalManager.simulation_stepped.emit(tick_count)
	
	# 4. Compile Batch for Undo
	var batch = CmdBatch.new(graph, "Simulation Step %d" % tick_count)
	
	# A. Commands from Brains (Paint, Grow, etc.)
	for cmd in recorder.recorded_commands:
		batch.add_command(cmd)
		
	# B. Movement Updates (Position/State changes)
	for agent in graph.agents:
		if pre_sim_states.has(agent.id):
			var start = pre_sim_states[agent.id]
			var end = _snapshot_agent(agent)
			
			# Only create command if state changed (Position OR Bump Visuals)
			if start.hash() != end.hash():
				var move_cmd = CmdUpdateAgent.new(graph, agent, start, end)
				batch.add_command(move_cmd)
				
	# [THE FIX]
	# If 'any_active' is true, we MUST return a batch to keep the controller running,
	# even if the batch is empty (meaning everyone stalled this turn).
	# This prevents the "Pause on Bump" bug.
	return batch

# Helper to capture agent state for Diffing
func _snapshot_agent(agent) -> Dictionary:
	return {
		"pos": agent.pos,
		"node_id": agent.current_node_id,
		"step_count": agent.step_count,
		"history": agent.history.duplicate(),
		"active": agent.active,
		"is_finished": agent.is_finished,
		# Track visuals so Undo clears the red lines, 
		# and so "Bumping" counts as a state change!
		"last_bump_pos": agent.last_bump_pos 
	}

# Resets the state (Rewind Logic)
func reset_state() -> GraphCommand:
	var batch = CmdBatch.new(graph, "Reset Simulation")
	
	# 1. Snapshot Current State
	var pre_reset_states = {}
	for agent in graph.agents:
		pre_reset_states[agent.id] = _snapshot_agent(agent)

	# 2. Reset Internal Sim State
	tick_count = 0
	
	# 3. Apply Reset & Record Differences
	for agent in graph.agents:
		var start_state = pre_reset_states[agent.id]
		
		# --- APPLY RESET LOGIC ---
		agent.reset_state() 
		
		var target_pos = agent.pos 
		var target_node = ""
		
		if agent.start_node_id != "" and graph.nodes.has(agent.start_node_id):
			target_node = agent.start_node_id
			target_pos = graph.get_node_pos(target_node)
			
		agent.warp(target_pos, target_node)
		
		if target_node != "":
			agent.history.append({ "node": target_node, "step": 0 })
			
		# --- END RESET LOGIC ---

		# 4. Snapshot New State & Create Command
		var end_state = _snapshot_agent(agent)
		
		if start_state.hash() != end_state.hash():
			var cmd = CmdUpdateAgent.new(graph, agent, start_state, end_state)
			batch.add_command(cmd)
	
	SignalManager.simulation_reset.emit()
			
	if batch.get_command_count() > 0:
		return batch
		
	return null
