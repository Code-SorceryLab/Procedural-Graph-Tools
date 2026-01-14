class_name GraphZone
extends Resource

# Zone Types
enum ZoneType {
	GEOGRAPHICAL, # Defined by fixed grid cells. Nodes enter/leave.
	LOGICAL       # Defined by the roster of nodes. Zone shape follows them.
}

# --- IDENTITY ---
var zone_name: String = "Zone"
var zone_color: Color = Color(0.2, 0.2, 0.2, 0.3) 

# Configuration
var zone_type: ZoneType = ZoneType.GEOGRAPHICAL
# Interaction Rule
@export var is_grouped: bool = false # If true, selecting one selects all.

# --- SHAPE DEFINITION ---
# Dual Storage: Array for fast rendering, Dict for fast lookup
var cells: Array[Vector2i] = [] 
var _lookup: Dictionary = {}

# Calculated bounding box for camera focus / culling
var bounds: Rect2 = Rect2()

# --- LOGIC ---
# Core rules used by the simulation
var is_active: bool = true
var allow_new_nodes: bool = false
var traversal_cost: float = 1.0 
var damage_per_tick: float = 0.0

# [NEW] Dynamic Data (for the Inspector Wizard)
var custom_data: Dictionary = {}

# --- METADATA ---
# List of Node IDs that act as "Ports" (Entrances/Exits)
var ports: Array[String] = [] 

# [NEW] The "Live Roster"
# A list of node IDs currently considered "inside" or "belonging to" this zone.
# We verify this list does not save duplicates.
var registered_nodes: Array[String] = []
var _roster_lookup: Dictionary = {} # Fast Lookup Cache

# --- LIFECYCLE ---

func _init(p_name: String = "Zone", p_color: Color = Color(0.5, 0.5, 0.5, 0.3)) -> void:
	zone_name = p_name
	zone_color = p_color

# --- SHAPE API ---

func add_cell(grid_pos: Vector2i, spacing: Vector2) -> void:
	if _lookup.has(grid_pos): return
	
	# 1. Add to Data Structures
	cells.append(grid_pos)
	_lookup[grid_pos] = true
	
	# 2. Update Bounds (Incremental Expand)
	var world_pos = Vector2(grid_pos.x * spacing.x, grid_pos.y * spacing.y)
	var size = spacing
	# Assuming grid_pos is center; calculate Top-Left
	var tl = world_pos - (size / 2.0)
	var rect = Rect2(tl, size)
	
	if bounds.has_area():
		bounds = bounds.merge(rect)
	else:
		bounds = rect

func remove_cell(grid_pos: Vector2i) -> void:
	if not _lookup.has(grid_pos): return
	
	cells.erase(grid_pos)
	_lookup.erase(grid_pos)
	
	# Note: We don't shrink bounds on remove because it's expensive (requires recalc).
	# Ideally, you recalculate bounds only when finished editing.

func has_cell(grid_pos: Vector2i) -> bool:
	return _lookup.has(grid_pos)

func clear() -> void:
	cells.clear()
	_lookup.clear()
	bounds = Rect2()
	ports.clear()

# Roster Management
func register_node(node_id: String) -> void:
	# O(1) Check instead of O(N)
	if not _roster_lookup.has(node_id):
		_roster_lookup[node_id] = true
		registered_nodes.append(node_id)

func unregister_node(node_id: String) -> void:
	if _roster_lookup.has(node_id):
		_roster_lookup.erase(node_id)
		registered_nodes.erase(node_id) # This is still O(N), but happens rarely (only on exit)

# Adds a patch centered on a world position.
# Radius 1 = 3x3 grid (9 cells).
# Radius 0 (Default) = Smart 2x2 grid (4 cells) based on sub-cell position.
func add_patch_at_world_pos(world_pos: Vector2, spacing: Vector2, radius: int = 0) -> void:
	# 1. Identify the Primary Cell (The one the node is mathematically inside)
	var base_gx = round(world_pos.x / spacing.x)
	var base_gy = round(world_pos.y / spacing.y)
	
	# CASE A: 3x3 (Radius 1)
	# Good for "Thick" zones or messy dragging
	if radius >= 1:
		for x in range(-radius, radius + 1):
			for y in range(-radius, radius + 1):
				add_cell(Vector2i(base_gx + x, base_gy + y), spacing)
		return

	# CASE B: Smart 2x2 (Radius 0 / Optimization)
	# We find which "Quadrant" of the cell we are in to pick the best neighbors
	var cell_center = Vector2(base_gx * spacing.x, base_gy * spacing.y)
	var diff = world_pos - cell_center
	
	# If we are to the right of center, expand Right (+1). Else Left (-1).
	var dir_x = 1 if diff.x >= 0 else -1
	# If we are below center, expand Down (+1). Else Up (-1).
	var dir_y = 1 if diff.y >= 0 else -1
	
	# Add the 4 cells of the quadrant
	# 1. The Primary Cell
	add_cell(Vector2i(base_gx, base_gy), spacing) 
	# 2. The Horizontal Neighbor
	add_cell(Vector2i(base_gx + dir_x, base_gy), spacing)
	# 3. The Vertical Neighbor
	add_cell(Vector2i(base_gx, base_gy + dir_y), spacing)
	# 4. The Diagonal Neighbor
	add_cell(Vector2i(base_gx + dir_x, base_gy + dir_y), spacing)


# --- SERIALIZATION (The JSON Bridge) ---

func serialize() -> Dictionary:
	var safe_cells = []
	for c in cells: safe_cells.append([c.x, c.y])
		
	return {
		"name": zone_name,
		"color": zone_color.to_html(),
		"type": zone_type, # [NEW] Save Type
		"cells": safe_cells,
		"bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
		"allow_new_nodes": allow_new_nodes,
		"traversal_cost": traversal_cost,
		"damage_per_tick": damage_per_tick,
		"ports": ports,
		"custom_data": custom_data,
		# Note: We do NOT save registered_nodes for Geographical zones, 
		# as they should be recalculated on load based on position.
		# For Logical/Group zones, we MIGHT save them.
		# For now, let's treat it as transient.
		"registered_nodes": registered_nodes if zone_type != ZoneType.GEOGRAPHICAL else []
	}

static func deserialize(data: Dictionary) -> GraphZone:
	var name = data.get("name", "Unnamed Zone")
	var color = Color.from_string(data.get("color", "gray"), Color.GRAY)
	
	var zone = GraphZone.new(name, color)
	zone.zone_type = int(data.get("type", ZoneType.GEOGRAPHICAL))
	
	# Restore Logic
	zone.allow_new_nodes = data.get("allow_new_nodes", false)
	zone.traversal_cost = float(data.get("traversal_cost", 1.0))
	zone.damage_per_tick = float(data.get("damage_per_tick", 0.0))
	zone.ports.assign(data.get("ports", []))
	zone.custom_data = data.get("custom_data", {})
	
	# Restore Bounds
	var b_arr = data.get("bounds", [])
	if b_arr.size() == 4:
		zone.bounds = Rect2(b_arr[0], b_arr[1], b_arr[2], b_arr[3])
	
	# Restore Spatial Data
	var raw_cells = data.get("cells", [])
	for item in raw_cells:
		if item is Array and item.size() >= 2:
			# We skip bounds recalc here for speed, assuming bounds were loaded above
			var vec = Vector2i(item[0], item[1])
			zone.cells.append(vec)
			zone._lookup[vec] = true
	# Restore Roster (Only for non-geo zones)
	var saved_roster = data.get("registered_nodes", [])
	for id in saved_roster:
		zone.registered_nodes.append(id)
		
	return zone
