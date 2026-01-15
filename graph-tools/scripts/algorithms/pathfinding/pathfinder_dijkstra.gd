class_name PathfinderDijkstra
extends PathfinderAStar

func _init() -> void:
	# Heuristic Scale 0.0 turns A* into Dijkstra
	super._init(0.0)
