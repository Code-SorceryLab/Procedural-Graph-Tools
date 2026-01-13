extends Node2D
class_name GraphRenderer

# ==============================================================================
# 1. VISUAL CONFIGURATION
# ==============================================================================
@export_group("Dimensions")
@export var node_radius: float = GraphSettings.NODE_RADIUS
@export var edge_width: float = GraphSettings.EDGE_WIDTH

@export_group("Colors")
@export var default_color: Color = GraphSettings.COLOR_DEFAULT
@export var selected_color: Color = GraphSettings.COLOR_SELECTED
@export var path_color: Color = GraphSettings.COLOR_PATH
@export var hover_color: Color = GraphSettings.COLOR_HOVER
@export var dragged_color: Color = GraphSettings.COLOR_DRAGGED

@export_group("Debug")
@export var debug_show_depth: bool = false

# Depth Calculation State
var _depth_cache: Dictionary = {}
var _depth_cache_dirty: bool = true

# Tool Overlay Data
var tool_line_start: Vector2 = Vector2.INF
var tool_line_end: Vector2 = Vector2.INF

# Font reference for drawing walker numbers
var font: Font

# ==============================================================================
# 2. DATA REFERENCES
# ==============================================================================
var graph_ref: Graph
var selected_nodes_ref: Array[String] = []
var current_path_ref: Array[String] = []
var new_nodes_ref: Array[String] = [] 
var pre_selection_ref: Array[String] = []
var pre_selected_agents_ref: Array = []
var node_labels_ref: Dictionary = {}
var selected_edges_ref: Array = []

# Reference for Agent Selection
var selected_agent_ids_ref: Array = [] 
# Reference for Agent Selection (Objects)
var selected_agents_ref: Array = []

var selected_zones_ref: Array = []
# ==============================================================================
# 3. INTERACTION STATE
# ==============================================================================
var path_start_ids: Array = [] 
var path_end_ids: Array = []
var drag_start_id: String = ""
var hovered_id: String = ""
var snap_preview_pos: Vector2 = Vector2.INF
var selection_rect: Rect2 = Rect2()

# ==============================================================================
# 4. DRAWING LOOP
# ==============================================================================

func _ready() -> void:
	font = ThemeDB.get_fallback_font()

func _draw() -> void:
	if not graph_ref:
		return
	
	# 0. Draw Zones
	_draw_zones()
	
	# Layer 1: Connections
	_draw_edges()
	
	# Layer 2: A* Path
	_draw_current_path()
	
	# Layer 3: Nodes
	_draw_nodes()
	
	# [NEW] Layer 3.25: Agent Tokens (The Physical Bodies)
	_draw_agent_tokens()
	
	# Layer 3.5: Custom Labels
	_draw_custom_labels()
	
	# Layer 4: Interactive Elements
	_draw_interaction_overlays()

	# Layer 5: Selection Box
	_draw_selection_box()
	
	# Layer 6: Dynamic Depth Overlay
	if debug_show_depth:
		_draw_depth_numbers()


# --- HELPER: ZONES ---
func _draw_zones() -> void:
	# --- DIAGNOSTIC PRINT ---
	#if graph_ref:
	#	print("RENDERER DIAGNOSTIC: Drawing Frame. Zone Count: %d" % graph_ref.zones.size())
	#	if not graph_ref.zones.is_empty():
	#		print(" - First Zone: %s | Bounds: %s" % [graph_ref.zones[0].zone_name, graph_ref.zones[0].bounds])
	#else:
	#	print("RENDERER DIAGNOSTIC: No Graph Ref!")
	# ------------------------

	if not graph_ref or graph_ref.zones.is_empty():
		return
		
	var spacing = GraphSettings.GRID_SPACING
	# Half-size for centering the rect on the node point
	var half_size = spacing / 2.0
	
	for zone in graph_ref.zones:
		# Draw every cell in the zone
		# (Optimized: In a real game we'd merge these into a polygon, but for an editor, drawing rects is fine)
		for cell in zone.cells:
			var world_pos = Vector2(cell.x * spacing.x, cell.y * spacing.y)
			var rect = Rect2(world_pos - half_size, spacing)
			draw_rect(rect, zone.zone_color, true) # Filled
			draw_rect(rect, zone.zone_color.lightened(0.2), false, 1.0) # Border

# --- HELPER: EDGES ---
func _draw_edges() -> void:
	# We use this to avoid drawing bi-directional edges twice
	var drawn_bidirectional := {} 
	
	for id: String in graph_ref.nodes:
		var start_pos = graph_ref.get_node_pos(id)
		
		for neighbor: String in graph_ref.get_neighbors(id):
			var end_pos = graph_ref.get_node_pos(neighbor)
			
			# Construct the sorted pair key for this connection
			var pair = [id, neighbor]
			pair.sort()
			
			# --- 1. DRAW SELECTION HIGHLIGHT ---
			# We draw this first so it appears "behind" the actual edge line
			# Note: We check 'has' on the Array. Since 'pair' is sorted, it matches the stored format.
			if selected_edges_ref.has(pair):
				draw_line(start_pos, end_pos, selected_color, edge_width + 4.0)
			
			# --- 2. DRAW ACTUAL EDGE ---
			
			# Check for return path using our Graph API
			var is_bidirectional = graph_ref.has_edge(neighbor, id)
			
			if is_bidirectional:
				# CASE A: Standard Two-Way Connection
				if drawn_bidirectional.has(pair):
					continue
				
				drawn_bidirectional[pair] = true
				
				draw_line(start_pos, end_pos, GraphSettings.COLOR_EDGE, edge_width)
				
			else:
				# CASE B: One-Way Connection
				draw_line(start_pos, end_pos, GraphSettings.COLOR_EDGE, edge_width)
				_draw_arrow_head(start_pos, end_pos)

# HELPER: Draws an arrow tip at the 'to' position
func _draw_arrow_head(from: Vector2, to: Vector2) -> void:
	var dir = (to - from).normalized()
	
	# Calculate the tip position
	# We back off from the node center by (radius + padding) so the arrow isn't hidden
	var tip_offset = node_radius + 6.0
	var tip = to - (dir * tip_offset)
	
	# Arrow Shape Configuration
	var arrow_size = 12.0
	var angle = PI / 5.0 # ~35 degrees
	
	# Calculate wing points
	var p1 = tip - dir.rotated(angle) * arrow_size
	var p2 = tip - dir.rotated(-angle) * arrow_size
	
	var color = GraphSettings.COLOR_EDGE
	var width = edge_width + 1.0 # Slightly thicker for visibility
	
	draw_line(tip, p1, color, width)
	draw_line(tip, p2, color, width)

# --- HELPER: PATHFINDING LINE ---
func _draw_current_path() -> void:
	if current_path_ref.size() > 1:
		var points = PackedVector2Array()
		for id in current_path_ref:
			points.append(graph_ref.get_node_pos(id))
		draw_polyline(points, path_color, edge_width + 2.0)

# --- HELPER: NODES ---
func _draw_nodes() -> void:
	for id: String in graph_ref.nodes:
		var node_data = graph_ref.nodes[id] as NodeData
		var pos = node_data.position
		
		# 1. Determine Color Priority
		var col = _get_node_color(id, node_data)
		
		# 2. Draw Body
		draw_circle(pos, node_radius, col)
		draw_circle(pos, node_radius * 0.7, Color(0, 0, 0, 0.1))
		
		# 3. Draw Indicators
		_draw_node_indicators(id, pos)

# ==============================================================================
# AGENT RENDERING LOGIC
# ==============================================================================

# --- VISUAL POSITION HELPER ---
# Calculates where an agent should be drawn/clicked based on grouping
func get_agent_visual_position(agent, all_agents_at_node: Array) -> Vector2:
	if agent.current_node_id == "" or not graph_ref.nodes.has(agent.current_node_id):
		return agent.pos # Floating agent
		
	var node_pos = graph_ref.get_node_pos(agent.current_node_id)
	var count = all_agents_at_node.size()
	
	# Optimization: If stack threshold reached, we don't calculate individual orbits
	if count > GraphSettings.AGENT_STACK_THRESHOLD:
		# Return the stack position (usually slightly offset or centered)
		return node_pos # Simplified for stack logic
		
	# CASE 1: SINGLE AGENT
	# Move slightly Up-Right so the Node Center is clickable
	if count == 1:
		return node_pos + Vector2(10, -10)
		
	# CASE 2: MULTIPLE AGENTS (Orbit)
	var index = all_agents_at_node.find(agent)
	var angle = (TAU / count) * index
	# Slightly larger radius for the ring to clear the node visual
	var orbit_radius = GraphSettings.AGENT_RING_OFFSET # e.g., 16.0 or 20.0
	var offset = Vector2(cos(angle), sin(angle)) * orbit_radius
	return node_pos + offset

# --- HIT TESTING API ---
func get_agent_at_position(local_pos: Vector2) -> AgentWalker:
	if not graph_ref or graph_ref.agents.is_empty():
		return null
		
	# 1. Group Agents (Cache this if performance becomes an issue)
	var agents_by_node = {}
	for w in graph_ref.agents: 
		var node_id = w.current_node_id
		if not agents_by_node.has(node_id): agents_by_node[node_id] = []
		agents_by_node[node_id].append(w)
		
	var best_agent = null
	var best_dist = INF
	var hit_radius = 10.0 # Match visual size (approx 10px radius)
	
	for node_id in agents_by_node:
		if not graph_ref.nodes.has(node_id): continue
		
		var node_pos = graph_ref.get_node_pos(node_id)
		# Fast bounding check
		if local_pos.distance_squared_to(node_pos) > 3600: # 60px^2
			continue
			
		var node_agents = agents_by_node[node_id]
		var count = node_agents.size()
		
		# CASE A: Stack
		if count > GraphSettings.AGENT_STACK_THRESHOLD:
			# Stack logic: hit the node center area
			if local_pos.distance_to(node_pos) < 20.0:
				return node_agents.back()
		
		# CASE B: Individual Tokens
		else:
			for agent in node_agents:
				var visual_pos = get_agent_visual_position(agent, node_agents)
				var dist = local_pos.distance_to(visual_pos)
				
				if dist < hit_radius and dist < best_dist:
					best_dist = dist
					best_agent = agent
					
	return best_agent

# --- DRAWING ---
func _draw_agent_tokens() -> void:
	if not graph_ref or graph_ref.agents.is_empty():
		return
	
	var agents_by_node = {}
	for w in graph_ref.agents: 
		var node_id = w.current_node_id
		if not agents_by_node.has(node_id): agents_by_node[node_id] = []
		agents_by_node[node_id].append(w)
		
	for node_id in agents_by_node:
		if not graph_ref.nodes.has(node_id): continue
		
		var node_agents = agents_by_node[node_id]
		var count = node_agents.size()
		var node_pos = graph_ref.get_node_pos(node_id)
		
		if count > GraphSettings.AGENT_STACK_THRESHOLD:
			_draw_agent_stack_icon(node_pos, count)
		else:
			for agent in node_agents:
				# [FIX] Use shared visual logic
				var draw_pos = get_agent_visual_position(agent, node_agents)
				
				var is_selected = selected_agent_ids_ref.has(agent)
				_draw_diamond_token(draw_pos, is_selected, agent)
				
				if is_selected:
					_draw_agent_brain(agent)

func _draw_diamond_token(center: Vector2, is_selected: bool, agent_ref: Object) -> void:
	var radius = GraphSettings.AGENT_RADIUS
	
	var points = PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius, 0)
	])
	
	# 1. Fill Logic
	var fill_col = GraphSettings.COLOR_AGENT_NORMAL
	
	# If selected OR pre-selected, we can optionally light up the face too
	if is_selected:
		fill_col = GraphSettings.COLOR_AGENT_SELECTED
	
	draw_colored_polygon(points, fill_col)
	
	# 2. Outline Logic
	var line_col = Color.WHITE
	var width = 1.0
	
	# DEFINE GOLD COLOR (Matches your theme)
	var selection_gold = Color(1, 0.8, 0.2) 
	
	if is_selected:
		# STATUS: CONFIRMED SELECTION
		# Full Opacity, Thick Line
		line_col = selection_gold
		width = 3.0
		
	elif pre_selected_agents_ref.has(agent_ref):
		# STATUS: HOVER / PRE-SELECTION
		# Same Gold Color, slightly transparent, slightly thinner
		# This says "I am about to be selected"
		line_col = selection_gold
		line_col.a = 0.7 
		width = 3.0
		
	else:
		# STATUS: NORMAL
		line_col = Color.BLACK
		width = 1.0
		
	points.append(points[0]) # Close loop
	draw_polyline(points, line_col, width)

func _draw_agent_stack_icon(center: Vector2, count: int) -> void:
	# Draw a slightly larger diamond
	var radius = GraphSettings.AGENT_RADIUS * 1.5
	var points = PackedVector2Array([
		center + Vector2(0, -radius),
		center + Vector2(radius, 0),
		center + Vector2(0, radius),
		center + Vector2(-radius, 0)
	])
	
	# White background for stack
	draw_colored_polygon(points, GraphSettings.COLOR_AGENT_STACK)
	
	# Draw Count Text
	# Move text slightly up/left to center it manually
	var text_pos = center + Vector2(-4, 4) 
	draw_string(font, text_pos, str(count), HORIZONTAL_ALIGNMENT_CENTER, -1, 10, Color.BLACK)

# 2. Add Visual Hit Testing for Rects
func get_agents_in_visual_rect(local_rect: Rect2) -> Array:
	if not graph_ref: return []
	var result = []
	
	var agents_by_node = {}
	for w in graph_ref.agents: 
		var node_id = w.current_node_id
		if not agents_by_node.has(node_id): agents_by_node[node_id] = []
		agents_by_node[node_id].append(w)
		
	for node_id in agents_by_node:
		if not graph_ref.nodes.has(node_id): continue
		
		var node_pos = graph_ref.get_node_pos(node_id)
		if not local_rect.grow(50).has_point(node_pos): continue
			
		var node_agents = agents_by_node[node_id]
		var count = node_agents.size()
		
		for i in range(count):
			var agent = node_agents[i]
			var visual_pos = node_pos
			
			if count > 1 and count <= GraphSettings.AGENT_STACK_THRESHOLD:
				var angle = (TAU / count) * i
				var offset = Vector2(cos(angle), sin(angle)) * GraphSettings.AGENT_RING_OFFSET
				visual_pos += offset
			
			if local_rect.has_point(visual_pos):
				result.append(agent)
				
	return result

# BRAIN VISUALIZATION HELPER
func _draw_agent_brain(agent) -> void:
	# 1. VISUALIZE RANDOM WALK (Mode 1: Paint/Random or Mode 3 with Algo 0)
	# If agent is set to "Paint" OR "Seek" with "Random Algo"
	if agent.behavior_mode == 1 or (agent.behavior_mode == 3 and agent.movement_algo == 0):
		var neighbors = graph_ref.get_neighbors(agent.current_node_id)
		for n_id in neighbors:
			var n_pos = graph_ref.get_node_pos(n_id)
			var dir = (n_pos - agent.pos).normalized()
			var arrow_start = agent.pos + (dir * 10.0)
			var arrow_end = agent.pos + (dir * 25.0) # Short stubby arrow
			
			# Draw Arrows indicating "I might go here"
			_draw_arrow_head_visual(arrow_start, arrow_end, Color(1, 1, 0, 0.6))
			
	# 2. VISUALIZE TARGET SEEKING (Mode 3)
	elif agent.behavior_mode == 3 and agent.target_node_id != "":
		if graph_ref.nodes.has(agent.target_node_id):
			var target_pos = graph_ref.get_node_pos(agent.target_node_id)
			
			# Draw Dashed Line (Intent)
			draw_dashed_line(agent.pos, target_pos, Color(1, 1, 1, 0.5), 2.0, 10.0)
			
			# Draw Target Reticle
			draw_circle(target_pos, 4.0, Color(1, 0, 0, 0.5))
			draw_arc(target_pos, 8.0, 0, TAU, 16, Color(1, 0, 0, 0.5), 1.0)

# Helper for drawing small visual arrows
func _draw_arrow_head_visual(from: Vector2, to: Vector2, color: Color) -> void:
	draw_line(from, to, color, 2.0)
	var dir = (to - from).normalized()
	var tip = to
	var size = 6.0
	var angle = PI / 5.0
	draw_line(tip, tip - dir.rotated(angle) * size, color, 2.0)
	draw_line(tip, tip - dir.rotated(-angle) * size, color, 2.0)

# --- 3.5 HELPER: CUSTOM LABELS ---
func _draw_custom_labels() -> void:
	if node_labels_ref.is_empty():
		return
	
	#print("Renderer: Drawing %d labels." % node_labels_ref.size())
	
	# Draw text for every node in the dictionary
	for id in node_labels_ref:
		# Safety check: ensure the node actually exists in the graph
		if not graph_ref.nodes.has(id):
			continue
			
		var pos = graph_ref.get_node_pos(id)
		var text = node_labels_ref[id]
		
		# Position: Top Right, slightly higher than the Red End Marker
		# Red Marker is at Y = -radius + 8. We go up to Y = -radius - 8 to stack above it.
		var text_pos = pos + Vector2(node_radius + 4, -node_radius - 8)
		
		# Draw with high opacity for readability
		draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.9))

# --- HELPER: INTERACTIVE OVERLAYS ---
func _draw_interaction_overlays() -> void:
	if snap_preview_pos != Vector2.INF:
		draw_circle(snap_preview_pos, node_radius, Color(1, 1, 1, 0.3))
		draw_line(snap_preview_pos - Vector2(5,0), snap_preview_pos + Vector2(5,0), Color(1,1,1,0.5), 1.0)
		draw_line(snap_preview_pos - Vector2(0,5), snap_preview_pos + Vector2(0,5), Color(1,1,1,0.5), 1.0)
	
	if not drag_start_id.is_empty():
		var start_pos = graph_ref.get_node_pos(drag_start_id)
		var mouse_pos = get_local_mouse_position()
		draw_line(start_pos, mouse_pos, dragged_color, 2.0)
	
	if tool_line_start != Vector2.INF and tool_line_end != Vector2.INF:
		draw_line(tool_line_start, tool_line_end, Color.ORANGE_RED, 2.0)

func _draw_selection_box():
	if selection_rect.has_area():
		draw_rect(selection_rect, GraphSettings.COLOR_SELECT_BOX_Fill, true)
		draw_rect(selection_rect, GraphSettings.COLOR_SELECT_BOX_BORDER, false, 1.0)

# ==============================================================================
# 5. DYNAMIC DEPTH LOGIC (The New Brain)
# ==============================================================================

func _draw_depth_numbers() -> void:
	if _depth_cache_dirty:
		_recalculate_depth_cache()
	
	var default_font = ThemeDB.fallback_font
	var font_size = 14
	
	var start_hue = 0.33 
	var hue_step = 0.05 
	
	for id in _depth_cache:
		if not graph_ref.nodes.has(id): continue
		
		var pos = graph_ref.get_node_pos(id)
		var depth_val = _depth_cache[id]
		var text = str(depth_val)
		
		var current_hue = fmod(start_hue + (depth_val * hue_step), 1.0)
		
		# CHANGED: Saturation lowered from 0.85 to 0.55
		# Value kept at 1.0 (Maximum Brightness)
		var depth_color = Color.from_hsv(current_hue, 0.55, 1.0)
		
		var text_size = default_font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = pos + Vector2(-text_size.x / 2.0, text_size.y / 4.0)
		
		# Increased outline thickness to 4 for better contrast against the lighter text
		draw_string_outline(default_font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, 4, Color.BLACK)
		draw_string(default_font, text_pos, text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, depth_color)

func _recalculate_depth_cache() -> void:
	_depth_cache.clear()
	if graph_ref.nodes.is_empty():
		return
		
	# A. IDENTIFY SEEDS (Roots)
	var seeds: Array[String] = []
	
	# Priority 1: Selected Nodes (Context-Sensitive Depth)
	var selected_spawns: Array[String] = [] 
	
	for id in selected_nodes_ref:
		if graph_ref.nodes.has(id):
			var node = graph_ref.nodes[id]
			if node.type == NodeData.RoomType.SPAWN:
				selected_spawns.append(id)
	
	if not selected_spawns.is_empty():
		seeds = selected_spawns
	
	# Priority 2: All Spawns (Global Depth)
	# If nothing specific is selected, flow from ALL entrances.
	if seeds.is_empty():
		for id in graph_ref.nodes:
			if graph_ref.nodes[id].type == NodeData.RoomType.SPAWN:
				seeds.append(id)
				
	# Priority 3: Fallback (Center)
	# If the graph has NO spawns, pick the node closest to 0,0
	if seeds.is_empty():
		var closest = ""
		var min_dist = INF
		for id in graph_ref.nodes:
			var d = graph_ref.get_node_pos(id).length_squared()
			if d < min_dist:
				min_dist = d
				closest = id
		if closest != "":
			seeds.append(closest)

	# B. BREADTH-FIRST SEARCH (The "Flow")
	var queue: Array = []
	for seed_id in seeds:
		_depth_cache[seed_id] = 0
		queue.append(seed_id)
		
	while not queue.is_empty():
		var current = queue.pop_front()
		var current_depth = _depth_cache[current]
		
		for neighbor in graph_ref.get_neighbors(current):
			if not _depth_cache.has(neighbor):
				_depth_cache[neighbor] = current_depth + 1
				queue.append(neighbor)
	
	_depth_cache_dirty = false

# ==============================================================================
# 6. UTILITY FUNCTIONS
# ==============================================================================

func _get_node_color(id: String, node_data: NodeData) -> Color:
	var col = GraphSettings.get_color(node_data.type)
	if new_nodes_ref.has(id):
		col = GraphSettings.COLOR_NEW_GENERATION
	return col

func _draw_node_indicators(id: String, pos: Vector2) -> void:
	# 1. Selection Rings
	if selected_nodes_ref.has(id) or pre_selection_ref.has(id):
		draw_arc(pos, node_radius + 4.0, 0, TAU, 32, selected_color, 3.0)
	elif id == hovered_id:
		draw_arc(pos, node_radius + 4.0, 0, TAU, 32, hover_color, 2.0)
	
	# 2. START INDICATORS (Green, Top-Left Text)
	var start_indices = []
	for i in range(path_start_ids.size()):
		if path_start_ids[i] == id:
			start_indices.append(str(i + 1)) # "1", "2"
			
	if not start_indices.is_empty():
		# Draw the Ring (Once)
		draw_circle(pos, node_radius * 0.5, GraphSettings.COLOR_PATH_START) 
		draw_arc(pos, node_radius + 9.0, 0, TAU, 32, GraphSettings.COLOR_PATH_START, 3.0) 
		
		# Draw the Numbers (Top Left)
		var label = ",".join(start_indices)
		# Position: Left and Up relative to the node
		var text_pos = pos + Vector2(-node_radius - 24, -node_radius + 8)
		# Align Right so text grows outward to the left
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_RIGHT, -1, 16, GraphSettings.COLOR_PATH_START)

	# 3. END INDICATORS (Red, Top-Right Text)
	var end_indices = []
	for i in range(path_end_ids.size()):
		if path_end_ids[i] == id:
			end_indices.append(str(i + 1))
			
	if not end_indices.is_empty():
		# Draw the Ring (Once)
		draw_circle(pos, node_radius * 0.5, GraphSettings.COLOR_PATH_END)
		draw_arc(pos, node_radius + 6.0, 0, TAU, 32, GraphSettings.COLOR_PATH_END, 3.0)
		
		# Draw the Numbers (Top Right)
		var label = ",".join(end_indices)
		# Position: Right and Up relative to the node
		var text_pos = pos + Vector2(node_radius + 4, -node_radius + 8)
		# Align Left so text grows outward to the right
		draw_string(font, text_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GraphSettings.COLOR_PATH_END)
