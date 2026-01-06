class_name GraphToolPropertyPaint
extends GraphTool

# --- STATE ---
var _is_painting: bool = false
var _current_type: int = NodeData.RoomType.ENEMY 
var _last_painted_id: String = ""

func enter() -> void:
	# Feedback so user knows what color they are holding
	_print_current_type()

func handle_input(event: InputEvent) -> void:
	# 1. PAINTING (Left Click)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# FEATURE: Alt+Click to "Pick" the color under mouse
				if event.alt_pressed:
					_pick_type_under_mouse()
				else:
					_is_painting = true
					_paint_under_mouse()
			else:
				_is_painting = false
				_last_painted_id = ""
		
		# 2. CYCLING TYPES (Right Click)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cycle_type()
			
	# 3. DRAGGING (Paint Brush effect)
	elif event is InputEventMouseMotion:
		if _is_painting:
			_paint_under_mouse()
		
		_update_hover(_editor.get_global_mouse_position())

# --- LOGIC ---

func _paint_under_mouse() -> void:
	var mouse_pos = _editor.get_global_mouse_position()
	var id = _get_node_at_pos(mouse_pos)
	
	# Optimization: Only update if we hit a valid node AND haven't just painted it
	# (This prevents spamming the same node 60 times a second while holding the mouse still)
	if id != "" and id != _last_painted_id:
		
		# --- BATCH LOGIC START ---
		if _editor.selected_nodes.has(id):
			# If we are painting a node that is part of a selection, 
			# apply the paint to the ENTIRE selection.
			for selected_id in _editor.selected_nodes:
				var node = _graph.nodes[selected_id]
				# Only update nodes that actually need changing (prevents redundant updates)
				if node.type != _current_type:
					_editor.set_node_type(selected_id, _current_type)
		else:
			# --- SINGLE LOGIC ---
			# Normal painting (painting a node that isn't selected)
			var node = _graph.nodes[id]
			if node.type != _current_type:
				_editor.set_node_type(id, _current_type)
		# --- BATCH LOGIC END ---
			
		_last_painted_id = id

func _pick_type_under_mouse() -> void:
	var mouse_pos = _editor.get_global_mouse_position()
	var id = _get_node_at_pos(mouse_pos)
	
	if id != "":
		var node = _graph.nodes[id]
		_current_type = node.type
		_print_current_type()

func _cycle_type() -> void:
	# Get all defined keys from settings
	var types = GraphSettings.ROOM_COLORS.keys()
	var current_index = types.find(_current_type)
	
	# Move to next index, wrapping around to 0 at the end
	var next_index = (current_index + 1) % types.size()
	_current_type = types[next_index]
	
	_print_current_type()

func _print_current_type() -> void:
	var type_name = _get_type_name(_current_type)
	var msg = "Type Brush: [Right-Click] to Cycle. Active: %s" % type_name
	
	# Send to Status Bar
	_show_status(msg)

func _get_type_name(type_int: int) -> String:
	match type_int:
		NodeData.RoomType.EMPTY: return "Empty (Gray)"
		NodeData.RoomType.SPAWN: return "Spawn (Green)"
		NodeData.RoomType.ENEMY: return "Enemy (Red)"
		NodeData.RoomType.TREASURE: return "Treasure (Gold)"
		NodeData.RoomType.BOSS: return "Boss (Dark Red)"
		NodeData.RoomType.SHOP: return "Shop (Purple)"
		_: return "Unknown"
