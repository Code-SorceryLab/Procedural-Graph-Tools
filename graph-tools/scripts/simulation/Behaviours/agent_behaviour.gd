class_name AgentBehavior
extends RefCounted

func enter(_agent: AgentWalker, _graph: Graph) -> void:
	pass

func exit(_agent: AgentWalker, _graph: Graph) -> void:
	pass

# [UPDATED] Added 'context' for passing grid settings/sim params
func step(_agent: AgentWalker, _graph: Graph, _context: Dictionary = {}) -> void:
	push_warning("AgentBehavior: step() not implemented.")
