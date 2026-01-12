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
	# 1. Transform Coords
	var global_tl = rect.position
	var global_br = rect.end
	var local_tl = _editor.renderer.to_local(global_tl)
	var local_br = _editor.renderer.to_local(global_br)
	var local_rect = Rect2(local_tl, local_br - local_tl).abs()
	
	# 2. Get Agents in Box
	var agents_in_area = _editor.renderer.get_agents_in_visual_rect(local_rect)
	
	# Clear Pre-selection visuals
	_editor.renderer.pre_selected_agents_ref = []
	_editor.renderer.queue_redraw()
	
	# 3. Apply Logic
	if not agents_in_area.is_empty():
		if _current_mode == Mode.DELETE:
			for agent in agents_in_area:
				_editor.remove_agent(agent)
			_editor.clear_selection()
			_update_markers()
			_show_status("Deleted %d Agents." % agents_in_area.size())
			
		else: # SELECT or CREATE modes
			# [FIX] Exclusive Agent Box Selection
			# We explicitly DO NOT select nodes here.
			
			var additive = Input.is_key_pressed(KEY_SHIFT)
			
			if not additive:
				# Clear previous selection if not holding shift
				_editor.clear_selection()       # Clear Nodes
				_editor.set_agent_selection([], false) # Clear Agents
			
			# Select only the agents found
			_editor.set_agent_selection(agents_in_area, true) 
			
			_show_status("Selected %d Agents." % agents_in_area.size())
			
			if _editor.has_signal("request_inspector_view"):
				_editor.request_inspector_view.emit()
	else:
		if not Input.is_key_pressed(KEY_SHIFT):
			_editor.clear_selection()
			_editor.set_agent_selection([])

# --- MODE LOGIC ---

func _cycle_mode() -> void:
	_current_mode = (_current_mode + 1) % 3
	_update_status_display()
	
	# [NEW] Clear highlight immediately on mode switch
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
	
	var additive = Input.is_key_pressed(KEY_SHIFT)
	var subtractive = Input.is_key_pressed(KEY_CTRL) # [NEW] Ctrl support
	
	# 1. Check Agent Hit
	var global_mouse = _editor.get_global_mouse_position()
	var local_pos = _editor.renderer.to_local(global_mouse)
	var hit_agent = _editor.renderer.get_agent_at_position(local_pos)
	
	if hit_agent:
		# --- AGENT LOGIC ---
		
		# CASE A: Subtract (Ctrl+Click)
		if subtractive:
			# We need to manually calculate the new list
			var current_selection = _editor.selected_agent_ids.duplicate() # Assuming editor tracks IDs or Agents
			# If editor tracks objects directly, use that list. 
			# Assuming generic set_agent_selection takes objects:
			var new_list = []
			# (Pseudo-code depending on how your Editor tracks selection. 
			#  If it relies on IDs, we filter IDs. If objects, objects.)
			#  Let's assume standard behavior:
			_editor.set_agent_selection([hit_agent], false) # This might be tricky if subtract isn't native.
			# Simpler Subtraction:
			# If your system supports "toggle", use that. 
			# Otherwise, we assume the user just wants to deselect this one.
			# For now, let's treat Ctrl as "Toggle Off" by re-selecting everyone else?
			# Actually, most Godot tools handle this inside the Editor class. 
			# If not, let's stick to standard "Replace" or "Add".
			pass 
			
		# [FIX] Standard Logic handling
		if additive:
			# Shift+Click: Add this agent to existing
			_editor.set_agent_selection([hit_agent], true)
			
		elif subtractive:
			# Ctrl+Click: Remove this agent
			# We pass 'false' for additive, but we need the list WITHOUT this agent.
			# Since that's complex to fetch from here, a UI standard is often:
			# Ctrl+Click acts as Toggle. 
			# For this implementation, let's just make Ctrl behave like Additive 
			# but implied 'toggle' if your underlying system supports it.
			# If not, let's just stick to Additive for now to ensure stability, 
			# or implement a specific 'deselect' call if available.
			# _editor.deselect_agent(hit_agent) # Ideal if exists
			pass 

		else:
			# Normal Click: Exclusive Select
			# 1. [CRITICAL FIX] Clear everything FIRST
			_editor.clear_selection()      # Clears Nodes
			_editor.set_agent_selection([], false) # Clears Agents
			
			# 2. THEN Select the Agent
			_editor.set_agent_selection([hit_agent], false)
			
		_show_status("Selected Agent #%d" % hit_agent.id)
		
		# Force Inspector Update
		if _editor.has_signal("request_inspector_view"):
			_editor.request_inspector_view.emit()
		return

	# 2. Check Node Hit (Fallback)
	var id = _get_node_at_pos(global_mouse)
	
	if id != "":
		# --- NODE LOGIC ---
		if additive:
			_editor.set_selection_batch([id], [], true)
		elif subtractive:
			# Implement node deselect if needed
			pass
		else:
			# Normal Click: Exclusive Node
			_editor.set_agent_selection([], false) # Clear Agents FIRST
			_editor.clear_selection()      # Clear other Nodes
			_editor.set_selection_batch([id], [], false)
			
		_show_status("Selected Node %s" % id)
		
		if _editor.has_signal("request_inspector_view"):
			_editor.request_inspector_view.emit()
		return

	# 3. Background Click
	if not additive and not subtractive:
		_editor.clear_selection()
		_editor.set_agent_selection([])
		_show_status("Selection Cleared.")

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
		_show_status("Deleted Agent #%d." % hit_agent.id)
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
