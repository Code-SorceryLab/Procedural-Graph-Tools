extends Node
class_name StrategyController

# --- 1. REFERENCES ---
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
	# Register Strategies
	strategies.append(StrategyGrid.new())
	strategies.append(StrategyWalker.new())
	strategies.append(StrategyMST.new())
	strategies.append(StrategyDLA.new())
	strategies.append(StrategyPolar.new()) 
	strategies.append(StrategyAnalyze.new())
	
	# Setup Dropdown
	algo_select.clear()
	for i in range(strategies.size()):
		algo_select.add_item(strategies[i].strategy_name, i)
	
	# Connect Signals
	algo_select.item_selected.connect(_on_algo_selected)
	grow_btn.pressed.connect(_on_grow_pressed)
	debug_depth_chk.toggled.connect(_on_debug_depth_toggled)
	generate_btn.pressed.connect(_on_generate_pressed)
	clear_btn.pressed.connect(_on_clear_pressed)
	
	# Select Default
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
	
	# 1. PARAMETER 1 (Width, Steps, Particles, WEDGES)
	if ("width" in params or "steps" in params or "particles" in params or "wedges" in params):
		param1_label.visible = true
		param1_input.visible = true
		
		if "steps" in params: param1_label.text = "Steps"
		elif "particles" in params: param1_label.text = "Particles"
		elif "wedges" in params: param1_label.text = "Wedges"
		else: param1_label.text = "Width"

	# 2. PARAMETER 2 (Height, RADIUS)
	if ("height" in params or "radius" in params):
		param2_label.visible = true
		param2_input.visible = true
		
		if "radius" in params: param2_label.text = "Radius"
		else: param2_label.text = "Height"
	
	# 3. TOGGLE
	if current_strategy.toggle_text != "":
		option_toggle.visible = true
		option_toggle.text = current_strategy.toggle_text
		option_toggle.button_pressed = false 

	# 4. BUTTONS
	if (current_strategy is StrategyDLA) or \
	   (current_strategy is StrategyWalker) or \
	   (current_strategy is StrategyMST):
		grow_btn.visible = true
	
	if current_strategy.reset_on_generate:
		generate_btn.text = "Generate"
	else:
		generate_btn.text = "Apply" 

func _on_generate_pressed() -> void:
	var params = _collect_params()
	if current_strategy.reset_on_generate:
		graph_editor.clear_graph()
	graph_editor.apply_strategy(current_strategy, params)

func _on_grow_pressed() -> void:
	var params = _collect_params()
	params["append"] = true 
	graph_editor.apply_strategy(current_strategy, params)

func _collect_params() -> Dictionary:
	# Map the UI inputs to all possible keys. 
	# The strategy will only use the keys it asked for.
	var params = {
		"width": int(param1_input.value),
		"height": int(param2_input.value),
		"steps": int(param1_input.value), 
		"particles": int(param1_input.value),
		"wedges": int(param1_input.value), # Mapped to Param 1
		"radius": int(param2_input.value), # Mapped to Param 2
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
