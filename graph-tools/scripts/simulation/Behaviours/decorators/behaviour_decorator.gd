class_name BehaviorDecorator
extends AgentBehavior

var _inner: AgentBehavior

func _init(inner: AgentBehavior) -> void:
	_inner = inner

func enter(agent: AgentWalker, graph) -> void:
	if _inner: _inner.enter(agent, graph)

func exit(agent: AgentWalker, graph) -> void:
	if _inner: _inner.exit(agent, graph)

# Note: We remove the strict ': Graph' type hint here to allow 
# passing a GraphRecorder (which might not extend Graph but shares the API)
func step(agent: AgentWalker, graph, context: Dictionary = {}) -> void:
	if _inner: 
		_inner.step(agent, graph, context)
