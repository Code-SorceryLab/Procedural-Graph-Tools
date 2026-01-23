class_name AgentWalker
extends RefCounted

# --- CONSTANTS ---
const OPTIONS_BEHAVIOR = "Hold Position,Paint (Random),Grow (Expansion),Seek Target,Maze Generator" 
const OPTIONS_ALGO = "Random Walk,Breadth-First,Depth-First,A-Star,Dijkstra"

# ==============================================================================
# 1. NEW ARCHITECTURE: CAPABILITIES
# ==============================================================================

# Registry: "What can I do?"
var capabilities: Dictionary = {} # Key: String, Value: AgentCapability

# Brain: "What do I want to do?"
var brain: AgentBehavior

# ==============================================================================
# 2. IDENTITY & STATE
# ==============================================================================
var uuid: String            
var display_id: int         
var pos: Vector2
var _initial_pos: Vector2  
var current_node_id: String
var start_node_id: String  
var step_count: int = 0    
var history: Array[Dictionary] = []
var custom_data: Dictionary = {}

# The Generic Backpack (Algorithm Specifics)
var algo_settings: Dictionary = {}

# CONSTRAINT & GENERATION STATE
var use_geometric_fc: bool = false
var use_zone_constraints: bool = false
var branching_probability: float = 0.0
var destructive_backtrack: bool = true
var last_bump_pos: Vector2 = Vector2.INF

# ==============================================================================
# 3. CONFIGURATION
# ==============================================================================
var behavior_mode: int = 0  
var movement_algo: int = 0  
var _current_path_cache: Array[String] = []
var _path_target_id: String = ""
var target_node_id: String = ""

var my_paint_type: int = 2 
var active: bool = true             
var is_finished: bool = false       
var snap_to_grid: bool = false
var steps: int = 15

# --- STATIC TEMPLATES ---
static var spawn_template: Dictionary = {
	"global_behavior": 0, "movement_algo": 0, "target_node_id": "",
	"steps": 15, "paint_type": 2, "snap_to_grid": false, 
	"use_geometric_fc": false, "use_zone_constraints": false,
	"branching_prob": 0.0, "destructive_backtrack": true
}

static func update_template(key: String, value: Variant) -> void:
	if spawn_template.has(key): spawn_template[key] = value

# ==============================================================================
# 4. CAPABILITY API
# ==============================================================================

func add_capability(name: String, cap: AgentCapability) -> void:
	capabilities[name] = cap

func get_capability(name: String) -> AgentCapability:
	return capabilities.get(name, null)

func has_capability(name: String) -> bool:
	return capabilities.has(name)

# ==============================================================================
# 5. LIFECYCLE
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
		
	# [NEW] Install Default Capabilities
	# Every agent gets a Motor by default (for now)
	add_capability("Motor", CapMotor.new(self))
	
	_refresh_brain()

func reset_state() -> void:
	step_count = 0
	current_node_id = start_node_id 
	pos = _initial_pos              
	history.clear()
	last_bump_pos = Vector2.INF 
	
	if start_node_id != "":
		history.append({ "node": start_node_id, "step": 0 })
		
	is_finished = false
	
	# Reset Brain
	if brain: brain.enter(self, null)

	# [NEW] Reset Capabilities (if they have state)
	for cap in capabilities.values():
		cap.setup(null) 

# Undo Crash Fix
func validate_state(graph: Graph) -> void:
	if current_node_id != "" and not graph.nodes.has(current_node_id):
		print("Agent Warning: Standing on deleted node '%s'. Resetting to Start." % current_node_id)
		if graph.nodes.has(start_node_id):
			current_node_id = start_node_id
			pos = graph.get_node_pos(start_node_id)
		else:
			current_node_id = ""
		
		_current_path_cache.clear() 
		target_node_id = "" 
		return

	if target_node_id != "" and not graph.nodes.has(target_node_id):
		target_node_id = ""
		_current_path_cache.clear()
		
	if not history.is_empty():
		var valid_history: Array[Dictionary] = []
		for entry in history:
			var id = entry.get("node", "")
			if graph.nodes.has(id):
				valid_history.append(entry)
		
		if valid_history.size() != history.size():
			history = valid_history

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
		"path_cache": _current_path_cache,
		"target_node": target_node_id,
		"paint_type": my_paint_type,
		"active": active,
		"is_finished": is_finished,
		"steps": steps,
		"snap_to_grid": snap_to_grid,
		"algo_settings": algo_settings, # The generic bag
		
		# Specific Generation Flags
		"use_geometric_fc": use_geometric_fc,
		"use_zone_constraints": use_zone_constraints,
		"branching_prob": branching_probability,
		"destructive_backtrack": destructive_backtrack
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
	agent._current_path_cache.assign(data.get("path_cache", []))
	agent.target_node_id = data.get("target_node", "")
	agent.active = data.get("active", true)
	agent.is_finished = data.get("is_finished", false)
	agent.snap_to_grid = data.get("snap_to_grid", false)
	agent.algo_settings = data.get("algo_settings", {})
	
	# [NEW] Load Flags
	agent.use_geometric_fc = data.get("use_geometric_fc", false)
	agent.use_zone_constraints = data.get("use_zone_constraints", false)
	agent.branching_probability = float(data.get("branching_prob", 0.0))
	agent.destructive_backtrack = data.get("destructive_backtrack", true)
	
	# Handle legacy conversion (if 'use_forward_checking' existed)
	if data.has("use_forward_checking") and data.use_forward_checking:
		agent.use_geometric_fc = true

	agent._refresh_brain()
	return agent

# ==============================================================================
# 6. BEHAVIOR LOOP
# ==============================================================================

func step(graph: Graph, _context: Dictionary = {}) -> void:
	if not active: return
	if steps != -1 and step_count >= steps:
		is_finished = true
		return

	# [NEW] Tick Capabilities (Passive Updates)
	for cap in capabilities.values():
		cap.tick(1.0)

	if not brain: _refresh_brain()
	
	last_bump_pos = Vector2.INF 
	brain.step(self, graph)

func _refresh_brain() -> void:
	# Note: We will refactor 'StandardBehaviors' next, but this still works for now
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
# 7. ACTIONS API (Wrappers)
# ==============================================================================

func move_to_node(node_id: String, graph: Graph) -> void:
	# [NEW] Delegate to Motor Capability
	var motor = get_capability("Motor") as CapMotor
	if motor:
		motor.move_to_node(node_id, graph)
	else:
		# Fallback (Should not happen if initialized correctly)
		if not graph.nodes.has(node_id): return
		pos = graph.get_node_pos(node_id)
		current_node_id = node_id
		step_count += 1
		history.append({ "node": node_id, "step": step_count })

func paint_current_node(graph: Graph, type_idx: int = -1) -> void:
	# [TODO] Delegate to CapPainter in next step
	if current_node_id == "": return
	var t = type_idx if type_idx != -1 else my_paint_type
	graph.set_node_type(current_node_id, t)

func warp(new_pos: Vector2, new_node_id: String = "") -> void:
	# [NEW] Delegate to Motor
	var motor = get_capability("Motor") as CapMotor
	if motor:
		motor.warp(new_pos, new_node_id)
	else:
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
		
		# [NEW] Generation Settings
		{ "name": "use_geometric_fc", "label": "Geometric Check", "type": TYPE_BOOL, "default": false, "hint": "Expensive: Prevent strangling neighbors" },
		{ "name": "use_zone_constraints", "label": "Zone Check", "type": TYPE_BOOL, "default": false, "hint": "Respect Zone Traversability" },
		
		{ "name": "branching_prob", "label": "Branching", "type": TYPE_FLOAT, "default": 0.0, "min": 0.0, "max": 1.0, "step": 0.1, "hint": "0=Snake, 1=Random Growth" },
		{ "name": "destructive_backtrack", "label": "Destructive Undo", "type": TYPE_BOOL, "default": true, "hint": "Delete nodes on retreat?" },
		
		{ "name": "sep_core", "type": TYPE_NIL, "hint": "separator" },
		
		{ "name": "target_node", "label": "Target ID", "type": TYPE_STRING, "default": "" },
		{ "name": "active", "type": TYPE_BOOL, "default": true },
		{ "name": "paint_type", "type": TYPE_INT, "default": default_idx, "options": options_string },
		{ "name": "steps", "label": "Step Limit", "type": TYPE_INT, "default": 15, "min": -1, "hint": "-1 = Endless" },
		{ "name": "snap_to_grid", "type": TYPE_BOOL, "default": false }
	]

func get_agent_settings() -> Array[Dictionary]:
	var settings = AgentWalker.get_template_settings()
	
	# Fill defaults with instance values
	for s in settings:
		if s.name == "active": s.default = active
		elif s.name == "steps": s.default = steps
		elif s.name == "snap_to_grid": s.default = snap_to_grid
		elif s.name == "global_behavior": s.default = behavior_mode
		elif s.name == "movement_algo": s.default = movement_algo
		elif s.name == "target_node": s.default = target_node_id
		
		# [NEW]
		elif s.name == "use_geometric_fc": s.default = use_geometric_fc
		elif s.name == "use_zone_constraints": s.default = use_zone_constraints
		elif s.name == "branching_prob": s.default = branching_probability
		elif s.name == "destructive_backtrack": s.default = destructive_backtrack
		
		elif s.name == "paint_type":
			var ids = GraphSettings.current_names.keys()
			ids.sort()
			var idx = ids.find(my_paint_type)
			if idx != -1: s.default = idx
			
	# Stats
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

func apply_setting(key: String, value: Variant) -> void:
	var brain_dirty = false
	match key:
		"global_behavior": 
			behavior_mode = value
			brain_dirty = true
		"movement_algo": 
			movement_algo = value
			brain_dirty = true
		"target_node": target_node_id = value
		"active": active = value
		"snap_to_grid": snap_to_grid = value
		"steps": steps = value
		
		# [NEW]
		"use_geometric_fc": use_geometric_fc = value
		"use_zone_constraints": use_zone_constraints = value
		"branching_prob": branching_probability = value
		"destructive_backtrack": destructive_backtrack = value
		
		"paint_type":
			var ids = GraphSettings.current_names.keys()
			ids.sort()
			if value >= 0 and value < ids.size():
				my_paint_type = ids[value]
		"pos": warp(value)
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
	
	# [NEW]
	use_geometric_fc = t.get("use_geometric_fc", false)
	use_zone_constraints = t.get("use_zone_constraints", false)
	branching_probability = t.get("branching_prob", 0.0)
	destructive_backtrack = t.get("destructive_backtrack", true)
	
	_refresh_brain()
