class_name DungeonDoor
extends StaticBody2D

var lock_type: String = "Red"

func setup(p_type: String, p_color: Color, tile_size: int) -> void:
	lock_type = p_type
	modulate = p_color
	
	# Fit the door to the exact tile size
	var tex_size = $Sprite2D.texture.get_size()
	#$Sprite2D.scale = Vector2(tile_size, tile_size) / tex_size

func _on_bump_detector_body_entered(body: Node2D) -> void:
	if body is Player:
		if body.can_open_door(lock_type):
			print("Door Unlocked: ", lock_type)
			queue_free() # Destroy the door
		else:
			print("Door is Locked! Requires: ", lock_type)
