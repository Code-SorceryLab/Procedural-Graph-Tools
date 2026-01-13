extends Node
class_name InspectorController

# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor
@export var strategy_controller: StrategyController

@export_group("UI Inspector Tab")
@export var inspector_vbox: VBoxContainer    # The main container

@export var property_wizard_scene: PackedScene
var _wizard_instance: PropertyWizard

# 1. VIEW CONTAINERS
@export var lbl_no_selection: Label      
@export var single_container: Control     
@export var group_container: Control      

# 2. ZONE CONTAINER
@export_group("Zone Inspector")
@export var zone_container: Control

# 3. DYNAMIC WALKER CONTROLS
@export_group("Walker Inspector")
@export var walker_container: VBoxContainer 
@export var opt_walker_select: OptionButton


# 5. EDGE CONTROLS
@export_group("Edge Inspector")
@export var edge_container: Control

# --- STATE ---
var _tracked_nodes: Array[String] = []
var _tracked_edges: Array = []           
var _tracked_agents: Array = []
var _tracked_zones: Array = []

var _is_updating_ui: bool = false
var _current_walker_ref: Object = null 
var _current_walker_list: Array = [] 

# Maps for dynamic controls
var _walker_inputs: Dictionary = {}
var _edge_inputs: Dictionary = {}
var _node_inputs: Dictionary = {}  # Track node inputs
var _group_inputs: Dictionary = {} # Track group inputs

func _ready() -> void:
	# 1. Connect Core Signals
	graph_editor.selection_changed.connect(_on_selection_changed)
	
	if graph_editor.has_signal("edge_selection_changed"):
		graph_editor.edge_selection_changed.connect(_on_edge_selection_changed)

	# Listen to Global Bus for Agent Selection
	if SignalManager.has_signal("agent_selection_changed"):
		SignalManager.agent_selection_changed.connect(_on_agent_selection_changed)
	
	# Listen for Zone Selection
	if SignalManager.has_signal("zone_selection_changed"):
		SignalManager.zone_selection_changed.connect(_on_zone_selection_changed)
	
	# Inspector View Requests
	if graph_editor.has_signal("request_inspector_view"):
		graph_editor.request_inspector_view.connect(_on_inspector_view_requested)

	# Refresh Options on Load (still useful for Schema enums)
	graph_editor.graph_loaded.connect(func(_g): _refresh_all_views())

	set_process(false)
	
	# 2. Configure Controls
	# [REMOVED] All spin_pos_x / option_type connections
	
	# We still need this for the Walker Dropdown (which we kept)
	opt_walker_select.item_selected.connect(_on_walker_dropdown_selected)
	
	# 3. Initialize Wizard
	if property_wizard_scene:
		_wizard_instance = property_wizard_scene.instantiate()
		add_child(_wizard_instance)
		_wizard_instance.property_defined.connect(func(_n): _rebuild_ui_after_schema_change())
		
		# [NEW] Connect Purge Signal
		_wizard_instance.purge_requested.connect(_on_purge_requested)
		
		
	_clear_inspector()

# --- UTILITY ---
func _on_inspector_view_requested() -> void:
	if not inspector_vbox: return
	var parent = inspector_vbox.get_parent()
	if parent is TabContainer:
		parent.current_tab = inspector_vbox.get_index()
	else:
		inspector_vbox.visible = true



# ==============================================================================
# SELECTION HANDLERS
# ==============================================================================

# Node Handler
func _on_selection_changed(selected_nodes: Array[String]) -> void:
	_tracked_nodes = selected_nodes
	_check_selection_state()

# Edge Handler
func _on_edge_selection_changed(selected_edges: Array) -> void:
	_tracked_edges = selected_edges
	if not _tracked_edges.is_empty():
		_rebuild_edge_inspector_ui()
	_check_selection_state()

# Agent Handler
func _on_agent_selection_changed(selected_agents: Array) -> void:
	_tracked_agents = selected_agents
	_check_selection_state()

# Zone Handler
func _on_zone_selection_changed(zones: Array) -> void:
	_tracked_zones = zones
	_check_selection_state()

# Central State Checker
func _check_selection_state() -> void:
	# Check nodes, edges, agents, AND zones
	if _tracked_nodes.is_empty() and _tracked_edges.is_empty() and _tracked_agents.is_empty() and _tracked_zones.is_empty():
		_clear_inspector()
	else:
		_refresh_all_views()

# THE VISIBILITY ROUTER
func _refresh_all_views() -> void:
	var has_nodes = not _tracked_nodes.is_empty()
	var has_edges = not _tracked_edges.is_empty()
	var has_agents = not _tracked_agents.is_empty()
	var has_zones = not _tracked_zones.is_empty() # [NEW]
	
	# 1. No Selection
	lbl_no_selection.visible = (not has_nodes and not has_edges and not has_agents and not has_zones)
	
	# 2. Node Inspector
	single_container.visible = (has_nodes and _tracked_nodes.size() == 1)
	group_container.visible = (has_nodes and _tracked_nodes.size() > 1)
	
	if single_container.visible:
		_update_single_inspector(_tracked_nodes[0])
	elif group_container.visible:
		_update_group_inspector(_tracked_nodes)
		
	# 3. Edge Inspector
	edge_container.visible = has_edges
	
	# 4. Walker Inspector
	var show_walkers = false
	if has_agents:
		show_walkers = true
		_update_walker_inspector_from_selection()
	elif has_nodes and _tracked_nodes.size() == 1:
		show_walkers = _update_walker_inspector_from_node(_tracked_nodes[0])
		
	walker_container.visible = show_walkers
	
	# 5. Zone Inspector [NEW]
	zone_container.visible = has_zones
	if has_zones:
		_build_zone_inspector()

	set_process(has_nodes)
	
# ==============================================================================
# ZONE INSPECTOR LOGIC
# ==============================================================================

func _build_zone_inspector() -> void:
	if _tracked_zones.is_empty(): return
	
	var zone = _tracked_zones[0] as GraphZone
	
	# 1. DEFINE SCHEMA
	var schema = [
		{ "name": "head", "label": "Zone Inspector", "type": TYPE_STRING, "default": "Properties", "hint": "read_only" },
		{ "name": "zone_name", "label": "Name", "type": TYPE_STRING, "default": zone.zone_name },
		{ "name": "zone_color", "label": "Color", "type": TYPE_COLOR, "default": zone.zone_color },
		
		{ "name": "sep_rules", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "allow_new_nodes", "label": "Allow New Nodes", "type": TYPE_BOOL, "default": zone.allow_new_nodes },
		{ "name": "traversal_cost", "label": "Traversal Cost", "type": TYPE_FLOAT, "default": zone.traversal_cost, "step": 0.1, "min": 0.1 },
		{ "name": "damage_per_tick", "label": "Damage / Tick", "type": TYPE_FLOAT, "default": zone.damage_per_tick, "step": 1.0 }
	]
	
	# 2. INJECT DYNAMIC PROPERTIES
	var registered_props = GraphSettings.get_properties_for_target("ZONE")
	
	if not registered_props.is_empty():
		schema.append({ "name": "sep_custom", "type": TYPE_NIL, "hint": "separator" })
		
	for key in registered_props:
		var def = registered_props[key]
		var val = def.default
		if "custom_data" in zone:
			val = zone.custom_data.get(key, def.default)
			
		schema.append({
			"name": key,
			"label": key.capitalize(),
			"type": def.type,
			"default": val
		})
		
	# 3. ADD WIZARD BUTTON
	schema.append({
		"name": "action_add_property",
		"label": "Add Custom Data...",
		"type": TYPE_NIL,
		"hint": "button"
	})
	
	# 4. RENDER (Using dedicated container)
	_render_dynamic_section(zone_container, schema, _on_zone_setting_changed)

func _on_zone_setting_changed(key: String, value: Variant) -> void:
	if _tracked_zones.is_empty(): return
	var zone = _tracked_zones[0] as GraphZone
	
	# 1. WIZARD ACTION
	if key == "action_add_property":
		if _wizard_instance:
			# Assumes 'ZONE' is added to TARGETS in PropertyWizard at index 3
			_wizard_instance.input_target.selected = 3 
			_wizard_instance.popup_wizard()
		return

	# 2. CORE PROPERTIES
	if key in ["zone_name", "zone_color", "allow_new_nodes", "traversal_cost", "damage_per_tick"]:
		zone.set(key, value)
		
		if key == "zone_color":
			graph_editor.renderer.queue_redraw()
			graph_editor.mark_modified()
		elif key == "zone_name":
			graph_editor.mark_modified()
			 
	# 3. DYNAMIC PROPERTIES
	else:
		zone.custom_data[key] = value
		graph_editor.mark_modified()

# ==============================================================================
# EDGE VIEW LOGIC 
# ==============================================================================

func _get_edge_inspector_schema() -> Array:
	if _tracked_edges.is_empty(): return []
	var graph = graph_editor.graph
	
	var schema = [] # Start fresh
	
	# Conditional Separator
	# If we have nodes selected, the Node Inspector is above us. Add a line.
	if not _tracked_nodes.is_empty():
		schema.append({ "name": "sep_edge", "type": TYPE_NIL, "hint": "separator" })

	# 1. SETUP REFERENCE (Use the first selected edge as the "Truth")
	var first_pair = _tracked_edges[0]
	var u = first_pair[0]
	var v = first_pair[1]
	
	# Fetch Physical Data
	var ref_weight = 1.0
	if graph.has_edge(u, v): ref_weight = graph.get_edge_weight(u, v)
	elif graph.has_edge(v, u): ref_weight = graph.get_edge_weight(v, u)
	
	# Fetch Directionality
	var has_ab = graph.has_edge(u, v)
	var has_ba = graph.has_edge(v, u)
	var ref_dir = 0 
	if has_ab and not has_ba: ref_dir = 1
	elif not has_ab and has_ba: ref_dir = 2

	# Fetch Semantic Data
	var ref_data = graph.get_edge_data(u, v)
	if ref_data.is_empty() and has_ba:
		ref_data = graph.get_edge_data(v, u)
		
	var ref_type = ref_data.get("type", 0)
	var ref_lock = ref_data.get("lock_level", 0)
	
	# 2. DETECT MIXED STATE
	var mixed = { "weight": false, "direction": false, "type": false, "lock_level": false }
	var count = _tracked_edges.size()
	var limit = min(count, GraphSettings.MAX_ANALYSIS_COUNT)
	
	for i in range(1, limit):
		var pair = _tracked_edges[i]
		var a = pair[0]; var b = pair[1]
		
		# (Your existing Mixed Logic...)
		var w = 1.0
		if graph.has_edge(a, b): w = graph.get_edge_weight(a, b)
		elif graph.has_edge(b, a): w = graph.get_edge_weight(b, a)
		if not is_equal_approx(w, ref_weight): mixed.weight = true
		
		# ... (Direction & Semantic Checks) ...
		var d = graph.get_edge_data(a, b)
		if d.is_empty() and graph.has_edge(b, a): d = graph.get_edge_data(b, a)
		if int(d.get("type", 0)) != ref_type: mixed.type = true
		if int(d.get("lock_level", 0)) != ref_lock: mixed.lock_level = true

	# 3. APPEND STANDARD FIELDS TO SCHEMA
	# We use append_array to add to our 'schema' variable which might contain the separator
	schema.append_array([
		{ 
			"name": "header_basic", 
			"label": "Selection", 
			"type": TYPE_STRING, 
			"default": "%d Edge(s)" % count, 
			"hint": "read_only" 
		},
		{ 
			"name": "weight", 
			"label": "Weight (Cost)", 
			"type": TYPE_FLOAT, 
			"default": ref_weight, 
			"min": 0.1, "max": 100.0, "step": 0.1,
			"mixed": mixed.weight
		},
		{
			"name": "direction", 
			"label": "Orientation", 
			"type": TYPE_INT, 
			"default": ref_dir, 
			"hint": "enum", 
			"hint_string": "Bi-Directional,Forward (A->B),Reverse (B->A)",
			"mixed": mixed.direction
		},
		{ 
			"name": "header_semantic", 
			"label": "Logic & Gameplay", 
			"type": TYPE_STRING, 
			"default": "Custom Data", 
			"hint": "read_only" 
		},
		{
			"name": "type", 
			"label": "Edge Type", 
			"type": TYPE_INT,
			"default": ref_type, 
			"hint": "enum",
			"hint_string": "Corridor,Door (Open),Door (Locked),Secret Passage,Climbable",
			"mixed": mixed.type
		},
		{
			"name": "lock_level", 
			"label": "Lock Level", 
			"type": TYPE_INT,
			"default": ref_lock,
			"min": 0, "max": 10,
			"mixed": mixed.lock_level,
			"hint": "0 = Unlocked, 1+ = Required Key ID"
		}
	])
	
	# [PHASE 5] INJECT DYNAMIC EDGE PROPERTIES
	var registered_props = GraphSettings.get_properties_for_target("EDGE")
	
	for key in registered_props:
		var def = registered_props[key]
		# Need to fetch actual value from ref_data (which we got earlier in the function)
		var val = ref_data.get(key, def.default)
		
		# (Optional: Add mixed check for dynamic props here)
		
		schema.append({
			"name": key,
			"label": key.capitalize(),
			"type": def.type,
			"default": val
		})

	# [PHASE 5] ADD BUTTON
	schema.append({
		"name": "action_add_property",
		"label": "Add Custom Data...",
		"type": TYPE_NIL,
		"hint": "button"
	})
	
	return schema

func _rebuild_edge_inspector_ui() -> void:
	var schema = _get_edge_inspector_schema()
	_edge_inputs = _render_dynamic_section(edge_container, schema, _on_edge_setting_changed)

func _on_edge_setting_changed(key: String, value: Variant) -> void:
	if _tracked_edges.is_empty(): return
	
	# 1. HANDLE GLOBAL ACTIONS (Wizard)
	# Check this first so we don't loop through edges for a UI event
	if key == "action_add_property":
		if _wizard_instance: 
			_wizard_instance.input_target.selected = 1 # Select "EDGE" (index 1)
			_wizard_instance.popup_wizard()
		return

	var graph = graph_editor.graph 
	
	# 2. APPLY TO SELECTION
	for pair in _tracked_edges:
		var u = pair[0]; var v = pair[1]
		
		match key:
			"weight":
				if graph.has_edge(u, v): graph_editor.set_edge_weight(u, v, value)
				# Only update reverse if it exists (Bi-Directional)
				if graph.has_edge(v, u): graph_editor.set_edge_weight(v, u, value)
			
			"direction":
				graph_editor.set_edge_directionality(u, v, int(value))
			
			# Hardcoded Semantic Properties (Legacy/Core)
			"type", "lock_level":
				graph_editor.set_edge_property(u, v, key, value)
				# Symmetric update for bi-directional edges
				if graph.has_edge(v, u):
					graph_editor.set_edge_property(v, u, key, value)
			
			# [NEW] DYNAMIC CATCH-ALL
			# Any custom property added via the Wizard (e.g. "is_slippery", "cost") falls here.
			_:
				# We treat custom data as symmetric by default for edges.
				graph_editor.set_edge_property(u, v, key, value)
				if graph.has_edge(v, u):
					graph_editor.set_edge_property(v, u, key, value)
		

# --- VIEW LOGIC ---

func _update_single_inspector(node_id: String) -> void:
	var graph = graph_editor.graph
	if not graph.nodes.has(node_id): return
	
	var node_data = graph.nodes[node_id]
	var neighbors = graph.get_neighbors(node_id)
	
	# 1. PREPARE DATA Strings
	var neighbor_text = ""
	for n_id in neighbors: neighbor_text += "%s\n" % n_id
	if neighbor_text == "": neighbor_text = "(None)"
	
	# Build Enum String for "Type"
	var ids = GraphSettings.current_names.keys()
	ids.sort() 
	var type_names = []
	for id in ids: type_names.append(GraphSettings.get_type_name(id))
	var type_hint = ",".join(type_names)
	
	# 2. BUILD SCHEMA
	var schema = [
		{ "name": "head", "label": "ID: %s" % node_id, "type": TYPE_STRING, "default": "", "hint": "read_only" },
		
		# Split Position for safety (works with standard Float SpinBoxes)
		{ "name": "pos_x", "label": "Position X", "type": TYPE_FLOAT, "default": node_data.position.x, "step": GraphSettings.INSPECTOR_POS_STEP },
		{ "name": "pos_y", "label": "Position Y", "type": TYPE_FLOAT, "default": node_data.position.y, "step": GraphSettings.INSPECTOR_POS_STEP },
		
		{ "name": "type", "label": "Room Type", "type": TYPE_INT, "default": node_data.type, "hint": "enum", "hint_string": type_hint },
		
		{ "name": "info_n", "label": "Neighbors", "type": TYPE_STRING, "default": neighbor_text, "hint": "read_only_multiline" }
	]
	
	# 3. INJECT DYNAMIC PROPERTIES
	var registered_props = GraphSettings.get_properties_for_target("NODE")
	for key in registered_props:
		var def = registered_props[key]
		# Use get_data helper if available, else direct dict access
		var val = def.default
		if "custom_data" in node_data:
			val = node_data.custom_data.get(key, def.default)
			
		schema.append({
			"name": key,
			"label": key.capitalize(),
			"type": def.type,
			"default": val
		})

	# 4. ADD WIZARD BUTTON
	schema.append({
		"name": "action_add_property",
		"label": "Add Custom Data...",
		"type": TYPE_NIL,
		"hint": "button"
	})

	# 5. RENDER
	_node_inputs = _render_dynamic_section(single_container, schema, _on_node_setting_changed)
	
	# Refresh walker list (logic kept separate)
	_refresh_walker_list_state(node_id)

func _rebuild_walker_ui() -> void:
	var tracked_count = _tracked_agents.size()
	if tracked_count == 0: return
	
	var ref_agent = _tracked_agents[0]
	var raw_settings = ref_agent.get_agent_settings()
	var final_settings = []
	
	# [NEW] Conditional Separator
	if not _tracked_nodes.is_empty() or not _tracked_edges.is_empty():
		final_settings.append({ "name": "sep_walker", "type": TYPE_NIL, "hint": "separator" })
	
	# --- 1. THE HEADER ---
	var header_text = ""
	if tracked_count == 1:
		var d_id = ref_agent.display_id if "display_id" in ref_agent else ref_agent.id
		var uid = ref_agent.uuid.left(6) if "uuid" in ref_agent else "???"
		header_text = "Agent #%d [%s]" % [d_id, uid]
	else:
		header_text = "%d Agents Selected" % tracked_count

	final_settings.append({
		"name": "identity_display",
		"label": "Walker Selection", 
		"type": TYPE_STRING,
		"default": header_text,
		"hint": "read_only" 
	})

	# --- 2. STATUS ---
	if tracked_count == 1:
		final_settings.append({
			"name": "status_display",
			"label": "Current State",
			"type": TYPE_STRING,
			"default": "Active" if ref_agent.active else "Paused",
			"hint": "read_only"
		})

	# --- 3. DETECT MIXED VALUES ---
	var mixed_keys = {}
	
	if tracked_count > 1:
		for item in raw_settings:
			var key = item.name
			if item.get("hint") == "action": continue 
			
			var ref_val = _get_agent_value(ref_agent, key)
			
			for i in range(1, tracked_count):
				var other = _tracked_agents[i]
				var other_val = _get_agent_value(other, key)
				
				if key == "pos" and ref_val is Vector2 and other_val is Vector2:
					if ref_val.distance_squared_to(other_val) > 0.1:
						mixed_keys[key] = true
						break
				elif str(other_val) != str(ref_val):
					mixed_keys[key] = true
					break

	# --- 4. BUILD SETTINGS LIST ---
	var delete_action_item = null # Store this to append at the very end
	
	for item in raw_settings:
		var key = item.name
		
		# [CHANGED] Capture Delete button to move it to the bottom
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
	
	# --- 5. INJECT DYNAMIC PROPERTIES (From Registry) ---
	var registered_props = GraphSettings.get_properties_for_target("AGENT")
	for key in registered_props:
		var def = registered_props[key]
		
		# Access custom_data on the reference agent
		var val = def.default
		if "custom_data" in ref_agent:
			val = ref_agent.custom_data.get(key, def.default)
		
		# (Optional: You could add mixed value checking for custom props here)
		
		final_settings.append({
			"name": key,
			"label": key.capitalize(),
			"type": def.type,
			"default": val
		})

	# --- 6. ADD WIZARD BUTTON ---
	final_settings.append({
		"name": "action_add_property",
		"label": "Add Custom Data...",
		"type": TYPE_NIL,
		"hint": "button"
	})
	
	# --- 7. APPEND DELETE BUTTON (At the bottom) ---
	if delete_action_item:
		if tracked_count > 1:
			delete_action_item["label"] = "Delete %d Agents" % tracked_count
		else:
			delete_action_item["label"] = "Delete Agent"
		final_settings.append(delete_action_item)
	
	# --- 8. RENDER ---
	_walker_inputs = _render_dynamic_section(
		walker_container, 
		final_settings, 
		_on_walker_setting_changed
	)
	
	# Sync Picker Button Visuals
	if not mixed_keys.get("target_node", false):
		var t_node = ref_agent.get("target_node_id")
		SettingsUIBuilder.sync_picker_button(_walker_inputs, "action_pick_target", "Target Node", t_node)
	
	walker_container.visible = true

func _rebuild_ui_after_schema_change() -> void:
	# When a new property is defined, we must force a UI refresh
	# so the new field appears immediately.
	_refresh_all_views()

# [NEW] THE HEAVY CLEANUP LOGIC
func _on_purge_requested(key: String, target: String) -> void:
	var graph = graph_editor.graph
	var clean_count = 0
	
	match target:
		"NODE":
			for node_id in graph.nodes:
				var node = graph.nodes[node_id]
				# Check custom_data
				if "custom_data" in node and node.custom_data.has(key):
					node.custom_data.erase(key)
					clean_count += 1
					
		"AGENT":
			for agent in graph.agents:
				# Check custom_data (AgentWalker stores dynamic props here)
				if "custom_data" in agent and agent.custom_data.has(key):
					agent.custom_data.erase(key)
					clean_count += 1
					
		"EDGE":
			# Edges are tricky (Adjacency List). We iterate unique pairs.
			# Usually stored as graph.adj = { u: { v: {data...} } }
			# Or graph.edges array depending on implementation.
			
			# Assuming standard iteration over all connections:
			var visited_edges = {} # To avoid double-cleaning A-B and B-A
			
			for u in graph.nodes:
				var neighbors = graph.get_neighbors(u)
				for v in neighbors:
					# Sort key to handle bi-directional uniqueness
					var pair_key = [u, v]
					pair_key.sort() 
					if visited_edges.has(pair_key): continue
					visited_edges[pair_key] = true
					
					# Clean A->B
					var data_ab = graph.get_edge_data(u, v)
					if data_ab.has(key): 
						data_ab.erase(key)
						clean_count += 1
						
					# Clean B->A (if symmetric)
					if graph.has_edge(v, u):
						var data_ba = graph.get_edge_data(v, u)
						if data_ba.has(key): data_ba.erase(key)
	
	print("Purge Complete: Removed '%s' from %d %ss." % [key, clean_count, target.to_lower()])
	
	# Force UI Refresh in case we are looking at a purged item
	_refresh_all_views()

# Helper to safely get value (Dictionary vs Object)
func _get_agent_value(agent, key: String):
	# AgentWalker is an Object, but some scripts might treat it as Dict.
	# We use 'get()' if available, otherwise direct access is tricky in GDScript without string lookup.
	# AgentWalker has 'apply_setting' but not a generic 'get_setting'.
	# We rely on property access.
	if key == "global_behavior": return agent.behavior_mode
	if key == "movement_algo": return agent.movement_algo
	if key == "target_node": return agent.target_node_id
	if key == "paint_type": return agent.my_paint_type
	if key in agent: return agent.get(key)
	return null

func _update_group_inspector(nodes: Array[String]) -> void:
	var graph = graph_editor.graph
	var count = nodes.size()
	
	# 1. CALCULATE STATS & MIXED STATE
	var center_sum = Vector2.ZERO
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	
	var first_type = graph.nodes[nodes[0]].type
	var is_mixed_type = false
	
	for id in nodes:
		var n = graph.nodes[id]
		center_sum += n.position
		min_pos.x = min(min_pos.x, n.position.x)
		min_pos.y = min(min_pos.y, n.position.y)
		max_pos.x = max(max_pos.x, n.position.x)
		max_pos.y = max(max_pos.y, n.position.y)
		
		if n.type != first_type: is_mixed_type = true

	var avg_center = center_sum / count
	var bounds = max_pos - min_pos
	
	# Prepare Type Dropdown
	var ids = GraphSettings.current_names.keys()
	ids.sort() 
	var type_names = []
	for id in ids: type_names.append(GraphSettings.get_type_name(id))
	var type_hint_string = ",".join(type_names)

	# 2. BUILD SCHEMA
	var schema = [
		{ "name": "head", "label": "Selection", "type": TYPE_STRING, "default": "%d Nodes" % count, "hint": "read_only" },
		
		# Read-Only Stats
		{ "name": "stat_center", "label": "Center", "type": TYPE_VECTOR2, "default": avg_center, "hint": "read_only" },
		{ "name": "stat_bounds", "label": "Bounds", "type": TYPE_VECTOR2, "default": bounds, "hint": "read_only" },
		
		# Editable Bulk Properties
		{ 
			"name": "type", "label": "Bulk Type", "type": TYPE_INT, 
			"default": first_type, 
			"hint": "enum", 
			"hint_string": type_hint_string,
			"mixed": is_mixed_type 
		}
	]
	
	# [OPTIONAL/FUTURE] Inject mixed-value checks for Custom Properties here

	# ADD WIZARD BUTTON
	schema.append({
		"name": "action_add_property",
		"label": "Add Custom Data...",
		"type": TYPE_NIL,
		"hint": "button"
	})
	
	# 3. RENDER
	_render_dynamic_section(group_container, schema, _on_node_setting_changed)

func _clear_inspector() -> void:
	_tracked_nodes = []
	_tracked_edges = []
	_tracked_agents = []
	_tracked_zones = []
	
	_current_walker_ref = null
	graph_editor.set_node_labels({})
	
	_refresh_all_views()

# --- INPUT HANDLERS ---

func _on_node_setting_changed(key: String, value: Variant) -> void:
	if _tracked_nodes.is_empty(): return
	var graph = graph_editor.graph
	
	# Wizard Trigger
	if key == "action_add_property":
		if _wizard_instance:
			_wizard_instance.input_target.selected = 0 # Target = NODE
			_wizard_instance.popup_wizard()
		return

	# Single Node Updates
	if _tracked_nodes.size() == 1:
		var id = _tracked_nodes[0]
		var current_pos = graph.get_node_pos(id)
		
		match key:
			"pos_x":
				var new_pos = Vector2(value, current_pos.y)
				graph_editor.set_node_position(id, new_pos)
				# Optional: Commit Move Command
			"pos_y":
				var new_pos = Vector2(current_pos.x, value)
				graph_editor.set_node_position(id, new_pos)
			"type":
				graph_editor.set_node_type(id, int(value))
			_:
				# Dynamic Property
				var node_obj = graph.nodes[id]
				if node_obj.has_method("set_data"):
					node_obj.set_data(key, value)
				elif "custom_data" in node_obj:
					node_obj.custom_data[key] = value

	# Batch Updates (Group)
	else:
		if key == "type":
			graph_editor.set_node_type_bulk(_tracked_nodes, int(value))


# --- WALKER HANDLERS ---

func _refresh_walker_list_state(node_id: String) -> void:
	# 1. Fetch
	var new_list = []
	if strategy_controller and strategy_controller.current_strategy:
		var strat = strategy_controller.current_strategy
		if strat.has_method("get_walkers_at_node"):
			new_list = strat.get_walkers_at_node(node_id, graph_editor.graph)
			
	if new_list.is_empty():
		_current_walker_list.clear()
		_current_walker_ref = null
		walker_container.visible = false
		return

	# 2. Update UI
	_populate_walker_dropdown(node_id, null)
	walker_container.visible = true

func _update_walker_inspector_from_selection() -> void:
	if _tracked_agents.is_empty(): return
	var agent = _tracked_agents[0]
	
	var context_node = agent.current_node_id
	if context_node != "":
		_populate_walker_dropdown(context_node, agent)
	else:
		_current_walker_list = [agent]
		_populate_dropdown_ui(0)
		if _current_walker_ref != agent:
			_activate_walker_visuals(agent)

func _update_walker_inspector_from_node(node_id: String) -> bool:
	var list = graph_editor.graph.get_agents_at_node(node_id)
	if list.is_empty(): return false
	_populate_walker_dropdown(node_id, null) 
	return true

func _populate_walker_dropdown(node_id: String, target_selection = null) -> void:
	var new_list = graph_editor.graph.get_agents_at_node(node_id)
	
	if new_list != _current_walker_list:
		_current_walker_list = new_list
		var selected_idx = 0
		if target_selection:
			var found = _current_walker_list.find(target_selection)
			if found != -1: selected_idx = found
		
		_populate_dropdown_ui(selected_idx)
		if not _current_walker_list.is_empty():
			_activate_walker_visuals(_current_walker_list[selected_idx])
	else:
		if target_selection:
			var found = _current_walker_list.find(target_selection)
			if found != -1:
				if opt_walker_select.selected != found or _current_walker_ref != target_selection:
					opt_walker_select.selected = found
					_activate_walker_visuals(target_selection)

func _populate_dropdown_ui(select_index: int) -> void:
	opt_walker_select.clear()
	for i in range(_current_walker_list.size()):
		var w = _current_walker_list[i]
		var status = "" if w.get("active") else " (Paused)"
		opt_walker_select.add_item("Agent #%d%s" % [w.id, status], i)
	
	opt_walker_select.selected = select_index
	opt_walker_select.visible = (_current_walker_list.size() > 1)

func _on_walker_dropdown_selected(index: int) -> void:
	if index < 0 or index >= _current_walker_list.size(): return
	var agent = _current_walker_list[index]
	_activate_walker_visuals(agent)



func _activate_walker_visuals(walker_obj) -> void:
	_current_walker_ref = walker_obj
	
	# 1. Build Dynamic UI (Identity Display is now handled here)
	_rebuild_walker_ui()
	
	# 2. Visuals (Trails)
	if walker_obj.has_method("get_history_labels"):
		graph_editor.set_node_labels(walker_obj.get_history_labels())
	
	# 3. Markers (Direct Graph Access)
	# Collects all active paths from the graph to update visual markers
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

func _on_walker_setting_changed(key: String, value: Variant) -> void:
	if _tracked_agents.is_empty(): return

	# 1. SPECIAL ACTIONS
	if key == "action_pick_target":
		graph_editor.request_node_pick(_on_inspector_target_picked)
		return
		
	if key == "action_delete":
		# Batch Delete
		var list_copy = _tracked_agents.duplicate()
		for a in list_copy:
			graph_editor.remove_agent(a)
		_clear_inspector()
		graph_editor.clear_selection()
		return 
	
	if key == "action_add_property":
		if _wizard_instance: 
			_wizard_instance.input_target.selected = 2 # Select "AGENT"
			_wizard_instance.popup_wizard()
		return
	
	# 2. BATCH APPLY
	for agent in _tracked_agents:
		if agent.has_method("apply_setting"):
			agent.apply_setting(key, value)
			
	# 3. SYNC VISUALS (If needed)
	if key == "target_node":
		SettingsUIBuilder.sync_picker_button(_walker_inputs, "action_pick_target", "Target Node", value)

func _on_inspector_target_picked(node_id: String) -> void:
	if _walker_inputs.has("target_node"):
		_walker_inputs["target_node"].text = node_id
		_on_walker_setting_changed("target_node", node_id)

# --- GENERIC UI HELPER ---
func _render_dynamic_section(container: Control, schema: Array, callback: Callable) -> Dictionary:
	var content_box = container.get_node_or_null("ContentBox")
	if not content_box:
		content_box = VBoxContainer.new()
		content_box.name = "ContentBox"
		content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
		container.add_child(content_box)
	
	var inputs = SettingsUIBuilder.build_ui(schema, content_box)
	SettingsUIBuilder.connect_live_updates(inputs, callback)
	return inputs
