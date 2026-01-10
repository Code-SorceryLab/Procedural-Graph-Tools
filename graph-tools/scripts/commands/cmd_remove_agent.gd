class_name CmdRemoveAgent
extends GraphCommand

var _agent : AgentWalker

func _init(graph: Graph, agent: AgentWalker) -> void:
	_graph = graph
	_agent = agent

func execute() -> void:
	_graph.remove_agent(_agent)

func undo() -> void:
	_graph.add_agent(_agent)

func get_name() -> String:
	return "Remove Agent"
