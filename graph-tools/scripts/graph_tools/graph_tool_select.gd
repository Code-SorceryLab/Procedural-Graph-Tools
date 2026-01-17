class_name GraphToolSelect
extends GraphTool

const DRAG_THRESHOLD: float = 4.0

# State A: Moving Nodes
var _drag_node_id: String = ""        # The "Anchor" node we clicked on
var _group_offsets: Dictionary = {}   # Stores { "node_id": Vector2_offset_from_anchor }
var _drag_start_positions: Dictionary = {}

# State B: Box Selection
var _box_start_pos: Vector2 = Vector2.INF

func handle_input(event: InputEvent) -> void:
	# 1. MOUSE BUTTON INPUT
	if event is InputEventMouseButton:
		
		# [FIX] HANDLE RIGHT CLICK (CANCEL / DESELECT)
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_handle_right_click_cancel()
			return

		var mouse_pos = _editor.get_global_mouse_position()
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# --- CLICK DOWN ---
				
				# 1. Check Agent
				var local_pos = _editor.renderer.to_local(mouse_pos)
				var hit_agent = _editor.renderer.get_agent_at_position(local_pos)
				if hit_agent:
					_handle_agent_click(hit_agent)
					return 
				
				# 2. Check Node
				var clicked_id = _get_node_at_pos(mouse_pos)
				if not clicked_id.is_empty():
					_start_moving_node(clicked_id)
				else:
					# 3. Check Edge
					var clicked_edge = _graph.get_edge_at_position(mouse_pos)
					if not clicked_edge.is_empty():
						_handle_edge_click(clicked_edge)
					else:
						# 4. Box Select
						_start_box_selection(mouse_pos)

			else:
				# --- CLICK RELEASE ---
				if not _drag_node_id.is_empty():
					_finish_moving_node()
				elif _box_start_pos != Vector2.INF:
					_finish_box_selection(mouse_pos)
		
		_renderer.queue_redraw()

	# 2. MOUSE MOTION INPUT
	elif event is InputEventMouseMotion:
		var mouse_pos = _editor.get_global_mouse_position()
		
		# Update Move State
		if not _drag_node_id.is_empty():
			var anchor_pos = mouse_pos
			if Input.is_key_pressed(KEY_SHIFT):
				anchor_pos = anchor_pos.snapped(GraphSettings.GRID_SPACING)
			
			_editor.set_node_position(_drag_node_id, anchor_pos, true)
			
			for id in _group_offsets:
				if id == _drag_node_id: continue
				var new_group_pos = anchor_pos + _group_offsets[id]
				_editor.set_node_position(id, new_group_pos, true)
		
		# Update Box State
		elif _box_start_pos != Vector2.INF:
			var rect = _get_rect(_box_start_pos, mouse_pos)
			_renderer.selection_rect = rect
			
			# Optimized visual feedback check
			var potential_nodes = _graph.get_nodes_in_rect(rect)
			_renderer.pre_selection_ref = potential_nodes
			_renderer.queue_redraw()
		
		if has_method("_update_hover"):
			call("_update_hover", mouse_pos)

# --- HELPER FUNCTIONS ---

func _handle_right_click_cancel() -> void:
	_perform_global_deselect()
	_reset_tool_state()
	_editor.send_status_message("Selection cleared.")

func _handle_agent_click(agent) -> void:
	var is_shift = Input.is_key_pressed(KEY_SHIFT)
	var is_ctrl = Input.is_key_pressed(KEY_CTRL)
	
	# 1. HANDLE MODIFIERS (Multi-Select)
	if is_shift or is_ctrl:
		var current_selection = _editor.selected_agent_ids.duplicate()
		
		if is_ctrl: # Toggle
			if agent in current_selection:
				current_selection.erase(agent)
			else:
				current_selection.append(agent)
			_editor.set_agent_selection(current_selection, false)
				
		elif is_shift: # Add
			if not agent in current_selection:
				current_selection.append(agent)
				_editor.set_agent_selection(current_selection, false)

		# Optional: Sync Node Selection for context
		if is_shift:
			_editor.add_to_selection(agent.current_node_id)
			
		return

	# 2. STANDARD CLICK (Exclusive)
	_editor.set_selection_batch([agent.current_node_id], [], true)
	_editor.set_agent_selection([agent], false)
	
	# 3. Open Inspector
	if _editor.has_signal("request_inspector_view"):
		_editor.request_inspector_view.emit()

# Edge Selection Logic
func _handle_edge_click(edge_pair: Array) -> void:
	edge_pair.sort() 
	
	if Input.is_key_pressed(KEY_SHIFT) or Input.is_key_pressed(KEY_CTRL):
		_editor.toggle_edge_selection(edge_pair)
	else:
		_editor.clear_selection()
		_editor.set_edge_selection(edge_pair)

func _start_moving_node(id: String) -> void:
	_drag_node_id = id
	_renderer.drag_start_id = id
	
	var nodes_to_action: Array[String] = [id]
	var is_group_action: bool = false
	var active_group_zone: GraphZone = null 
	
	# 1. IDENTIFY TARGETS (Group Logic)
	if _graph.zones:
		for zone in _graph.zones:
			if zone.is_grouped and zone.contains_node(id):
				is_group_action = true
				active_group_zone = zone 
				
				for peer_id in zone.registered_nodes:
					if not nodes_to_action.has(peer_id):
						nodes_to_action.append(peer_id)

	# --- 2. SELECTION MODIFICATION (BATCHED) ---
	if Input.is_key_pressed(KEY_SHIFT):
		var nodes_to_add: Array[String] = []
		for target in nodes_to_action:
			if not _editor.selected_nodes.has(target):
				nodes_to_add.append(target)
		
		if not nodes_to_add.is_empty():
			_editor.set_selection_batch(nodes_to_add, [], false)
			
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
				
		if selection_changed:
			_editor.set_selection_batch(new_selection, _editor.selected_edges, true)
			
	else:
		if is_group_action:
			if not _editor.selected_nodes.has(id):
				_editor.set_selection_batch(nodes_to_action, [], true)
		else:
			if not _editor.selected_nodes.has(id):
				_editor.set_selection_batch([id], [], true)

	# --- SYNC ZONE SELECTION ---
	if is_group_action and active_group_zone:
		_editor.set_zone_selection([active_group_zone], false)
	
	# --- 3. PREPARE MOVEMENT ---
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
	# --- COMMIT UNDO HISTORY ---
	if not _drag_start_positions.is_empty():
		var move_payload = {}
		for id in _drag_start_positions:
			if _graph.nodes.has(id):
				move_payload[id] = {
					"from": _drag_start_positions[id],
					"to": _graph.nodes[id].position
				}
		_editor.commit_move_batch(move_payload)
	
	# --- CLEANUP ---
	_reset_tool_state()

# --- BOX SELECTION (OPTIMIZED) ---
func _start_box_selection(pos: Vector2) -> void:
	_box_start_pos = pos

func _finish_box_selection(mouse_pos: Vector2) -> void:
	var drag_dist = _box_start_pos.distance_to(mouse_pos)
	
	# --- 1. CLICK / CANCEL LOGIC ---
	if drag_dist < DRAG_THRESHOLD:
		if not Input.is_key_pressed(KEY_SHIFT) and not Input.is_key_pressed(KEY_CTRL):
			_perform_global_deselect()
			print("SelectTool: Left Click Empty -> Reset Complete")
		
		_reset_tool_state()
		return
	
	# --- 2. BOX SELECTION LOGIC ---
	var rect = _get_rect(_box_start_pos, mouse_pos)
	var nodes_in_box = _graph.get_nodes_in_rect(rect)
	var edges_in_box = _graph.get_edges_in_rect(rect) 
	
	var agents_in_box = []
	for id in nodes_in_box:
		agents_in_box.append_array(_graph.get_agents_at_node(id))
	
	var is_shift = Input.is_key_pressed(KEY_SHIFT)
	var is_ctrl = Input.is_key_pressed(KEY_CTRL)
	
	if not is_shift and not is_ctrl:
		# REPLACE
		for pair in edges_in_box: pair.sort()
		_editor.set_selection_batch(nodes_in_box, edges_in_box, true)
		
		if not agents_in_box.is_empty():
			_editor.set_agent_selection(agents_in_box, false)
			
	elif is_shift:
		# ADD
		var nodes_to_add: Array[String] = []
		for id in nodes_in_box:
			if not _editor.selected_nodes.has(id): nodes_to_add.append(id)
				
		var edges_to_add: Array = []
		for pair in edges_in_box:
			pair.sort()
			if not _editor.is_edge_selected(pair): edges_to_add.append(pair)
		
		if not nodes_to_add.is_empty() or not edges_to_add.is_empty():
			_editor.set_selection_batch(nodes_to_add, edges_to_add, false)
			if not agents_in_box.is_empty():
				_add_agents_to_selection(agents_in_box)

	elif is_ctrl:
		# SUBTRACT
		var final_nodes = _editor.selected_nodes.duplicate()
		for id in nodes_in_box:
			if final_nodes.has(id): final_nodes.erase(id)
		
		var final_edges = _editor.selected_edges.duplicate()
		for pair in edges_in_box:
			pair.sort()
			if _editor.is_edge_selected(pair): final_edges.erase(pair)
		
		_editor.set_selection_batch(final_nodes, final_edges, true)
		_remove_agents_from_selection(agents_in_box)
			
	_reset_tool_state()

# --- UTILITIES ---

func _perform_global_deselect() -> void:
	_editor.clear_selection()
	_editor.set_zone_selection([], false)

func _reset_tool_state() -> void:
	_drag_node_id = ""
	_box_start_pos = Vector2.INF
	_group_offsets.clear()
	_drag_start_positions.clear()
	
	_renderer.selection_rect = Rect2()
	_renderer.pre_selection_ref = []
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

func _get_rect(p1: Vector2, p2: Vector2) -> Rect2:
	var min_x = min(p1.x, p2.x)
	var max_x = max(p1.x, p2.x)
	var min_y = min(p1.y, p2.y)
	var max_y = max(p1.y, p2.y)
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

func exit() -> void:
	_reset_tool_state()
