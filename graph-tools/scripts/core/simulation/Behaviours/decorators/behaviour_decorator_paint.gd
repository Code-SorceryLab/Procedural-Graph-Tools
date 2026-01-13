class_name BehaviorDecoratorPaint
extends BehaviorDecorator

func step(agent: AgentWalker, graph, context: Dictionary = {}) -> void:
	# 1. Execute the movement logic first (Wander, Seek, etc.)
	super.step(agent, graph, context)
	
	# 2. Paint the ground wherever we ended up
	if agent.current_node_id != "":
		agent.paint_current_node(graph)
