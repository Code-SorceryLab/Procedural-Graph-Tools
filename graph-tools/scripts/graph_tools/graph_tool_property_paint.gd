class_name GraphToolPropertyPaint
extends GraphTool

# --- CONSTANTS ---
const TARGETS = ["NODE", "EDGE", "AGENT", "ZONE"]

# --- STATE ---
var _is_painting: bool = false
var _last_painted_id: String = ""

# The active brush configuration
var _target_idx: int = 0      # 0=NODE, 1=EDGE, 2=AGENT, 3=ZONE
var _field_idx: int = 0       # 0="type", 1+ = Custom Properties
var _value: Variant = "enemy" # Starts as default enemy type

# UI Caches
var _available_fields: Array = []
var _available_categories: Array = []

# --- LIFECYCLE ---

func enter() -> void:
	_reset_value_to_default()
	_print_current_brush()
	_show_status("Universal Brush: Select target from Top Bar. Alt-Click to pick.")

func exit() -> void:
	_is_painting = false
	_last_painted_id = ""
	_show_status("")

# --- TOOL OPTIONS API ---

func get_options_schema() -> Array:
	var schema = []
	var target_str = TARGETS[_target_idx]
	
	# 1. Target Selector
	schema.append({
		"name": "opt_target", "label": "Target", "type": TYPE_INT, 
		"default": _target_idx, "hint": "enum", "hint_string": "Node,Edge,Agent,Zone"
	})
	
	# 2. Field Selector
	_available_fields = ["type"] # Category is always index 0
	var field_labels = ["Category (Type)"]
	
	var props = SemanticRegistry.properties[target_str]
	for k in props.keys():
		_available_fields.append(k)
		field_labels.append(props[k].get("label", k.capitalize()))
		
	# Safety bounds check if fields were deleted
	if _field_idx >= _available_fields.size(): _field_idx = 0
	var current_field = _available_fields[_field_idx]

	schema.append({
		"name": "opt_field", "label": "Property", "type": TYPE_INT, 
		"default": _field_idx, "hint": "enum", "hint_string": ",".join(field_labels)
	})
	
	# 3. Value Selector
	if current_field == "type":
		var cat_schema = SemanticRegistry.get_category_ui_schema(target_str)
		_available_categories = cat_schema["keys"]
		
		var current_val_idx = _available_categories.find(_value)
		if current_val_idx == -1: current_val_idx = 0
		
		schema.append({
			"name": "opt_value", "label": "Value", "type": TYPE_INT,
			"default": current_val_idx, "hint": "enum", "hint_string": cat_schema["hint_string"]
		})
	else:
		# Custom Property (Dynamically assumes Bool, Int, Float, Color, String)
		var prop_def = props[current_field]
		var safe_val = _value if _value != null else prop_def["default"]
		schema.append({
			"name": "opt_value", "label": "Value", "type": prop_def["type"], "default": safe_val
		})

	return schema

func apply_option(param_name: String, value: Variant) -> void:
	var needs_rebuild = false
	var target_str = TARGETS[_target_idx]
	var current_field = _available_fields[_field_idx]

	match param_name:
		"opt_target":
			_target_idx = int(value)
			_field_idx = 0 
			_reset_value_to_default()
			needs_rebuild = true
		"opt_field":
			_field_idx = int(value)
			_reset_value_to_default()
			needs_rebuild = true
		"opt_value":
			if current_field == "type":
				var ui_idx = int(value)
				if ui_idx >= 0 and ui_idx < _available_categories.size():
					_value = _available_categories[ui_idx]
			else:
				_value = value
				
	if needs_rebuild:
		# Hack: Emitting this forces the TopbarController to dynamically rebuild our UI!
		if _editor.tool_manager:
			SignalManager.active_tool_changed.emit(_editor.tool_manager.active_tool_id)

	_print_current_brush()

func _reset_value_to_default() -> void:
	var target_str = TARGETS[_target_idx]
	
	if _available_fields.is_empty(): _available_fields = ["type"]
	var current_field = _available_fields[_field_idx]
	
	if current_field == "type":
		var keys = SemanticRegistry.categories[target_str].keys()
		_value = keys[0] if not keys.is_empty() else "empty"
		# Keep starting default as enemy if we are on nodes
		if target_str == "NODE" and keys.has("enemy"): _value = "enemy"
	else:
		var props = SemanticRegistry.properties[target_str]
		if props.has(current_field):
			_value = props[current_field]["default"]

# --- INPUT ---

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if event.alt_pressed:
					_pick_under_mouse()
				else:
					_is_painting = true
					_editor.start_undo_transaction("Universal Paint", false)
					_paint_under_mouse()
			else:
				if _is_painting:
					_editor.commit_undo_transaction()
					_is_painting = false
					_last_painted_id = ""
					
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cycle_value()
			
	elif event is InputEventMouseMotion:
		if _is_painting:
			_paint_under_mouse()
		_update_hover(_editor.get_global_mouse_position())

# --- LOGIC & HIT DETECTION ---

func _paint_under_mouse() -> void:
	var mouse_pos = _editor.get_global_mouse_position()
	var target_str = TARGETS[_target_idx]
	var current_field = _available_fields[_field_idx]
	var graph = _editor.graph
	
	match target_str:
		"NODE":
			var id = _get_node_at_pos(mouse_pos)
			if id != "" and id != _last_painted_id:
				if current_field == "type": _editor.set_node_type(id, _value)
				else: _editor.set_node_property(id, current_field, _value)
				_last_painted_id = id
				
		"EDGE":
			var edge = _get_edge_at_pos(mouse_pos)
			if edge.size() == 2 and str(edge) != _last_painted_id:
				_editor.set_edge_property(edge[0], edge[1], current_field, _value)
				if graph.has_edge(edge[1], edge[0]):
					_editor.set_edge_property(edge[1], edge[0], current_field, _value)
				_last_painted_id = str(edge)
				
		"AGENT":
			var agent = _editor.renderer.get_agent_at_position(mouse_pos)
			if agent and agent.uuid != _last_painted_id:
				var old_val = _get_obj_val(agent, current_field)
				var cmd = CmdSetProperty.new(graph, "AGENT", agent, current_field, _value, old_val)
				_editor._commit_command(cmd)
				_last_painted_id = agent.uuid
				
		"ZONE":
			var zone = _get_zone_at_pos(mouse_pos)
			if zone and zone.zone_name != _last_painted_id:
				var old_val = _get_obj_val(zone, current_field)
				var cmd = CmdSetProperty.new(graph, "ZONE", zone, current_field, _value, old_val)
				_editor._commit_command(cmd)
				_last_painted_id = zone.zone_name

func _update_hover(mouse_pos: Vector2) -> void:
	# 1. Clear all hovers to prevent ghosting
	_editor.set_hovered_node("")
	if _editor.has_method("set_hovered_edge"): _editor.set_hovered_edge([])
	if _editor.has_method("set_hovered_agent"): _editor.set_hovered_agent(null)
	if _editor.has_method("set_hovered_zone"): _editor.set_hovered_zone(null)
	
	# 2. Apply hover only to the target system we are currently painting
	var target_str = TARGETS[_target_idx]
	match target_str:
		"NODE":
			_editor.set_hovered_node(_get_node_at_pos(mouse_pos))
		"EDGE":
			if _editor.has_method("set_hovered_edge"):
				_editor.set_hovered_edge(_get_edge_at_pos(mouse_pos))
		"AGENT":
			if _editor.has_method("set_hovered_agent"):
				var agent = _editor.renderer.get_agent_at_position(mouse_pos)
				_editor.set_hovered_agent(agent)
		"ZONE":
			if _editor.has_method("set_hovered_zone"):
				_editor.set_hovered_zone(_get_zone_at_pos(mouse_pos))

func _pick_under_mouse() -> void:
	var mouse_pos = _editor.get_global_mouse_position()
	var target_str = TARGETS[_target_idx]
	var current_field = _available_fields[_field_idx]
	var val = null
	
	match target_str:
		"NODE":
			var id = _get_node_at_pos(mouse_pos)
			if id != "": val = _get_obj_val(_editor.graph.nodes[id], current_field)
		"EDGE":
			var edge = _get_edge_at_pos(mouse_pos)
			if edge.size() == 2: val = _editor.graph.edge_data[edge[0]][edge[1]].get(current_field)
		"AGENT":
			var agent = _editor.renderer.get_agent_at_position(mouse_pos)
			if agent: val = _get_obj_val(agent, current_field)
		"ZONE":
			var zone = _get_zone_at_pos(mouse_pos)
			if zone: val = _get_obj_val(zone, current_field)
			
	if val != null:
		_value = val
		if _editor.tool_manager: SignalManager.active_tool_changed.emit(_editor.tool_manager.active_tool_id)
		_print_current_brush()

func _cycle_value() -> void:
	var target_str = TARGETS[_target_idx]
	var current_field = _available_fields[_field_idx]
	
	if current_field == "type":
		var keys = SemanticRegistry.categories[target_str].keys()
		if keys.is_empty(): return
		var idx = keys.find(_value)
		_value = keys[(idx + 1) % keys.size()]
		if _editor.tool_manager: SignalManager.active_tool_changed.emit(_editor.tool_manager.active_tool_id)
	elif typeof(_value) == TYPE_BOOL:
		_value = not _value
		if _editor.tool_manager: SignalManager.active_tool_changed.emit(_editor.tool_manager.active_tool_id)

func _print_current_brush() -> void:
	var target_str = TARGETS[_target_idx]
	var field_str = _available_fields[_field_idx]
	var val_str = str(_value)
	
	if field_str == "type":
		val_str = SemanticRegistry.get_category_name(target_str, _value)
		
	_show_status("Paint Brush: [%s] -> %s = %s" % [target_str, field_str, val_str])

# --- HIT HELPERS ---

func _get_obj_val(obj, key: String) -> Variant:
	if key in obj: return obj.get(key)
	if "custom_data" in obj: return obj.custom_data.get(key)
	return null
