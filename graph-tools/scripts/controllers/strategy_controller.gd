extends Node
class_name StrategyController

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
	grow_btn.pressed.connect(_on_grow_pressed)
	debug_depth_chk.toggled.connect(_on_debug_depth_toggled)
	generate_btn.pressed.connect(_on_generate_pressed)
	clear_btn.pressed.connect(_on_clear_pressed)
	
	if strategies.size() > 0:
		_on_algo_selected(0)

# --- DYNAMIC UI LOGIC ---
func _on_algo_selected(index: int) -> void:
	current_strategy = strategies[index]
	_build_ui_for_strategy()

func _build_ui_for_strategy() -> void:
	# 1. Get Settings Schema
	var settings = current_strategy.get_settings()
	
	# 2. Build UI Elements (REFACTORED)
	# The builder automatically clears previous children and generates new ones.
	_active_inputs = SettingsUIBuilder.build_ui(settings, settings_container)

	# 3. Handle Buttons Visibility
	grow_btn.visible = current_strategy.supports_grow
	
	if current_strategy.reset_on_generate:
		generate_btn.text = "Generate"
	else:
		generate_btn.text = "Apply"

func _collect_params() -> Dictionary:
	# 1. Collect Dynamic Params (REFACTORED)
	var params = SettingsUIBuilder.collect_params(_active_inputs)
	
	# 2. Add Global Static Params
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
