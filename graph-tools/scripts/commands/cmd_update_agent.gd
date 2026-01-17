class_name CmdUpdateAgent
extends GraphCommand

var _agent_id: int
var _agent_ref
var _before_state: Dictionary
var _after_state: Dictionary

func _init(graph: Graph, agent, before: Dictionary, after: Dictionary) -> void:
	_graph = graph
	_agent_ref = agent
	
	# [FIX] Use display_id (matches the 'int' type definition)
	_agent_id = agent.display_id if "display_id" in agent else -1
	
	_before_state = before
	_after_state = after

func execute() -> void:
	_apply_state(_after_state)

func undo() -> void:
	_apply_state(_before_state)

func _apply_state(state: Dictionary) -> void:
	# Check if agent is valid
	# (Optional: You could check is_instance_valid(_agent_ref) for extra safety)
	if not _agent_ref: return
	
	# Match AgentWalker variable names
	if state.has("pos"): _agent_ref.pos = state["pos"]
	if state.has("node_id"): _agent_ref.current_node_id = state["node_id"]
	if state.has("step_count"): _agent_ref.step_count = state["step_count"]
	if state.has("history"): _agent_ref.history = state["history"].duplicate()
	if state.has("active"): _agent_ref.active = state["active"]
	
	# [FIX] Apply the new state variables we added to Simulation.gd
	if state.has("is_finished"): _agent_ref.is_finished = state["is_finished"]
	if state.has("last_bump_pos"): _agent_ref.last_bump_pos = state["last_bump_pos"]

func get_name() -> String:
	return "Update Agent #%d State" % _agent_id
