class_name EndPoint
extends Area2D

signal player_entered

func _ready() -> void:
	# Connect the built-in body_entered signal
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		print("Player reached the exit!")
		player_entered.emit()
