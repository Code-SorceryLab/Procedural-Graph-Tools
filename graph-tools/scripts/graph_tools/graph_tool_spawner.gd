class_name GraphToolSpawner
extends GraphTool

# Dependencies
var _target_strategy: StrategyWalker
var _drag_handler: GraphDragHandler # [NEW] Component for handling Drag vs Click

# Mode State
enum Mode { CREATE = 0, SELECT = 1, DELETE = 2 }
var _current_mode: int = Mode.CREATE

func enter() -> void:
	if _ensure_strategy_active():
		# 1. Initialize the Drag Handler Component
		_drag_handler = GraphDragHandler.new(_editor)
		
		# 2. Connect Component Signals
		# If user clicks (no drag), we execute the current mode (Spawn/Select/Delete)
		if not _drag_handler.clicked.is_connected(_on_click_action):
			_drag_handler.clicked.connect(_on_click_action)
			
		# If user drags, we perform a box selection (Override)
		if not _drag_handler.box_selected.is_connected(_on_box_selection):
			_drag_handler.box_selected.connect(_on_box_selection)
		
		_current_mode = Mode.CREATE
		_update_status_display()

func handle_input(event: InputEvent) -> void:
	# 1. Let the Component handle Left Clicks & Drags
	if _drag_handler.handle_input(event):
		return
		
	# 2. Handle Right Click (Mode Cycle) manually
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_cycle_mode()

# --- INPUT HANDLERS (From Component) ---

# Called when user clicks without dragging (< 10px)
func _on_click_action(_pos: Vector2) -> void:
	# Execute the logic for the current mode
	match _current_mode:
		Mode.CREATE: _spawn_under_mouse()
		Mode.SELECT: _select_agent_under_mouse()
		Mode.DELETE: _delete_agent_under_mouse()

# Called when user finishes dragging a box (> 10px)
func _on_box_selection(rect: Rect2) -> void:
	# 1. Query Graph for nodes in box
	var nodes_in_area = _editor.graph.get_nodes_in_rect(rect)
	
	# 2. Filter: Only pick nodes that have Walkers
	var relevant_nodes: Array[String] = []
	for id in nodes_in_area:
		var agents = _target_strategy.get_walkers_at_node(id)
		if not agents.is_empty():
			relevant_nodes.append(id)
			
	# 3. Apply Selection
	if not relevant_nodes.is_empty():
		_editor.set_selection_batch(relevant_nodes, [])
		
		# Force Inspector Open
		if _editor.has_signal("request_inspector_view"):
			_editor.request_inspector_view.emit()
			
		_show_status("Box Selected %d Nodes." % relevant_nodes.size())
	else:
		_editor.clear_selection()
		_show_status("No agents in selection area.")

# --- MODE LOGIC (Unchanged) ---

func _cycle_mode() -> void:
	_current_mode = (_current_mode + 1) % 3
	_update_status_display()

func _update_status_display() -> void:
	match _current_mode:
		Mode.CREATE:
			_show_status("[CREATE] L-Click: Spawn | Drag: Select | R-Click: Switch")
		Mode.SELECT:
			_show_status("[SELECT] L-Click: Inspect | Drag: Select | R-Click: Switch")
		Mode.DELETE:
			_show_status("[DELETE] L-Click: Remove | Drag: Select | R-Click: Switch")

# --- ACTIONS (With your Inspector Signals included) ---

func _spawn_under_mouse() -> void:
	if not _ensure_strategy_active(): return
	var mouse_pos = _editor.get_global_mouse_position()
	var id = _get_node_at_pos(mouse_pos)
	
	if id != "":
		_target_strategy.add_agent_at_node(id, _editor.graph)
		_editor.set_selection_batch([id], [])
		_update_markers()
		
		if _editor.has_signal("request_inspector_view"):
			_editor.request_inspector_view.emit()
		
		_show_status("Agent Spawned!")

func _select_agent_under_mouse() -> void:
	if not _ensure_strategy_active(): return
	var mouse_pos = _editor.get_global_mouse_position()
	var id = _get_node_at_pos(mouse_pos)
	
	if id != "":
		var agents = _target_strategy.get_walkers_at_node(id)
		if not agents.is_empty():
			_editor.set_selection_batch([id], [])
			if _editor.has_signal("request_inspector_view"):
				_editor.request_inspector_view.emit()
			_show_status("Agent Selected.")
		else:
			_show_status("No agents found here.")
			_editor.clear_selection()
	else:
		_editor.clear_selection()

func _delete_agent_under_mouse() -> void:
	if not _ensure_strategy_active(): return
	var mouse_pos = _editor.get_global_mouse_position()
	var id = _get_node_at_pos(mouse_pos)
	
	if id == "": return
	var agents = _target_strategy.get_walkers_at_node(id)
	
	if agents.is_empty():
		_show_status("Nothing to delete here.")
		return

	for agent in agents:
		_target_strategy.remove_agent(agent)
	
	_editor.set_node_labels({}) 
	_editor.clear_selection()   
	_update_markers()          
	_show_status("Deleted %d Agent(s)." % agents.size())

# --- HELPERS ---

func _update_markers() -> void:
	if _target_strategy:
		var agent_positions = _target_strategy.get_all_agent_positions()
		_editor.set_path_ends(agent_positions)
		var agent_starts = _target_strategy.get_all_agent_starts()
		_editor.set_path_starts(agent_starts)

func _ensure_strategy_active() -> bool:
	if StrategyController.instance == null:
		_show_status("Error: StrategyController not initialized.")
		return false
	
	# 1. Force switch
	StrategyController.instance.switch_to_strategy_type(StrategyWalker)
	
	# 2. Cache reference
	if StrategyController.instance.current_strategy is StrategyWalker:
		_target_strategy = StrategyController.instance.current_strategy
		return true
	
	_show_status("Error: Failed to switch to Agent Strategy.")
	return false
