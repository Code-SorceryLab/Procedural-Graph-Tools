class_name PushBox
extends CharacterBody2D

var friction: float = 800.0

func _physics_process(delta: float) -> void:
	# Naturally slow down to a stop after being pushed
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()
