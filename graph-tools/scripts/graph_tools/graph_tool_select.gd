class_name GraphToolSelect
extends GraphTool

const DRAG_THRESHOLD: float = 4.0

# State A: Moving Nodes
var _drag_node_id: String = ""        # The "Anchor" node we clicked on
var _group_offsets: Dictionary = {}   # Stores { "node_id": Vector2_offset_from_anchor }
var _drag_start_positions: Dictionary = {}

# State B: Region Selection
var _box_start_pos: Vector2 = Vector2.INF
var _selection_mode: int = 0 # 0 = Rectangle, 1 = Lasso
var _lasso_path: PackedVector2Array = []

# --- TRANSFORM STATE ---
const TRANSFORM_PAD: float = 20.0 # Padding around nodes
const HANDLE_RADIUS: float = 10.0 # How close mouse must be to grab a handle
const ROTATE_RADIUS: float = 30.0 # Distance outside corner to trigger rotation

var _transform_active: bool = false
var _transform_type: String = "none" # "scale", "rotate", "none"
var _transform_handle: Vector2 = Vector2.ZERO # e.g. (-1, -1) for Top-Left
var _transform_start_rect: Rect2
var _transform_start_mouse: Vector2
var _transform_original_positions: Dictionary = {}

# ==============================================================================
# INPUT ROUTING
# ==============================================================================

func handle_input(event: InputEvent) -> void:
	# 1. MOUSE BUTTON INPUT
	if event is InputEventMouseButton:
		
		# HANDLE RIGHT CLICK (CANCEL / DESELECT)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click_cancel()
			return

		var mouse_pos = _editor.get_global_mouse_position()
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				
				# --- CLICK DOWN WATERFALL ---
				
				# 0. Check Transform Handles First
				var hit_transform = _get_transform_handle_at_pos(mouse_pos)
				if hit_transform.type != "none":
					_start_transform(hit_transform, mouse_pos)
					return
				
				# 1. Check Agent
				var hit_agent = _get_agent_at_pos(mouse_pos)
				if hit_agent:
					_handle_agent_click(hit_agent)
					return 
				
				# 2. Check Node
				var clicked_id = _get_node_at_pos(mouse_pos)
				if not clicked_id.is_empty():
					_start_moving_node(clicked_id)
					return
					
				# 3. Check Edge
				var clicked_edge = _get_edge_at_pos(mouse_pos)
				if not clicked_edge.is_empty():
					_handle_edge_click(clicked_edge)
					return
						
				# 4. Check Zone
				var clicked_zone = _get_zone_at_pos(mouse_pos)
				if clicked_zone:
					_handle_zone_click(clicked_zone)
					return
						
				# 5. Nothing Hit -> Start Box/Lasso Select
				_start_region_selection(mouse_pos)

			else:
				# --- CLICK RELEASE ---
				if _transform_active: # Stop transforming!
					_finish_transform()
				elif not _drag_node_id.is_empty():
					_finish_moving_node()
				elif _box_start_pos != Vector2.INF:
					_finish_region_selection(mouse_pos)
		
		_renderer.queue_redraw() 

	# 2. MOUSE MOTION INPUT
	elif event is InputEventMouseMotion:
		var mouse_pos = _editor.get_global_mouse_position()
		
		# Update Transform State
		if _transform_active:
			var is_shift = Input.is_key_pressed(KEY_SHIFT)
			if _transform_type == "scale":
				var is_ctrl = Input.is_key_pressed(KEY_CTRL)
				_update_scale_transform(mouse_pos, is_shift, is_ctrl)
			elif _transform_type == "rotate":
				_update_rotate_transform(mouse_pos, is_shift)
		
		# Update Move State
		elif not _drag_node_id.is_empty():
			var anchor_pos = mouse_pos
			if Input.is_key_pressed(KEY_SHIFT):
				anchor_pos = anchor_pos.snapped(GraphSettings.GRID_SPACING)
			
			_editor.set_node_position(_drag_node_id, anchor_pos, true)
			
			for id in _group_offsets:
				if id == _drag_node_id: continue
				var new_group_pos = anchor_pos + _group_offsets[id]
				_editor.set_node_position(id, new_group_pos, true)
		
		# Update Region Selection State (Rectangle vs Lasso)
		elif _box_start_pos != Vector2.INF:
			if _selection_mode == 0:
				var rect = _get_rect(_box_start_pos, mouse_pos)
				_renderer.selection_rect = rect
				if "selection_lasso" in _renderer: _renderer.selection_lasso.clear()
				
				var potential_nodes = _get_nodes_in_rect(rect)
				_renderer.pre_selection_ref = potential_nodes
			else:
				# Lasso Mode: Drop a breadcrumb every 5 pixels
				if _lasso_path.is_empty() or _lasso_path[-1].distance_to(mouse_pos) > 5.0:
					_lasso_path.append(mouse_pos)
				
				_renderer.selection_rect = Rect2()
				if "selection_lasso" in _renderer: _renderer.selection_lasso = _lasso_path
				
				var potential_nodes = _get_nodes_in_lasso(_lasso_path)
				_renderer.pre_selection_ref = potential_nodes
				
			_renderer.queue_redraw()
		
		# [UPDATED] Live Hover Feedback
		_update_hover(mouse_pos)
		
		# --- DYNAMIC MOUSE CURSORS ---
		if not _transform_active and _renderer.transform_rect.size != Vector2.ZERO:
			var hover_handle = _get_transform_handle_at_pos(mouse_pos)
			
			if hover_handle.type == "rotate":
				DisplayServer.cursor_set_shape(DisplayServer.CURSOR_POINTING_HAND)
			elif hover_handle.type == "scale":
				var d = hover_handle.dir
				if d == Vector2(-1, -1) or d == Vector2(1, 1):
					DisplayServer.cursor_set_shape(DisplayServer.CURSOR_FDIAGSIZE)
				elif d == Vector2(1, -1) or d == Vector2(-1, 1):
					DisplayServer.cursor_set_shape(DisplayServer.CURSOR_BDIAGSIZE)
				elif d.y == 0:
					DisplayServer.cursor_set_shape(DisplayServer.CURSOR_HSIZE)
				elif d.x == 0:
					DisplayServer.cursor_set_shape(DisplayServer.CURSOR_VSIZE)
			else:
				DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
		elif not _transform_active:
			DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)

# ==============================================================================
# HOVER OVERRIDE (Contextual Visual Feedback)
# ==============================================================================

func _update_hover(mouse_pos: Vector2) -> void:
	# Keep the transform box visually synchronized!
	
	_renderer.transform_rect = _get_selection_bounds()
	# 1. Clear previous hovers
	_clear_all_hovers()
	
	# 2. Highlight whichever element is foremost under the cursor
	var agent = _get_agent_at_pos(mouse_pos)
	if agent:
		if _editor.has_method("set_hovered_agent"): _editor.set_hovered_agent(agent)
		return
		
	var node = _get_node_at_pos(mouse_pos)
	if node != "":
		if _editor.has_method("set_hovered_node"): _editor.set_hovered_node(node)
		return
		
	var edge = _get_edge_at_pos(mouse_pos)
	if not edge.is_empty():
		if _editor.has_method("set_hovered_edge"): _editor.set_hovered_edge(edge)
		return
		
	var zone = _get_zone_at_pos(mouse_pos)
	if zone:
		if _editor.has_method("set_hovered_zone"): _editor.set_hovered_zone(zone)

# ==============================================================================
# SELECTION LOGIC
# ==============================================================================

func _handle_right_click_cancel() -> void:
	_perform_global_deselect()
	_reset_tool_state()
	_editor.send_status_message("Selection cleared.")

func _handle_agent_click(agent) -> void:
	var is_shift = Input.is_key_pressed(KEY_SHIFT)
	var is_ctrl = Input.is_key_pressed(KEY_CTRL)
	
	if is_shift or is_ctrl:
		var current_selection = _editor.selected_agent_ids.duplicate()
		if is_ctrl: 
			if agent in current_selection: current_selection.erase(agent)
			else: current_selection.append(agent)
		elif is_shift:
			if not agent in current_selection: current_selection.append(agent)
			
		_editor.set_agent_selection(current_selection, false)
		if is_shift: _editor.add_to_selection(agent.current_node_id)
		return

	_editor.set_selection_batch([agent.current_node_id], [], true)
	_editor.set_agent_selection([agent], false)
	if _editor.has_signal("request_inspector_view"): _editor.request_inspector_view.emit()

func _handle_edge_click(edge_pair: Array) -> void:
	edge_pair.sort() 
	
	if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL):
		_editor.toggle_edge_selection(edge_pair)
	else:
		_editor.clear_selection()
		_editor.set_edge_selection(edge_pair)

# Handle clicking a Zone directly
func _handle_zone_click(zone) -> void:
	if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL):
		var current = _editor.selected_zones.duplicate()
		if current.has(zone): current.erase(zone)
		else: current.append(zone)
		_editor.set_zone_selection(current, false)
	else:
		_perform_global_deselect()
		_editor.set_zone_selection([zone], true)
		if _editor.has_signal("request_inspector_view"): _editor.request_inspector_view.emit()

# ==============================================================================
# NODE MOVEMENT LOGIC
# ==============================================================================

func _start_moving_node(id: String) -> void:
	_drag_node_id = id
	_renderer.drag_start_id = id
	
	var nodes_to_action: Array[String] = [id]
	var is_group_action: bool = false
	var active_group_zone: GraphZone = null 
	
	if _graph.zones:
		for zone in _graph.zones:
			if zone.is_grouped and zone.contains_node(id):
				is_group_action = true
				active_group_zone = zone 
				for peer_id in zone.registered_nodes:
					if not nodes_to_action.has(peer_id):
						nodes_to_action.append(peer_id)

	if Input.is_key_pressed(KEY_SHIFT):
		var nodes_to_add: Array[String] = []
		for target in nodes_to_action:
			if not _editor.selected_nodes.has(target): nodes_to_add.append(target)
		if not nodes_to_add.is_empty(): _editor.set_selection_batch(nodes_to_add, [], false)
			
	elif Input.is_key_pressed(KEY_CTRL):
		var new_selection = _editor.selected_nodes.duplicate()
		var selection_changed = false
		for target in nodes_to_action:
			if new_selection.has(target):
				new_selection.erase(target)
				selection_changed = true
			else:
				new_selection.append(target)
				selection_changed = true
		if selection_changed: _editor.set_selection_batch(new_selection, _editor.selected_edges, true)
			
	else:
		if is_group_action:
			if not _editor.selected_nodes.has(id): _editor.set_selection_batch(nodes_to_action, [], true)
		else:
			if not _editor.selected_nodes.has(id): _editor.set_selection_batch([id], [], true)

	if is_group_action and active_group_zone:
		_editor.set_zone_selection([active_group_zone], false)
	
	if _editor.selected_nodes.has(id):
		_group_offsets.clear()
		_drag_start_positions.clear() 
		
		var anchor_pos = _graph.nodes[id].position
		for selected_id in _editor.selected_nodes:
			if selected_id != id:
				var diff = _graph.nodes[selected_id].position - anchor_pos
				_group_offsets[selected_id] = diff
			
			if _graph.nodes.has(selected_id):
				_drag_start_positions[selected_id] = _graph.nodes[selected_id].position
	else:
		_drag_node_id = ""
		_renderer.drag_start_id = "" 
		_renderer.queue_redraw()

func _finish_moving_node() -> void:
	if not _drag_start_positions.is_empty():
		var move_payload = {}
		for id in _drag_start_positions:
			if _graph.nodes.has(id):
				move_payload[id] = {
					"from": _drag_start_positions[id],
					"to": _graph.nodes[id].position
				}
		_editor.commit_move_batch(move_payload)
	_reset_tool_state()

# ==============================================================================
# REGION SELECTION (OMNI-TARGETING)
# ==============================================================================

func _start_region_selection(pos: Vector2) -> void:
	_box_start_pos = pos
	_lasso_path.clear()
	_lasso_path.append(pos)

func _finish_region_selection(mouse_pos: Vector2) -> void:
	var drag_dist = _box_start_pos.distance_to(mouse_pos)
	
	if drag_dist < DRAG_THRESHOLD:
		if not Input.is_key_pressed(KEY_SHIFT) and not Input.is_key_pressed(KEY_CTRL):
			_perform_global_deselect()
		_reset_tool_state()
		return
		
	var nodes_in_region = []
	var edges_in_region = []
	var agents_in_region = []
	var zones_in_region = []
	
	if _selection_mode == 0:
		var rect = _get_rect(_box_start_pos, mouse_pos)
		nodes_in_region = _get_nodes_in_rect(rect)
		edges_in_region = _get_edges_in_rect(rect) 
		agents_in_region = _get_agents_in_rect(rect)
		zones_in_region = _get_zones_in_rect(rect)
	else:
		nodes_in_region = _get_nodes_in_lasso(_lasso_path)
		edges_in_region = _get_edges_in_lasso(_lasso_path)
		agents_in_region = _get_agents_in_lasso(_lasso_path)
		zones_in_region = _get_zones_in_lasso(_lasso_path)
	
	var is_shift = Input.is_key_pressed(KEY_SHIFT)
	var is_ctrl = Input.is_key_pressed(KEY_CTRL)
	
	if not is_shift and not is_ctrl:
		# REPLACE
		_editor.set_selection_batch(nodes_in_region, edges_in_region, true)
		if not agents_in_region.is_empty(): _editor.set_agent_selection(agents_in_region, false)
		if not zones_in_region.is_empty(): _editor.set_zone_selection(zones_in_region, false)
			
	elif is_shift:
		# ADD
		var nodes_to_add: Array[String] = []
		for id in nodes_in_region:
			if not _editor.selected_nodes.has(id): nodes_to_add.append(id)
				
		var edges_to_add: Array = []
		for pair in edges_in_region:
			if not _editor.is_edge_selected(pair): edges_to_add.append(pair)
		
		if not nodes_to_add.is_empty() or not edges_to_add.is_empty():
			_editor.set_selection_batch(nodes_to_add, edges_to_add, false)
			
		if not agents_in_region.is_empty(): _add_agents_to_selection(agents_in_region)
		if not zones_in_region.is_empty(): _add_zones_to_selection(zones_in_region)

	elif is_ctrl:
		# SUBTRACT
		var final_nodes = _editor.selected_nodes.duplicate()
		for id in nodes_in_region:
			if final_nodes.has(id): final_nodes.erase(id)
		
		var final_edges = _editor.selected_edges.duplicate()
		for pair in edges_in_region:
			if _editor.is_edge_selected(pair): final_edges.erase(pair)
		
		_editor.set_selection_batch(final_nodes, final_edges, true)
		_remove_agents_from_selection(agents_in_region)
		_remove_zones_from_selection(zones_in_region)
			
	_reset_tool_state()



func get_options_schema() -> Array:
	return [{
		"name": "selection_mode",
		"label": "Mode",
		"type": TYPE_INT,
		"default": _selection_mode,
		"hint": "enum",
		"hint_string": "Rectangle,Lasso"
	}]

func apply_option(param_name: String, value: Variant) -> void:
	if param_name == "selection_mode":
		_selection_mode = int(value)
# ==============================================================================
# TRANSFORM BOUNDING BOX MATH
# ==============================================================================

# Calculates a perfect rectangle wrapping all selected nodes
func _get_selection_bounds() -> Rect2:
	var selected = _editor.selected_nodes
	if selected.size() < 2: 
		return Rect2() # Only show transform box if 2+ nodes are selected
		
	var min_x = INF; var max_x = -INF
	var min_y = INF; var max_y = -INF
	
	for id in selected:
		if _graph.nodes.has(id):
			var pos = _graph.nodes[id].position
			min_x = min(min_x, pos.x)
			max_x = max(max_x, pos.x)
			min_y = min(min_y, pos.y)
			max_y = max(max_y, pos.y)
			
	# Pad it slightly so the handles don't overlap the nodes
	var rect = Rect2(min_x, min_y, max_x - min_x, max_y - min_y)
	rect.position -= Vector2(TRANSFORM_PAD, TRANSFORM_PAD)
	rect.size += Vector2(TRANSFORM_PAD * 2, TRANSFORM_PAD * 2)
	if rect.size.x == 0: rect.position.x -= 0.1; rect.size.x = 0.2
	if rect.size.y == 0: rect.position.y -= 0.1; rect.size.y = 0.2
	return rect

# Checks if the mouse is hovering over a scale handle or rotation zone
# Returns a dictionary: {"type": "scale"|"rotate"|"none", "dir": Vector2}
func _get_transform_handle_at_pos(mouse_pos: Vector2) -> Dictionary:
	var bounds = _get_selection_bounds()
	if not bounds.has_area(): return {"type": "none", "dir": Vector2.ZERO}
	
	# The 8 grab directions
	var dirs = [
		Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), # Top Left, Top Center, Top Right
		Vector2(-1, 0),                  Vector2(1, 0),  # Left Center, Right Center
		Vector2(-1, 1),  Vector2(0, 1),  Vector2(1, 1)   # Bot Left, Bot Center, Bot Right
	]
	
	# 1. Check Scale Handles (Edges & Corners)
	for d in dirs:
		# Map the Vector2 direction to a global point on the bounds rectangle
		var handle_pos = bounds.position + (bounds.size / 2.0) + (d * bounds.size / 2.0)
		if mouse_pos.distance_to(handle_pos) <= HANDLE_RADIUS:
			return {"type": "scale", "dir": d}
			
	# 2. Check Rotation Zones (Just outside the 4 corners)
	var corners = [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
	for d in corners:
		var corner_pos = bounds.position + (bounds.size / 2.0) + (d * bounds.size / 2.0)
		if mouse_pos.distance_to(corner_pos) <= ROTATE_RADIUS:
			return {"type": "rotate", "dir": d}
			
	return {"type": "none", "dir": Vector2.ZERO}

func _start_transform(handle_info: Dictionary, mouse_pos: Vector2) -> void:
	_transform_active = true
	_transform_type = handle_info.type
	_transform_handle = handle_info.dir
	_transform_start_mouse = mouse_pos
	_transform_start_rect = _get_selection_bounds()
	
	_transform_original_positions.clear()
	for id in _editor.selected_nodes:
		if _graph.nodes.has(id):
			_transform_original_positions[id] = _graph.nodes[id].position

func _update_scale_transform(mouse_pos: Vector2, is_shift: bool, is_ctrl: bool) -> void:
	# 1. Strip the visual padding so our pivots sit EXACTLY on the nodes
	var raw_start_rect = _transform_start_rect
	raw_start_rect.position += Vector2(TRANSFORM_PAD, TRANSFORM_PAD)
	raw_start_rect.size -= Vector2(TRANSFORM_PAD * 2, TRANSFORM_PAD * 2)
	
	var start_center = raw_start_rect.get_center()
	var start_size = raw_start_rect.size
	
	# Prevent division by zero if all nodes are in a perfectly straight line
	if start_size.x == 0: start_size.x = 0.001
	if start_size.y == 0: start_size.y = 0.001
	
	var pivot: Vector2
	var new_size: Vector2
	
	# Decouple the movement from the padded bounds by using pure mouse delta
	var mouse_delta = mouse_pos - _transform_start_mouse
	
	# 2. Determine Pivot & Size
	if is_ctrl:
		pivot = start_center
		# If scaling from center, a 10px mouse drag expands the total size by 20px
		var axis_delta = mouse_delta * _transform_handle
		new_size.x = start_size.x + (axis_delta.x * 2.0) if _transform_handle.x != 0 else start_size.x
		new_size.y = start_size.y + (axis_delta.y * 2.0) if _transform_handle.y != 0 else start_size.y
	else:
		var opposite_dir = -_transform_handle
		pivot = start_center + (opposite_dir * start_size / 2.0)
		
		var axis_delta = mouse_delta * _transform_handle
		new_size.x = start_size.x + axis_delta.x if _transform_handle.x != 0 else start_size.x
		new_size.y = start_size.y + axis_delta.y if _transform_handle.y != 0 else start_size.y
		
	# 3. Apply SHIFT Constraint (Uniform Aspect Ratio)
	if is_shift and _transform_handle.x != 0 and _transform_handle.y != 0:
		var ratio = start_size.x / start_size.y
		if abs(new_size.x) > abs(new_size.y * ratio):
			new_size.y = new_size.x / ratio * sign(new_size.y) * sign(new_size.x)
		else:
			new_size.x = new_size.y * ratio * sign(new_size.x) * sign(new_size.y)
			
	# 4. Calculate Scale Factors
	var scale_x = new_size.x / start_size.x
	var scale_y = new_size.y / start_size.y
	var scale = Vector2(scale_x, scale_y)
	
	# 5. Apply to Nodes relative to Pivot
	for id in _transform_original_positions:
		var orig_pos = _transform_original_positions[id]
		var local_pos = orig_pos - pivot
		var new_pos = pivot + (local_pos * scale)
		
		if Input.is_key_pressed(KEY_ALT):
			new_pos = new_pos.snapped(GraphSettings.GRID_SPACING)
			
		_editor.set_node_position(id, new_pos, true)

func _update_rotate_transform(mouse_pos: Vector2, is_shift: bool) -> void:
	# Rotation ALWAYS pivots around the center of the block
	var pivot = _transform_start_rect.get_center()
	
	# Calculate the angle delta between where the mouse started and where it is now
	var start_angle = pivot.angle_to_point(_transform_start_mouse)
	var current_angle = pivot.angle_to_point(mouse_pos)
	var angle_delta = current_angle - start_angle
	
	# SHIFT Constraint: Snap rotation to 15-degree (PI/12) increments
	if is_shift:
		angle_delta = snapped(angle_delta, PI / 12.0)
		
	# Apply 2D rotation matrix math
	for id in _transform_original_positions:
		var orig_pos = _transform_original_positions[id]
		var local_pos = orig_pos - pivot
		
		var rotated_pos = pivot + local_pos.rotated(angle_delta)
		
		# Optional grid snapping
		if Input.is_key_pressed(KEY_ALT):
			rotated_pos = rotated_pos.snapped(GraphSettings.GRID_SPACING)
			
		_editor.set_node_position(id, rotated_pos, true)

# ==============================================================================
# UTILITIES
# ==============================================================================

func _perform_global_deselect() -> void:
	_editor.clear_selection()

func _reset_tool_state() -> void:
	_drag_node_id = ""
	_box_start_pos = Vector2.INF
	_group_offsets.clear()
	_drag_start_positions.clear()
	
	# Transform resets
	_transform_active = false
	_transform_type = "none"
	# Guarantee the cursor goes back to normal when switching tools
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
	
	_renderer.selection_rect = Rect2()
	_renderer.transform_rect = Rect2() # Hide the box
	_renderer.pre_selection_ref = []
	_renderer.selection_lasso.clear()
	_renderer.drag_start_id = ""
	_renderer.queue_redraw()

func _add_agents_to_selection(new_agents: Array) -> void:
	var current = _editor.selected_agent_ids.duplicate()
	for a in new_agents:
		if not current.has(a): current.append(a)
	_editor.set_agent_selection(current, false)

func _remove_agents_from_selection(rem_agents: Array) -> void:
	if rem_agents.is_empty(): return
	var final = _editor.selected_agent_ids.duplicate()
	for a in rem_agents:
		if final.has(a): final.erase(a)
	_editor.set_agent_selection(final, false)

func _add_zones_to_selection(new_zones: Array) -> void:
	var current = _editor.selected_zones.duplicate()
	for z in new_zones:
		if not current.has(z): current.append(z)
	_editor.set_zone_selection(current, false)

func _remove_zones_from_selection(rem_zones: Array) -> void:
	if rem_zones.is_empty(): return
	var final = _editor.selected_zones.duplicate()
	for z in rem_zones:
		if final.has(z): final.erase(z)
	_editor.set_zone_selection(final, false)

func _get_rect(p1: Vector2, p2: Vector2) -> Rect2:
	var min_x = min(p1.x, p2.x)
	var max_x = max(p1.x, p2.x)
	var min_y = min(p1.y, p2.y)
	var max_y = max(p1.y, p2.y)
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

func _finish_transform() -> void:
	if not _transform_original_positions.is_empty():
		var move_payload = {}
		for id in _transform_original_positions:
			if _graph.nodes.has(id):
				move_payload[id] = {
					"from": _transform_original_positions[id],
					"to": _graph.nodes[id].position
				}
		_editor.commit_move_batch(move_payload)
		
	_transform_active = false
	_transform_type = "none"
	_transform_original_positions.clear()
	_renderer.queue_redraw()


func exit() -> void:
	super.exit()
	_reset_tool_state()
