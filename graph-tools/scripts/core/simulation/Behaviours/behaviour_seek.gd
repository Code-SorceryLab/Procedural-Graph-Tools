class_name BehaviorSeek
extends AgentBehavior

var _navigator_algo: int = AgentNavigator.Algo.ASTAR

func _init(algo: int = AgentNavigator.Algo.ASTAR) -> void:
	_navigator_algo = algo

func step(agent, graph, _context = {}):
	
	# 1. Check Goal
	if agent.current_node_id == agent.target_node_id:
		return # We arrived. Do nothing.
		
	# 2. Ask the Utility (Navigator) for the path
	# Note: We use the Agent's variables (target_node_id) as inputs
	var next_node = AgentNavigator.get_next_step(
		agent.current_node_id, 
		agent.target_node_id, 
		_navigator_algo, 
		graph
	)
	
	# 3. Command the Body
	if next_node != "":
		agent.move_to_node(next_node, graph)
