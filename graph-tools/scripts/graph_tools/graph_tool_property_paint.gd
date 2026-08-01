class_name GraphToolPropertyPaint
extends GraphTool

# --- STATE ---
var _is_painting: bool = false
var _current_type: String = "enemy"
var _last_painted_id: String = ""

# --- CACHE FOR UI ---
var _available_types: Array = []   # Stores the actual String keys (e.g. ["empty", "spawn", "enemy"])
var _available_names: String = ""  # Stores "Empty,Enemy,Boss,Custom"

# --- LIFECYCLE ---

func enter() -> void:
	# 1. Build the list of types dynamically 
	# (Catches custom types from the Semantic Registry)
	_refresh_type_list()
	
	_print_current_type()
	
	# Show ghost/status immediately
	_show_status("Type Brush: Select type from Top Bar or Right-Click to cycle.")

func exit() -> void:
	_is_painting = false
	_last_painted_id = ""
	_show_status("")

# --- TOOL OPTIONS API ---

func get_options_schema() -> Array:
	# Ensure list is fresh
	if _available_types.is_empty():
		_refresh_type_list()
		
	# Find which Index matches our current Type Key
	var current_ui_index = _available_types.find(_current_type)
	if current_ui_index == -1: 
		current_ui_index = 0

	return [
		{
			"name": "paint_type",
			"label": "Type",
			"type": TYPE_INT,
			"default": current_ui_index, # UI expects the List Index
			"hint": "enum",
			"hint_string": _available_names
		}
	]

func apply_option(param_name: String, value: Variant) -> void:
	if param_name == "paint_type":
		var ui_index = int(value)
		
		# Map the UI Index back to the Real Type Key
		if ui_index >= 0 and ui_index < _available_types.size():
			_current_type = _available_types[ui_index]
			_print_current_type()

# --- INPUT ---

func handle_input(event: InputEvent) -> void:
	# 1. PAINTING (Left Click)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.alt_pressed:
					_pick_type_under_mouse()
				else:
					# --- MOUSE DOWN: START SESSION ---
					_is_painting = true
					_editor.start_undo_transaction("Paint Type", false)
					_paint_under_mouse()
			else:
				# --- MOUSE UP: COMMIT SESSION ---
				if _is_painting:
					_editor.commit_undo_transaction()
					_is_painting = false
					_last_painted_id = ""
		
		# 2. CYCLING TYPES (Right Click)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cycle_type()
			
	# 3. DRAGGING
	elif event is InputEventMouseMotion:
		if _is_painting:
			_paint_under_mouse()
		
		_update_hover(_editor.get_global_mouse_position())

# --- LOGIC ---

func _refresh_type_list() -> void:
	# [UPDATED] Pull keys from SemanticRegistry
	_available_types = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE].keys()
	
	# Note: In Godot 4, dictionaries preserve insertion order. 
	# If you want them strictly alphabetical, you can uncomment the line below.
	# _available_types.sort() 
	
	# Build the comma-separated string for the UI Builder
	var names_arr = []
	for type_key in _available_types:
		names_arr.append(_get_type_name(type_key))
	
	_available_names = ",".join(names_arr)

func _paint_under_mouse() -> void:
	var mouse_pos = _editor.get_global_mouse_position()
	var id = _get_node_at_pos(mouse_pos)
	
	if id != "" and id != _last_painted_id:
		# --- BATCH LOGIC ---
		if _editor.selected_nodes.has(id):
			_editor.set_node_type_bulk(_editor.selected_nodes, _current_type)
		else:
			_editor.set_node_type(id, _current_type)
			
		_last_painted_id = id

func _pick_type_under_mouse() -> void:
	var mouse_pos = _editor.get_global_mouse_position()
	var id = _get_node_at_pos(mouse_pos)
	if id != "":
		var node = _graph.nodes[id]
		_current_type = node.type
		_print_current_type()

func _cycle_type() -> void:
	if _available_types.is_empty():
		_refresh_type_list()
		
	var current_idx = _available_types.find(_current_type)
	var next_idx = (current_idx + 1) % _available_types.size()
	
	_current_type = _available_types[next_idx]
	_print_current_type()

func _print_current_type() -> void:
	var type_name = _get_type_name(_current_type)
	_show_status("Type Brush: %s" % type_name)

func _get_type_name(type_key: String) -> String: 
	return SemanticRegistry.get_category_name(SemanticRegistry.TARGET_NODE, type_key)
