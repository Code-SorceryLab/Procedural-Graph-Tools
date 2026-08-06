class_name RealizerController
extends Node

@export_group("Core References")
@export var graph_editor: GraphEditor
@export var tile_map_layer: TileMapLayer
@export var ui_container: VBoxContainer

@export_group("Tile Mapping (Visuals)")
@export var floor_source_id: int = 0

var _realizer: GraphRealizer
var _active_inputs: Dictionary = {}
var _params: Dictionary = {}

# Stores the visual mapping results
var _atlas_mappings: Dictionary = {
	"default_floor": Vector2i(0, 0),
	"default_wall": Vector2i(1, 0)
}
var _mapping_popup: TileMappingPopup
var _shape_popup: AlgorithmSettingsPopup

func _ready() -> void:
	_build_ui()
	
	# Instantiate the popup in memory
	_mapping_popup = TileMappingPopup.new()
	add_child(_mapping_popup)
	_mapping_popup.confirmed.connect(_on_mapping_confirmed)
	
	# Setup the Shape Ratios Popup
	_shape_popup = AlgorithmSettingsPopup.new()
	add_child(_shape_popup)
	_shape_popup.settings_confirmed.connect(_on_shape_settings_confirmed)
	
	# Load saved mappings from disk on startup
	var saved_mappings = ConfigManager.load_rasterizer_mappings()
	if not saved_mappings.is_empty():
		# Merge overrides defaults with saved values, while keeping defaults 
		# intact if they were missing from the file!
		_atlas_mappings.merge(saved_mappings, true)




# ==============================================================================
# UI GENERATION
# ==============================================================================
func _build_ui() -> void:
	if not ui_container: return
		
	var schema = [
		{ "name": "btn_rasterize", "label": "Rasterize Graph", "type": TYPE_NIL, "hint": "action" },
		{ "name": "btn_clear", "label": "Clear TileMap", "type": TYPE_NIL, "hint": "action" },
		{ "name": "sep_1", "type": TYPE_NIL, "hint": "separator" },
		
		# [NEW] The single entry point for visual mapping
		{ "name": "btn_open_mapper", "label": "Open Visual Tile Mapper", "type": TYPE_NIL, "hint": "action" },
		{ "name": "sep_mapper", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "realizer_seed", "label": "Generator Seed", "type": TYPE_STRING, "default": "research_01", 
		  "hint_text": "Determines the random sizing of rooms. The same seed produces identical room sizes for a given graph topology." },
		{ "name": "grid_scale", "label": "Grid Scale", "type": TYPE_FLOAT, "default": 50.0, "step": 1.0, "min": 10.0, "max": 200.0, 
		  "hint_text": "How many abstract graph pixels map to 1 physical TileMap cell. (e.g. 50 Graph Units = 1 Tile)" },
		{ "name": "padding", "label": "Map Padding", "type": TYPE_INT, "default": 5, "min": 0, "max": 20, 
		  "hint_text": "Extra tiles added around the outermost boundaries of the map to prevent rooms on the edges from being clipped." },
		{ "name": "sep_2", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "btn_shape_ratios", "label": "Configure Shape Ratios...", "type": TYPE_NIL, "hint": "button" },
		{ "name": "room_radius_min", "label": "Min Room Radius", "type": TYPE_INT, "default": 2, "min": 1, "max": 20, 
		  "hint_text": "Minimum size of a room. A radius of 2 generates a 5x5 tile footprint." },
		{ "name": "room_radius_max", "label": "Max Room Radius", "type": TYPE_INT, "default": 4, "min": 1, "max": 20, 
		  "hint_text": "Maximum size of a room. A radius of 4 generates a 9x9 tile footprint." },
		{ "name": "sep_3", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "allow_diagonal_corridors", "label": "Diagonal Corridors", "type": TYPE_BOOL, "default": false, 
		  "hint_text": "If true, the A* pathfinder can carve diagonal hallways, making paths look less rigid and blocky." },
		{ "name": "corridor_radius", "label": "Corridor Thickness", "type": TYPE_INT, "default": 0, "min": 0, "max": 5, 
		  "hint_text": "Thickness of connecting hallways. 0 = 1 tile wide, 1 = 3 tiles wide, 2 = 5 tiles wide." },
		{ "name": "debug_routing", "label": "Show Critical Path", "type": TYPE_BOOL, "default": false,
		  "hint_text": "Draws the raw corridor pathways directly over the room interiors. Useful for debugging topological connections." },
		{ "name": "sep_4", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "ca_iterations", "label": "CA Smoothing Passes", "type": TYPE_INT, "default": 0, "min": 0, "max": 10, 
		  "hint_text": "Runs a Cellular Automata simulation on the grid to melt rigid squares into organic caves. (0 = Disabled)" },
		{ "name": "ca_survive_min", "label": "CA Survive Min", "type": TYPE_INT, "default": 4, "min": 0, "max": 8, 
		  "hint_text": "Floor tiles with fewer than this many floor neighbors will erode into walls." },
		{ "name": "ca_birth_min", "label": "CA Birth Min", "type": TYPE_INT, "default": 5, "min": 0, "max": 8, 
		  "hint_text": "Wall tiles with this many floor neighbors will turn into floor tiles." }
	]
	
	for item in schema:
		if item.has("default"): _params[item["name"]] = item["default"]
			
	# Inject the hidden shape ratio defaults directly!
	_params["ratio_square"] = 1
	_params["ratio_circle"] = 0
	_params["ratio_triangle"] = 0
			
	var section = SettingsUIBuilder.create_collapsible_section(ui_container, "TileMap Realizer", true)
	_active_inputs = SettingsUIBuilder.render_dynamic_section(section, schema, _on_ui_interaction)

func _on_ui_interaction(key: String, value: Variant) -> void:
	if key == "btn_rasterize":
		_on_rasterize_pressed()
	elif key == "btn_clear":
		_on_clear_pressed()
	elif key == "btn_open_mapper":
		if tile_map_layer and tile_map_layer.tile_set:
			_mapping_popup.open(tile_map_layer.tile_set, _atlas_mappings)
		else:
			push_warning("Cannot open Tile Mapper: No TileSet assigned to the TileMapLayer.")
	elif key == "btn_shape_ratios":
		# Explicitly type the array as Array[Dictionary]
		var shape_schema: Array[Dictionary] = [
			{ "name": "ratio_square", "label": "Square Weight", "type": TYPE_INT, "default": 1, "min": 0 },
			{ "name": "ratio_circle", "label": "Circle Weight", "type": TYPE_INT, "default": 0, "min": 0 },
			{ "name": "ratio_triangle", "label": "Triangle Weight", "type": TYPE_INT, "default": 0, "min": 0 }
		]
		_shape_popup.open_settings("Room Shape Distribution", shape_schema, _params)
	else:
		_params[key] = value

func _on_mapping_confirmed() -> void:
	# Save the data from the popup back into the controller when the user hits 'OK'
	_atlas_mappings = _mapping_popup.mappings.duplicate()
	
	# Persist the new mappings to disk instantly
	ConfigManager.save_rasterizer_mappings(_atlas_mappings)

func _on_shape_settings_confirmed(new_settings: Dictionary) -> void:
	# Merge the popup's output directly into the Realizer's parameters
	_params.merge(new_settings, true)

# ==============================================================================
# PIPELINE EXECUTION
# ==============================================================================
func _on_rasterize_pressed() -> void:
	if not graph_editor or not "graph" in graph_editor: return
	var graph = graph_editor.graph
	if graph == null or graph.nodes.is_empty(): return
	if not tile_map_layer: return

	_realizer = GraphRealizer.new()
	var grid = _realizer.realize(graph, _params)
	
	# 1. Grab base defaults
	var def_floor_atlas = _atlas_mappings.get("default_floor", Vector2i(0,0))
	var def_wall_atlas = _atlas_mappings.get("default_wall", Vector2i(1,0))
	
	# 2. Base mapping dict
	var mapping = {
		_realizer.floor_id: { "source_id": floor_source_id, "atlas_coords": def_floor_atlas },
		_realizer.wall_id: { "source_id": floor_source_id, "atlas_coords": def_wall_atlas }
	}
	
	# Helper function to auto-detect terrain data from an atlas coordinate
	var get_mapping_data = func(atlas_coord: Vector2i) -> Dictionary:
		var source = tile_map_layer.tile_set.get_source(floor_source_id)
		if source is TileSetAtlasSource:
			# Get the Godot TileData resource for the clicked tile
			var tile_data = source.get_tile_data(atlas_coord, 0)
			# If the terrain_set is valid (>= 0), the user set up Autotiling for this tile!
			if tile_data and tile_data.terrain_set >= 0:
				return { 
					"is_terrain": true, 
					"terrain_set": tile_data.terrain_set, 
					"terrain": tile_data.terrain 
				}
		# Fallback to standard static tile
		return { "is_terrain": false, "source_id": floor_source_id, "atlas_coords": atlas_coord }

	# 3. Inject Semantic Types & Auto-Detect Terrains
	# Update the default floor/wall with terrain detection
	mapping[_realizer.floor_id] = get_mapping_data.call(def_floor_atlas)
	mapping[_realizer.wall_id] = get_mapping_data.call(def_wall_atlas)
	
	for cat_key in _realizer.semantic_floor_ids:
		var s_floor_id = _realizer.semantic_floor_ids[cat_key]
		var s_wall_id = _realizer.semantic_wall_map[s_floor_id]
		
		var custom_floor = _atlas_mappings.get(cat_key + "_floor", def_floor_atlas)
		var custom_wall = _atlas_mappings.get(cat_key + "_wall", def_wall_atlas)
		
		# Auto-detect terrain status for both semantic floors and walls
		mapping[s_floor_id] = get_mapping_data.call(custom_floor)
		mapping[s_wall_id] = get_mapping_data.call(custom_wall)
		
	# 4. Paint to Screen
	TileMapAdapter.apply_to_layer(grid, tile_map_layer, mapping)
	
	# Auto-Alignment Engine
	if tile_map_layer.tile_set:
		var cell_size = float(tile_map_layer.tile_set.tile_size.x)
		var visual_scale = _params["grid_scale"] / cell_size
		tile_map_layer.scale = Vector2(visual_scale, visual_scale)
		
		var offset_x = _realizer._world_offset.x - (_params["padding"] * _params["grid_scale"])
		var offset_y = _realizer._world_offset.y - (_params["padding"] * _params["grid_scale"])
		tile_map_layer.position = Vector2(offset_x, offset_y)

func _on_clear_pressed() -> void:
	if tile_map_layer:
		tile_map_layer.clear()
