class_name AgentWalker
extends RefCounted

# --- CONSTANTS ---
const OPTIONS_BEHAVIOR = "Hold Position,Paint (Random),Grow (Expansion),Seek Target,Generate Maze"
const OPTIONS_ALGO = "Random Walk,Breadth-First,Depth-First,A-Star,Dijkstra"

# ==============================================================================
# 1. IDENTITY & STATE
# ==============================================================================

# [IDENTITY]
var uuid: String           # Unique String (Data Integrity / Merging)
var display_id: int        # Simple Integer (UI Readability: "Agent #5")

# [COMPATIBILITY]
var id: int:
	get: return display_id
	set(value): display_id = value

# [PHYSICAL STATE]
var pos: Vector2
var _initial_pos: Vector2  # For resetting correctly
var current_node_id: String
var start_node_id: String 
var step_count: int = 0    # [READ-ONLY STAT]
var history: Array[Dictionary] = []

# SEMANTIC DATA
var custom_data: Dictionary = {}

# [MENTAL STATE]
var brain: AgentBehavior

# The Generic Backpack
var algo_settings: Dictionary = {}

# [NEW] CONSTRAINT SATISFACTION STATE
var last_bump_pos: Vector2 = Vector2.INF # Visual feedback for failed moves
var use_forward_checking: bool = false   # Logic toggle: Filter invalid moves before picking

# ==============================================================================
# 2. CONFIGURATION & SETTINGS
# ==============================================================================

# [BEHAVIOR]
var behavior_mode: int = 0  # 0=Hold, 1=Paint, 2=Grow, 3=Seek
var movement_algo: int = 0  # 0=Random, 1=BFS, 2=DFS, 3=A*
var _current_path_cache: Array[String] = []
var _path_target_id: String = ""
var target_node_id: String = ""

# [PARAMETERS]
var my_paint_type: int = 2 
var active: bool = true           
var is_finished: bool = false     
var snap_to_grid: bool = false
var steps: int = 15
var branch_randomly: bool = false

# --- STATIC TEMPLATES ---
static var spawn_template: Dictionary = {
	"global_behavior": 0, "movement_algo": 0, "target_node_id": "",
	"steps": 15, "paint_type": 2, "snap_to_grid": false, "branch_randomly": false,
	"use_forward_checking": false
}

static func update_template(key: String, value: Variant) -> void:
	if spawn_template.has(key): spawn_template[key] = value

# ==============================================================================
# 3. LIFECYCLE (Init & Reset)
# ==============================================================================

func _init(p_uuid: String, p_display_id: int, start_pos: Vector2, start_node: String, p_type: int, p_steps: int) -> void:
	uuid = p_uuid
	display_id = p_display_id
	
	pos = start_pos
	_initial_pos = start_pos
	current_node_id = start_node
	start_node_id = start_node
	my_paint_type = p_type
	steps = p_steps
	
	if start_node != "":
		history.append({ "node": start_node, "step": 0 })
		
	_refresh_brain()

func reset_state() -> void:
	step_count = 0
	current_node_id = start_node_id 
	pos = _initial_pos              
	history.clear()
	last_bump_pos = Vector2.INF # [NEW] Clear visual artifacts on reset
	
	if start_node_id != "":
		history.append({ "node": start_node_id, "step": 0 })
		
	is_finished = false
	if brain: brain.enter(self, null)

# ==============================================================================
# 4. SERIALIZATION
# ==============================================================================

func serialize() -> Dictionary:
	return {
		"uuid": uuid,
		"display_id": display_id,
		"pos_x": pos.x,
		"pos_y": pos.y,
		"current_node": current_node_id,
		"start_node": start_node_id,
		"step_count": step_count,
		"history": history,
		"custom_data": custom_data,
		"behavior_mode": behavior_mode,
		"movement_algo": movement_algo,
		"algo_settings": algo_settings,
		"path_cache": _current_path_cache,
		"target_node": target_node_id,
		"paint_type": my_paint_type,
		"active": active,
		"is_finished": is_finished,
		"steps": steps,
		"snap_to_grid": snap_to_grid,
		"branch_randomly": branch_randomly,
		"use_forward_checking": use_forward_checking,
	}


static func deserialize(data: Dictionary) -> AgentWalker:
	var d_uuid = data.get("uuid", "")
	var d_id = int(data.get("display_id", 1))
	var d_pos = Vector2(data.get("pos_x", 0), data.get("pos_y", 0))
	var d_start = data.get("start_node", "")
	var d_paint = int(data.get("paint_type", 2))
	var d_steps = int(data.get("steps", 15))
	
	var agent = AgentWalker.new(d_uuid, d_id, d_pos, d_start, d_paint, d_steps)
	
	agent.current_node_id = data.get("current_node", "")
	agent.step_count = int(data.get("step_count", 0))
	
	var raw_history = data.get("history", [])
	if raw_history is Array:
		agent.history.clear() 
		agent.history.assign(raw_history)
	
	agent.custom_data = data.get("custom_data", {})
	
	agent.behavior_mode = int(data.get("behavior_mode", 0))
	agent.movement_algo = int(data.get("movement_algo", 0))
	agent.algo_settings = data.get("algo_settings", {})
	agent._current_path_cache.assign(data.get("path_cache", []))
	agent.target_node_id = data.get("target_node", "")
	agent.active = data.get("active", true)
	agent.is_finished = data.get("is_finished", false)
	agent.snap_to_grid = data.get("snap_to_grid", false)
	agent.branch_randomly = data.get("branch_randomly", false)
	agent.use_forward_checking = data.get("use_forward_checking", false)
	
	agent._refresh_brain()
	return agent

# ==============================================================================
# 5. BEHAVIOR LOGIC (Unchanged)
# ==============================================================================

func step(graph: Graph, _context: Dictionary = {}) -> void:
	if not active: return
	if steps != -1 and step_count >= steps:
		is_finished = true
		return

	if not brain: _refresh_brain()
	
	# [NEW] Clear bump visualization at start of every step
	# This ensures the red line only lasts for one "tick"
	last_bump_pos = Vector2.INF
	
	brain.step(self, graph)

func _refresh_brain() -> void:
	match behavior_mode:
		0: set_behavior(BehaviorHold.new())
		1: 
			var wander = BehaviorWander.new()
			set_behavior(BehaviorDecoratorPaint.new(wander))
		2: set_behavior(BehaviorGrow.new()) 
		3: set_behavior(BehaviorSeek.new(movement_algo))
		4: set_behavior(BehaviorMazeGen.new())
		_: set_behavior(BehaviorHold.new())

func set_behavior(new_brain: AgentBehavior, graph: Graph = null) -> void:
	if brain: brain.exit(self, graph)
	brain = new_brain
	if brain: brain.enter(self, graph)

# ==============================================================================
# 6. ACTIONS API (Unchanged)
# ==============================================================================

func move_to_node(node_id: String, graph: Graph) -> void:
	if not graph.nodes.has(node_id): return
	var new_pos = graph.get_node_pos(node_id)
	pos = new_pos
	current_node_id = node_id
	step_count += 1
	history.append({ "node": node_id, "step": step_count })

func paint_current_node(graph: Graph, type_idx: int = -1) -> void:
	if current_node_id == "": return
	var t = type_idx if type_idx != -1 else my_paint_type
	graph.set_node_type(current_node_id, t)

func warp(new_pos: Vector2, new_node_id: String = "") -> void:
	pos = new_pos
	current_node_id = new_node_id

func generate_unique_id(graph) -> String:
	var temp_count = step_count + 1 
	var new_id = "walk:%d:%d" % [display_id, temp_count]
	while graph.nodes.has(new_id):
		temp_count += 1
		new_id = "walk:%d:%d" % [display_id, temp_count]
	return new_id

# This replaces raw calls to AgentNavigator.get_next_step
func get_next_move_step(graph: Graph) -> String:
	
	# 1. Invalid Cache Check
	# If the target changed, cache is empty, or we finished the previous path...
	var needs_recalc = false
	
	# A. Target Changed?
	if target_node_id != _path_target_id: 
		needs_recalc = true
	# B. Cache Empty?
	elif _current_path_cache.is_empty(): 
		needs_recalc = true
	
	# C. Lost/Desync Check? 
	# If cache says "Go B", but we are currently at "D", we are lost.
	# We allow being at index 0 (current) or index 1 (next, if we just moved).
	if not _current_path_cache.is_empty():
		# Logic: The first item in cache should normally be where we are standing NOW.
		if _current_path_cache[0] != current_node_id:
			# Special Case: Did we already step forward and forget to commit?
			if _current_path_cache.size() > 1 and _current_path_cache[1] == current_node_id:
				# We are actually at the 'next' node. Fix the cache.
				_current_path_cache.pop_front()
			else:
				# We are truly lost. Recalculate.
				needs_recalc = true

	if needs_recalc:
		_recalculate_path(graph)
		
	# 2. Retrieve Next Step from Memory
	if _current_path_cache.is_empty(): return ""
	
	# The path array is [Current, Next, Next+1, ... End]
	# We want index 1.
	if _current_path_cache.size() > 1:
		return _current_path_cache[1]
	
	return ""

# Call this AFTER a successful move to update the memory
func commit_move(node_id: String) -> void:
	# If we moved to the node we expected, remove the old 'current' from the list
	if not _current_path_cache.is_empty() and _current_path_cache.size() > 1:
		if _current_path_cache[1] == node_id:
			_current_path_cache.pop_front() # Remove old 'Current'
			# Now the node we just entered is index 0

func _recalculate_path(graph: Graph) -> void:
	_path_target_id = target_node_id
	_current_path_cache.clear()
	
	if current_node_id == "" or target_node_id == "": return
	
	# Pack options for the strategy
	var options = algo_settings.duplicate()
	options["max_steps"] = steps
	
	# [FIX] Pass options as the 5th argument
	var full_path = AgentNavigator.get_projected_path(
		current_node_id, 
		target_node_id, 
		movement_algo, 
		graph,
		options
	)
	
	_current_path_cache = full_path

# ==============================================================================
# 7. UI / INSPECTOR SUPPORT
# ==============================================================================

# Returns the definition list for the SettingsUIBuilder
static func get_template_settings() -> Array[Dictionary]:
	var ids = GraphSettings.current_names.keys()
	ids.sort()
	var names: PackedStringArray = []
	var default_idx = 0
	for i in range(ids.size()):
		var type_id = ids[i]
		names.append(GraphSettings.get_type_name(type_id))
		if type_id == 2: default_idx = i 
	var options_string = ",".join(names)
	
	return [
		{ "name": "global_behavior", "label": "Goal", "type": TYPE_INT, "default": 0, "options": OPTIONS_BEHAVIOR },
		{ "name": "movement_algo", "label": "Pathfinding", "type": TYPE_INT, "default": 0, "options": OPTIONS_ALGO },
		{ "name": "use_forward_checking", "label": "Forward Checking", "type": TYPE_BOOL, "default": false, "hint": "Filter blocked paths vs Fail blindly" },
		{ "name": "target_node", "label": "Target ID", "type": TYPE_STRING, "default": "" },
		{ "name": "active", "type": TYPE_BOOL, "default": true },
		{ "name": "paint_type", "type": TYPE_INT, "default": default_idx, "options": options_string },
		{ "name": "steps", "label": "Step Limit", "type": TYPE_INT, "default": 15, "min": -1, "hint": "Set to -1 for Endless Mode" },
		{ "name": "snap_to_grid", "type": TYPE_BOOL, "default": false },
		{ "name": "branch_randomly", "type": TYPE_BOOL, "default": false }
	]

# Returns instance-specific settings (with current values)
func get_agent_settings() -> Array[Dictionary]:
	var settings = AgentWalker.get_template_settings()
	
	for s in settings:
		if s.name == "active": s.default = active
		elif s.name == "steps": s.default = steps
		elif s.name == "snap_to_grid": s.default = snap_to_grid
		elif s.name == "branch_randomly": s.default = branch_randomly
		elif s.name == "global_behavior": s.default = behavior_mode
		elif s.name == "movement_algo": s.default = movement_algo
		elif s.name == "target_node": s.default = target_node_id
		elif s.name == "use_forward_checking": s.default = use_forward_checking
		elif s.name == "paint_type":
			var ids = GraphSettings.current_names.keys()
			ids.sort()
			var idx = ids.find(my_paint_type)
			if idx != -1: s.default = idx
			
	# Insert Read-Only Statistics
	settings.append({ 
		"name": "stat_steps", 
		"label": "Steps Taken", 
		"type": TYPE_STRING, 
		"default": "%d / %d" % [step_count, steps],
		"hint": "read_only"
	})

	# Actions
	settings.append_array([
		{ "name": "pos", "type": TYPE_VECTOR2, "default": pos },
		{ "name": "action_delete", "type": TYPE_BOOL, "hint": "action", "label": "Delete Agent" }
	])
	return settings

# Applies settings from a dictionary (e.g. Inspector change)
func apply_setting(key: String, value: Variant) -> void:
	var brain_dirty = false
	match key:
		"global_behavior": 
			behavior_mode = value
			brain_dirty = true
		"movement_algo": 
			movement_algo = value
			brain_dirty = true
		
		# [NEW] Intercept Algorithm Settings
		# Since we don't have variables for them anymore, we check if they are
		# part of our known algorithm keys (or just dump them in).
		"rw_vibrate", "rw_backtrack", "heuristic_scale":
			algo_settings[key] = value
			# We don't necessarily need to restart the brain, 
			# but we might need to clear the path cache if params changed?
			_current_path_cache.clear()
		"target_node": target_node_id = value
		"active": active = value
		"snap_to_grid": snap_to_grid = value
		"steps": steps = value
		"branch_randomly": branch_randomly = value
		"use_forward_checking": use_forward_checking = value
		"paint_type":
			var ids = GraphSettings.current_names.keys()
			ids.sort()
			if value >= 0 and value < ids.size():
				my_paint_type = ids[value]
		"pos": warp(value)
		
		# Catch-all
		_:
			custom_data[key] = value
	
	if brain_dirty:
		_refresh_brain()

func apply_template_defaults() -> void:
	var t = AgentWalker.spawn_template
	behavior_mode = t.get("global_behavior", 0)
	movement_algo = t.get("movement_algo", 0)
	target_node_id = t.get("target_node_id", "")
	steps = t.get("steps", 15)
	my_paint_type = t.get("paint_type", 2)
	snap_to_grid = t.get("snap_to_grid", false)
	branch_randomly = t.get("branch_randomly", false)
	use_forward_checking = t.get("use_forward_checking", false) # [NEW]
	_refresh_brain()
