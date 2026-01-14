class_name CmdAddZone
extends GraphCommand

var _zone: GraphZone

func _init(graph: Graph, zone: GraphZone) -> void:
	_graph = graph
	_zone = zone

func execute() -> void:
	if not _graph.zones.has(_zone):
		_graph.add_zone(_zone)

func undo() -> void:
	if _graph.zones.has(_zone):
		_graph.zones.erase(_zone)
