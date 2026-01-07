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
	
	_on_algo_selected(0)

# --- DYNAMIC UI LOGIC ---
func _on_algo_selected(index: int) -> void:
	current_strategy = strategies[index]
	_build_ui_for_strategy()

func _build_ui_for_strategy() -> void:
	# 1. Clear existing UI
	for child in settings_container.get_children():
		child.queue_free()
	_active_inputs.clear()
	
	# 2. Get Settings Schema
	var settings = current_strategy.get_settings()
	
	# 3. Build new UI Elements
	for setting in settings:
		var key = setting["name"]
		var type = setting["type"]
		var default = setting.get("default", 0)
		
		# 1. Capture the hint
		var hint_text = setting.get("hint", "")
		
		
		# 2. Create Label & Apply Hint
		var label = Label.new()
		label.text = key.capitalize() 
		# Apply tooltip to the label too, so hovering the text works
		if hint_text != "":
			label.tooltip_text = hint_text
			label.mouse_filter = Control.MOUSE_FILTER_STOP # Required for Labels to catch mouse events
		settings_container.add_child(label)
		
		var control: Control
		
		match type:
			TYPE_INT, TYPE_FLOAT:
				var spin = SpinBox.new()
				
				# --- CRITICAL FIX START ---
				# We must set Min/Max/Step BEFORE setting Value.
				spin.min_value = setting.get("min", 0)
				spin.max_value = setting.get("max", 100)
				
				if type == TYPE_FLOAT:
					# Use custom step if provided (e.g. 0.05), else default to 0.1
					spin.step = setting.get("step", 0.1)
				else:
					spin.step = 1.0
					
				spin.custom_arrow_step = spin.step
				
				# NOW we can safely set the value without it rounding to int
				spin.value = default
				# --- CRITICAL FIX END ---
				
				control = spin
				
			TYPE_BOOL:
				var chk = CheckBox.new()
				chk.text = "Enable"
				chk.button_pressed = bool(default)
				control = chk
		
		# 3. Apply Hint to the Input Control
		if control:
			if hint_text != "":
				control.tooltip_text = hint_text
			
			settings_container.add_child(control)
			_active_inputs[key] = control
	

	# 4. Handle Buttons Visibility
	grow_btn.visible = current_strategy.supports_grow
	
	
	if current_strategy.reset_on_generate:
		generate_btn.text = "Generate"
	else:
		generate_btn.text = "Apply"

func _collect_params() -> Dictionary:
	var params = {}
	for key in _active_inputs:
		var control = _active_inputs[key]
		if control is SpinBox:
			params[key] = control.value
		elif control is CheckBox:
			params[key] = control.button_pressed
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
