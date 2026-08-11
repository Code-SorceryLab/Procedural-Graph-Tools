class_name AgentWalker
extends RefCounted

# --- CONSTANTS ---
const OPTIONS_BEHAVIOR = "Hold Position,Wander,Grow (Expansion),Seek Target,Maze Generator,Solve Questline,Player Controlled"
const OPTIONS_ALGO = "Random Walk,Breadth-First,Depth-First,A-Star,Dijkstra"

# Strictly typed behavior modes
enum BehaviorMode {
	HOLD = 0,
	WANDER = 1,
	GROW = 2,
	SEEK = 3,
	MAZE = 4,
	SOLVER = 5,
	MANUAL = 6
}
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

#Local RNG
var my_seed: int = 0
var rng: RandomNumberGenerator

# CONSTRAINT & GENERATION STATE
var use_geometric_fc: bool = false
var use_zone_constraints: bool = false
var branching_probability: float = 0.0
var destructive_backtrack: bool = true
var last_bump_pos: Vector2 = Vector2.INF

# ==============================================================================
# 3. CONFIGURATION
# ==============================================================================
var behavior_mode: int = BehaviorMode.GROW
var movement_algo: int = 0  
var _current_path_cache: Array[String] = []
var _path_target_id: String = ""
var target_node_id: String = ""

var auto_paint: bool = false 
var paint_target: String = "NODE"
var paint_field: String = "type"
var paint_value: Variant = "empty"
var active: bool = true             
var is_finished: bool = false       
var snap_to_grid: bool = false
var steps: int = 15

# --- STATIC TEMPLATES ---
static var spawn_template: Dictionary = {
	"global_behavior": BehaviorMode.GROW, # [FIXED]
	"movement_algo": 0, "target_node_id": "",
	"steps": 15, "snap_to_grid": false, 
	"use_geometric_fc": false, "use_zone_constraints": false,
	"branching_prob": 0.0, "destructive_backtrack": true,
	"auto_paint": false, "paint_target": "NODE", "paint_field": "type", "paint_value": "empty"
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

func _init(p_uuid: String, p_display_id: int, start_pos: Vector2, start_node: String, p_steps: int) -> void:
	uuid = p_uuid
	display_id = p_display_id
	pos = start_pos
	_initial_pos = start_pos
	current_node_id = start_node
	start_node_id = start_node
	steps = p_steps
	
	# Initialize default isolated RNG
	rng = RandomNumberGenerator.new()
	my_seed = rng.seed
	
	if start_node != "":
		history.append({ "node": start_node, "step": 0 })
		
	# Install Default Capabilities
	# Every agent gets movement, data painting, and node building logic
	add_capability("Motor", CapMotor.new(self))
	add_capability("Painter", CapPainter.new(self))
	add_capability("Builder", CapBuilder.new(self))
	add_capability("Inventory", CapInventory.new(self))
	
	_refresh_brain()

func reset_state(graph: Graph = null) -> void:
	step_count = 0
	current_node_id = start_node_id 
	pos = _initial_pos              
	history.clear()
	last_bump_pos = Vector2.INF 
	
	rng.seed = my_seed
	
	if start_node_id != "":
		history.append({ "node": start_node_id, "step": 0 })
		
	is_finished = false
	
	if brain: brain.enter(self, graph)

	# Pass the graph into the capabilities so they can restore the world!
	for cap in capabilities.values():
		cap.setup(graph)

# Function to set seed deterministically 
func set_seed(new_seed: int) -> void:
	my_seed = new_seed
	rng.seed = my_seed

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
		"paint_target": paint_target,
		"paint_field": paint_field,
		"paint_value": paint_value,
		"active": active,
		"is_finished": is_finished,
		"steps": steps,
		"snap_to_grid": snap_to_grid,
		"algo_settings": algo_settings,
		"auto_paint": auto_paint,
		# Seed state
		"my_seed": my_seed,
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
	var raw_paint = data.get("paint_type", "empty")
	var d_steps = int(data.get("steps", 15))
	var agent = AgentWalker.new(d_uuid, d_id, d_pos, d_start, d_steps)
	
	agent.paint_target = data.get("paint_target", "NODE")
	agent.paint_field = data.get("paint_field", "type")
	agent.paint_value = data.get("paint_value", "empty")
	

	
	# Restore the exact deterministic seed state
	if data.has("my_seed"):
		agent.set_seed(int(data.get("my_seed")))
	
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
	
	# Load Flags
	agent.use_geometric_fc = data.get("use_geometric_fc", false)
	agent.use_zone_constraints = data.get("use_zone_constraints", false)
	agent.branching_probability = float(data.get("branching_prob", 0.0))
	agent.destructive_backtrack = data.get("destructive_backtrack", true)
	
	agent.auto_paint = data.get("auto_paint", false)
	
	# Handle legacy conversion
	if data.has("use_forward_checking") and data.use_forward_checking:
		agent.use_geometric_fc = true

	agent._refresh_brain()
	return agent

# ==============================================================================
# 6. BEHAVIOR LOOP
# ==============================================================================

func step(graph: Graph, _context: Dictionary = {}) -> void:
	# --- DEBUG INJECTION ---
	print("[AGENT_%d] Step Tick | Active: %s | Finished: %s | Node: %s" % [display_id, active, is_finished, current_node_id])
	
	if not active: return
	if steps != -1 and step_count >= steps:
		print("[AGENT_%d] Died of old age (Steps: %d/%d)" % [display_id, step_count, steps])
		is_finished = true
		return

	if current_node_id == "" or not graph.nodes.has(current_node_id):
		print("[AGENT_%d] Error: Standing in the void! Node ID: '%s'" % [display_id, current_node_id])
		return

	# 1. Tick Capabilities
	for cap in capabilities.values():
		cap.tick(1.0)

	# 2. Run Brain
	if not brain: _refresh_brain()
	
	print("[AGENT_%d] Brain Executing: Mode %d" % [display_id, behavior_mode])
	brain.step(self, graph)
	
	# 3. Auto-Paint Logic
	if auto_paint and current_node_id != "":
		perform_paint(graph)

func _refresh_brain() -> void:
	match behavior_mode:
		BehaviorMode.HOLD: set_behavior(BehaviorsStandard.Hold.new())
		BehaviorMode.WANDER: set_behavior(BehaviorsStandard.Wander.new()) 
		BehaviorMode.GROW: set_behavior(BehaviorGrow.new()) 
		BehaviorMode.SEEK: set_behavior(BehaviorsStandard.Seek.new(movement_algo))
		BehaviorMode.MAZE: set_behavior(BehaviorMazeGen.new()) 
		BehaviorMode.SOLVER: set_behavior(BehaviorSolver.new())
		BehaviorMode.MANUAL: set_behavior(BehaviorManual.new())
		_: set_behavior(BehaviorsStandard.Hold.new())

func set_behavior(new_brain: AgentBehavior, graph: Graph = null) -> void:
	if brain: brain.exit(self, graph)
	brain = new_brain
	if brain: brain.enter(self, graph)

# ==============================================================================
# 7. ACTIONS API (Wrappers)
# ==============================================================================

func move_to_node(node_id: String, graph: Graph) -> void:
	# Delegate to Motor Capability
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

func perform_paint(graph: Graph) -> void:
	var painter = get_capability("Painter") as CapPainter
	if painter:
		painter.configure(paint_target, paint_field, paint_value)
		
		# Retrieve the node we were just standing on to paint the traversed edge
		var prev_node = ""
		if history.size() >= 2:
			prev_node = history[history.size() - 2].get("node", "")
			
		painter.paint(graph, current_node_id, prev_node)

func warp(new_pos: Vector2, new_node_id: String = "") -> void:
	# Delegate to Motor
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
# 8. UI / INSPECTOR SUPPORT
# ==============================================================================

static func get_template_settings() -> Array[Dictionary]:
	# Pull dynamically from Registry
	var schema = SemanticRegistry.get_category_ui_schema(SemanticRegistry.TARGET_NODE)
	var options_string = schema["hint_string"]
	
	return [
		{ "name": "agent_seed", "label": "Agent Seed", "type": TYPE_STRING, "default": "", 
		  "hint_text": "Force a specific seed for this individual agent. Overrides the strategy seed." },
		{ "name": "global_behavior", "label": "Goal", "type": TYPE_INT, "default": BehaviorMode.GROW, "options": OPTIONS_BEHAVIOR, 
		  "hint_text": "Determines the agent's primary brain logic and how it interacts with the world.\n- Hold Position: Remains stationary\n- Wander: Randomly traverses edges\n- Grow (Expansion): Builds new nodes into empty space\n- Seek Target: Navigates toward a specific node\n- Maze Generator: Uses DFS to carve structured paths" },
		  
		{ "name": "movement_algo", "label": "Pathfinding", "type": TYPE_INT, "default": 0, "options": OPTIONS_ALGO, 
		  "hint_text": "The mathematical algorithm used to navigate existing nodes (primarily used by Seek Target).\n- Random Walk: Pure chance\n- BFS: Shortest path by steps\n- DFS: Explores deeply before backtracking\n- A-Star: Fast, directional optimal pathfinding\n- Dijkstra: Safely evaluates edge weights" },
		

		# Generation Settings
		{ "name": "sep_gen", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "use_geometric_fc", "label": "Geometric Check", "type": TYPE_BOOL, "default": false, 
		  "hint_text": "A smart constraint that prevents the agent from stepping or building into a space that would instantly 'strangle' or wall off its neighboring open spaces." },
		{ "name": "use_zone_constraints", "label": "Zone Check", "type": TYPE_BOOL, "default": false, 
		  "hint_text": "Forces the agent to strictly obey the traversal and building permissions defined by underlying Graph Zones." },
		{ "name": "branching_prob", "label": "Branching", "type": TYPE_FLOAT, "default": 0.0, "min": 0.0, "max": 1.0, "step": 0.1, 
		  "hint_text": "Controls how often a generating agent abandons its current path head to branch off a previous node. 0.0 yields snake-like tunnels; 1.0 yields highly fractured clusters." },
		{ "name": "destructive_backtrack", "label": "Destructive Undo", "type": TYPE_BOOL, "default": true, 
		  "hint_text": "When the agent retreats from a dead end, it will delete the nodes it just created, cleaning up failed branches visually and logically." },
		
		# Target & Core
		{ "name": "sep_core", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "target_node", "label": "Target ID", "type": TYPE_STRING, "default": "", 
		  "hint_text": "The exact unique identifier of the node the agent is trying to reach." },
		{ "name": "active", "type": TYPE_BOOL, "default": true, 
		  "hint_text": "Toggles whether the agent processes its step logic during the simulation. Uncheck to pause this specific agent." },
		{ "name": "steps", "label": "Step Limit", "type": TYPE_INT, "default": 15, "min": -1, 
		  "hint_text": "The maximum number of moves the agent is allowed to make before dying. Set to -1 for an infinite lifespan." },
		{ "name": "snap_to_grid", "type": TYPE_BOOL, "default": false, 
		  "hint_text": "Forces the agent to lock onto strict grid coordinates." }
	]

func get_agent_settings() -> Array[Dictionary]:
	var settings = AgentWalker.get_template_settings()
	
	# Fill defaults for standard static settings
	for s in settings:
		var s_name = s.get("name", "")
		if s_name == "agent_seed": s["default"] = str(my_seed) 
		elif s_name == "active": s["default"] = active
		elif s_name == "steps": s["default"] = steps
		elif s_name == "snap_to_grid": s["default"] = snap_to_grid
		elif s_name == "global_behavior": s["default"] = behavior_mode
		elif s_name == "movement_algo": s["default"] = movement_algo
		elif s_name == "target_node": s["default"] = target_node_id
		elif s_name == "use_geometric_fc": s["default"] = use_geometric_fc
		elif s_name == "use_zone_constraints": s["default"] = use_zone_constraints
		elif s_name == "branching_prob": s["default"] = branching_probability
		elif s_name == "destructive_backtrack": s["default"] = destructive_backtrack

	# --- DYNAMIC PAINT CONFIGURATION UI ---
	# [FIXED] Grouped all paint properties perfectly together with their own separator
	settings.append({ "name": "sep_paint", "type": TYPE_NIL, "hint": "separator" })
	
	settings.append({ 
		"name": "auto_paint", "label": "Auto Paint", "type": TYPE_BOOL, "default": auto_paint, 
		"hint_text": "If enabled, the agent will automatically apply its Paint Configuration to the world on every step." 
	})

	var targets = ["NODE", "EDGE"]
	var t_idx = targets.find(paint_target)
	if t_idx == -1: t_idx = 0
	
	settings.append({
		"name": "paint_target", "label": "Paint Target", "type": TYPE_INT, 
		"default": t_idx, "hint": "enum", "hint_string": "Node,Edge"
	})
	
	var avail_fields = ["type"]
	var field_labels = ["Category (Type)"]
	if paint_target == "EDGE":
		avail_fields.append("weight")
		field_labels.append("Weight (Cost)")
		
	var props = SemanticRegistry.properties.get(paint_target, {})
	for k in props:
		avail_fields.append(k)
		field_labels.append(props[k].get("label", k.capitalize()))
		
	var f_idx = avail_fields.find(paint_field)
	if f_idx == -1: f_idx = 0
	var current_field = avail_fields[f_idx]
	
	settings.append({
		"name": "paint_field", "label": "Paint Property", "type": TYPE_INT, 
		"default": f_idx, "hint": "enum", "hint_string": ",".join(field_labels)
	})
	
	if current_field == "type":
		var cat_schema = SemanticRegistry.get_category_ui_schema(paint_target)
		var keys = cat_schema["keys"]
		var v_idx = keys.find(paint_value)
		if v_idx == -1: v_idx = 0
		settings.append({
			"name": "paint_value", "label": "Paint Value", "type": TYPE_INT,
			"default": v_idx, "hint": "enum", "hint_string": cat_schema["hint_string"]
		})
	elif current_field == "weight":
		var safe_weight = float(paint_value) if paint_value != null and str(paint_value).is_valid_float() else 1.0
		settings.append({ "name": "paint_value", "label": "Paint Value", "type": TYPE_FLOAT, "default": safe_weight })
	else:
		var p_def = props[current_field]
		var safe_val = paint_value if paint_value != null else p_def["default"]
		settings.append({ "name": "paint_value", "label": "Paint Value", "type": p_def["type"], "default": safe_val })

	# Stats & Actions (Keep your existing bottom block)
	settings.append({ "name": "stat_steps", "label": "Steps Taken", "type": TYPE_STRING, "default": "%d / %d" % [step_count, steps], "hint": "read_only" })
	settings.append_array([
		{ "name": "pos", "type": TYPE_VECTOR2, "default": pos, "hint_text": "Absolute spatial coordinates." },
		{ "name": "action_delete", "type": TYPE_BOOL, "hint": "action", "label": "Delete Agent" }
	])
	return settings

func apply_setting(key: String, value: Variant) -> void:
	var brain_dirty = false
	match key:
		"agent_seed":
			if str(value) != "": set_seed(SeedUtils.hash_seed(str(value)))
			
		"global_behavior": 
			behavior_mode = int(value)
			brain_dirty = true
			is_finished = false
		"movement_algo": 
			movement_algo = int(value)
			brain_dirty = true
		"target_node": 
			target_node_id = str(value)
			is_finished = false
		"active": active = bool(value)
		"snap_to_grid": snap_to_grid = bool(value)
		"steps": 
			steps = int(value)
			if steps == -1 or step_count < steps: is_finished = false
			
		"auto_paint": auto_paint = bool(value)
		
		# --- [FIXED] DUMB ASSIGNMENTS ---
		# InspectorAgent already handles the translation and cascade logic!
		"paint_target": paint_target = str(value)
		"paint_field": paint_field = str(value)
		"paint_value": paint_value = value
		# --------------------------------
		
		"use_geometric_fc": use_geometric_fc = bool(value)
		"use_zone_constraints": use_zone_constraints = bool(value)
		"branching_prob": branching_probability = float(value)
		"destructive_backtrack": destructive_backtrack = bool(value)
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
	snap_to_grid = t.get("snap_to_grid", false)
	
	auto_paint = t.get("auto_paint", false)
	paint_target = t.get("paint_target", "NODE")
	paint_field = t.get("paint_field", "type")
	paint_value = t.get("paint_value", "empty")
	
	use_geometric_fc = t.get("use_geometric_fc", false)
	use_zone_constraints = t.get("use_zone_constraints", false)
	branching_probability = t.get("branching_prob", 0.0)
	destructive_backtrack = t.get("destructive_backtrack", true)
	
	_refresh_brain()
