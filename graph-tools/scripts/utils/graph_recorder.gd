class_name GraphRecorder
extends Graph

# The payload we will deliver to the Undo System later
var recorded_commands: Array[GraphCommand] = []

# The Real Graph (Who the commands will actually affect later)
var _target_graph: Graph

# [NEW] Zone Context State
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
		
		# 2. Duplicate Edge Data (Deep Copy)
		edge_data = target.edge_data.duplicate(true)
			
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

# ==============================================================================
# 2. MUTATOR OVERRIDES (With Hooks)
# ==============================================================================

func add_node(id: String, pos: Vector2 = Vector2.ZERO) -> void:
	var already_exists = nodes.has(id)
	
	# 1. Update Simulation
	super.add_node(id, pos)
	
	# [NEW] 1.5. Automatic Zone Registration Hook
	if _active_zone:
		_active_zone.register_node(id)
		# Use Smart 2x2 (Radius 0) if enabled, otherwise 3x3 (Radius 1)
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

# ... (Keep all existing methods below: add_edge, remove_node, etc.) ...

func add_edge(a: String, b: String, weight: float = 1.0, directed: bool = false, extra_data: Dictionary = {}) -> void:
	var already_exists = has_edge(a, b)
	super.add_edge(a, b, weight, directed, extra_data)
	if not already_exists:
		var cmd = CmdConnect.new(_target_graph, a, b, weight)
		recorded_commands.append(cmd)

func remove_node(id: String) -> void:
	super.remove_node(id)
	var cmd = CmdDeleteNode.new(_target_graph, id)
	recorded_commands.append(cmd)

func remove_edge(a: String, b: String, directed: bool = false) -> void:
	var w = get_edge_weight(a, b)
	super.remove_edge(a, b, directed)
	var cmd = CmdDisconnect.new(_target_graph, a, b, w)
	recorded_commands.append(cmd)

func set_node_type(id: String, new_type: int) -> void:
	if nodes.has(id):
		nodes[id].type = new_type
	var old_type = 0
	if _target_graph.nodes.has(id):
		old_type = _target_graph.nodes[id].type
	var cmd = CmdSetType.new(_target_graph, id, old_type, new_type)
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
