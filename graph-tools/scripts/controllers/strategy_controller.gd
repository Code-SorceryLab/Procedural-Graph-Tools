extends Node
class_name StrategyController

# --- STATIC INSTANCE (SINGLETON) ---
static var instance: StrategyController

func _enter_tree() -> void:
	if instance == null:
		instance = self

func _exit_tree() -> void:
	if instance == self:
		instance = null

# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor

@export_group("UI Generation Tab")
@export var algo_select: OptionButton
@export var settings_container: Control 

@export var debug_depth_chk: CheckBox
@export var merge_chk: CheckBox 
@export var grow_btn: Button
@export var generate_btn: Button
@export var clear_btn: Button

# --- STATE ---
var strategies: Array[GraphStrategy] = []
var current_strategy: GraphStrategy
var _active_inputs: Dictionary = {} 

# --- INITIALIZATION ---
func _ready() -> void:
	strategies.append(StrategyGrid.new())
	strategies.append(StrategyWalker.new()) # Index 1 (Usually)
	strategies.append(StrategyMST.new())
	strategies.append(StrategyDLA.new())
	strategies.append(StrategyCA.new())
	strategies.append(StrategyPolar.new()) 
	strategies.append(StrategyAnalyze.new())
	
	algo_select.clear()
	for i in range(strategies.size()):
		algo_select.add_item(strategies[i].strategy_name, i)
	
	algo_select.item_selected.connect(_on_algo_selected)
	grow_btn.pressed.connect(_on_grow_pressed)
	debug_depth_chk.toggled.connect(_on_debug_depth_toggled)
	generate_btn.pressed.connect(_on_generate_pressed)
	clear_btn.pressed.connect(_on_clear_pressed)
	
	if strategies.size() > 0:
		_on_algo_selected(0)

# --- PUBLIC API (NEW) ---

# Allows tools to force-switch the tab
func switch_to_strategy_type(target_type_script) -> bool:
	# 1. Check if we are already there
	if is_instance_of(current_strategy, target_type_script):
		return true
		
	# 2. Find the index of the requested strategy class
	for i in range(strategies.size()):
		if is_instance_of(strategies[i], target_type_script):
			# Found it! Switch the UI.
			algo_select.selected = i
			_on_algo_selected(i) # Manually trigger the update
			return true
			
	print("StrategyController: Could not find strategy of type ", target_type_script)
	return false

# --- DYNAMIC UI LOGIC ---
func _on_algo_selected(index: int) -> void:
	current_strategy = strategies[index]
	_build_ui_for_strategy()

func _build_ui_for_strategy() -> void:
	var settings = current_strategy.get_settings()
	_active_inputs = SettingsUIBuilder.build_ui(settings, settings_container)
	
	# Connect Signals
	SettingsUIBuilder.connect_live_updates(_active_inputs, _on_live_setting_changed)

	grow_btn.visible = current_strategy.supports_grow
	if current_strategy.reset_on_generate:
		generate_btn.text = "Generate"
	else:
		generate_btn.text = "Apply"

# [FIXED] Handler for Strategy Buttons
func _on_live_setting_changed(key: String, _value: Variant) -> void:
	if key == "action_clear_all" and current_strategy is StrategyWalker:
		# [FIX] Strategy no longer manages data. We use the Editor to clear.
		# We iterate a duplicate array to safely remove items while looping.
		var agents_to_nuke = graph_editor.graph.agents.duplicate()
		
		# Using remove_agent ensures the action is added to the Undo Stack!
		for agent in agents_to_nuke:
			graph_editor.remove_agent(agent)
		
		# Clear visual markers
		graph_editor.set_path_ends([])
		graph_editor.set_path_starts([])
		
		print("Controller: All agents cleared (Undoable).")

func _collect_params() -> Dictionary:
	var params = SettingsUIBuilder.collect_params(_active_inputs)
	params["merge_overlaps"] = merge_chk.button_pressed
	return params

# --- EVENT HANDLERS ---
func _on_generate_pressed() -> void:
	var params = _collect_params()
	if current_strategy.reset_on_generate:
		graph_editor.clear_graph()
	graph_editor.apply_strategy(current_strategy, params)

func _on_grow_pressed() -> void:
	var params = _collect_params()
	params["append"] = true
	graph_editor.apply_strategy(current_strategy, params)

func _on_clear_pressed() -> void:
	graph_editor.clear_graph()

func _on_debug_depth_toggled(toggled: bool) -> void:
	graph_editor.renderer.debug_show_depth = toggled
	graph_editor.renderer.queue_redraw()
