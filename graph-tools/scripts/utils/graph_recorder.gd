class_name GraphRecorder
extends Graph

# The payload we will deliver to the Undo System later
var recorded_commands: Array[GraphCommand] = []

# The Real Graph (Who the commands will actually affect later)
var _target_graph: Graph

func _init(target: Graph, clone_data: bool = true) -> void:
	_target_graph = target
	
	# --- STATE CLONE ---
	if clone_data:
		# 1. Duplicate nodes
		for id in target.nodes:
			nodes[id] = target.nodes[id].duplicate()
		
		# 2. Duplicate Edge Data (Deep Copy)
		edge_data = target.edge_data.duplicate(true)
			
		# 3. Rebuild spatial grid
		_rebuild_spatial_grid()
		
		# 4. Clone Existing Zones (So algorithms can see existing claims)
		# We duplicate the array so we don't accidentally modify the real list directly
		if "zones" in target:
			zones = target.zones.duplicate()

# --- MUTATOR OVERRIDES ---

# [NEW] Handle Zone Registration
func add_zone(zone: GraphZone) -> void:
	# 1. Update Simulation (So this algorithm sees its own zone immediately)
	super.add_zone(zone)
	
	# 2. Apply to Target (Directly for now)
	# Since we don't have a CmdAddZone yet, we bypass the undo stack for metadata.
	# This ensures the zone appears in the editor immediately.
	if _target_graph and _target_graph.has_method("add_zone"):
		_target_graph.add_zone(zone)
	else:
		push_error("GraphRecorder: Target graph missing add_zone method.")

func add_node(id: String, pos: Vector2 = Vector2.ZERO) -> void:
	var already_exists = nodes.has(id)
	
	super.add_node(id, pos)
	
	if not already_exists:
		var cmd = CmdAddNode.new(_target_graph, id, pos)
		recorded_commands.append(cmd)

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
