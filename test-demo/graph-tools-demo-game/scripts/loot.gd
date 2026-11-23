class_name Loot
extends Area2D

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		print("Picked up Loot!")
		# (Optional: call a body.add_score(1) function here later)
		queue_free()
