class_name AgentWalker
extends RefCounted

# --- CONSTANTS ---
const OPTIONS_BEHAVIOR = "Hold Position,Paint (Random),Grow (Expansion),Seek Target"
const OPTIONS_ALGO = "Random Walk,Breadth-First,Depth-First,A-Star"

# --- STATE (The Body) ---
var id: int
var pos: Vector2
var current_node_id: String
var start_node_id: String 
var step_count: int = 0 
var history: Array[Dictionary] = [] 

# [NEW] THE BRAIN
var brain: AgentBehavior

# --- CONFIGURATION (Data for the Brain) ---
# We keep these variables so the Inspector/UI has something to read/write.
# When these change, we re-spawn the Brain.
var behavior_mode: int = 0  # 0=Hold, 1=Paint, 2=Grow, 3=Seek
var movement_algo: int = 0  # 0=Random, 1=BFS, 2=DFS, 3=A*
var target_node_id: String = ""

# --- SETTINGS ---
var my_paint_type: int = 2 
var active: bool = true          # CONFIG: User wants this enabled
var is_finished: bool = false    # STATE: Agent has completed its run
var snap_to_grid: bool = false
var steps: int = 15
var branch_randomly: bool = false

# --- STATIC TEMPLATES (Unchanged) ---
static var spawn_template: Dictionary = {
	"global_behavior": 0, "movement_algo": 0, "target_node_id": "",
	"steps": 15, "paint_type": 2, "snap_to_grid": false, "branch_randomly": false
}

static func update_template(key: String, value: Variant) -> void:
	if spawn_template.has(key): spawn_template[key] = value

# --- INITIALIZATION ---
func _init(uid: int, start_pos: Vector2, start_id: String, initial_type: int, default_steps: int) -> void:
	id = uid
	pos = start_pos
	current_node_id = start_id
	start_node_id = start_id
	my_paint_type = initial_type
	steps = default_steps
	
	if start_id != "":
		history.append({ "node": start_id, "step": 0 })
		
	# [NEW] Initialize the Mind
	_refresh_brain()

func reset_state() -> void:
	step_count = 0
	current_node_id = ""
	pos = Vector2.ZERO
	history.clear()
	
	# [FIX] Reset runtime state, but DO NOT touch 'active'
	is_finished = false
	
	# Reset Brain
	if brain: brain.enter(self, null)

# --- BRAIN MANAGEMENT ---

# Called whenever configuration changes
func _refresh_brain() -> void:
	match behavior_mode:
		0: # Hold
			set_behavior(BehaviorHold.new())
			
		1: # Paint (Now composed of Wander + Paint Decorator)
			var wander_brain = BehaviorWander.new()
			var painting_brain = BehaviorDecoratorPaint.new(wander_brain)
			set_behavior(painting_brain)
			
		2: # Grow
			set_behavior(BehaviorGrow.new()) 
			
		3: # Seek
			# Note: You COULD wrap this in PaintDecorator too if you wanted "Seek & Paint"!
			set_behavior(BehaviorSeek.new(movement_algo))
			
		_: # Fallback
			set_behavior(BehaviorHold.new())

func set_behavior(new_brain: AgentBehavior, graph: Graph = null) -> void:
	if brain:
		brain.exit(self, graph)
	brain = new_brain
	if brain:
		brain.enter(self, graph)

# --- MAIN LOOP ---

# [UPDATED] The generic step function
func step(graph: Graph, _context: Dictionary = {}) -> void:
	if not active: return
	
	# If we have no brain (or haven't initialized), try to make one
	if not brain: _refresh_brain()
	
	# Delegate thinking to the component
	brain.step(self, graph)

# --- PUBLIC API (Actions the Brain can take) ---

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

# --- HELPERS (Used by Behaviors like Grow) ---

func generate_unique_id(graph) -> String:
	var temp_count = step_count + 1 
	var new_id = "walk:%d:%d" % [id, temp_count]
	while graph.nodes.has(new_id):
		temp_count += 1
		new_id = "walk:%d:%d" % [id, temp_count]
	return new_id

# --- INSPECTOR / UI SUPPORT (Unchanged logic, just data mapping) ---

static func get_template_settings() -> Array[Dictionary]:
	# (Keep your existing static implementation exactly as is)
	# ... [Your existing code here] ...
	return AgentWalker._get_template_settings_impl() # Moved implementation to helper to keep clean

# (Internal helper to keep the paste short - use your existing get_template_settings body)
static func _get_template_settings_impl() -> Array[Dictionary]:
	var ids = GraphSettings.current_names.keys()
	ids.sort()
	var names: PackedStringArray = []
	var default_idx = 0
	
	for i in range(ids.size()):
		var type_id = ids[i] # [FIX] Renamed from 'id' to 'type_id'
		
		names.append(GraphSettings.get_type_name(type_id))
		
		# We are looking for the default paint type (usually ID 2)
		if type_id == 2: 
			default_idx = i 
			
	var options_string = ",".join(names)
	
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
			
	settings.append_array([
		{ "name": "pos", "type": TYPE_VECTOR2, "default": pos },
		{ "name": "action_delete", "type": TYPE_BOOL, "hint": "action", "label": "Delete Agent" }
	])
	return settings

func apply_template_defaults() -> void:
	var t = AgentWalker.spawn_template
	behavior_mode = t.get("global_behavior", 0)
	movement_algo = t.get("movement_algo", 0)
	target_node_id = t.get("target_node_id", "")
	steps = t.get("steps", 15)
	my_paint_type = t.get("paint_type", 2)
	snap_to_grid = t.get("snap_to_grid", false)
	branch_randomly = t.get("branch_randomly", false)
	
	_refresh_brain() # Apply changes to the Brain!

func apply_setting(key: String, value: Variant) -> void:
	var brain_dirty = false
	match key:
		"global_behavior": 
			behavior_mode = value
			brain_dirty = true
		"movement_algo": 
			movement_algo = value
			brain_dirty = true
		"target_node": 
			target_node_id = value
			# Note: Seek behavior reads this directly from agent, no restart needed unless switching logic
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
