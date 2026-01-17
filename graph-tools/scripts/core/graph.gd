extends Resource
class_name Graph

const PRIORITY_QUEUE = preload("res://scripts/utils/priority_queue.gd")
const SPATIAL_GRID = preload("res://scripts/utils/spatial_grid.gd")

# 1. Export the main dictionary
@export var nodes: Dictionary = {}

# Stores rich data for edges [FromID][ToID] = { data }
@export var edge_data: Dictionary = {}
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
		
		# [NEW] IMMEDIATE ZONE SYNC
		# Fundamental Fix: Any node born on a tile automatically joins that zone.
		_sync_node_zone_membership(id, pos)
		

func remove_node(id: String) -> void:
	if not nodes.has(id): return
	
	# 1. Spatial Grid
	if _spatial_grid != null:
		_spatial_grid.remove_node(id)
	
	# 2. Clean Edges
	for other_id: String in nodes:
		var other_node: NodeData = nodes[other_id]
		if other_node.connections.has(id):
			other_node.connections.erase(id)
			
	# 3. Clean Zones
	for zone in zones:
		if zone.contains_node(id):
			zone.unregister_node(id)

	# 4. Clean Agents (The Ghost Fix)
	# If we don't do this, agents float in the void at the deleted position.
	# We iterate backwards to safely remove while looping.
	for i in range(agents.size() - 1, -1, -1):
		var agent = agents[i]
		if agent.current_node_id == id:
			# Option A: Kill them
			agents.remove_at(i)
			
			# Option B: Warp them to start (Safer)
			# agent.reset_state()
			
			# Option C: Just clear their node ref (Floating)
			# agent.current_node_id = "" 
	
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

# Now accepts an optional 'data' dictionary for future expansion
func add_edge(a: String, b: String, weight: float = 1.0, directed: bool = false, extra_data: Dictionary = {}) -> void:
	if not nodes.has(a) or not nodes.has(b):
		push_error("Graph: Attempted to connect non-existent nodes [%s, %s]" % [a, b])
		return
	
	# 1. Update Legacy Adjacency (For A* Speed)
	var node_a: NodeData = nodes[a]
	node_a.connections[b] = weight
	
	if not directed:
		var node_b: NodeData = nodes[b]
		node_b.connections[a] = weight

	# 2. Update Rich Edge Data (For Logic/Inspector)
	if not edge_data.has(a): edge_data[a] = {}
	
	# Merge weight into data so we have a single source of truth inside edge_data
	var final_data = extra_data.duplicate()
	final_data["weight"] = weight
	# Default type 0 (Standard) if not provided
	if not final_data.has("type"): final_data["type"] = 0
	
	edge_data[a][b] = final_data
	
	if not directed:
		if not edge_data.has(b): edge_data[b] = {}
		# Create independent copy for the return path
		edge_data[b][a] = final_data.duplicate()

func remove_edge(a: String, b: String, directed: bool = false) -> void:
	# 1. Clear Legacy
	if nodes.has(a): nodes[a].connections.erase(b)
	if not directed and nodes.has(b): nodes[b].connections.erase(a)
	
	# 2. Clear Rich Data
	if edge_data.has(a): edge_data[a].erase(b)
	if not directed and edge_data.has(b): edge_data[b].erase(a)

func clear_edges() -> void:
	# 1. Clear Legacy
	for id in nodes:
		if nodes[id] is NodeData:
			nodes[id].connections.clear()
	# 2. Clear Rich Data
	edge_data.clear()

func has_edge(a: String, b: String) -> bool:
	if nodes.has(a):
		return nodes[a].connections.has(b)
	return false

# --- Helpers ---

func get_neighbors(id: String) -> Array:
	if nodes.has(id):
		return nodes[id].connections.keys()
	return []

func get_edge_weight(a: String, b: String) -> float:
	if nodes.has(a):
		return nodes[a].connections.get(b, INF)
	return INF

# Helper to get the full data object
func get_edge_data(a: String, b: String) -> Dictionary:
	if edge_data.has(a) and edge_data[a].has(b):
		return edge_data[a][b]
	return {}

# Unified Cost Function
# Used by A*, Dijkstra, and Decision Making behaviors.
func get_travel_cost(from_id: String, to_id: String) -> float:
	var base_dist = get_edge_weight(from_id, to_id)
	if base_dist == INF: return INF
		
	var multiplier = 1.0
	
	# Resolve Zone
	var to_pos = nodes[to_id].position
	var grid_spacing = GraphSettings.GRID_SPACING
	var grid_pos = Vector2i(round(to_pos.x / grid_spacing.x), round(to_pos.y / grid_spacing.y))
	
	var zone = get_zone_at(grid_pos)
	if zone:
		# [THE FIX] Check 'is_traversable' instead of 'allow_new_nodes'
		if not zone.is_traversable:
			return INF # Absolute Wall
			
		# [FEATURE] Apply the cost multiplier (Mud vs Road)
		multiplier = zone.traversal_cost

	return base_dist * multiplier

func get_node_pos(id: String) -> Vector2:
	if nodes.has(id):
		return nodes[id].position
	return Vector2.ZERO

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
	var checked = {}
	
	# Geometry setup...
	var rect_tl = rect.position
	var rect_tr = Vector2(rect.end.x, rect.position.y)
	var rect_br = rect.end
	var rect_bl = Vector2(rect.position.x, rect.end.y)
	
	# [THE FIX] Iterate ALL edges. 
	# Do NOT use _spatial_grid here, or you can't select the middle of a wire.
	for a in edge_data:
		if not nodes.has(a): continue
		var pos_a = nodes[a].position
		
		for b in edge_data[a]:
			if not nodes.has(b): continue
			
			var pair = [a, b]
			pair.sort() # Sort internally for deduplication
			
			if checked.has(pair): continue
			checked[pair] = true
			
			var pos_b = nodes[b].position
			
			# 1. Box Check (Points inside)
			if rect.has_point(pos_a) and rect.has_point(pos_b):
				result.append(pair); continue
			
			# 2. Segment Intersection Check (The "Crossing" Logic)
			# This detects wires that cross the box even if endpoints are outside.
			if Geometry2D.segment_intersects_segment(pos_a, pos_b, rect_tl, rect_tr) != null:
				result.append(pair); continue
			if Geometry2D.segment_intersects_segment(pos_a, pos_b, rect_tr, rect_br) != null:
				result.append(pair); continue
			if Geometry2D.segment_intersects_segment(pos_a, pos_b, rect_br, rect_bl) != null:
				result.append(pair); continue
			if Geometry2D.segment_intersects_segment(pos_a, pos_b, rect_bl, rect_tl) != null:
				result.append(pair); continue
				
	return result

# Updates existing edge or creates new one
func set_edge_weight(id_a: String, id_b: String, weight: float) -> void:
	# 1. Handle Non-Existent Edge
	if not has_edge(id_a, id_b):
		add_edge(id_a, id_b, weight) # FIXED: Was 'connect_node'
		return
		
	# 2. Update Legacy Adjacency (CRITICAL for A* Pathfinding)
	if nodes.has(id_a):
		nodes[id_a].connections[id_b] = weight
		
	# 3. Update Rich Data (For Inspector/Logic)
	if edge_data.has(id_a) and edge_data[id_a].has(id_b):
		edge_data[id_a][id_b]["weight"] = weight
	
	# Note: We do NOT automatically update B->A here. 
	# This allows for asymmetric weights (e.g. going uphill vs downhill).

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
	# 1. Rebuild Spatial Grid (Crucial for clicking/selecting)
	_rebuild_spatial_grid()
	
	# 2. Re-sync Geographical Zones
	# Since serializers often bypass 'add_node', we must manually 
	# introduce every node to the zones again.
	if not zones.is_empty():
		for id in nodes:
			var pos = nodes[id].position
			_sync_node_zone_membership(id, pos)
			
	# 3. Optional: Verify Integrity
	# (e.g. ensure all edges point to valid nodes)

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

# Returns a sorted pair [id_a, id_b] if an edge is found, or empty [] if none.
func get_edge_at_position(pos: Vector2, max_dist: float = 10.0) -> Array:
	var closest_dist = INF
	var closest_pair = []
	
	# Cache checked pairs to avoid checking A->B and B->A twice
	var checked = {}
	
	# Iterate our new edge_data structure
	for a in edge_data:
		if not nodes.has(a): continue
		var pos_a = nodes[a].position
		
		for b in edge_data[a]:
			if not nodes.has(b): continue
			
			# Create canonical key (Alphabetically sorted)
			var pair = [a, b]
			pair.sort()
			
			if checked.has(pair): continue
			checked[pair] = true
			
			var pos_b = nodes[b].position
			
			# MATH: Distance to Line Segment
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
	
	# Clear Edge Data
	edge_data.clear()
	
	# Clear visual/logical zones
	zones.clear()
	
	# [NEW] Clear Agents
	agents.clear()
	
	if _spatial_grid != null:
		_spatial_grid.clear()
	_spatial_grid_dirty = true
