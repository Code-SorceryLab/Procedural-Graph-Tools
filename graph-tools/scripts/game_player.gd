extends Node
class_name GamePlayer

# The "GamePlayer" is now a clean composition root.
# It doesn't contain logic. It just holds the Controllers and UI layout.

# If you need global coordination later (e.g., "Reset Everything"),
# you can add it here. Otherwise, it stays clean!

func _ready() -> void:
	print("GamePlayer: All systems initialized.")
