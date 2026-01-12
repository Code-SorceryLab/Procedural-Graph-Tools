class_name AgentWalker
extends RefCounted

# --- CONSTANTS ---
const OPTIONS_BEHAVIOR = "Hold Position,Paint (Random),Grow (Expansion),Seek Target"
const OPTIONS_ALGO = "Random Walk,Breadth-First,Depth-First,A-Star"

# ==============================================================================
# 1. IDENTITY & STATE
# ==============================================================================

# [IDENTITY]
var uuid: String           # Unique String (Data Integrity / Merging)
var display_id: int        # Simple Integer (UI Readability: "Agent #5")

# [COMPATIBILITY]
# Maps existing 'agent.id' calls to the display_id (Ticket Number).
var id: int:
	get: return display_id
	set(value): display_id = value

# [PHYSICAL STATE]
var pos: Vector2
var current_node_id: String
var start_node_id: String 
var step_count: int = 0 
var history: Array[Dictionary] = [] 

# SEMANTIC DATA
# Stores arbitrary game data (e.g., {"health": 100, "team": "red"})
var custom_data: Dictionary = {}

# [MENTAL STATE]
var brain: AgentBehavior

# ==============================================================================
# 2. CONFIGURATION & SETTINGS
# ==============================================================================

# [BEHAVIOR]
var behavior_mode: int = 0  # 0=Hold, 1=Paint, 2=Grow, 3=Seek
var movement_algo: int = 0  # 0=Random, 1=BFS, 2=DFS, 3=A*
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
	"steps": 15, "paint_type": 2, "snap_to_grid": false, "branch_randomly": false
}

static func update_template(key: String, value: Variant) -> void:
	if spawn_template.has(key): spawn_template[key] = value

# ==============================================================================
# 3. LIFECYCLE
# ==============================================================================

func _init(p_uuid: String, p_display_id: int, start_pos: Vector2, start_node: String, p_type: int, p_steps: int) -> void:
	uuid = p_uuid
	display_id = p_display_id
	
	pos = start_pos
	current_node_id = start_node
	start_node_id = start_node
	my_paint_type = p_type
	steps = p_steps
	
	if start_node != "":
		history.append({ "node": start_node, "step": 0 })
		
	_refresh_brain()

func reset_state() -> void:
	step_count = 0
	current_node_id = ""
	pos = Vector2.ZERO
	history.clear()
	
	# Reset logic state, but keep 'active' configuration
	is_finished = false
	
	# Restart the Brain
	if brain: brain.enter(self, null)

# ==============================================================================
# 4. SERIALIZATION (Saving/Loading)
# ==============================================================================

# Packs the agent into a JSON-friendly Dictionary
func serialize() -> Dictionary:
	return {
		# Identity
		"uuid": uuid,
		"display_id": display_id,
		
		# State
		"pos_x": pos.x,
		"pos_y": pos.y,
		"current_node": current_node_id,
		"start_node": start_node_id,
		"step_count": step_count,
		"history": history, # Array of Dictionaries is JSON safe
		"custom_data": custom_data,
		
		# Configuration
		"behavior_mode": behavior_mode,
		"movement_algo": movement_algo,
		"target_node": target_node_id,
		"paint_type": my_paint_type,
		"active": active,
		"is_finished": is_finished,
		"steps": steps,
		"snap_to_grid": snap_to_grid,
		"branch_randomly": branch_randomly
	}

# Factory Method: Reconstructs an Agent from a Dictionary
static func deserialize(data: Dictionary) -> AgentWalker:
	# 1. Extract Core Constructor Args
	# We use .get() with defaults to prevent crashes on old save files
	var d_uuid = data.get("uuid", "")
	# If UUID is missing (very old save), we can't generate one here easily without Utils.
	# We'll leave it empty and let the Graph fix it, or the Loader.
	
	var d_id = int(data.get("display_id", 1))
	var d_pos = Vector2(data.get("pos_x", 0), data.get("pos_y", 0))
	var d_start = data.get("start_node", "")
	var d_paint = int(data.get("paint_type", 2))
	var d_steps = int(data.get("steps", 15))
	
	# 2. Instantiate
	var agent = AgentWalker.new(d_uuid, d_id, d_pos, d_start, d_paint, d_steps)
	
	# 3. Restore State
	agent.current_node_id = data.get("current_node", "")
	agent.step_count = int(data.get("step_count", 0))
	agent.history = data.get("history", []) # Warning: Array needs explicit cast if strict typed
	agent.custom_data = data.get("custom_data", {})
	
	# 4. Restore Config
	agent.behavior_mode = int(data.get("behavior_mode", 0))
	agent.movement_algo = int(data.get("movement_algo", 0))
	agent.target_node_id = data.get("target_node", "")
	agent.active = data.get("active", true)
	agent.is_finished = data.get("is_finished", false)
	agent.snap_to_grid = data.get("snap_to_grid", false)
	agent.branch_randomly = data.get("branch_randomly", false)
	
	# 5. Re-ignite the Brain
	agent._refresh_brain()
	
	return agent

# ==============================================================================
# 5. BEHAVIOR LOGIC
# ==============================================================================

func step(graph: Graph, _context: Dictionary = {}) -> void:
	if not active: return
	
	# Lazy Initialization safety check
	if not brain: _refresh_brain()
	
	brain.step(self, graph)

func _refresh_brain() -> void:
	match behavior_mode:
		0: set_behavior(BehaviorHold.new())
		1: 
			var wander = BehaviorWander.new()
			set_behavior(BehaviorDecoratorPaint.new(wander))
		2: set_behavior(BehaviorGrow.new()) 
		3: set_behavior(BehaviorSeek.new(movement_algo))
		_: set_behavior(BehaviorHold.new())

func set_behavior(new_brain: AgentBehavior, graph: Graph = null) -> void:
	if brain: brain.exit(self, graph)
	brain = new_brain
	if brain: brain.enter(self, graph)

# ==============================================================================
# 6. ACTIONS API (Used by Brains)
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
	# Uses display_id (Ticket) for readable node names: "walk:5:1"
	var new_id = "walk:%d:%d" % [display_id, temp_count]
	
	while graph.nodes.has(new_id):
		temp_count += 1
		new_id = "walk:%d:%d" % [display_id, temp_count]
	return new_id

# ==============================================================================
# 7. UI / INSPECTOR SUPPORT
# ==============================================================================

# Returns the definition list for the SettingsUIBuilder
static func get_template_settings() -> Array[Dictionary]:
	# 1. Fetch Types for Paint Dropdown
	var ids = GraphSettings.current_names.keys()
	ids.sort()
	var names: PackedStringArray = []
	var default_idx = 0
	
	for i in range(ids.size()):
		var type_id = ids[i]
		names.append(GraphSettings.get_type_name(type_id))
		if type_id == 2: default_idx = i 
			
	var options_string = ",".join(names)
	
	# 2. Return Schema
	return [
		{ "name": "global_behavior", "label": "Goal", "type": TYPE_INT, "default": 0, "options": OPTIONS_BEHAVIOR },
		{ "name": "movement_algo", "label": "Pathfinding", "type": TYPE_INT, "default": 0, "options": OPTIONS_ALGO },
		{ "name": "target_node", "label": "Target ID", "type": TYPE_STRING, "default": "" },
		{ "name": "active", "type": TYPE_BOOL, "default": true },
		{ "name": "paint_type", "type": TYPE_INT, "default": default_idx, "options": options_string },
		{ "name": "steps", "type": TYPE_INT, "default": 15 },
		{ "name": "snap_to_grid", "type": TYPE_BOOL, "default": false },
		{ "name": "branch_randomly", "type": TYPE_BOOL, "default": false }
	]

# Returns instance-specific settings (with current values)
func get_agent_settings() -> Array[Dictionary]:
	var settings = AgentWalker.get_template_settings()
	
	# Sync Defaults with Current State
	for s in settings:
		if s.name == "active": s.default = active
		elif s.name == "steps": s.default = steps
		elif s.name == "snap_to_grid": s.default = snap_to_grid
		elif s.name == "branch_randomly": s.default = branch_randomly
		elif s.name == "global_behavior": s.default = behavior_mode
		elif s.name == "movement_algo": s.default = movement_algo
		elif s.name == "target_node": s.default = target_node_id
		elif s.name == "paint_type":
			var ids = GraphSettings.current_names.keys()
			ids.sort()
			var idx = ids.find(my_paint_type)
			if idx != -1: s.default = idx
			
	# Append Instance Actions
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
		"target_node": target_node_id = value
		"active": active = value
		"snap_to_grid": snap_to_grid = value
		"steps": steps = value
		"branch_randomly": branch_randomly = value
		"paint_type":
			var ids = GraphSettings.current_names.keys()
			ids.sort()
			if value >= 0 and value < ids.size():
				my_paint_type = ids[value]
		"pos": warp(value)
	
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
	_refresh_brain()
