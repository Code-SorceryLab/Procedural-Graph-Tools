# scripts/controllers/inspector/strategies/InspectorAgent.gd
class_name InspectorAgent
extends InspectorStrategy

# Specific Dependencies
var algo_popup: AlgorithmSettingsPopup

# State
var _tracked_agents: Array = []
var _current_walker_list: Array = []
var _current_walker_ref: Object = null
var _walker_inputs: Dictionary = {}

func _init(p_editor: GraphEditor, p_container: Control, p_popup: AlgorithmSettingsPopup) -> void:
	super._init(p_editor, p_container)
	algo_popup = p_popup
	
	# Connect Popup Signal once
	if algo_popup:
		if not algo_popup.settings_confirmed.is_connected(_on_algo_settings_confirmed):
			# We use a generic connection here; the binding happens dynamically
			algo_popup.settings_confirmed.connect(_on_algo_settings_confirmed)

func can_handle(_nodes, _edges, agents: Array, _zones) -> bool:
	return not agents.is_empty()

func enter(_nodes, _edges, agents: Array, _zones) -> void:
	super.enter(_nodes, _edges, agents, _zones)
	_tracked_agents = agents
	_update_walker_inspector_from_selection()

func update(_nodes, _edges, agents: Array, _zones) -> void:
	_tracked_agents = agents
	_update_walker_inspector_from_selection()

func exit() -> void:
	super.exit()
	_tracked_agents.clear()
	_current_walker_ref = null

# --- UI LOGIC ---

func _update_walker_inspector_from_selection() -> void:
	if _tracked_agents.is_empty(): return
	var agent = _tracked_agents[0]
	
	var context_node = agent.current_node_id
	if context_node != "":
		_populate_walker_dropdown(context_node, agent)
	else:
		_current_walker_list = [agent]
		_activate_walker_visuals(agent)

func _populate_walker_dropdown(node_id: String, target_selection = null) -> void:
	var new_list = graph_editor.graph.get_agents_at_node(node_id)
	
	if new_list != _current_walker_list:
		_current_walker_list = new_list
		# ... (Reuse the logic for populating dropdown, or expose dropdown control) ...
		# NOTE: If the dropdown is external (in Main Controller), we might need to 
		# emit a signal here to tell Main Controller to update the dropdown.
		# For now, let's assume we focus on the PROPERTY list.
		
	if not _current_walker_list.is_empty():
		var idx = 0
		if target_selection:
			idx = _current_walker_list.find(target_selection)
			if idx == -1: idx = 0
		_activate_walker_visuals(_current_walker_list[idx])

func _activate_walker_visuals(walker_obj) -> void:
	_current_walker_ref = walker_obj
	_rebuild_walker_ui()
	
	# Visuals Logic
	if walker_obj.has_method("get_history_labels"):
		graph_editor.set_node_labels(walker_obj.get_history_labels())
	
	# Update Markers (Optional: Could be moved to Main Controller as it affects global view)
	_refresh_markers()

func _rebuild_walker_ui() -> void:
	if not _current_walker_ref: return
	var ref_agent = _current_walker_ref
	var tracked_count = _tracked_agents.size()
	
	var raw_settings = ref_agent.get_agent_settings()
	var final_settings = []
	
	# --- 1. DETECT MIXED VALUES ---
	var mixed_keys = {}
	
	if tracked_count > 1:
		for item in raw_settings:
			var key = item.name
			if item.get("hint") == "action": continue
			
			var ref_val = _get_agent_value(ref_agent, key)
			
			for i in range(1, tracked_count):
				var other = _tracked_agents[i]
				var other_val = _get_agent_value(other, key)
				
				# Compare (Vector2 distance check or String check)
				if key == "pos" and ref_val is Vector2 and other_val is Vector2:
					if ref_val.distance_squared_to(other_val) > 0.1:
						mixed_keys[key] = true
						break
				elif str(other_val) != str(ref_val):
					mixed_keys[key] = true
					break

	# --- 2. BUILD HEADER & STATUS ---
	var header_text = ""
	if tracked_count == 1:
		var d_id = ref_agent.display_id if "display_id" in ref_agent else -1
		# Optional: Add UUID snippet
		var uid = ref_agent.uuid.left(6) if "uuid" in ref_agent else "???"
		header_text = "Agent #%d [%s]" % [d_id, uid]
	else:
		header_text = "%d Agents Selected" % tracked_count

	final_settings.append({
		"name": "identity_display",
		"label": "Selection", 
		"type": TYPE_STRING,
		"default": header_text,
		"hint": "read_only" 
	})
	
	# Status (Active/Paused)
	if tracked_count == 1:
		final_settings.append({
			"name": "status_display",
			"label": "Current State",
			"type": TYPE_STRING,
			"default": "Active" if ref_agent.active else "Paused",
			"hint": "read_only"
		})

	# --- 3. BUILD SETTINGS LIST ---
	var delete_action_item = null
	
	for item in raw_settings:
		var key = item.name
		
		# A. Capture Delete Button (To move to bottom)
		if key == "action_delete":
			delete_action_item = item.duplicate()
			continue
			
		var new_item = item.duplicate()
		
		# B. Apply Mixed Flag
		if mixed_keys.has(key):
			new_item["mixed"] = true
			
		# C. Inject Picker Button (Before Target Node)
		if key == "target_node":
			final_settings.append({
				"name": "action_pick_target",
				"label": "Pick Target Node",
				"type": TYPE_BOOL, 
				"hint": "action",
				"mixed": mixed_keys.get("target_node", false)
			})
			
		# D. Add the Item
		final_settings.append(new_item)
		
		# E. Inject Algorithm Config Button (After Movement Algo)
		if key == "movement_algo":
			# Only show config button if single agent selected (to avoid complexity)
			if tracked_count == 1:
				# Check if this algorithm actually HAS settings
				if _can_configure_algo(ref_agent.movement_algo):
					final_settings.append({
						"name": "action_configure_algo",
						"label": "Configure Algorithm...",
						"type": TYPE_NIL,
						"hint": "button"
					})
	
	# --- 4. FINAL APPENDS ---
	
	# Wizard Button
	final_settings.append({
		"name": "action_add_property", "label": "Add Custom Data...", "type": TYPE_NIL, "hint": "button"
	})
	
	# Delete Button (At the very bottom)
	if delete_action_item:
		if tracked_count > 1:
			delete_action_item["label"] = "Delete %d Agents" % tracked_count
		final_settings.append(delete_action_item)
	
	# --- 5. RENDER ---
	_walker_inputs = SettingsUIBuilder.render_dynamic_section(
		container, 
		final_settings, 
		_on_setting_changed
	)
	
	# Sync Picker Visuals
	if not mixed_keys.get("target_node", false):
		var t_node = ref_agent.get("target_node_id")
		SettingsUIBuilder.sync_picker_button(_walker_inputs, "action_pick_target", "Target Node", t_node)


# [RESTORED HELPER]
func _get_agent_value(agent, key: String):
	if key == "global_behavior": return agent.behavior_mode
	if key == "movement_algo": return agent.movement_algo
	if key == "target_node": return agent.target_node_id
	if key == "paint_type": return agent.my_paint_type
	if key in agent: return agent.get(key)
	return null

# --- INPUT HANDLER ---

func _on_setting_changed(key: String, value: Variant) -> void:
	if _tracked_agents.is_empty(): return
	
	# 1. Wizard Request
	if key == "action_add_property":
		request_wizard.emit("AGENT")
		return
		
	# 2. Algo Popup Request
	if key == "action_configure_algo":
		_open_algo_popup()
		return
		
	# 3. Target Picker
	if key == "action_pick_target":
		graph_editor.request_node_pick(func(id): _on_setting_changed("target_node", id))
		return
	
	# 4. Standard Apply
	for agent in _tracked_agents:
		if agent.has_method("apply_setting"):
			agent.apply_setting(key, value)
			
	# 5. Sync UI
	if key == "target_node":
		SettingsUIBuilder.sync_picker_button(_walker_inputs, "action_pick_target", "Target Node", value)

# --- ALGO POPUP LOGIC ---

func _can_configure_algo(algo_id: int) -> bool:
	var strategy = AgentNavigator._get_strategy(algo_id)
	if strategy and strategy.has_method("get_settings"):
		return not strategy.get_settings().is_empty()
	return false

func _open_algo_popup() -> void:
	var agent = _tracked_agents[0]
	var algo_id = agent.movement_algo
	var algo_key = str(algo_id)
	var strategy = AgentNavigator._get_strategy(algo_id)
	
	if strategy:
		var schema = strategy.get_settings()
		var current_values = {}
		if agent.algo_settings.has(algo_key):
			current_values = agent.algo_settings[algo_key]
			
		# Re-bind signal
		if algo_popup.settings_confirmed.is_connected(_on_algo_settings_confirmed):
			algo_popup.settings_confirmed.disconnect(_on_algo_settings_confirmed)
		algo_popup.settings_confirmed.connect(_on_algo_settings_confirmed.bind(algo_key))
		
		algo_popup.open_settings("Algorithm Settings", schema, current_values)

func _on_algo_settings_confirmed(new_settings: Dictionary, algo_key: String = "") -> void:
	# Ensure this signal was meant for US (simple check: do we have agents?)
	if _tracked_agents.is_empty(): return
	
	for agent in _tracked_agents:
		if not agent.algo_settings.has(algo_key):
			agent.algo_settings[algo_key] = {}
		agent.algo_settings[algo_key].merge(new_settings, true)
		
		if agent.has_method("_recalculate_path") and graph_editor.graph:
			agent._recalculate_path(graph_editor.graph)
			
	request_refresh_ui.emit()

func _refresh_markers() -> void:
	# (Simplified marker logic from original controller)
	var all_starts: Array[String] = []
	var all_ends: Array[String] = []
	if graph_editor.graph:
		for agent in graph_editor.graph.agents:
			if agent.current_node_id != "": all_ends.append(agent.current_node_id)
			if agent.get("start_node_id"): all_starts.append(agent.start_node_id)
	graph_editor.set_path_starts(all_starts)
	graph_editor.set_path_ends(all_ends)
