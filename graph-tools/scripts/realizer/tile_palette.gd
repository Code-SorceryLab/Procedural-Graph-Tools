class_name TilePalette
extends RefCounted

const VOID_ID = 0

var _next_id: int = 1
var _definitions: Dictionary = {}
var _name_to_id: Dictionary = {}

func _init() -> void:
	# 0 is strictly reserved as empty space / the void outside the map
	_definitions[VOID_ID] = { "name": "Void", "walkable": false, "transparent": true }
	_name_to_id["Void"] = VOID_ID

# Registers a new tile type and assigns it an integer ID.
# If it already exists, it updates the semantic data.
func register_tile(tile_name: String, semantic_data: Dictionary = {}) -> int:
	if _name_to_id.has(tile_name):
		var id = _name_to_id[tile_name]
		_definitions[id].merge(semantic_data, true)
		return id
		
	var id = _next_id
	_next_id += 1
	
	var final_data = semantic_data.duplicate(true)
	final_data["name"] = tile_name
	
	_definitions[id] = final_data
	_name_to_id[tile_name] = id
	
	return id

# Converts a string name back into its integer for array insertion
func get_id(tile_name: String) -> int:
	return _name_to_id.get(tile_name, VOID_ID)

# Fetches the semantic properties for a specific tile ID
func get_data(id: int) -> Dictionary:
	return _definitions.get(id, _definitions[VOID_ID])

func has_id(id: int) -> bool:
	return _definitions.has(id)
