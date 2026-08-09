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
	"default_wall": Vector2i(1, 0),
}

# Store dynamic Image settings
var _tileset_image_path: String = ""
var _tileset_tile_size: Vector2i = Vector2i(16, 16)

var _mapping_popup: TileMappingPopup
var _shape_popup: AlgorithmSettingsPopup
var _structure_popup: StructureDesignerPopup
var _interaction_popup: BiomeInteractionPopup

var _custom_structures: Dictionary = {} # Caches the structures for the UI
var _procedural_flags: Dictionary = {}
var _palette_params: Dictionary = {}

# Biome State
var _biome_selector: ConfirmationDialog
var _biome_dropdown: OptionButton
var _current_editing_biome: String = ""
var _biome_params: Dictionary = {}

func _ready() -> void:
	_custom_structures = ConfigManager.load_structures() # Load before building UI!
	_build_ui()
	
	# Instantiate the popup in memory
	_mapping_popup = TileMappingPopup.new()
	add_child(_mapping_popup)
	_mapping_popup.confirmed.connect(_on_mapping_confirmed)
	
	# Setup the Shape Ratios Popup
	_shape_popup = AlgorithmSettingsPopup.new()
	add_child(_shape_popup)
	_shape_popup.settings_confirmed.connect(_on_shape_settings_confirmed)
	
	# Clear the internal state if the user cancels out of the popup!
	_shape_popup.canceled.connect(func(): _current_editing_biome = "")
	
	# Setup the Structure Designer Popup
	_structure_popup = StructureDesignerPopup.new()
	add_child(_structure_popup)
	_structure_popup.confirmed.connect(_on_structure_designer_saved)
	
	# Setup Biome Interaction Popup
	_interaction_popup = BiomeInteractionPopup.new()
	add_child(_interaction_popup)
	_interaction_popup.confirmed.connect(_on_interaction_popup_saved)
	
	# Setup the tiny Biome Selector Dialog
	_biome_selector = ConfirmationDialog.new()
	_biome_selector.title = "Select Biome to Override"
	var vb = VBoxContainer.new()
	var lbl = Label.new()
	lbl.text = "Select Semantic Category:"
	vb.add_child(lbl)
	_biome_dropdown = OptionButton.new()
	vb.add_child(_biome_dropdown)
	_biome_selector.add_child(vb)
	add_child(_biome_selector)
	_biome_selector.confirmed.connect(_on_biome_selected)
	
	# Load the Biomes from disk BEFORE updating the UI!
	_biome_params = ConfigManager.load_biome_overrides()
	
	# Update the button visuals on startup
	_update_biome_button_text()
	
	# Extract the nested dict from ConfigManager
	var saved_data = ConfigManager.load_rasterizer_mappings()
	if saved_data.has("mappings") and not saved_data["mappings"].is_empty():
		_atlas_mappings.merge(saved_data["mappings"], true)
	if saved_data.has("procedural_flags"):
		_procedural_flags.merge(saved_data["procedural_flags"], true)
	if saved_data.has("palette_params"):
		_palette_params.merge(saved_data["palette_params"], true)
	_tileset_image_path = saved_data.get("texture_path", "")
	_tileset_tile_size = saved_data.get("tile_size", Vector2i(16, 16))




# ==============================================================================
# UI GENERATION
# ==============================================================================
func _build_ui() -> void:
	if not ui_container: return
		
	var schema = [
		{ "name": "btn_rasterize", "label": "Rasterize Graph", "type": TYPE_NIL, "hint": "action" },
		{ "name": "btn_clear", "label": "Clear TileMap", "type": TYPE_NIL, "hint": "action" },
		{ "name": "sep_1", "type": TYPE_NIL, "hint": "separator" },
		
		# The single entry point for visual mapping
		{ "name": "btn_open_mapper", "label": "Open Visual Tile Mapper", "type": TYPE_NIL, "hint": "action" },
		{ "name": "btn_open_structure_designer", "label": "Open Structure Designer", "type": TYPE_NIL, "hint": "action" },
		{ "name": "sep_mapper", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "realizer_seed", "label": "Generator Seed", "type": TYPE_STRING, "default": "research_01", 
		  "hint_text": "Determines the random sizing of rooms. The same seed produces identical room sizes for a given graph topology." },
		{ "name": "grid_scale", "label": "Grid Scale", "type": TYPE_FLOAT, "default": 25.0, "step": 1.0, "min": 10.0, "max": 200.0, 
		  "hint_text": "How many abstract graph pixels map to 1 physical TileMap cell. (e.g. 25 Graph Units = 1 Tile)" },
		{ "name": "padding", "label": "Map Padding", "type": TYPE_INT, "default": 15, "min": 0, "max": 20, 
		  "hint_text": "Extra tiles added around the outermost boundaries of the map to prevent rooms on the edges from being clipped." },
		{ "name": "sep_2", "type": TYPE_NIL, "hint": "separator" },
		
		# Master Switch
		{ "name": "btn_shape_ratios", "label": "Global Shape Ratios...", "type": TYPE_NIL, "hint": "button" },
		{ "name": "btn_global_structures", "label": "Global Structure Rules...", "type": TYPE_NIL, "hint": "button" },
		{ "name": "use_biome_overrides", "label": "Use Biome Overrides", "type": TYPE_BOOL, "default": true, 
		  "hint_text": "If disabled, all rooms will use the global rasterization settings regardless of their type." },
		{ "name": "btn_biome_config", "label": "Override Biome Rules...", "type": TYPE_NIL, "hint": "button" },
		{ "name": "btn_biome_interactions", "label": "Biome Edge Matrix...", "type": TYPE_NIL, "hint": "button" },
		
		{ "name": "room_radius_min", "label": "Min Room Radius", "type": TYPE_INT, "default": 2, "min": 1, "max": 20,
		  "hint_text": "Minimum size of a room. A radius of 2 generates a 5x5 tile footprint." },
		{ "name": "room_radius_max", "label": "Max Room Radius", "type": TYPE_INT, "default": 4, "min": 1, "max": 20, 
		  "hint_text": "Maximum size of a room. A radius of 4 generates a 9x9 tile footprint." },
		{ "name": "sep_3", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "allow_diagonal_corridors", "label": "Diagonal Corridors", "type": TYPE_BOOL, "default": false, 
		  "hint_text": "If true, the A* pathfinder can carve diagonal hallways, making paths look less rigid and blocky." },
		{ "name": "corridor_thickness", "label": "Corridor Thickness", "type": TYPE_INT, "default": 1, "min": 1, "max": 10, 
		  "hint_text": "Exact tile width of connecting hallways. 1 = 1 tile wide, 3 = 3 tiles wide." },
		
		# --- EROSION SETTINGS ---
		{ "name": "corridor_erosion", "label": "Corridor Erosion", "type": TYPE_FLOAT, "default": 0.0, "min": 0.0, "max": 0.9, "step": 0.05, 
		  "hint_text": "Degrades the edges of thick corridors using noise to make them look like natural caves. (Does not affect 1-tile paths)." },
		{ "name": "corridor_erosion_scale", "label": "Erosion Chunk Size", "type": TYPE_FLOAT, "default": 0.1, "min": 0.01, "max": 0.5, "step": 0.01, 
		  "hint_text": "Lower values create massive chunks of missing wall, higher values create noisy gravel-like edges." },
		
		{ "name": "debug_routing", "label": "Show Critical Path", "type": TYPE_BOOL, "default": false,
		  "hint_text": "Draws the raw corridor pathways directly over the room interiors. Useful for debugging topological connections." },
		{ "name": "sep_4", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "ca_iterations", "label": "CA Smoothing Passes", "type": TYPE_INT, "default": 0, "min": 0, "max": 10, 
		  "hint_text": "Runs a Cellular Automata simulation on the grid to melt rigid squares into organic caves. (0 = Disabled)" },
		{ "name": "ca_survive_min", "label": "CA Survive Min", "type": TYPE_INT, "default": 4, "min": 0, "max": 8, 
		  "hint_text": "Floor tiles with fewer than this many floor neighbors will erode into walls." },
		{ "name": "ca_birth_min", "label": "CA Birth Min", "type": TYPE_INT, "default": 5, "min": 0, "max": 8, 
		  "hint_text": "Wall tiles with this many floor neighbors will turn into floor tiles." },
		
		# --- SCATTER SETTING ---
		{ "name": "sep_scatter", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "scatter_density", "label": "Entity Scatter Density", "type": TYPE_FLOAT, "default": 0.05, "min": 0.0, "max": 0.5, "step": 0.01, 
		  "hint_text": "Chance to spawn an entity on any valid non-critical floor tile." },
		{ "name": "scatter_min_dist", "label": "Scatter Min Wall Dist", "type": TYPE_INT, "default": 0, "min": 0, "max": 20, 
		  "hint_text": "0 = Can spawn against walls. Higher values push entities to the center of rooms." },
		{ "name": "scatter_max_dist", "label": "Scatter Max Wall Dist", "type": TYPE_INT, "default": 99, "min": 1, "max": 99, 
		  "hint_text": "99 = No max limit. 1 = Forces entities to strictly hug walls." },
		{ "name": "show_entities", "label": "Show Scattered Entities", "type": TYPE_BOOL, "default": true, 
		  "hint_text": "Draws gold markers over the map to visualize where entities have been scattered." }
	]
	
	for item in schema:
		if item.has("default"): _params[item["name"]] = item["default"]
			
	# Inject the hidden shape ratio defaults directly!
	_params["ratio_square"] = 1
	_params["ratio_circle"] = 0
	_params["ratio_triangle"] = 0
	
	# Inject the hidden global structure defaults!
	_params["spawn_structure"] = false
	
	# Dynamically register all custom structures to 0 weight by default
	for key in _custom_structures:
		_params["weight_" + key] = 0
			
	var section = SettingsUIBuilder.create_collapsible_section(ui_container, "TileMap Realizer", true)
	_active_inputs = SettingsUIBuilder.render_dynamic_section(section, schema, _on_ui_interaction)

func _on_ui_interaction(key: String, value: Variant) -> void:
	if key == "btn_rasterize":
		_on_rasterize_pressed()
	elif key == "btn_clear":
		_on_clear_pressed()
	elif key == "btn_open_mapper":
		_mapping_popup.open(_tileset_image_path, _tileset_tile_size, _atlas_mappings, _procedural_flags, _palette_params)
	
	elif key == "btn_open_structure_designer":
		_structure_popup.open()
	
	elif key == "btn_shape_ratios":
		_current_editing_biome = "" # Explicitly tell the system we are editing GLOBAL rules
		
		var shape_schema: Array[Dictionary] = [
			{ "name": "ratio_square", "label": "Square Weight", "type": TYPE_INT, "default": _params.get("ratio_square", 1), "min": 0 },
			{ "name": "ratio_circle", "label": "Circle Weight", "type": TYPE_INT, "default": _params.get("ratio_circle", 0), "min": 0 },
			{ "name": "ratio_triangle", "label": "Triangle Weight", "type": TYPE_INT, "default": _params.get("ratio_triangle", 0), "min": 0 }
		]
		_shape_popup.open_settings("Global Shape Distribution", shape_schema, _params)
		
	# --- GLOBAL STRUCTURE INTERCEPT ---
	elif key == "btn_global_structures":
		_current_editing_biome = "" # Explicitly edit GLOBAL rules
		
		var struct_schema: Array[Dictionary] = [
			{ "name": "spawn_structure", "label": "Spawn Central Structure", "type": TYPE_BOOL, "default": _params.get("spawn_structure", false), 
			  "hint_text": "Attempts to find a safe footprint in this room to spawn one of your custom blueprints." }
		]
		
		# Dynamically build sliders for every saved structure!
		if _custom_structures.size() > 0:
			struct_schema.append({ "name": "sep_str_weights", "type": TYPE_NIL, "hint": "separator" })
			for structure_key in _custom_structures:
				var s_name = _custom_structures[structure_key].get("name", "Unnamed")
				struct_schema.append({
					"name": "weight_" + structure_key,
					"label": s_name + " Weight",
					"type": TYPE_INT,
					"default": _params.get("weight_" + structure_key, 0),
					"min": 0,
					"max": 100
				})
				
		_shape_popup.open_settings("Global Structure Rules", struct_schema, _params)
	
	elif key == "btn_biome_interactions":
		_interaction_popup.open()
	
	elif key == "btn_biome_config":
		_biome_dropdown.clear()
		
		# Fetch the raw category dictionary so we have access to the colors!
		var node_cats = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE]
		var keys = []
		
		for cat_key in node_cats:
			keys.append(cat_key)
			var cat = node_cats[cat_key]
			var display_name = cat["name"]
			
			# 1. Visual Feedback for Active States
			if _biome_params.has(cat_key) and _biome_params[cat_key].get("override_enabled", false):
				display_name += "  [ ACTIVE ]"
				
			# 2. Dynamic Color Icon
			var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
			img.fill(cat["color"])
			
			# Add a subtle dark border around the color square so light colors (like empty) don't vanish into the UI
			var border_color = cat["color"].darkened(0.5)
			for x in range(16):
				img.set_pixel(x, 0, border_color)
				img.set_pixel(x, 15, border_color)
			for y in range(16):
				img.set_pixel(0, y, border_color)
				img.set_pixel(15, y, border_color)
				
			var tex = ImageTexture.create_from_image(img)
			
			# Add it to the dropdown with the newly generated icon!
			_biome_dropdown.add_icon_item(tex, display_name)
			
		_biome_dropdown.set_meta("keys", keys)
		_biome_selector.popup_centered(Vector2(320, 100)) # Made slightly wider to fit the [ACTIVE] text
	
	# --- INSTANT VISIBILITY TOGGLES ---
	elif key == "show_entities":
		_params[key] = value
		if tile_map_layer:
			for child in tile_map_layer.get_children():
				if child.is_in_group("realizer_entity"):
					child.visible = value
					
	elif key == "debug_routing":
		_params[key] = value
		if tile_map_layer:
			for child in tile_map_layer.get_children():
				if child.is_in_group("realizer_critical_path"):
					child.visible = value
	# ---------------------------------------
	
	else:
		_params[key] = value


func _on_mapping_confirmed() -> void:
	_atlas_mappings = _mapping_popup.mappings.duplicate()
	_procedural_flags = _mapping_popup.procedural_flags.duplicate()
	_palette_params = _mapping_popup.palette_editor.params.duplicate()
	_tileset_image_path = _mapping_popup.atlas_texture_path
	_tileset_tile_size = _mapping_popup.tile_size
	
	ConfigManager.save_rasterizer_mappings(_atlas_mappings, _tileset_image_path, _tileset_tile_size, _procedural_flags, _palette_params)

func _on_shape_settings_confirmed(new_settings: Dictionary) -> void:
	if _current_editing_biome != "":
		# We were editing a specific Biome! Save it to the internal dictionary
		_biome_params[_current_editing_biome] = new_settings
		_current_editing_biome = "" # Reset state
		_update_biome_button_text() # Update the sidebar UI instantly!
		
		# Save to disk immediately!
		ConfigManager.save_biome_overrides(_biome_params)
	else:
		# We were editing Global Settings!
		_params.merge(new_settings, true)
		
		# [OPTIONAL ENHANCEMENT] If you want Global shapes to persist, 
		# we will need a save function for _params later!

func _on_structure_designer_saved() -> void:
	# Save the structures to disk when the user clicks 'OK' on the popup
	ConfigManager.save_structures(_structure_popup.structures)
	
	# Refresh the cache and inject any brand-new structures into the global defaults!
	_custom_structures = _structure_popup.structures.duplicate()
	for key in _custom_structures:
		var weight_key = "weight_" + key
		if not _params.has(weight_key):
			_params[weight_key] = 0

func _on_interaction_popup_saved() -> void:
	ConfigManager.save_biome_interactions(_interaction_popup.interactions)

func _on_biome_selected() -> void:
	var idx = _biome_dropdown.selected
	if idx < 0: return
	var keys = _biome_dropdown.get_meta("keys")
	_current_editing_biome = keys[idx]
	var biome_name = _biome_dropdown.get_item_text(idx)
	
	# Fetch existing overrides, pulling from Global defaults as a baseline
	var current_vals = _biome_params.get(_current_editing_biome, {
		"override_enabled": false,
		"room_radius_min": _params.get("room_radius_min", 2),
		"room_radius_max": _params.get("room_radius_max", 4),
		"ratio_square": _params.get("ratio_square", 1),
		"ratio_circle": _params.get("ratio_circle", 0),
		"ratio_triangle": _params.get("ratio_triangle", 0),
		"ca_iterations": _params.get("ca_iterations", 0),
		"ca_survive_min": _params.get("ca_survive_min", 4),
		"ca_birth_min": _params.get("ca_birth_min", 5),
		"allow_diagonal_corridors": _params.get("allow_diagonal_corridors", false),
		"corridor_thickness": _params.get("corridor_thickness", 1),
		"corridor_erosion": _params.get("corridor_erosion", 0.0),
		"corridor_erosion_scale": _params.get("corridor_erosion_scale", 0.1),
		"scatter_density": _params.get("scatter_density", 0.05),
		"scatter_min_dist": _params.get("scatter_min_dist", 0),
		"scatter_max_dist": _params.get("scatter_max_dist", 99),
		"spawn_structure": _params.get("spawn_structure", false)
	})
	
	# Dynamically pull existing biome weights, or fallback to global defaults
	for key in _custom_structures:
		var p_name = "weight_" + key
		if not current_vals.has(p_name):
			current_vals[p_name] = _params.get(p_name, 0)
	
	# Build a superset schema controlling sizes, shapes, corridors, AND cellular smoothing!
	var schema: Array[Dictionary] = [
		{ "name": "override_enabled", "label": "Enable Biome Overrides", "type": TYPE_BOOL, "default": false },
		{ "name": "sep_1", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "room_radius_min", "label": "Min Radius", "type": TYPE_INT, "default": 2, "min": 1 },
		{ "name": "room_radius_max", "label": "Max Radius", "type": TYPE_INT, "default": 4, "min": 1 },
		{ "name": "sep_2", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "ratio_square", "label": "Square Weight", "type": TYPE_INT, "default": 1, "min": 0 },
		{ "name": "ratio_circle", "label": "Circle Weight", "type": TYPE_INT, "default": 0, "min": 0 },
		{ "name": "ratio_triangle", "label": "Triangle Weight", "type": TYPE_INT, "default": 0, "min": 0 },
		# Corridor Settings
		{ "name": "sep_3", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "allow_diagonal_corridors", "label": "Diagonal Corridors", "type": TYPE_BOOL, "default": false },
		{ "name": "corridor_thickness", "label": "Corridor Thickness", "type": TYPE_INT, "default": 1, "min": 1, "max": 10, 
		  "hint_text": "Exact tile width of connecting hallways. 1 = 1 tile wide, 3 = 3 tiles wide." },
		  
		# Erosion Settings
		{ "name": "corridor_erosion", "label": "Corridor Erosion", "type": TYPE_FLOAT, "default": 0.0, "min": 0.0, "max": 0.9, "step": 0.05, 
		  "hint_text": "Degrades the edges of thick corridors using noise to make them look like natural caves. (Does not affect 1-tile paths)." },
		{ "name": "corridor_erosion_scale", "label": "Erosion Chunk Size", "type": TYPE_FLOAT, "default": 0.1, "min": 0.01, "max": 0.5, "step": 0.01, 
		  "hint_text": "Lower values create massive chunks of missing wall, higher values create noisy gravel-like edges." },
		
		# CA Settings
		{ "name": "sep_4", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "ca_iterations", "label": "CA Smoothing Passes", "type": TYPE_INT, "default": 0, "min": 0, "max": 10 },
		{ "name": "ca_survive_min", "label": "CA Survive Min", "type": TYPE_INT, "default": 4, "min": 0, "max": 8 },
		{ "name": "ca_birth_min", "label": "CA Birth Min", "type": TYPE_INT, "default": 5, "min": 0, "max": 8 },
		# Scatter Settings
		{ "name": "sep_5", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "scatter_density", "label": "Scatter Density", "type": TYPE_FLOAT, "default": 0.05, "min": 0.0, "max": 0.5, "step": 0.01 },
		{ "name": "scatter_min_dist", "label": "Min Wall Dist", "type": TYPE_INT, "default": 0, "min": 0, "max": 20 },
		{ "name": "scatter_max_dist", "label": "Max Wall Dist", "type": TYPE_INT, "default": 99, "min": 1, "max": 99 },
		
		# --- WEIGHTED BLUEPRINTS SCHEMA ---
		{ "name": "sep_6", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "spawn_structure", "label": "Spawn Central Structure", "type": TYPE_BOOL, "default": false, 
		  "hint_text": "Attempts to find a safe footprint in this room to spawn one of your custom blueprints." }
	]
	
	# Dynamically build sliders for every saved structure!
	if _custom_structures.size() > 0:
		schema.append({ "name": "sep_7", "type": TYPE_NIL, "hint": "separator" })
		for key in _custom_structures:
			var s_name = _custom_structures[key].get("name", "Unnamed")
			schema.append({
				"name": "weight_" + key,
				"label": s_name + " Weight",
				"type": TYPE_INT,
				"default": 0,
				"min": 0,
				"max": 100
			})
	
	_shape_popup.open_settings(biome_name + " Rules", schema, current_vals)



# ==============================================================================
# PIPELINE EXECUTION
# ==============================================================================
func _on_rasterize_pressed() -> void:
	if not graph_editor or not "graph" in graph_editor: return
	var graph = graph_editor.graph
	if graph == null or graph.nodes.is_empty(): return
	if not tile_map_layer: return

	# [DEBUG] Check the Master Switch before passing the overrides!
	if _params.get("use_biome_overrides", true):
		_params["biomes"] = _biome_params
	else:
		_params["biomes"] = {} # Force the allocator to ignore biomes
		
	_realizer = GraphRealizer.new()
	var grid = _realizer.realize(graph, _params)
	
	# --- PROGRAMMATIC TILESET GENERATION ---
	var dynamic_tileset = TileSet.new()
	dynamic_tileset.tile_size = _tileset_tile_size
	
	# 1. Calculate Procedural Colors
	var active_proc_keys = []
	for key in _realizer.semantic_floor_ids:
		if _procedural_flags.get(key, false):
			active_proc_keys.append(key)
	active_proc_keys.sort() 
	
	var biome_colors = {}
	var wall_shift = _palette_params.get("wall_shift", 0.1)
	
	for i in range(active_proc_keys.size()):
		var key = active_proc_keys[i]
		var t = float(i) / max(1.0, float(active_proc_keys.size() - 1))
		
		biome_colors[key + "_floor"] = CosinePaletteEditor.get_iq_color(t, _palette_params)
		biome_colors[key + "_wall"] = CosinePaletteEditor.get_iq_color(t + wall_shift, _palette_params)

	# 2. Setup the Mapping Data structures
	var def_floor_atlas = _atlas_mappings.get("default_floor", Vector2i(0,0))
	var def_wall_atlas = _atlas_mappings.get("default_wall", Vector2i(1,0))
	var debug_path_atlas = _atlas_mappings.get("debug_path", Vector2i(2,0)) 
	
	var biome_alt_ids = {} # Stores { cat_key + "_floor": alt_id }
	
	if _tileset_image_path != "" and FileAccess.file_exists(_tileset_image_path):
		var img = Image.load_from_file(_tileset_image_path)
		if img:
			var source = TileSetAtlasSource.new()
			source.texture = ImageTexture.create_from_image(img)
			source.texture_region_size = _tileset_tile_size
			
			# Helper to ensure a base tile exists
			var ensure_base_tile = func(coord: Vector2i):
				if not source.has_tile(coord):
					source.create_tile(coord)
			
			# Ensure defaults and explicit mappings exist as base tiles (alt_id = 0)
			ensure_base_tile.call(def_floor_atlas)
			ensure_base_tile.call(def_wall_atlas)
			ensure_base_tile.call(debug_path_atlas)
			for mapping_key in _atlas_mappings:
				ensure_base_tile.call(_atlas_mappings[mapping_key])
				
			# Generate Alternative Tiles for Procedural Biomes!
			var next_alt_id = {} # Tracks the next available alt_id per coordinate
			
			for cat_key in _realizer.semantic_floor_ids:
				if _procedural_flags.get(cat_key, false):
					var f_coord = _atlas_mappings.get(cat_key + "_floor", def_floor_atlas)
					var w_coord = _atlas_mappings.get(cat_key + "_wall", def_wall_atlas)
					
					# Floor Alt
					var f_alt = next_alt_id.get(f_coord, 1)
					next_alt_id[f_coord] = f_alt + 1
					source.create_alternative_tile(f_coord, f_alt)
					source.get_tile_data(f_coord, f_alt).modulate = biome_colors[cat_key + "_floor"]
					biome_alt_ids[cat_key + "_floor"] = f_alt
					
					# Wall Alt
					var w_alt = next_alt_id.get(w_coord, 1)
					next_alt_id[w_coord] = w_alt + 1
					source.create_alternative_tile(w_coord, w_alt)
					source.get_tile_data(w_coord, w_alt).modulate = biome_colors[cat_key + "_wall"]
					biome_alt_ids[cat_key + "_wall"] = w_alt
					
			dynamic_tileset.add_source(source, floor_source_id)
			
	tile_map_layer.tile_set = dynamic_tileset
	
	# 3. Apply mappings
	# [FIXED] Pass the alternative_tile ID to the mapping dictionary
	var get_mapping_data = func(atlas_coord: Vector2i, alt_id: int = 0) -> Dictionary:
		return { "is_terrain": false, "source_id": floor_source_id, "atlas_coords": atlas_coord, "alternative_tile": alt_id }

	var mapping = {
		_realizer.floor_id: get_mapping_data.call(def_floor_atlas),
		_realizer.wall_id: get_mapping_data.call(def_wall_atlas),
		_realizer.debug_path_id: get_mapping_data.call(debug_path_atlas)
	}
	
	for cat_key in _realizer.semantic_floor_ids:
		var s_floor_id = _realizer.semantic_floor_ids[cat_key]
		var s_wall_id = _realizer.semantic_wall_map[s_floor_id]
		
		var custom_floor = _atlas_mappings.get(cat_key + "_floor", def_floor_atlas)
		var custom_wall = _atlas_mappings.get(cat_key + "_wall", def_wall_atlas)
		
		var floor_alt = biome_alt_ids.get(cat_key + "_floor", 0)
		var wall_alt = biome_alt_ids.get(cat_key + "_wall", 0)
		
		mapping[s_floor_id] = get_mapping_data.call(custom_floor, floor_alt)
		mapping[s_wall_id] = get_mapping_data.call(custom_wall, wall_alt)
		
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
		
	# --- OVERLAY RENDERING (Entities & Debug Paths) ---
	# First, clear all old overlays
	for child in tile_map_layer.get_children():
		if child.is_in_group("realizer_entity") or child.is_in_group("realizer_critical_path"):
			child.queue_free()
			
	if tile_map_layer.tile_set:
		var cell_size = float(tile_map_layer.tile_set.tile_size.x)
		
		# A. Render Critical Path Overlays
		var show_path = _params.get("debug_routing", false)
		for pos in _realizer.critical_path_cells:
			var rect = ColorRect.new()
			rect.color = Color(1.0, 0.0, 1.0, 0.4) # Semi-transparent magenta
			rect.size = Vector2(cell_size, cell_size) # Cover the full tile
			
			var local_x = pos.x * cell_size
			var local_y = pos.y * cell_size
			rect.position = Vector2(local_x, local_y)
			
			rect.visible = show_path
			rect.add_to_group("realizer_critical_path")
			tile_map_layer.add_child(rect)

		# B. Render Entity Overlays
		var show_entities = _params.get("show_entities", true)
		for pos in grid.entities:
			var entity_data = grid.entities[pos]
			var e_type = entity_data.get("type", "generic_entity")
			
			var rect = ColorRect.new()
			
			if e_type == "structure":
				# --- CUSTOM STRUCTURE FOOTPRINT ---
				var struct_color = entity_data.get("color", Color(0.2, 0.6, 1.0, 0.7))
				var footprint_world = entity_data.get("footprint_world", [])
				
				for pt in footprint_world:
					var pt_rect = ColorRect.new()
					pt_rect.color = struct_color
					pt_rect.size = Vector2(cell_size, cell_size)
					pt_rect.position = Vector2(pt.x * cell_size, pt.y * cell_size)
					pt_rect.visible = show_entities
					pt_rect.add_to_group("realizer_entity")
					tile_map_layer.add_child(pt_rect)
				continue # Skip the base rect addition below
				
			elif e_type == "door":
				# --- [NEW] DOOR / PORTAL ---
				rect.color = Color(0.8, 0.5, 0.2, 0.9) # Distinct Orange-Brown
				rect.size = Vector2(cell_size, cell_size) # Fills the whole tile
				rect.position = Vector2(pos.x * cell_size, pos.y * cell_size)
				
			elif e_type == "fringe":
				# --- [NEW] BOUNDARY FRINGE ---
				rect.color = Color(0.2, 0.9, 0.2, 0.8) # Bright Green Decor
				rect.size = Vector2(cell_size * 0.4, cell_size * 0.4) 
				rect.position = Vector2(pos.x * cell_size + (cell_size * 0.3), pos.y * cell_size + (cell_size * 0.3))
				
			else:
				# --- STANDARD 1x1 SCATTER ---
				rect.color = Color(1.0, 0.8, 0.0, 0.8) # Solid Gold
				rect.size = Vector2(cell_size * 0.5, cell_size * 0.5) 
				rect.position = Vector2(pos.x * cell_size + (cell_size * 0.25), pos.y * cell_size + (cell_size * 0.25))
			
			rect.visible = show_entities
			rect.add_to_group("realizer_entity")
			tile_map_layer.add_child(rect)

func _on_clear_pressed() -> void:
	if tile_map_layer:
		tile_map_layer.clear()
		for child in tile_map_layer.get_children():
			if child.is_in_group("realizer_entity") or child.is_in_group("realizer_critical_path"):
				child.queue_free()

# ==============================================================================
# VISUAL FEEDBACK HELPER
# ==============================================================================
func _update_biome_button_text() -> void:
	if not _active_inputs.has("btn_biome_config"): return
	
	var active_count = 0
	for b_key in _biome_params:
		if _biome_params[b_key].get("override_enabled", false):
			active_count += 1
			
	var btn = _active_inputs["btn_biome_config"] as Button
	if active_count > 0:
		btn.text = "Override Biome Rules (%d Active)..." % active_count
		btn.modulate = Color(0.6, 1.0, 0.6) # Tint green to show it's active!
	else:
		btn.text = "Override Biome Rules..."
		btn.modulate = Color.WHITE
