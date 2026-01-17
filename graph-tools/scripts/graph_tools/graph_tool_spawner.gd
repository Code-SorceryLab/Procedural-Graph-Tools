class_name GraphToolSpawner
extends GraphTool

# Dependencies
var _target_strategy: StrategyWalker
var _drag_handler: GraphDragHandler

# Mode State
enum Mode { CREATE = 0, SELECT = 1, DELETE = 2 }
var _current_mode: int = Mode.CREATE

func enter() -> void:
	if _ensure_strategy_active():
		_drag_handler = GraphDragHandler.new(_editor)
		
		if not _drag_handler.clicked.is_connected(_on_click_action):
			_drag_handler.clicked.connect(_on_click_action)
		if not _drag_handler.box_selected.is_connected(_on_box_selection):
			_drag_handler.box_selected.connect(_on_box_selection)
			
		# Connect Live Drag
		if not _drag_handler.drag_updated.is_connected(_on_drag_update):
			_drag_handler.drag_updated.connect(_on_drag_update)
		
		_current_mode = Mode.CREATE
		_update_status_display()

func exit() -> void:
	_editor.tool_overlay_rect = Rect2()
	# Clear pre-selection on exit
	if _editor.renderer:
		_editor.renderer.pre_selected_agents_ref = []
		_editor.renderer.queue_redraw()
	
	

# Live Feedback Handler
func _on_drag_update(rect: Rect2) -> void:
	if _current_mode != Mode.SELECT and _current_mode != Mode.DELETE:
		return
		
	# Convert Global Screen Rect to Local Renderer Rect
	# We transform top-left and bottom-right to handle zoom/pan
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
	
	# [OPTIONAL] Live Status Update
	if not agents_in_box.is_empty():
		_show_status("Selecting %d Agents..." % agents_in_box.size())
	else:
		_show_status("Drag to select...")

func handle_input(event: InputEvent) -> void:
	# 1. Let the Component handle Left Clicks & Drags
	if _drag_handler.handle_input(event):
		return
		
	# 2. [NEW] Hover Logic (Mouse Motion)
	if event is InputEventMouseMotion:
		_update_hover_highlight()
		
	# 3. Handle Right Click (Mode Cycle) manually
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cycle_mode()

# [NEW] Visual Feedback Logic
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
		var radius = GraphSettings.NODE_RADIUS # Typically 20.0
		var size = Vector2(radius * 2.5, radius * 2.5) # Slightly larger than node
		
		# Center the rect on the node
		_editor.tool_overlay_rect = Rect2(pos - size/2, size)
	else:
		# Clear if hovering empty space
		_editor.tool_overlay_rect = Rect2()

# --- INPUT HANDLERS (From Component) ---

# Called when user clicks without dragging (< 10px)
func _on_click_action(_pos: Vector2) -> void:
	# Execute the logic for the current mode
	match _current_mode:
		Mode.CREATE: _spawn_under_mouse()
		Mode.SELECT: _select_agent_under_mouse()
		Mode.DELETE: _delete_agent_under_mouse()

# --- BOX SELECTION (UPDATED) ---
func _on_box_selection(rect: Rect2) -> void:
	# 1. Convert Rect
	var global_tl = rect.position
	var global_br = rect.end
	var local_tl = _editor.renderer.to_local(global_tl)
	var local_br = _editor.renderer.to_local(global_br)
	var local_rect = Rect2(local_tl, local_br - local_tl).abs()
	
	# 2. Find Agents in Box
	var agents_in_box = _editor.renderer.get_agents_in_visual_rect(local_rect)
	
	_editor.renderer.pre_selected_agents_ref = []
	_editor.renderer.queue_redraw()
	
	if _current_mode == Mode.DELETE:
		# ... (Delete logic same as before)
		if not agents_in_box.is_empty():
			for a in agents_in_box: _editor.remove_agent(a)
			_editor.clear_selection()
			_update_markers()
			
	else: # SELECT MODE
		var is_shift = Input.is_key_pressed(KEY_SHIFT)
		var is_ctrl = Input.is_key_pressed(KEY_CTRL)
		
		# [FIX] Empty Box Logic
		if agents_in_box.is_empty():
			# If checking empty space without modifiers, clear selection
			if not is_shift and not is_ctrl:
				_editor.clear_selection()
				_editor.set_agent_selection([], false)
			return

		# [FIX] Multi-Select Logic
		var final_selection = []
		
		if is_ctrl:
			# SUBTRACT: Start with EVERYTHING we currently have
			final_selection = _get_selected_agent_objects()
			
			# Remove items found in the box
			for agent in agents_in_box:
				if agent in final_selection:
					final_selection.erase(agent)
					
		elif is_shift:
			# ADD: Start with EVERYTHING we currently have
			final_selection = _get_selected_agent_objects()
			
			# Add items found in the box (avoid duplicates)
			for agent in agents_in_box:
				if not agent in final_selection:
					final_selection.append(agent)
					
		else:
			# REPLACE: Only what is in the box
			_editor.clear_selection() # Clear nodes
			final_selection = agents_in_box

		# Apply
		_editor.set_agent_selection(final_selection, false)
		_show_status("Selected %d Agents." % final_selection.size())
		
		if _editor.has_signal("request_inspector_view"):
			_editor.request_inspector_view.emit()

# --- MODE LOGIC ---

func _cycle_mode() -> void:
	_current_mode = (_current_mode + 1) % 3
	_update_status_display()
	
	# Clear highlight immediately on mode switch
	_editor.tool_overlay_rect = Rect2()

func _update_status_display() -> void:
	match _current_mode:
		Mode.CREATE:
			_show_status("[CREATE] L-Click: Spawn | Drag: Select | R-Click: Switch")
		Mode.SELECT:
			_show_status("[SELECT] L-Click: Inspect | Drag: Select | R-Click: Switch")
		Mode.DELETE:
			_show_status("[DELETE] L-Click: Remove | Drag: Select | R-Click: Switch")

# --- ACTIONS ---

func _spawn_under_mouse() -> void:
	if not _ensure_strategy_active(): return
	var mouse_pos = _editor.get_global_mouse_position()
	var id = _get_node_at_pos(mouse_pos)
	
	if id != "":
		# 1. Create the object (Factory)
		var agent = _target_strategy.create_agent_for_node(id, _editor.graph)
		
		if agent:
			# 2. Add via Editor (History/Undo)
			_editor.add_agent(agent)
			
			_editor.set_selection_batch([id], [])
			_update_markers()
			
			if _editor.has_signal("request_inspector_view"):
				_editor.request_inspector_view.emit()
			
			_show_status("Agent Spawned!")

# --- SINGLE CLICK SELECTION ---
func _select_agent_under_mouse() -> void:
	if not _ensure_strategy_active(): return
	
	var is_shift = Input.is_key_pressed(KEY_SHIFT)
	var is_ctrl = Input.is_key_pressed(KEY_CTRL)
	
	var global_mouse = _editor.get_global_mouse_position()
	var local_pos = _editor.renderer.to_local(global_mouse)
	var hit_agent = _editor.renderer.get_agent_at_position(local_pos)
	
	if hit_agent:
		# Use the list directly since it holds Objects
		var current_selection = _editor.selected_agent_ids.duplicate()
		var is_already_selected = hit_agent in current_selection
		
		if is_ctrl:
			# SUBTRACT / TOGGLE
			if is_already_selected:
				current_selection.erase(hit_agent)
				_editor.set_agent_selection(current_selection, false)
				
				# [FIX] Use display_id for messaging
				var d_id = hit_agent.display_id if "display_id" in hit_agent else -1
				_show_status("Deselected Agent #%d" % d_id)
			else:
				current_selection.append(hit_agent)
				_editor.set_agent_selection(current_selection, false)
				
				var d_id = hit_agent.display_id if "display_id" in hit_agent else -1
				_show_status("Added Agent #%d" % d_id)
				
		elif is_shift:
			# ADDITIVE
			if not is_already_selected:
				current_selection.append(hit_agent)
				_editor.set_agent_selection(current_selection, false)
				
				var d_id = hit_agent.display_id if "display_id" in hit_agent else -1
				_show_status("Added Agent #%d" % d_id)

		else:
			# EXCLUSIVE (Normal Click)
			_editor.clear_selection()
			_editor.set_agent_selection([hit_agent], false)
			
			var d_id = hit_agent.display_id if "display_id" in hit_agent else -1
			_show_status("Selected Agent #%d" % d_id)
		
		if _editor.has_signal("request_inspector_view"):
			_editor.request_inspector_view.emit()
		return

	# ... (Node Selection Logic follows below - kept same as previous) ...
	# 2. Check Node Hit (Fallback)
	var id = _get_node_at_pos(global_mouse)
	if id != "":
		# Ensure we clear agent selection if clicking a node without modifiers
		if not is_shift and not is_ctrl:
			_editor.set_agent_selection([], false)
			_editor.clear_selection()
			
		# Standard Node selection logic...
		if is_shift: _editor.add_to_selection(id)
		elif is_ctrl: _editor.toggle_selection(id)
		else: _editor.set_selection_batch([id], [], false)
		return

	# 3. Background Click
	if not is_shift and not is_ctrl:
		_editor.clear_selection()
		_editor.set_agent_selection([], false)
		_show_status("Selection Cleared.")


# --- HELPER: Get Actual Objects ---
# [ARCHITECTURAL CHANGE]
# This helper handles the legacy "ID vs Object" confusion.
# It ensures we return a clean list of AgentWalker Objects.
func _get_selected_agent_objects() -> Array:
	var list = []
	if not _editor or not _editor.graph: return list
	
	# If nothing is selected, return empty immediately
	if _editor.selected_agent_ids.is_empty():
		return list
		
	for item in _editor.selected_agent_ids:
		# CASE A: It is already an Object (The new standard)
		if item is RefCounted: # AgentWalker is RefCounted
			list.append(item)
		# CASE B: It is a Legacy ID (The old way) - Try to recover
		elif (item is int or item is float) and "display_id" in item:
			# This branch is unlikely unless we have mixed types, 
			# but this is where you'd iterate graph.agents to find the match.
			pass
			
	return list

func _delete_agent_under_mouse() -> void:
	if not _ensure_strategy_active(): return
	
	# 1. Check Precision Hit
	var global_mouse = _editor.get_global_mouse_position()
	var local_pos = _editor.renderer.to_local(global_mouse)
	var hit_agent = _editor.renderer.get_agent_at_position(local_pos)
	
	if hit_agent:
		_editor.remove_agent(hit_agent)
		
		_editor.set_node_labels({}) 
		_editor.clear_selection()   
		_update_markers() 
		
		# [FIX] display_id for status
		var d_id = hit_agent.display_id if "display_id" in hit_agent else -1           
		_show_status("Deleted Agent #%d." % d_id)
		return

	# 2. Fallback: Bulk Delete at Node
	var id = _get_node_at_pos(global_mouse)
	if id == "": return
	
	# [FIX] Use Graph API
	var agents = _editor.graph.get_agents_at_node(id)
	if agents.is_empty():
		_show_status("Nothing to delete here.")
		return

	for agent in agents:
		_editor.remove_agent(agent)
	
	_editor.set_node_labels({}) 
	_editor.clear_selection()   
	_update_markers()            
	_show_status("Deleted %d Agent(s) from Node." % agents.size())

# --- HELPERS ---

func _update_markers() -> void:
	# Decoupled: Read directly from Graph Data
	var agent_positions: Array[String] = []
	var agent_starts: Array[String] = []
	
	if _editor and _editor.graph:
		for agent in _editor.graph.agents:
			# [FIX] Safe Property Access
			# 1. Check if 'active' exists, otherwise assume true (default)
			var is_active = true
			if "active" in agent:
				is_active = agent.active
			
			if is_active:
				# 2. Get Current Position (Red Markers)
				# Check property existence to support different agent types
				if "current_node_id" in agent and agent.current_node_id != "":
					agent_positions.append(agent.current_node_id)
				
				# 3. Get Start Position (Green Markers)
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
