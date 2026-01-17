class_name GraphToolSpawner
extends GraphTool

# Dependencies
var _target_strategy: StrategyWalker
var _drag_handler: GraphDragHandler

# Mode State
enum Mode { CREATE = 0, SELECT = 1, DELETE = 2 }
var _current_mode: int = Mode.CREATE

# ==============================================================================
# 1. LIFECYCLE & INPUT
# ==============================================================================

func enter() -> void:
	if _ensure_strategy_active():
		_drag_handler = GraphDragHandler.new(_editor)
		
		# Connect Signals
		if not _drag_handler.clicked.is_connected(_on_click_action):
			_drag_handler.clicked.connect(_on_click_action)
		if not _drag_handler.box_selected.is_connected(_on_box_selection):
			_drag_handler.box_selected.connect(_on_box_selection)
			
		# Connect Live Drag Feedback
		if not _drag_handler.drag_updated.is_connected(_on_drag_update):
			_drag_handler.drag_updated.connect(_on_drag_update)
		
		_current_mode = Mode.CREATE
		_update_status_display()

func exit() -> void:
	_reset_visuals()

func handle_input(event: InputEvent) -> void:
	# 1. Let the DragHandler component handle Left Clicks & Drags
	if _drag_handler.handle_input(event):
		return
		
	# 2. Hover Logic (Mouse Motion)
	if event is InputEventMouseMotion:
		_update_hover_highlight()
		
	# 3. Handle Right Click (Mode Cycle)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cycle_mode()

# ==============================================================================
# 2. VISUAL FEEDBACK
# ==============================================================================

func _update_hover_highlight() -> void:
	# We only want the "Blue Ring" when we are about to SPAWN something.
	if _current_mode != Mode.CREATE:
		_editor.tool_overlay_rect = Rect2()
		return

	var global_mouse = _editor.get_global_mouse_position()
	var node_id = _get_node_at_pos(global_mouse)
	
	if node_id != "":
		# Found a node! Draw the "Blue Ring" (Overlay Rect) around it.
		var pos = _editor.graph.get_node_pos(node_id)
		var radius = GraphSettings.NODE_RADIUS 
		var size = Vector2(radius * 2.5, radius * 2.5)
		
		# Center the rect on the node
		_editor.tool_overlay_rect = Rect2(pos - size/2, size)
	else:
		_editor.tool_overlay_rect = Rect2()

func _on_drag_update(rect: Rect2) -> void:
	if _current_mode != Mode.SELECT and _current_mode != Mode.DELETE:
		return
		
	# Transform Rect to Local
	var global_tl = rect.position
	var global_br = rect.end
	var local_tl = _editor.renderer.to_local(global_tl)
	var local_br = _editor.renderer.to_local(global_br)
	var local_rect = Rect2(local_tl, local_br - local_tl).abs()
	
	# Ask Renderer for visual overlap
	var agents_in_box = _editor.renderer.get_agents_in_visual_rect(local_rect)
	
	# Update visual highlight
	_editor.renderer.pre_selected_agents_ref = agents_in_box
	_editor.renderer.queue_redraw()
	
	# Status Update
	if not agents_in_box.is_empty():
		var action = "Deleting" if _current_mode == Mode.DELETE else "Selecting"
		_show_status("%s %d Agents..." % [action, agents_in_box.size()])
	else:
		_show_status("Drag to select...")

func _reset_visuals() -> void:
	_editor.tool_overlay_rect = Rect2()
	if _editor.renderer:
		_editor.renderer.pre_selected_agents_ref = []
		_editor.renderer.queue_redraw()

# ==============================================================================
# 3. ACTIONS (CLICKS)
# ==============================================================================

func _on_click_action(_pos: Vector2) -> void:
	match _current_mode:
		Mode.CREATE: _spawn_under_mouse()
		Mode.SELECT: _select_agent_under_mouse()
		Mode.DELETE: _delete_agent_under_mouse()

func _spawn_under_mouse() -> void:
	if not _ensure_strategy_active(): return
	var mouse_pos = _editor.get_global_mouse_position()
	var id = _get_node_at_pos(mouse_pos)
	
	if id != "":
		# 1. Create the object
		var agent = _target_strategy.create_agent_for_node(id, _editor.graph)
		
		if agent:
			# 2. Add via Editor
			_editor.add_agent(agent)
			
			# Select the NODE to show context
			_editor.set_selection_batch([id], [], true)
			_update_markers()
			
			if _editor.has_signal("request_inspector_view"):
				_editor.request_inspector_view.emit()
			
			_show_status("Agent Spawned!")

func _select_agent_under_mouse() -> void:
	if not _ensure_strategy_active(): return
	
	var is_shift = Input.is_key_pressed(KEY_SHIFT)
	var is_ctrl = Input.is_key_pressed(KEY_CTRL)
	
	var global_mouse = _editor.get_global_mouse_position()
	var local_pos = _editor.renderer.to_local(global_mouse)
	var hit_agent = _editor.renderer.get_agent_at_position(local_pos)
	
	if hit_agent:
		var current_selection = _editor.selected_agent_ids.duplicate()
		var is_already_selected = hit_agent in current_selection
		
		if is_ctrl:
			# TOGGLE
			if is_already_selected:
				current_selection.erase(hit_agent)
			else:
				current_selection.append(hit_agent)
			_editor.set_agent_selection(current_selection, false)
				
		elif is_shift:
			# ADD
			if not is_already_selected:
				current_selection.append(hit_agent)
				_editor.set_agent_selection(current_selection, false)

		else:
			# EXCLUSIVE (Replace)
			# [FIX] Use 'true' for second arg to clear nodes/edges automatically
			# This avoids the redundant _editor.clear_selection() call
			_editor.set_agent_selection([hit_agent], true)
		
		if _editor.has_signal("request_inspector_view"):
			_editor.request_inspector_view.emit()
		return

	# Fallback: Check Node Hit (Standard Selection)
	var id = _get_node_at_pos(global_mouse)
	if id != "":
		# Clicking a node without modifiers clears agent selection
		if not is_shift and not is_ctrl:
			_editor.set_agent_selection([], false) 
			_editor.set_selection_batch([id], [], true)
		elif is_shift:
			_editor.add_to_selection(id)
		elif is_ctrl:
			_editor.toggle_selection(id)
		return

	# Background Click
	if not is_shift and not is_ctrl:
		_perform_deselect()

func _delete_agent_under_mouse() -> void:
	if not _ensure_strategy_active(): return
	
	# 1. Check Precision Hit
	var global_mouse = _editor.get_global_mouse_position()
	var local_pos = _editor.renderer.to_local(global_mouse)
	var hit_agent = _editor.renderer.get_agent_at_position(local_pos)
	
	if hit_agent:
		_editor.remove_agent(hit_agent)
		_perform_deselect()
		_update_markers() 
		_show_status("Deleted Agent.")
		return

	# 2. Fallback: Bulk Delete at Node
	var id = _get_node_at_pos(global_mouse)
	if id == "": return
	
	var agents = _editor.graph.get_agents_at_node(id)
	if agents.is_empty():
		_show_status("Nothing to delete here.")
		return

	for agent in agents:
		_editor.remove_agent(agent)
	
	_perform_deselect()
	_update_markers()             
	_show_status("Deleted %d Agent(s)." % agents.size())

# ==============================================================================
# 4. BOX SELECTION (UPDATED)
# ==============================================================================

func _on_box_selection(rect: Rect2) -> void:
	# 1. Convert Rect
	var global_tl = rect.position
	var global_br = rect.end
	var local_tl = _editor.renderer.to_local(global_tl)
	var local_br = _editor.renderer.to_local(global_br)
	var local_rect = Rect2(local_tl, local_br - local_tl).abs()
	
	# 2. Find Agents
	var agents_in_box = _editor.renderer.get_agents_in_visual_rect(local_rect)
	
	# Clear visual feedback immediately
	_editor.renderer.pre_selected_agents_ref = []
	_editor.renderer.queue_redraw()
	
	if _current_mode == Mode.DELETE:
		if not agents_in_box.is_empty():
			for a in agents_in_box: _editor.remove_agent(a)
			_perform_deselect()
			_update_markers()
			
	else: # SELECT MODE
		var is_shift = Input.is_key_pressed(KEY_SHIFT)
		var is_ctrl = Input.is_key_pressed(KEY_CTRL)
		
		# [FIX] Empty Box Logic
		if agents_in_box.is_empty():
			if not is_shift and not is_ctrl:
				_perform_deselect()
			return

		# [FIX] Multi-Select Logic (Cleaner)
		var final_selection = []
		
		if is_ctrl:
			# SUBTRACT
			final_selection = _get_selected_agent_objects()
			for agent in agents_in_box:
				if agent in final_selection:
					final_selection.erase(agent)
					
		elif is_shift:
			# ADD
			final_selection = _get_selected_agent_objects()
			for agent in agents_in_box:
				if not agent in final_selection:
					final_selection.append(agent)
					
		else:
			# REPLACE
			# We use 'true' to clear nodes/edges automatically
			_editor.set_agent_selection(agents_in_box, true)
			_show_status("Selected %d Agents." % agents_in_box.size())
			
			if _editor.has_signal("request_inspector_view"):
				_editor.request_inspector_view.emit()
			return # Exit early since we handled assignment

		# Apply (Ctrl/Shift branches)
		_editor.set_agent_selection(final_selection, false)
		_show_status("Selected %d Agents." % final_selection.size())
		
		if _editor.has_signal("request_inspector_view"):
			_editor.request_inspector_view.emit()

# ==============================================================================
# 5. UTILITIES
# ==============================================================================

func _perform_deselect() -> void:
	_editor.clear_selection()
	_show_status("Selection Cleared.")

func _cycle_mode() -> void:
	_current_mode = (_current_mode + 1) % 3
	_update_status_display()
	_reset_visuals() # Important cleanup

func _update_status_display() -> void:
	match _current_mode:
		Mode.CREATE:
			_show_status("[CREATE] L-Click: Spawn | Drag: Select | R-Click: Switch")
		Mode.SELECT:
			_show_status("[SELECT] L-Click: Inspect | Drag: Select | R-Click: Switch")
		Mode.DELETE:
			_show_status("[DELETE] L-Click: Remove | Drag: Select | R-Click: Switch")

func _get_selected_agent_objects() -> Array:
	var list = []
	if not _editor or not _editor.graph: return list
	if _editor.selected_agent_ids.is_empty(): return list
		
	for item in _editor.selected_agent_ids:
		if item is RefCounted:
			list.append(item)
	return list

func _update_markers() -> void:
	var agent_positions: Array[String] = []
	var agent_starts: Array[String] = []
	
	if _editor and _editor.graph:
		for agent in _editor.graph.agents:
			var is_active = agent.get("active") if "active" in agent else true
			
			if is_active:
				if "current_node_id" in agent and agent.current_node_id != "":
					agent_positions.append(agent.current_node_id)
				if "start_node_id" in agent and agent.start_node_id != "":
					agent_starts.append(agent.start_node_id)

	_editor.set_path_ends(agent_positions)
	_editor.set_path_starts(agent_starts)

func _ensure_strategy_active() -> bool:
	if StrategyController.instance == null:
		_show_status("Error: StrategyController not initialized.")
		return false
	
	StrategyController.instance.switch_to_strategy_type(StrategyWalker)
	
	if StrategyController.instance.current_strategy is StrategyWalker:
		_target_strategy = StrategyController.instance.current_strategy
		return true
	
	_show_status("Error: Failed to switch to Agent Strategy.")
	return false
