class_name AgentWalker
extends RefCounted

# --- CONSTANTS ---
const OPTIONS_BEHAVIOR = "Hold Position,Wander,Grow (Expansion),Seek Target,Maze Generator"
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
var behavior_mode: int = 0  
var movement_algo: int = 0  
var _current_path_cache: Array[String] = []
var _path_target_id: String = ""
var target_node_id: String = ""

var auto_paint: bool = false 
var my_paint_type: String = "empty"
var active: bool = true             
var is_finished: bool = false       
var snap_to_grid: bool = false
var steps: int = 15

# --- STATIC TEMPLATES ---
static var spawn_template: Dictionary = {
	"global_behavior": 0, "movement_algo": 0, "target_node_id": "",
	"steps": 15, "paint_type": "empty", "snap_to_grid": false, 
	"use_geometric_fc": false, "use_zone_constraints": false,
	"branching_prob": 0.0, "destructive_backtrack": true,
	"auto_paint": false
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

func _init(p_uuid: String, p_display_id: int, start_pos: Vector2, start_node: String, p_type: String, p_steps: int) -> void:
	uuid = p_uuid
	display_id = p_display_id
	pos = start_pos
	_initial_pos = start_pos
	current_node_id = start_node
	start_node_id = start_node
	my_paint_type = p_type
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
	
	_refresh_brain()

func reset_state() -> void:
	step_count = 0
	current_node_id = start_node_id 
	pos = _initial_pos              
	history.clear()
	last_bump_pos = Vector2.INF 
	
	# Reset the RNG to its starting state so replay is identical
	rng.seed = my_seed
	
	if start_node_id != "":
		history.append({ "node": start_node_id, "step": 0 })
		
	is_finished = false
	
	# Reset Brain
	if brain: brain.enter(self, null)

	# Reset Capabilities (if they have state)
	for cap in capabilities.values():
		cap.setup(null) 

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
		"paint_type": my_paint_type,
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
	var d_paint = raw_paint if typeof(raw_paint) == TYPE_STRING else "empty"
	var d_steps = int(data.get("steps", 15))
	
	var agent = AgentWalker.new(d_uuid, d_id, d_pos, d_start, d_paint, d_steps)
	
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
	if not active: return
	if steps != -1 and step_count >= steps:
		is_finished = true
		return

	# 1. Tick Capabilities
	for cap in capabilities.values():
		cap.tick(1.0)

	# 2. Run Brain
	if not brain: _refresh_brain()
	brain.step(self, graph)
	
	# 3. Auto-Paint Logic (Replaces Decorator)
	# If the user enabled painting, we paint the current node every step.
	if auto_paint and current_node_id != "":
		paint_current_node(graph)

func _refresh_brain() -> void:
	match behavior_mode:
		0: set_behavior(BehaviorsStandard.Hold.new())
		1: set_behavior(BehaviorsStandard.Wander.new()) 
		2: set_behavior(BehaviorGrow.new()) # We will refactor this one later
		3: set_behavior(BehaviorsStandard.Seek.new(movement_algo))
		4: set_behavior(BehaviorMazeGen.new()) 
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

func paint_current_node(graph: Graph, type_idx: int = -1) -> void:
	# Delegate to Painter Capability
	var painter = get_capability("Painter") as CapPainter
	if painter:
		# If type_idx is -1 (default), use the agent's configured paint type
		var t = type_idx if type_idx != -1 else my_paint_type
		
		# We set the painter's brush, then paint.
		# In a cleaner future, the Painter would hold this state itself,
		# but for now we sync the Agent's setting to the Capability.
		painter.set_paint_type(t)
		painter.paint(graph, current_node_id)
	else:
		# Fallback
		if current_node_id == "": return
		var t = type_idx if type_idx != -1 else my_paint_type
		graph.set_node_type(current_node_id, t)

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
		{ "name": "global_behavior", "label": "Goal", "type": TYPE_INT, "default": 0, "options": OPTIONS_BEHAVIOR, 
		  "hint_text": "Determines the agent's primary brain logic and how it interacts with the world.\n- Hold Position: Remains stationary\n- Wander: Randomly traverses edges\n- Grow (Expansion): Builds new nodes into empty space\n- Seek Target: Navigates toward a specific node\n- Maze Generator: Uses DFS to carve structured paths" },
		  
		{ "name": "movement_algo", "label": "Pathfinding", "type": TYPE_INT, "default": 0, "options": OPTIONS_ALGO, 
		  "hint_text": "The mathematical algorithm used to navigate existing nodes (primarily used by Seek Target).\n- Random Walk: Pure chance\n- BFS: Shortest path by steps\n- DFS: Explores deeply before backtracking\n- A-Star: Fast, directional optimal pathfinding\n- Dijkstra: Safely evaluates edge weights" },
		
		# Action Settings
		{ "name": "sep_actions", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "auto_paint", "label": "Auto Paint", "type": TYPE_BOOL, "default": false, 
		  "hint_text": "If enabled, the agent will automatically apply the selected Paint Material to the node it currently occupies on every step." },
		{ "name": "paint_type", "label": "Paint Material", "type": TYPE_STRING, "default": "empty", "options": options_string, 
		  "hint_text": "The visual style and semantic node type the agent applies to the world when painting or building." },

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
	
	# Fill defaults
	for s in settings:
		var s_name = s.get("name", "")
		
		if s_name == "agent_seed": s["default"] = str(my_seed) # Show current seed
		elif s_name == "active": s["default"] = active
		elif s_name == "steps": s["default"] = steps
		elif s_name == "snap_to_grid": s["default"] = snap_to_grid
		elif s_name == "global_behavior": s["default"] = behavior_mode
		elif s_name == "movement_algo": s["default"] = movement_algo
		elif s_name == "target_node": s["default"] = target_node_id
		
		elif s_name == "auto_paint": s["default"] = auto_paint
		elif s_name == "paint_type":
			# [RESTORED] Map String back to UI integer index
			var keys = SemanticRegistry.get_category_ui_schema(SemanticRegistry.TARGET_NODE)["keys"]
			var idx = keys.find(my_paint_type)
			s["default"] = idx if idx != -1 else 0
			 
		elif s_name == "use_geometric_fc": s["default"] = use_geometric_fc
		elif s_name == "use_zone_constraints": s["default"] = use_zone_constraints
		elif s_name == "branching_prob": s["default"] = branching_probability
		elif s_name == "destructive_backtrack": s["default"] = destructive_backtrack
			
	# Stats & Actions
	settings.append({ "name": "stat_steps", "label": "Steps Taken", "type": TYPE_STRING, "default": "%d / %d" % [step_count, steps], "hint": "read_only" })
	settings.append_array([
		{ "name": "pos", "type": TYPE_VECTOR2, "default": pos, "hint_text": "The absolute spatial (X, Y) coordinates of the agent in the world, operating independently of the graph's logical topology." },
		{ "name": "action_delete", "type": TYPE_BOOL, "hint": "action", "label": "Delete Agent" }
	])
	return settings

func apply_setting(key: String, value: Variant) -> void:
	var brain_dirty = false
	match key:
		"agent_seed":
			if str(value) != "":
				set_seed(SeedUtils.hash_seed(str(value)))
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
		
		"auto_paint": auto_paint = value
		"paint_type":
			# [RESTORED] Map UI integer back to String key
			var keys = SemanticRegistry.get_category_ui_schema(SemanticRegistry.TARGET_NODE)["keys"]
			if value >= 0 and value < keys.size():
				my_paint_type = keys[value]
				
		"use_geometric_fc": use_geometric_fc = value
		"use_zone_constraints": use_zone_constraints = value
		"branching_prob": branching_probability = value
		"destructive_backtrack": destructive_backtrack = value
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
	my_paint_type = t.get("paint_type", "empty")
	snap_to_grid = t.get("snap_to_grid", false)
	
	auto_paint = t.get("auto_paint", false)
	
	use_geometric_fc = t.get("use_geometric_fc", false)
	use_zone_constraints = t.get("use_zone_constraints", false)
	branching_probability = t.get("branching_prob", 0.0)
	destructive_backtrack = t.get("destructive_backtrack", true)
	
	_refresh_brain()
