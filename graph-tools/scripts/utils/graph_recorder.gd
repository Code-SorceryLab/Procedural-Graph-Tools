class_name GraphRecorder
extends Graph

# The payload we will deliver to the Undo System later
var recorded_commands: Array[GraphCommand] = []

# The Real Graph (Who the commands will actually affect later)
var _target_graph: Graph

# PIPELINE CONTEXT MEMORY
# Tracks exactly what THIS recorder touched during its lifetime.
var touched_nodes: Array[String] = []
var touched_edges: Array = []

# Zone Context State
var _active_zone: GraphZone = null
var _use_smart_patch: bool = true
var _grid_spacing: Vector2 = Vector2(64, 64) # Default fallback

func _init(target: Graph, clone_data: bool = true) -> void:
	_target_graph = target
	
	# Attempt to grab spacing from settings if available, else default
	if GraphSettings:
		_grid_spacing = GraphSettings.GRID_SPACING
	
	# --- STATE CLONE ---
	if clone_data:
		# 1. Duplicate nodes
		for id in target.nodes:
			nodes[id] = target.nodes[id].duplicate()
			# Deep copy the dictionary so the Sandbox doesn't poison the Live Graph!
			if "custom_data" in nodes[id]:
				nodes[id].custom_data = target.nodes[id].custom_data.duplicate(true)
		
		# 2. Duplicate Canonical Edge Store (Deep Copy)
		edge_store = target.edge_store.duplicate(true)
		_rebuild_adjacency_cache() # Rebuild pathfinding map for the sandbox
			
		# 3. Rebuild spatial grid
		_rebuild_spatial_grid()
		
		# 4. Clone Existing Zones
		if "zones" in target:
			zones = target.zones.duplicate()
			
		# 5. Clone Existing Agents
		if "agents" in target:
			agents = target.agents.duplicate()

# ==============================================================================
# 1. ZONE CONTEXT API (The New "Smart" Layer)
# ==============================================================================

# Starts a "Recording Session" for a zone.
func start_zone(name: String, color: Color, use_smart_patch: bool = true) -> void:
	_active_zone = GraphZone.new(name, color)
	_active_zone.allow_new_nodes = false
	_active_zone.traversal_cost = 0.0
	_use_smart_patch = use_smart_patch

# Ends the session and commits the zone to the graph.
func end_zone() -> void:
	if _active_zone:
		# Only add if it actually has content
		if not _active_zone.cells.is_empty():
			add_zone(_active_zone)
		_active_zone = null

# Creates a zone retroactively from an array of existing node IDs.
func create_zone_from_nodes(zone_name: String, color: Color, node_ids: Array[String], use_smart_patch: bool = true) -> void:
	start_zone(zone_name, color, use_smart_patch)
	
	for id in node_ids:
		if nodes.has(id):
			_active_zone.register_node(id)
			var pos = nodes[id].position
			# Use Smart 2x2 (Radius 0) if enabled, otherwise 3x3 (Radius 1)
			var r = 0 if _use_smart_patch else 1
			_active_zone.add_patch_at_world_pos(pos, _grid_spacing, r)
		else:
			push_warning("GraphRecorder: Attempted to add missing node '%s' to zone '%s'" % [id, zone_name])
			
	end_zone()

# ==============================================================================
# 2. MUTATOR OVERRIDES (With Hooks)
# ==============================================================================

func set_node_position(id: String, new_pos: Vector2) -> void:
	if not nodes.has(id): return
	
	# Fetch the old position depending on how your recorder stores nodes internally
	var old_pos = nodes[id].position if typeof(nodes[id]) == TYPE_OBJECT else nodes[id]["position"]
	
	# Apply to the sandbox
	if typeof(nodes[id]) == TYPE_OBJECT:
		nodes[id].position = new_pos
	else:
		nodes[id]["position"] = new_pos
		
	# Track the footprint
	if not touched_nodes.has(id): touched_nodes.append(id)
		
	# Queue the command
	recorded_commands.append(CmdMoveNode.new(_target_graph, id, old_pos, new_pos))

func add_node(id: String, pos: Vector2 = Vector2.ZERO) -> void:
	var already_exists = nodes.has(id)
	
	# 1. Update Simulation
	super.add_node(id, pos)
	
	# Track the footprint
	if not touched_nodes.has(id): touched_nodes.append(id)
	
	# 1.5. Automatic Zone Registration Hook
	if _active_zone:
		_active_zone.register_node(id)
		var r = 0 if _use_smart_patch else 1
		_active_zone.add_patch_at_world_pos(pos, _grid_spacing, r)
	
	# 2. Record Command (Undo/Redo)
	if not already_exists:
		var cmd = CmdAddNode.new(_target_graph, id, pos)
		recorded_commands.append(cmd)

func add_zone(zone: GraphZone) -> void:
	# 1. Update Local Simulation
	super.add_zone(zone)
	
	# 2. Apply to Target
	# (We bypass Undo Stack for metadata/zones for now)
	if _target_graph and _target_graph.has_method("add_zone"):
		_target_graph.add_zone(zone)
	else:
		push_error("GraphRecorder: Target graph missing add_zone method.")


func add_edge(a: String, b: String, weight: float = 1.0, directed: bool = false, extra_data: Dictionary = {}) -> void:
	var already_exists = has_edge(a, b)
	super.add_edge(a, b, weight, directed, extra_data)
	
	# Track the footprint (Using alphabetical arrays to deduplicate bidirectional lines)
	var pair = [a, b]
	pair.sort()
	if not touched_edges.has(pair): touched_edges.append(pair)
	
	if not already_exists:
		var cmd = CmdConnect.new(_target_graph, a, b, weight, directed)
		recorded_commands.append(cmd)
		
		if not extra_data.is_empty():
			for k in extra_data:
				var cmd_prop = CmdSetProperty.new(_target_graph, "EDGE", [a, b], k, extra_data[k], null)
				recorded_commands.append(cmd_prop)

func remove_node(id: String) -> void:
	super.remove_node(id)
	
	# Remove from footprint so future modifiers don't try to target ghosts
	touched_nodes.erase(id)
	
	var cmd = CmdDeleteNode.new(_target_graph, id)
	recorded_commands.append(cmd)

func remove_edge(a: String, b: String, directed: bool = false) -> void:
	var w = get_edge_weight(a, b)
	super.remove_edge(a, b, directed)
	
	# Remove from footprint
	var pair = [a, b]
	pair.sort()
	touched_edges.erase(pair)
	
	var cmd = CmdDisconnect.new(_target_graph, a, b, w)
	recorded_commands.append(cmd)

func set_node_type(id: String, new_type: String) -> void: 
	var old_type = "empty" 
	if _target_graph.nodes.has(id):
		old_type = _target_graph.nodes[id].type
		
	if nodes.has(id):
		# [CRITICAL FIX] Prevent phantom touches if nothing changed!
		if nodes[id].type == new_type: return 
		nodes[id].type = new_type
	
	# Track the footprint
	if not touched_nodes.has(id): touched_nodes.append(id)
	
	var cmd = CmdSetProperty.new(_target_graph, "NODE", id, "type", new_type, old_type)
	recorded_commands.append(cmd)

# Allows procedural generators to set custom variables on Nodes!
func set_node_property(id: String, key: String, value: Variant) -> void:
	var old_val = null
	if _target_graph.nodes.has(id):
		var t_node = _target_graph.nodes[id]
		if key in t_node: old_val = t_node.get(key)
		else: old_val = t_node.custom_data.get(key)
		
	if nodes.has(id):
		var current_val = nodes[id].get(key) if key in nodes[id] else nodes[id].custom_data.get(key)
		# [CRITICAL FIX] Prevent phantom touches!
		if current_val == value: return 
		
		if key in nodes[id]: nodes[id].set(key, value)
		else: nodes[id].custom_data[key] = value
		
	if not touched_nodes.has(id): touched_nodes.append(id)
	
	var cmd = CmdSetProperty.new(_target_graph, "NODE", id, key, value, old_val)
	recorded_commands.append(cmd)

# Allows procedural generators to set custom variables on Edges!
func set_edge_property(a: String, b: String, key: String, value: Variant) -> void:
	var edge_key = get_edge_key(a, b)
	if not edge_store.has(edge_key): return
		
	var old_val = null
	if _target_graph.edge_store.has(edge_key):
		if key in ["weight", "direction"]:
			old_val = _target_graph.edge_store[edge_key].get(key)
		else:
			old_val = _target_graph.edge_store[edge_key].custom.get(key)
			
	# [CRITICAL FIX] Prevent phantom touches!
	var current_val = edge_store[edge_key].get(key) if key in ["weight", "direction"] else edge_store[edge_key].custom.get(key)
	if current_val == value: return 
			
	if key in ["weight", "direction"]:
		edge_store[edge_key][key] = value
		_rebuild_adjacency_cache()
	else:
		edge_store[edge_key].custom[key] = value
		
	var pair = [a, b]
	pair.sort()
	if not touched_edges.has(pair): touched_edges.append(pair)
		
	var cmd = CmdSetProperty.new(_target_graph, "EDGE", [a, b], key, value, old_val)
	recorded_commands.append(cmd)

func add_agent(agent: AgentWalker) -> void:
	super.add_agent(agent)
	var cmd = CmdAddAgent.new(_target_graph, agent)
	recorded_commands.append(cmd)

func remove_agent(agent) -> void:
	super.remove_agent(agent)
	var cmd = CmdRemoveAgent.new(_target_graph, agent)
	recorded_commands.append(cmd)

func get_next_display_id() -> int:
	if _target_graph: return _target_graph.get_next_display_id()
	return super.get_next_display_id()

func clear() -> void:
	super.clear()
	if _target_graph and "zones" in _target_graph: _target_graph.zones.clear()
	if _target_graph and "agents" in _target_graph: _target_graph.agents.clear()
