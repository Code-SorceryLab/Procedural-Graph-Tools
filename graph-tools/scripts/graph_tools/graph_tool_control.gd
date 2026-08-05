class_name GraphToolControl
extends GraphTool

var controlled_agent: AgentWalker = null

func enter() -> void:
	controlled_agent = null
	_editor.send_status_message("[PLAY MODE] Click an Agent to take control.")
	
	# Listen to simulation steps so we can clear the UI when the agent executes the move!
	if not SignalManager.simulation_stepped.is_connected(_on_sim_step):
		SignalManager.simulation_stepped.connect(_on_sim_step)
		
	_refresh_ui()

func exit() -> void:
	_perform_deselect()
	if SignalManager.simulation_stepped.is_connected(_on_sim_step):
		SignalManager.simulation_stepped.disconnect(_on_sim_step)

# ==============================================================================
# UI INTEGRATION (Dynamic Topbar Options)
# ==============================================================================

func get_options_schema() -> Array:
	var agent_text = "None"
	var status_text = "Select an Agent..."
	
	if controlled_agent:
		agent_text = "Agent %d" % controlled_agent.display_id
		status_text = "Ready to Move (Click Neighbor)"
			
	return [
		{ "name": "info_agent", "label": "Possessed", "type": TYPE_STRING, "default": agent_text, "hint": "read_only" },
		{ "name": "info_intent", "label": "Status", "type": TYPE_STRING, "default": status_text, "hint": "read_only" }
	]

func _refresh_ui() -> void:
	# Forces the TopbarController to dynamically rebuild our read-only displays!
	if _editor.tool_manager:
		SignalManager.active_tool_changed.emit(_editor.tool_manager.active_tool_id)

func _on_sim_step(_tick: int) -> void:
	# The Simulation just ticked, which means the agent cleared its intent. Update UI!
	_refresh_ui()
	_update_action_edges()

# ==============================================================================
# INPUT LOGIC
# ==============================================================================

func handle_input(event: InputEvent) -> void:
	var mouse_pos = _editor.get_global_mouse_position()
	
	# 1. Hover Logic (Cheap visual feedback on the bottom Status Bar)
	if event is InputEventMouseMotion:
		var hover_node = _get_node_at_pos(mouse_pos)
		_editor.set_hovered_node(hover_node)
		
		if controlled_agent and hover_node != "":
			if hover_node == controlled_agent.current_node_id:
				_editor.send_status_message("Standing here.")
			else:
				var current = controlled_agent.current_node_id
				var neighbors = _editor.graph.get_neighbors(current)
				
				if neighbors.has(hover_node):
					if CapInventory.can_unlock_edge(controlled_agent, _editor.graph, current, hover_node):
						_editor.send_status_message("[VALID MOVE] Click to lock target.")
					else:
						_editor.send_status_message("[LOCKED] You don't have the required key!")
				else:
					_editor.send_status_message("[INVALID] No direct path. (DAG edges are one-way!)")
		
	# 2. Click Logic (Permanent target locking)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_click(mouse_pos)
		_editor.get_viewport().set_input_as_handled()

func _handle_click(mouse_pos: Vector2) -> void:
	# A. Try to select an Agent
	var local_pos = _editor.renderer.to_local(mouse_pos)
	var hit_agent = _editor.renderer.get_agent_at_position(local_pos)
	
	if hit_agent:
		controlled_agent = hit_agent
		_editor.set_agent_selection([controlled_agent], true)
		
		# Auto-configure the agent for Manual Play!
		# Index 6 is "Player Controlled". We also set steps to -1 so it doesn't die of old age.
		if controlled_agent.behavior_mode != 6:
			controlled_agent.apply_setting("global_behavior", 6)
		if controlled_agent.steps != -1:
			controlled_agent.apply_setting("steps", -1)
			
		_editor.send_status_message("[PLAY MODE] Controlling Agent %d." % controlled_agent.display_id)
		
		_refresh_ui()
		_update_action_edges() # Instantly draw the valid paths!
		return
		
	# B. Try to issue an Intent & Execute Immediately
	if controlled_agent:
		var target_node = _get_node_at_pos(mouse_pos)
		if target_node != "":
			var current = controlled_agent.current_node_id
			var neighbors = _editor.graph.get_neighbors(current)
			
			if neighbors.has(target_node) and CapInventory.can_unlock_edge(controlled_agent, _editor.graph, current, target_node):
				
				# 1. Lock the intent
				controlled_agent.custom_data["manual_intent"] = target_node
				
				# 2. Instantly force the simulation to process the turn
				if _editor.simulation:
					var batch = _editor.simulation.step()
					if batch: 
						_editor._commit_command(batch)
						_editor.send_status_message("Moved to %s." % target_node)
					
				_refresh_ui()
				_update_action_edges() # Refresh the valid paths from the new location!

func _perform_deselect() -> void:
	controlled_agent = null
	_editor.clear_selection()
	_update_action_edges()
	_editor.send_status_message("Controlling ended.")
	_refresh_ui()

func _update_action_edges() -> void:
	var valid_edges = []
	var breadcrumbs = []
	
	if controlled_agent:
		var current = controlled_agent.current_node_id
		
		# 1. Calculate Valid Moves (Green animated lines)
		var neighbors = _editor.graph.get_neighbors(current)
		for n in neighbors:
			if CapInventory.can_unlock_edge(controlled_agent, _editor.graph, current, n):
				valid_edges.append([current, n])
				
		# 2. Extract History (Breadcrumb trail)
		var path_points = PackedVector2Array()
		for entry in controlled_agent.history:
			var node_id = entry.get("node", "")
			if _editor.graph.nodes.has(node_id):
				path_points.append(_editor.graph.nodes[node_id].position)
				
		if path_points.size() > 0:
			breadcrumbs.append(path_points)
				
	# Send to Editor
	if _editor.has_method("set_action_edges"):
		_editor.set_action_edges(valid_edges)
		
	if _editor.has_method("set_agent_breadcrumbs"):
		_editor.set_agent_breadcrumbs(breadcrumbs)
