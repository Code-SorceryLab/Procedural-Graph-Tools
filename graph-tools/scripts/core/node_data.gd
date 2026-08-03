# NodeData.gd
extends Resource
class_name NodeData


enum RoomShape {
	AUTO,       # Let the generator decide based on connections
	CLOSED,     # 0 connections (Solid/Secret)
	DEAD_END,   # 1 connection
	CORRIDOR,   # 2 connections (Straight/Corner)
	THREE_WAY,  # 3 connections
	FOUR_WAY    # 4 connections (Open/Empty)
}

# --- STRUCTURAL DATA (Hard Requirements) ---
@export var position: Vector2 = Vector2.ZERO

# --- VISUAL / CORE DATA (First-Class Citizens) ---
# We keep these as strict variables because the Renderer/Generator uses them constantly.
var type: String = "empty"
@export var shape: RoomShape = RoomShape.AUTO

# Hardcoded Physics Variable
# The base repulsion strength of this specific node (Higher = pushes others away harder)
var physics_repulsion: float = 100.0

# --- SEMANTIC DATA (The "Database") ---
# Stores anything else: "depth", "temperature", "is_locked", "loot_table_id", etc.
@export var custom_data: Dictionary = {}

# --- INITIALIZATION ---
func _init(pos: Vector2 = Vector2.ZERO) -> void:
	position = pos

# --- HELPER API (Quality of Life) ---

# Safely gets a value from custom_data with a default fallback
func get_data(key: String, default: Variant = null) -> Variant:
	return custom_data.get(key, default)

# Sets a value (fluent interface style)
func set_data(key: String, value: Variant) -> void:
	custom_data[key] = value

# Checks for a specific "Tag" (boolean flag)
# Usage: if node.has_tag("magma"): ...
func has_tag(tag: String) -> bool:
	return custom_data.get(tag, false) == true

# Sets a boolean tag
func set_tag(tag: String, enabled: bool = true) -> void:
	custom_data[tag] = enabled

# --- SERIALIZATION HELPER ---
# (Optional) If you want to use the Factory pattern later, this is ready.
# Currently, GraphSerializer handles nodes manually, which is fine for now.
func serialize() -> Dictionary:
	return {
		"x": position.x,
		"y": position.y,
		"type": type,
		"shape": shape,
		"physics_repulsion": physics_repulsion,
		"custom_data": custom_data
	}
