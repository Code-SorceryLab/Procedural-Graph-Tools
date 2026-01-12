extends Node
class_name StrategyController

# --- STATIC INSTANCE ---
static var instance: StrategyController

func _enter_tree() -> void:
	if instance == null: instance = self

func _exit_tree() -> void:
	if instance == self: instance = null

# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor

@export_group("UI Generation Tab")
@export var algo_select: OptionButton
@export var settings_container: Control 

@export var debug_depth_chk: CheckBox
@export var grow_btn: Button      # [MAPPED]: "Extend Branch"
@export var generate_btn: Button  # [MAPPED]: "Create New Graph"
@export var clear_btn: Button
@export var spawn_btn: Button
@export var clear_agents_btn: Button # "Clear Agents Only"

# --- STATE ---
var strategies: Array[GraphStrategy] = []
var current_strategy: GraphStrategy
var _active_inputs: Dictionary = {} 
var _current_schema: Array[Dictionary] = [] 

# UI State
var _show_advanced: bool = false
var _advanced_toggle_btn: CheckButton

# --- INITIALIZATION ---
func _ready() -> void:
	strategies.append(StrategyGrid.new())
	strategies.append(StrategyWalker.new()) 
	strategies.append(StrategyMST.new())
	strategies.append(StrategyDLA.new())
	strategies.append(StrategyCA.new())
	strategies.append(StrategyPolar.new()) 
	strategies.append(StrategyAnalyze.new())
	
	algo_select.clear()
	for i in range(strategies.size()):
		algo_select.add_item(strategies[i].strategy_name, i)
	
	algo_select.item_selected.connect(_on_algo_selected)
	
	# Connect Button Actions
	grow_btn.pressed.connect(_on_extend_pressed)       # Button 1
	generate_btn.pressed.connect(_on_create_new_pressed) # Button 2
	clear_btn.pressed.connect(_on_clear_pressed)
	spawn_btn.pressed.connect(_on_spawn_pressed)
	if clear_agents_btn:
		clear_agents_btn.pressed.connect(_on_clear_agents_pressed)
	
	debug_depth_chk.toggled.connect(_on_debug_depth_toggled)

	
	
	if strategies.size() > 0:
		_on_algo_selected(0)

# --- PUBLIC API ---

func switch_to_strategy_type(target_type_script) -> bool:
	if is_instance_of(current_strategy, target_type_script):
		return true
	for i in range(strategies.size()):
		if is_instance_of(strategies[i], target_type_script):
			algo_select.selected = i
			_on_algo_selected(i)
			return true
	return false

# --- DYNAMIC UI LOGIC ---

func _on_algo_selected(index: int) -> void:
	current_strategy = strategies[index]
	_build_ui_for_strategy()
	_update_button_states()

func _build_ui_for_strategy() -> void:
	# 1. Build Inputs FIRST
	_current_schema = current_strategy.get_settings()
	_active_inputs = SettingsUIBuilder.build_ui(_current_schema, settings_container)
	
	# 2. Add "Advanced Settings" Toggle AFTER
	if current_strategy is StrategyWalker:
		_advanced_toggle_btn = CheckButton.new()
		_advanced_toggle_btn.text = "Advanced Settings"
		_advanced_toggle_btn.button_pressed = _show_advanced
		_advanced_toggle_btn.toggled.connect(_on_advanced_toggled)
		settings_container.add_child(_advanced_toggle_btn)
		settings_container.move_child(_advanced_toggle_btn, 0)
	else:
		_advanced_toggle_btn = null

	# 3. Connect Signals
	SettingsUIBuilder.connect_live_updates(_active_inputs, _on_live_setting_changed)

	_refresh_visibility()

func _update_button_states() -> void:
	if not current_strategy: return
	
	# 1. VISIBILITY: Do we show Agent Controls?
	var show_agent_controls = current_strategy.supports_agents
	
	spawn_btn.visible = show_agent_controls
	if clear_agents_btn:
		clear_agents_btn.visible = show_agent_controls
	
	# 2. TEXT & CONTEXT: Update labels based on Strategy Type
	if show_agent_controls:
		# --- AGENT MODE ---
		grow_btn.text = "Extend Branch"
		grow_btn.visible = true 
		generate_btn.text = "Create New Graph"
		
		# Check for Paint Mode override (specific to Walker)
		if _active_inputs.has("global_behavior"):
			var mode = _active_inputs["global_behavior"].selected
			if mode == 1: # Paint Mode
				generate_btn.visible = false
				grow_btn.text = "Apply Paint"
				
	else:
		# --- STANDARD MODE ---
		grow_btn.text = "Grow"
		grow_btn.visible = current_strategy.supports_grow
		
		if current_strategy.reset_on_generate:
			generate_btn.text = "Generate"
		else:
			generate_btn.text = "Apply"
		generate_btn.visible = true

# --- HANDLER FOR ACTIONS ---

func _on_live_setting_changed(key: String, value: Variant) -> void:
	# If behavior changes (e.g. Grow -> Paint), update buttons immediately
	if key == "global_behavior":
		_update_button_states()

	# Picker Logic
	if key == "action_pick_node":
		graph_editor.request_node_pick(_on_node_picked)
		return
		
	# Legacy "Clear All" Logic
	if key == "action_clear_all" and current_strategy is StrategyWalker:
		var agents_to_nuke = graph_editor.graph.agents.duplicate()
		for agent in agents_to_nuke:
			graph_editor.remove_agent(agent)
		graph_editor.set_path_ends([])
		graph_editor.set_path_starts([])

func _on_node_picked(node_id: String) -> void:
	if _active_inputs.has("target_node"):
		_active_inputs["target_node"].text = node_id
	if _active_inputs.has("start_pos_node"):
		_active_inputs["start_pos_node"].text = node_id

func _collect_params() -> Dictionary:
	return SettingsUIBuilder.collect_params(_active_inputs)

# --- EVENT HANDLERS ---

# Button 2: "Create New Graph" (Destructive)
func _on_create_new_pressed() -> void:
	var params = _collect_params()
	
	if current_strategy is StrategyWalker:
		# Explicitly wipe everything first
		graph_editor.clear_graph()
		# StrategyWalker.execute will see empty agents and trigger a Spawn
	
	elif current_strategy.reset_on_generate:
		graph_editor.clear_graph()
		
	graph_editor.apply_strategy(current_strategy, params)

# Button 1: "Extend Branch" (Additive)
func _on_extend_pressed() -> void:
	var params = _collect_params()
	# We pass a flag, though Walker logic handles "Existing Agents" automatically
	params["append"] = true 
	graph_editor.apply_strategy(current_strategy, params)

func _on_clear_pressed() -> void:
	graph_editor.clear_graph()

# [NEW] Button 3: "Spawn Agents" (Additive, No Sim)
func _on_spawn_pressed() -> void:
	var params = _collect_params()
	params["spawn_only"] = true
	graph_editor.apply_strategy(current_strategy, params)

# [NEW] Button 4: "Clear Agents" (Destructive, Agents Only)
func _on_clear_agents_pressed() -> void:
	if not graph_editor or graph_editor.graph.agents.is_empty():
		return
		
	# We iterate a duplicate array so we can modify the original safely
	var agents_to_nuke = graph_editor.graph.agents.duplicate()
	
	# Using remove_agent ensures the action is added to the Undo Stack
	for agent in agents_to_nuke:
		graph_editor.remove_agent(agent)
	
	# Clear visual markers
	graph_editor.set_path_ends([])
	graph_editor.set_path_starts([])
	
	print("Controller: All agents cleared.")

# --- VISIBILITY HELPERS ---
func _on_advanced_toggled(toggled: bool) -> void:
	_show_advanced = toggled
	_refresh_visibility()

func _refresh_visibility() -> void:
	if not _advanced_toggle_btn: return
	for setting in _current_schema:
		var key = setting.name
		var is_advanced = setting.get("advanced", false)
		if _active_inputs.has(key):
			var row = _active_inputs[key].get_parent()
			if row: row.visible = not is_advanced or _show_advanced

func _on_debug_depth_toggled(toggled: bool) -> void:
	graph_editor.renderer.debug_show_depth = toggled
	graph_editor.renderer.queue_redraw()
