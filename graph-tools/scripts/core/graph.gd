extends Resource
class_name Graph

const PRIORITY_QUEUE = preload("res://scripts/utils/priority_queue.gd")
const SPATIAL_GRID = preload("res://scripts/utils/spatial_grid.gd")

# 1. Export the main dictionary
@export var nodes: Dictionary = {}

# Canonical Edge Store
# Format: { "nodeA___nodeB": { "u": "nodeA", "v": "nodeB", "weight": 1.0, "direction": int, "custom": {} } }
# Direction: 0 = Bi-directional, 1 = u->v, 2 = v->u
@export var edge_store: Dictionary = {}

# Fast runtime cache for A* pathfinding
var _adjacency_map: Dictionary = {}

const MIN_TRAVERSAL_COST: float = 0.1


# --- ZONES LAYER ---
@export var zones: Array[GraphZone] = []

# The Ticket Counter
# We export it so it saves/loads with the resource!
@export var agents: Array = [] # Stores AgentWalker objects

# --- ID MANAGEMENT ---
# The "Ticket Counter" for UI readability (1, 2, 3...)
# Saved with the graph so numbers don't reset/duplicate on load
@export var _next_display_id: int = 1

# 2. Spatial partitioning
var _spatial_grid: SpatialGrid = null
var _spatial_grid_dirty: bool = true  
var _node_radius: float = GraphSettings.NODE_RADIUS 

# --- Node Management ---

func add_node(id: String, pos: Vector2 = Vector2.ZERO) -> void:
	if not nodes.has(id):
		nodes[id] = NodeData.new(pos)
		
		# Update spatial grid
		_ensure_spatial_grid()
		_spatial_grid.add_node(id, pos, _node_radius)
		
		# IMMEDIATE ZONE SYNC
		# Fundamental Fix: Any node born on a tile automatically joins that zone.
		_sync_node_zone_membership(id, pos)
		

func remove_node(id: String) -> void:
	if not nodes.has(id): return
	
	# 1. Spatial Grid
	if _spatial_grid != null:
		_spatial_grid.remove_node(id)
	
	# 2. Clean Canonical Edges
	var keys_to_erase = []
	for key in edge_store:
		if edge_store[key].u == id or edge_store[key].v == id:
			keys_to_erase.append(key)
			
	for key in keys_to_erase:
		edge_store.erase(key)
		
	# [PIVOT] O(1) Cache cleanup instead of full rebuild
	if _adjacency_map.has(id): _adjacency_map.erase(id)
	for other_id in _adjacency_map:
		if _adjacency_map[other_id].has(id):
			_adjacency_map[other_id].erase(id)
			
	# 3. Clean Zones
	for zone in zones:
		if zone.contains_node(id):
			zone.unregister_node(id)

	# 4. Clean Agents (The Ghost Fix)
	for i in range(agents.size() - 1, -1, -1):
		var agent = agents[i]
		if agent.current_node_id == id:
			agents.remove_at(i)
	
	# 5. Delete Node
	nodes.erase(id)

# Add a method to update node position (for dragging)
func set_node_position(id: String, new_pos: Vector2) -> void:
	if nodes.has(id):
		var node_data: NodeData = nodes[id]
		node_data.position = new_pos
		
		# Update spatial grid
		_ensure_spatial_grid()
		_spatial_grid.update_node(id, new_pos, _node_radius)
		
		_sync_node_zone_membership(id, new_pos)

# --- Agent Management ---

func add_agent(agent) -> void:
	if not agents.has(agent):
		agents.append(agent)

func remove_agent(agent) -> void:
	if agents.has(agent):
		agents.erase(agent)

# Query API
# Returns all agents currently standing on the given node.
func get_agents_at_node(node_id: String) -> Array:
	var found = []
	for agent in agents:
		if agent.current_node_id == node_id:
			found.append(agent)
	return found

# --- HELPERS ---

# 1. Frontend: Get a nice number for the UI
func get_next_display_id() -> int:
	var id = _next_display_id
	_next_display_id += 1
	return id

# 2. Backend: Find agent by UUID (Used during Merging/Loading)
func get_agent_by_uuid(uuid: String) -> AgentWalker:
	for agent in agents:
		if agent.uuid == uuid:
			return agent
	return null

# 3. Merging Support (Future Proofing)
# When importing an agent from another graph, we keep its UUID 
# but assign it a NEW display_id valid for THIS graph.
func register_imported_agent(agent: AgentWalker) -> void:
	# Generate a new local ticket number to avoid collisions
	agent.display_id = get_next_display_id()
	agents.append(agent)

# --- Edge Management ---

# [PIVOT] Keys are now strictly directed: "A->B"
func get_edge_key(a: String, b: String) -> String:
	return a + "->" + b

func add_edge(a: String, b: String, weight: float = 1.0, directed: bool = false, extra_data: Dictionary = {}) -> void:
	if not nodes.has(a) or not nodes.has(b): return
	
	# 1. Add Forward Edge (A -> B)
	_add_directed_record(a, b, weight, extra_data)
	
	# 2. Add Reverse Edge if Undirected (B -> A)
	if not directed:
		_add_directed_record(b, a, weight, extra_data.duplicate())

# Internal helper for O(1) single-direction inserts
func _add_directed_record(u: String, v: String, weight: float, custom: Dictionary) -> void:
	var key = get_edge_key(u, v)
	
	if edge_store.has(key):
		edge_store[key].weight = weight
		for k in custom: edge_store[key].custom[k] = custom[k]
	else:
		var c = custom.duplicate()
		if not c.has("type"): c["type"] = 0
		if not c.has("physics_spring_length"): c["physics_spring_length"] = 150.0
		if not c.has("physics_stiffness"): c["physics_stiffness"] = 0.5
		
		edge_store[key] = {
			"u": u,
			"v": v,
			"weight": weight,
			"direction": 1, # Always 1 (Forward) because the key itself provides direction!
			"custom": c
		}
		
	# [PIVOT] O(1) Local Cache Update! No more full graph rebuilds!
	if not _adjacency_map.has(u): _adjacency_map[u] = {}
	_adjacency_map[u][v] = weight

func remove_edge(a: String, b: String, directed: bool = false) -> void:
	var key_ab = get_edge_key(a, b)
	if edge_store.has(key_ab):
		edge_store.erase(key_ab)
		if _adjacency_map.has(a): _adjacency_map[a].erase(b)
		
	if not directed:
		var key_ba = get_edge_key(b, a)
		if edge_store.has(key_ba):
			edge_store.erase(key_ba)
			if _adjacency_map.has(b): _adjacency_map[b].erase(a)

func clear_edges() -> void:
	edge_store.clear()
	_adjacency_map.clear()

# Fast pathfinding cache generator (Used mainly for loading saves)
func _rebuild_adjacency_cache() -> void:
	_adjacency_map.clear()
	for id in nodes: _adjacency_map[id] = {}
		
	for key in edge_store:
		var e = edge_store[key]
		if not _adjacency_map.has(e.u): _adjacency_map[e.u] = {}
		_adjacency_map[e.u][e.v] = e.weight

# --- Helpers ---

func has_edge(a: String, b: String) -> bool:
	if _adjacency_map.has(a): return _adjacency_map[a].has(b)
	return false

func get_neighbors(id: String) -> Array:
	if _adjacency_map.has(id): return _adjacency_map[id].keys()
	return []

func get_edge_weight(a: String, b: String) -> float:
	if _adjacency_map.has(a) and _adjacency_map[a].has(b):
		return _adjacency_map[a][b]
	return INF

func get_edge_data(a: String, b: String) -> Dictionary:
	var key = get_edge_key(a, b)
	if edge_store.has(key): return edge_store[key].custom
	return {}

func get_travel_cost(from_id: String, to_id: String) -> float:
	var base_dist = get_edge_weight(from_id, to_id)
	if base_dist == INF: return INF
		
	var multiplier = 1.0
	var to_pos = nodes[to_id].position
	var grid_spacing = GraphSettings.GRID_SPACING
	var grid_pos = Vector2i(round(to_pos.x / grid_spacing.x), round(to_pos.y / grid_spacing.y))
	
	var zone = get_zone_at(grid_pos)
	if zone:
		if not zone.is_traversable: return INF
		multiplier = zone.traversal_cost

	return base_dist * multiplier

func get_node_pos(id: String) -> Vector2:
	if nodes.has(id): return nodes[id].position
	return Vector2.ZERO

func set_edge_weight(id_a: String, id_b: String, weight: float) -> void:
	var key = get_edge_key(id_a, id_b)
	if edge_store.has(key):
		edge_store[key].weight = weight
		# [PIVOT] O(1) Local Cache Update!
		if not _adjacency_map.has(id_a): _adjacency_map[id_a] = {}
		_adjacency_map[id_a][id_b] = weight
	else:
		add_edge(id_a, id_b, weight, true)

# --- Spatial Grid Methods ---

# Initialize spatial grid
func _ensure_spatial_grid() -> void:
	if _spatial_grid == null:
		# Cell size should be 2-4 times node radius for good performance
		var cell_size = GraphSettings.NODE_RADIUS * 4
		_spatial_grid = SPATIAL_GRID.new(cell_size)
		_spatial_grid_dirty = true
	
	if _spatial_grid_dirty:
		_rebuild_spatial_grid()

# Rebuild spatial grid from scratch
func _rebuild_spatial_grid() -> void:
	if _spatial_grid == null:
		return
	
	_spatial_grid.clear()
	
	for id in nodes:
		var node_data: NodeData = nodes[id]
		_spatial_grid.add_node(id, node_data.position, _node_radius)
	
	_spatial_grid_dirty = false

# Get nodes near a position (for mouse picking)
func get_nodes_near_position(pos: Vector2, radius: float = -1.0) -> Array[String]:
	if radius < 0:
		radius = _node_radius
	
	_ensure_spatial_grid()
	return _spatial_grid.query_circle(pos, radius)

# Get nodes in a rectangle (for selection boxes, etc.)
func get_nodes_in_rect(rect: Rect2) -> Array[String]:
	# 1. Broad Phase: Get candidates from the Grid (Fast, but imprecise)
	var candidates: Array[String] = []
	if _spatial_grid:
		candidates = _spatial_grid.query_rect(rect)
	else:
		# If no grid, every node is a candidate
		candidates = nodes.keys()
	
	# 2. Narrow Phase: Check exact positions (Precise)
	var result: Array[String] = []
	for id in candidates:
		if not nodes.has(id): continue
		
		var pos = nodes[id].position
		
		# STRICT CHECK: Is the point actually inside the rectangle?
		if rect.has_point(pos):
			result.append(id)
			
	return result

func get_edges_in_rect(rect: Rect2) -> Array:
	var result = []
	var checked_pairs = {} # Prevent selecting A->B and B->A twice
	
	var rect_tl = rect.position
	var rect_tr = Vector2(rect.end.x, rect.position.y)
	var rect_br = rect.end
	var rect_bl = Vector2(rect.position.x, rect.end.y)
	
	for key in edge_store:
		var e = edge_store[key]
		if not nodes.has(e.u) or not nodes.has(e.v): continue
		
		# Deduplicate visual checks
		var pair = [e.u, e.v]
		pair.sort()
		if checked_pairs.has(pair): continue
		checked_pairs[pair] = true
		
		var pos_a = nodes[e.u].position
		var pos_b = nodes[e.v].position
		
		if rect.has_point(pos_a) and rect.has_point(pos_b):
			result.append(pair); continue
			
		if Geometry2D.segment_intersects_segment(pos_a, pos_b, rect_tl, rect_tr) != null or \
		   Geometry2D.segment_intersects_segment(pos_a, pos_b, rect_tr, rect_br) != null or \
		   Geometry2D.segment_intersects_segment(pos_a, pos_b, rect_br, rect_bl) != null or \
		   Geometry2D.segment_intersects_segment(pos_a, pos_b, rect_bl, rect_tl) != null:
			result.append(pair)
			
	return result


# --- ZONE MANAGEMENT ---
func add_zone(zone: GraphZone) -> void:
	zones.append(zone)

func clear_zones() -> void:
	zones.clear()

# The "Sensor" for Walkers: What zone am I standing in?
func get_zone_at(grid_pos: Vector2i) -> GraphZone:
	# Iterate backwards (newest zones on top)
	for i in range(zones.size() - 1, -1, -1):
		var z = zones[i]
		if z.has_cell(grid_pos):
			return z
	return null

# 2. The Robust Sync Helper (Moved from Editor -> Graph)
func _sync_node_zone_membership(node_id: String, world_pos: Vector2) -> void:
	if zones.is_empty(): return
	
	var spacing = GraphSettings.GRID_SPACING
	var grid_pos = Vector2i(round(world_pos.x / spacing.x), round(world_pos.y / spacing.y))
	
	for zone in zones:
		# We only care about Geographical (Tile) zones for auto-updates
		if zone.zone_type != GraphZone.ZoneType.GEOGRAPHICAL: continue
		
		# [OPTIMIZATION] If you track 'is_active', check it here. 
		# If 'is_active' is UI-only, remove this line.
		if "is_active" in zone and not zone.is_active: continue

		# Logic: Check if we are on a valid tile
		if zone.has_cell(grid_pos):
			# ENTERING / STAYING
			if not zone.registered_nodes.has(node_id):
				zone.register_node(node_id)
		else:
			# LEAVING
			if zone.registered_nodes.has(node_id):
				zone.unregister_node(node_id)

# --- POST-LOAD REPAIR ---

# Call this immediately after loading a graph from JSON
func post_load_fixup() -> void:
	_rebuild_adjacency_cache()
	_rebuild_spatial_grid()
	
	if not zones.is_empty():
		for id in nodes:
			var pos = nodes[id].position
			_sync_node_zone_membership(id, pos)
	
	if not zones.is_empty():
		for id in nodes:
			var pos = nodes[id].position
			_sync_node_zone_membership(id, pos)

# Find node at exact position (for mouse picking)
func get_node_at_position(pos: Vector2, pick_radius: float = -1.0) -> String:
	if pick_radius < 0:
		pick_radius = _node_radius
	
	var candidates = get_nodes_near_position(pos, pick_radius)
	
	var closest_id: String = ""
	var closest_dist: float = INF
	
	for candidate_id in candidates:
		var candidate_pos = get_node_pos(candidate_id)
		var dist = candidate_pos.distance_to(pos)
		if dist <= pick_radius and dist < closest_dist:
			closest_dist = dist
			closest_id = candidate_id
	
	return closest_id

func get_edge_at_position(pos: Vector2, max_dist: float = 10.0) -> Array:
	var closest_dist = INF
	var closest_pair = []
	var checked_pairs = {}
	
	for key in edge_store:
		var e = edge_store[key]
		if not nodes.has(e.u) or not nodes.has(e.v): continue
		
		# Deduplicate visual checks
		var pair = [e.u, e.v]
		pair.sort()
		if checked_pairs.has(pair): continue
		checked_pairs[pair] = true
		
		var pos_a = nodes[e.u].position
		var pos_b = nodes[e.v].position
		var point_on_segment = Geometry2D.get_closest_point_to_segment(pos, pos_a, pos_b)
		var dist = pos.distance_to(point_on_segment)
		
		if dist < max_dist and dist < closest_dist:
			closest_dist = dist
			closest_pair = pair
			
	return closest_pair

# Get spatial grid stats for debugging
func get_spatial_stats() -> Dictionary:
	_ensure_spatial_grid()
	return _spatial_grid.get_stats()

# Clear all nodes (update to handle spatial grid)
func clear() -> void:
	nodes.clear()
	
	# Clear Canonical Edge Store and its cache
	edge_store.clear()
	_adjacency_map.clear()
	
	# Clear visual/logical zones
	zones.clear()
	
	# Clear Agents
	agents.clear()
	
	if _spatial_grid != null:
		_spatial_grid.clear()
	_spatial_grid_dirty = true
