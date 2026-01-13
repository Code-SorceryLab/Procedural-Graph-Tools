class_name GraphZone
extends Resource

# --- IDENTITY ---
var zone_name: String = "Zone"
var zone_color: Color = Color(0.2, 0.2, 0.2, 0.3) 

# --- SHAPE DEFINITION ---
# Dual Storage: Array for fast rendering, Dict for fast lookup
var cells: Array[Vector2i] = [] 
var _lookup: Dictionary = {}

# Calculated bounding box for camera focus / culling
var bounds: Rect2 = Rect2()

# --- LOGIC ---
# Core rules used by the simulation
var allow_new_nodes: bool = false
var traversal_cost: float = 1.0 
var damage_per_tick: float = 0.0

# [NEW] Dynamic Data (for the Inspector Wizard)
var custom_data: Dictionary = {}

# --- METADATA ---
# List of Node IDs that act as "Ports" (Entrances/Exits)
var ports: Array[String] = [] 

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

# --- SERIALIZATION (The JSON Bridge) ---

func serialize() -> Dictionary:
	# Convert Vector2i array to JSON-safe array
	var safe_cells = []
	for c in cells: safe_cells.append([c.x, c.y])
		
	return {
		"name": zone_name,
		"color": zone_color.to_html(),
		"cells": safe_cells,
		"bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
		
		# Properties
		"allow_new_nodes": allow_new_nodes,
		"traversal_cost": traversal_cost,
		"damage_per_tick": damage_per_tick,
		"ports": ports,
		
		# The Magic Field for your Inspector
		"custom_data": custom_data
	}

static func deserialize(data: Dictionary) -> GraphZone:
	var name = data.get("name", "Unnamed Zone")
	var color = Color.from_string(data.get("color", "gray"), Color.GRAY)
	
	var zone = GraphZone.new(name, color)
	
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
			
	return zone
