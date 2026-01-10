class_name CmdUpdateAgent
extends GraphCommand

var _agent_id: int
var _agent_ref # [FIX] Relaxed type
var _before_state: Dictionary
var _after_state: Dictionary

func _init(graph: Graph, agent, before: Dictionary, after: Dictionary) -> void:
	_graph = graph
	_agent_ref = agent
	_agent_id = agent.id
	_before_state = before
	_after_state = after

func execute() -> void:
	_apply_state(_after_state)

func undo() -> void:
	_apply_state(_before_state)

func _apply_state(state: Dictionary) -> void:
	# Check if agent is valid
	if not _agent_ref: return
	
	# [FIX] Match AgentWalker variable names
	if state.has("pos"): _agent_ref.pos = state["pos"]
	if state.has("node_id"): _agent_ref.current_node_id = state["node_id"]
	if state.has("step_count"): _agent_ref.step_count = state["step_count"]
	if state.has("history"): _agent_ref.history = state["history"].duplicate()
	if state.has("active"): _agent_ref.active = state["active"]

func get_name() -> String:
	return "Update Agent State"
