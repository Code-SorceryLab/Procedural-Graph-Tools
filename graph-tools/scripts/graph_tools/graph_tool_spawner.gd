class_name GraphToolSpawner
extends GraphTool

# We only work if the active strategy is actually a Walker Strategy
var _target_strategy: StrategyWalker

func enter() -> void:
	if _ensure_strategy_active():
		_show_status("Spawner: Click a node to place an Agent.")

func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_spawn_under_mouse()

func _spawn_under_mouse() -> void:
	if not _ensure_strategy_active():
		return
		
	var mouse_pos = _editor.get_global_mouse_position()
	var id = _get_node_at_pos(mouse_pos)
	
	if id != "":
		# 1. Spawn the Agent
		_target_strategy.add_agent_at_node(id, _editor.graph)
		
		# 2. Select the Node (Forces Inspector Update)
		_editor.set_selection_batch([id], [])
		
		# 3. [NEW] Update Visual Markers (Red Rings)
		# We grab ALL agent positions (so we don't hide previous agents) 
		# and tell the editor to treat them as "Path Ends".
		var agent_positions = _target_strategy.get_all_agent_positions()
		_editor.set_path_ends(agent_positions)
		
		_show_status("Agent Spawned! Visual marker updated.")

func _ensure_strategy_active() -> bool:
	if StrategyController.instance == null:
		_show_status("Error: StrategyController not initialized.")
		return false
	
	# 1. Force the switch (if needed)
	StrategyController.instance.switch_to_strategy_type(StrategyWalker)
	
	# 2. Cache the reference
	if StrategyController.instance.current_strategy is StrategyWalker:
		_target_strategy = StrategyController.instance.current_strategy
		return true
	
	_show_status("Error: Failed to switch to Agent Strategy.")
	return false
