extends Node
class_name StrategyController

# --- 1. REFERENCES (Assigned in Inspector) ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor

@export_group("UI Generation Tab")
@export var algo_select: OptionButton
@export var param1_label: Label
@export var param1_input: SpinBox
@export var param2_label: Label
@export var param2_input: SpinBox
@export var option_toggle: CheckBox
@export var debug_depth_chk: CheckBox
@export var grow_btn: Button
@export var generate_btn: Button
@export var clear_btn: Button
@export var merge_chk: CheckBox 

# --- 2. STATE ---
var strategies: Array[GraphStrategy] = []
var current_strategy: GraphStrategy

# --- 3. INITIALIZATION ---
func _ready() -> void:
	# A. Register Strategies
	strategies.append(StrategyGrid.new())
	strategies.append(StrategyWalker.new())
	strategies.append(StrategyMST.new())
	strategies.append(StrategyDLA.new())
	strategies.append(StrategyAnalyze.new())
	
	# B. Setup Dropdown
	algo_select.clear()
	for i in range(strategies.size()):
		algo_select.add_item(strategies[i].strategy_name, i)
	
	# C. Connect Signals
	algo_select.item_selected.connect(_on_algo_selected)
	grow_btn.pressed.connect(_on_grow_pressed)
	debug_depth_chk.toggled.connect(_on_debug_depth_toggled)
	generate_btn.pressed.connect(_on_generate_pressed)
	clear_btn.pressed.connect(_on_clear_pressed)
	
	# D. Select Default
	_on_algo_selected(0)

# --- 4. LOGIC ---
func _on_algo_selected(index: int) -> void:
	current_strategy = strategies[index]
	_update_ui_for_strategy()

func _update_ui_for_strategy() -> void:
	# Reset Visibility
	param1_label.visible = false
	param1_input.visible = false
	param2_label.visible = false
	param2_input.visible = false
	option_toggle.visible = false
	grow_btn.visible = false
	
	var params = current_strategy.required_params
	
	# Dynamic Labels
	if ("width" in params or "steps" in params or "particles" in params):
		param1_label.visible = true
		param1_input.visible = true
		if "steps" in params: param1_label.text = "Steps"
		elif "particles" in params: param1_label.text = "Particles"
		else: param1_label.text = "Width"

	if ("height" in params):
		param2_label.visible = true
		param2_input.visible = true
		param2_label.text = "Height"
	
	if current_strategy.toggle_text != "":
		option_toggle.visible = true
		option_toggle.text = current_strategy.toggle_text
		option_toggle.button_pressed = false 

	# Show Grow Button for incremental strategies
	if (current_strategy is StrategyDLA) or \
	   (current_strategy is StrategyWalker) or \
	   (current_strategy is StrategyMST):
		grow_btn.visible = true
	
	# Updates the Generate Button Text for clarity
	if current_strategy.reset_on_generate:
		generate_btn.text = "Generate"
	else:
		generate_btn.text = "Apply" # "Apply MST", "Apply Analysis"

func _on_generate_pressed() -> void:
	var params = _collect_params()
	
	# INTELLIGENT RESET LOGIC
	# Only clear the graph if the strategy explicitly asks for a clean slate.
	if current_strategy.reset_on_generate:
		graph_editor.clear_graph()
	
	# Note: We don't pass 'reset_state' here because strategies manage their own 
	# internal memory (like _walkers array) based on whether 'append' is in params 
	# or if they are just running fresh.
	
	graph_editor.apply_strategy(current_strategy, params)

func _on_grow_pressed() -> void:
	var params = _collect_params()
	params["append"] = true # This tells the strategy "Keep your internal memory"
	
	# Grow NEVER clears the graph
	graph_editor.apply_strategy(current_strategy, params)

func _collect_params() -> Dictionary:
	var params = {
		"width": int(param1_input.value),
		"height": int(param2_input.value),
		"steps": int(param1_input.value), 
		"particles": int(param1_input.value),
		"merge_overlaps": merge_chk.button_pressed
	}
	if current_strategy.toggle_key != "":
		params[current_strategy.toggle_key] = option_toggle.button_pressed
	return params

func _on_clear_pressed() -> void:
	graph_editor.clear_graph()

func _on_debug_depth_toggled(toggled: bool) -> void:
	graph_editor.renderer.debug_show_depth = toggled
	graph_editor.renderer.queue_redraw()
