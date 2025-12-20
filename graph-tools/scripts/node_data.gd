# NodeData.gd
extends Resource
class_name NodeData

@export var position: Vector2 = Vector2.ZERO
@export var connections: Dictionary = {} # neighbor_id (String) -> weight (float)

# Constructor
func _init(pos: Vector2 = Vector2.ZERO) -> void:
	position = pos
