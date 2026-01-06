class_name GraphToolPropertyPaint
extends GraphTool

# --- STATE ---
var _is_painting: bool = false
var _current_type: int = NodeData.RoomType.ENEMY 
var _last_painted_id: String = ""

func enter() -> void:
	_print_current_type()

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
					_editor.start_undo_transaction("Paint Stroke", false)
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
	if id != "" and id != _last_painted_id:
		
		# --- BATCH LOGIC START ---
		if _editor.selected_nodes.has(id):
			# UPDATED: Use the new Bulk API
			# We pass the entire selection array. The Editor handles the Batch creation.
			_editor.set_node_type_bulk(_editor.selected_nodes, _current_type)
			
		else:
			# --- SINGLE LOGIC ---
			# Normal painting (painting a node that isn't selected)
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
	var types = GraphSettings.current_colors.keys()
	var current_index = types.find(_current_type)
	var next_index = (current_index + 1) % types.size()
	_current_type = types[next_index]
	_print_current_type()

func _print_current_type() -> void:
	var type_name = _get_type_name(_current_type)
	var msg = "Type Brush: [Right-Click] to Cycle. Active: %s" % type_name
	_show_status(msg)

func _get_type_name(type_int: int) -> String:
	return GraphSettings.get_type_name(type_int)
