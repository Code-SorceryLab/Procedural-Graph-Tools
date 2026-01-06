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
			
		# 2. Rebuild spatial grid
		_rebuild_spatial_grid()

# --- MUTATOR OVERRIDES ---

func add_node(id: String, pos: Vector2 = Vector2.ZERO) -> void:
	# FIX: Check if the node already exists in our simulation
	var already_exists = nodes.has(id)
	
	# 1. Update Simulation (Pass-Through)
	super.add_node(id, pos)
	
	# 2. Record Intent (ONLY if it didn't exist before)
	if not already_exists:
		var cmd = CmdAddNode.new(_target_graph, id, pos)
		recorded_commands.append(cmd)

func add_edge(a: String, b: String, weight: float = 1.0, directed: bool = false) -> void:
	# FIX: Check if the edge already exists in our simulation
	# We use 'has_edge' which we added to Graph.gd earlier
	var already_exists = has_edge(a, b)
	
	# 1. Update Simulation
	super.add_edge(a, b, weight, directed)
	
	# 2. Record Intent (ONLY if it didn't exist before)
	# This prevents "Double Booking" edges that belong to the underlying Grid
	if not already_exists:
		var cmd = CmdConnect.new(_target_graph, a, b, weight)
		recorded_commands.append(cmd)

func remove_node(id: String) -> void:
	# Note: If the algorithm deletes a node, we assume it INTENDS to destroy
	# whatever was there (Grid or otherwise), so we always record deletions.
	super.remove_node(id)
	
	var cmd = CmdDeleteNode.new(_target_graph, id)
	recorded_commands.append(cmd)

func remove_edge(a: String, b: String, directed: bool = false) -> void:
	var w = get_edge_weight(a, b)
	
	super.remove_edge(a, b, directed)
	
	var cmd = CmdDisconnect.new(_target_graph, a, b, w)
	recorded_commands.append(cmd)
