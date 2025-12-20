# NodeData.gd
extends Resource
class_name NodeData

# --- ENUMS ---
enum RoomType {
	EMPTY,      # Standard room
	SPAWN,      # The starting point
	ENEMY,      # Contains combat
	TREASURE,   # Contains loot
	BOSS,       # The goal
	SHOP        # Optional utility
}

enum RoomShape {
	AUTO,       # Let the generator decide based on connections
	CLOSED,     # 0 connections (Solid/Secret)
	DEAD_END,   # 1 connection
	CORRIDOR,   # 2 connections (Straight/Corner)
	THREE_WAY,  # 3 connections
	FOUR_WAY    # 4 connections (Open/Empty)
}

# --- DATA ---
@export var position: Vector2 = Vector2.ZERO
@export var connections: Dictionary = {}

# Semantic Data
@export var type: RoomType = RoomType.EMPTY
@export var shape: RoomShape = RoomShape.AUTO
@export var depth: int = 0  # Steps away from Spawn

func _init(pos: Vector2 = Vector2.ZERO) -> void:
	position = pos
