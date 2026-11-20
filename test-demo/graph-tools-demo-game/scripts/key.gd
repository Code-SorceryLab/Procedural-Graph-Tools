class_name DungeonKey
extends Area2D

var key_type: String = "Red"

func setup(p_type: String, p_color: Color, tile_size: int) -> void:
	key_type = p_type
	modulate = p_color
	
	# Scale visual to be a bit smaller than a full tile
	$Sprite2D.scale = Vector2(tile_size * 0.5, tile_size * 0.5) / $Sprite2D.texture.get_size()

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.collect_key(key_type)
		queue_free() # Destroy the key
