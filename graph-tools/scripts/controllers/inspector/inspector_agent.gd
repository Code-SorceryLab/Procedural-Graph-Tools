class_name InspectorAgent
extends InspectorStrategy

# --- DEPENDENCIES ---
var algo_popup: AlgorithmSettingsPopup

# --- STATE ---
var _tracked_agents: Array = []
var _ref_agent: Object = null # The primary agent used for values
var _agent_inputs: Dictionary = {}

# ==============================================================================
# 1. LIFECYCLE
# ==============================================================================

func _init(p_editor: GraphEditor, p_container: Control, p_popup: AlgorithmSettingsPopup) -> void:
	super._init(p_editor, p_container)
	algo_popup = p_popup

func can_handle(_nodes, _edges, agents: Array, _zones) -> bool:
	return not agents.is_empty()

func enter(_nodes, _edges, agents: Array, _zones) -> void:
	super.enter(_nodes, _edges, agents, _zones)
	_tracked_agents = agents
	_update_visual_context()
	_rebuild_agent_ui()

func update(_nodes, _edges, agents: Array, _zones) -> void:
	_tracked_agents = agents
	_update_visual_context()
	_rebuild_agent_ui()

func exit() -> void:
	super.exit()
	_tracked_agents.clear()
	_ref_agent = null
	_agent_inputs.clear()

# ==============================================================================
# 2. UI CONSTRUCTION
# ==============================================================================

func _update_visual_context() -> void:
	if _tracked_agents.is_empty(): return
	_ref_agent = _tracked_agents[0]
	
	# 1. Update Graph Labels (History)
	if _ref_agent.has_method("get_history_labels"):
		graph_editor.set_node_labels(_ref_agent.get_history_labels())
	
	# 2. Update Markers
	_refresh_markers()

func _rebuild_agent_ui() -> void:
	if not _ref_agent: return
	
	var tracked_count = _tracked_agents.size()
	var raw_settings = _ref_agent.get_agent_settings()
	var final_settings = []
	
	# A. Detect Mixed Values
	var mixed_keys = _detect_mixed_values(raw_settings)
	
	# B. Build Header
	final_settings.append(_build_header_item(tracked_count))
	
	# C. Build Status (Single Only)
	if tracked_count == 1:
		final_settings.append({
			"name": "status_display",
			"label": "Current State",
			"type": TYPE_STRING,
			"default": "Active" if _ref_agent.active else "Paused",
			"hint": "read_only"
		})

	# D. Build Property List
	var delete_action_item = null
	
	for item in raw_settings:
		var key = item.name
		
		# Capture Delete Action to move to bottom
		if key == "action_delete":
			delete_action_item = item.duplicate()
			continue
			
		var new_item = item.duplicate()
		
		# Apply Mixed Flag
		if mixed_keys.has(key):
			new_item["mixed"] = true
			
		# Inject Picker Button (Target Node)
		if key == "target_node":
			final_settings.append({
				"name": "action_pick_target",
				"label": "Pick Target Node",
				"type": TYPE_BOOL, 
				"hint": "action",
				"mixed": mixed_keys.get("target_node", false)
			})
			
		final_settings.append(new_item)
		
		# Inject Algo Config Button (Movement Algo)
		if key == "movement_algo" and tracked_count == 1:
			if _can_configure_algo(_ref_agent.movement_algo):
				final_settings.append({
					"name": "action_configure_algo",
					"label": "Configure Algorithm...",
					"type": TYPE_NIL,
					"hint": "button"
				})
	
	# Inject Dynamic Custom Agent Properties
	var registered_props = SemanticRegistry.get_properties_for_target(SemanticRegistry.TARGET_AGENT)
	if not registered_props.is_empty():
		final_settings.append({ "name": "sep_custom", "type": TYPE_NIL, "hint": "separator" })
		for key in registered_props:
			var def = registered_props[key]
			var val = _ref_agent.custom_data.get(key, def.default)
			
			var item = {
				"name": key,
				"label": def.get("label", key.capitalize()),
				"type": def.type,
				"default": val
			}
			if mixed_keys.has(key): item["mixed"] = true
			final_settings.append(item)
	
	# E. Final Actions
	final_settings.append({
		"name": "action_add_property", "label": "Add Custom Data...", "type": TYPE_NIL, "hint": "button"
	})
	
	if delete_action_item:
		if tracked_count > 1:
			delete_action_item["label"] = "Delete %d Agents" % tracked_count
		final_settings.append(delete_action_item)
	
	# F. Render into Collapsible Section
	# [CHANGE] Create section box first
	var section_box = _create_section("Agent Properties")
	
	# [CHANGE] Render into the section box
	_agent_inputs = SettingsUIBuilder.render_dynamic_section(
		section_box, 
		final_settings, 
		_on_setting_changed
	)
	
	# Sync Picker Visuals
	if not mixed_keys.get("target_node", false):
		var t_node = _ref_agent.get("target_node_id")
		SettingsUIBuilder.sync_picker_button(_agent_inputs, "action_pick_target", "Target Node", t_node)

# --- LOGIC HELPERS ---

func _detect_mixed_values(settings: Array) -> Dictionary:
	var mixed = {}
	var count = _tracked_agents.size()
	if count <= 1: return mixed
	
	for item in settings:
		var key = item.name
		if item.get("hint") == "action": continue
		
		var ref_val = _get_agent_value(_ref_agent, key)
		
		for i in range(1, count):
			var other = _tracked_agents[i]
			var other_val = _get_agent_value(other, key)
			
			# Comparison Logic
			if key == "pos" and ref_val is Vector2 and other_val is Vector2:
				if ref_val.distance_squared_to(other_val) > 0.1:
					mixed[key] = true
					break
			elif str(other_val) != str(ref_val):
				mixed[key] = true
				break
				
	return mixed

func _build_header_item(count: int) -> Dictionary:
	var text = ""
	if count == 1:
		var d_id = _ref_agent.display_id if "display_id" in _ref_agent else -1
		var uid = _ref_agent.uuid.left(6) if "uuid" in _ref_agent else "???"
		text = "Agent #%d [%s]" % [d_id, uid]
	else:
		text = "%d Agents Selected" % count
		
	return {
		"name": "identity_display",
		"label": "Selection", 
		"type": TYPE_STRING,
		"default": text,
		"hint": "read_only" 
	}

func _get_agent_value(agent, key: String):
	# Map special properties that aren't direct variables
	match key:
		"global_behavior": return agent.behavior_mode
		"movement_algo": return agent.movement_algo
		"target_node": return agent.target_node_id
		"paint_target": return agent.paint_target
		"paint_field": return agent.paint_field
		"paint_value": return agent.paint_value
	
	if key in agent: return agent.get(key)
	if "custom_data" in agent and agent.custom_data.has(key): return agent.custom_data.get(key)
	return null

# ==============================================================================
# 3. INTERACTION HANDLER
# ==============================================================================

func _on_setting_changed(key: String, value: Variant) -> void:
	if _tracked_agents.is_empty(): return
	
	# 1. Wizard
	if key == "action_add_property":
		request_wizard.emit("AGENT")
		return
		
	# 2. Algo Popup
	if key == "action_configure_algo":
		_open_algo_popup()
		return
		
	# 3. Target Picker
	if key == "action_pick_target":
		graph_editor.request_node_pick(func(id): _on_setting_changed("target_node", id))
		return
	
	# 4. Standard Apply (Wrapped in Undo Transaction!)
	var is_bulk = _tracked_agents.size() > 1
	if is_bulk:
		graph_editor.start_undo_transaction("Bulk Edit Agents")
		
	for agent in _tracked_agents:
		# Map UI property names back to actual Agent variable names
		var actual_key = key
		match key:
			"global_behavior": actual_key = "behavior_mode"
			"target_node": actual_key = "target_node_id"
			
		graph_editor.set_agent_property(agent, actual_key, value)
			
	if is_bulk:
		graph_editor.commit_undo_transaction()
			
	# 5. Structural UI Refresh
	if key in ["paint_target", "paint_field", "global_behavior"]:
		request_refresh_ui.emit.call_deferred()
			
	# 6. UI Sync
	if key == "target_node":
		SettingsUIBuilder.sync_picker_button(_agent_inputs, "action_pick_target", "Target Node", value)
		
# ==============================================================================
# 4. ALGORITHM SETTINGS (POPUP)
# ==============================================================================

func _can_configure_algo(algo_id: int) -> bool:
	var strategy = AgentNavigator._get_strategy(algo_id)
	if strategy and strategy.has_method("get_settings"):
		return not strategy.get_settings().is_empty()
	return false

func _open_algo_popup() -> void:
	if not algo_popup: return
	
	var agent = _tracked_agents[0]
	var algo_id = agent.movement_algo
	var algo_key = str(algo_id)
	var strategy = AgentNavigator._get_strategy(algo_id)
	
	if strategy:
		var schema = strategy.get_settings()
		var current_values = {}
		if agent.algo_settings.has(algo_key):
			current_values = agent.algo_settings[algo_key]
			
		# Re-bind signal dynamically to capture current context (algo_key)
		if algo_popup.settings_confirmed.is_connected(_on_algo_settings_confirmed):
			algo_popup.settings_confirmed.disconnect(_on_algo_settings_confirmed)
		
		# Bind the specific algo key to the callback
		algo_popup.settings_confirmed.connect(_on_algo_settings_confirmed.bind(algo_key))
		
		algo_popup.open_settings("Algorithm Settings", schema, current_values)

func _on_algo_settings_confirmed(new_settings: Dictionary, algo_key: String = "") -> void:
	if _tracked_agents.is_empty(): return
	
	var is_bulk = _tracked_agents.size() > 1
	if is_bulk:
		graph_editor.start_undo_transaction("Configure Agent Algorithm")
	
	for agent in _tracked_agents:
		# To make Dictionary changes undoable, we must assign a brand new Dictionary object
		var new_algo_settings = agent.algo_settings.duplicate(true)
		if not new_algo_settings.has(algo_key):
			new_algo_settings[algo_key] = {}
		new_algo_settings[algo_key].merge(new_settings, true)
		
		# Set it via the Command pipeline!
		graph_editor.set_agent_property(agent, "algo_settings", new_algo_settings)
		
		# Ensure path recalculates (if side-effect interceptor isn't catching it)
		if agent.has_method("_recalculate_path") and graph_editor.graph:
			agent._recalculate_path(graph_editor.graph)
			
	if is_bulk:
		graph_editor.commit_undo_transaction()
			
	request_refresh_ui.emit()

func _refresh_markers() -> void:
	var all_starts: Array[String] = []
	var all_ends: Array[String] = []
	
	if graph_editor.graph:
		for agent in graph_editor.graph.agents:
			if agent.current_node_id != "": 
				all_ends.append(agent.current_node_id)
			if agent.get("start_node_id") and agent.start_node_id != "": 
				all_starts.append(agent.start_node_id)
				
	graph_editor.set_path_starts(all_starts)
	graph_editor.set_path_ends(all_ends)
