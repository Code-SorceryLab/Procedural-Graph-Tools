class_name CmdAddAgent
extends GraphCommand

var _agent: AgentWalker # or AgentWalker if circular dependency isn't an issue

func _init(graph: Graph, agent: AgentWalker) -> void:
	_graph = graph
	_agent = agent

func execute() -> void:
	_graph.add_agent(_agent)

func undo() -> void:
	_graph.remove_agent(_agent)

func get_name() -> String:
	return "Add Agent"
