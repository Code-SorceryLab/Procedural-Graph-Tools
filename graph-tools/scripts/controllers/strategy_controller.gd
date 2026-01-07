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
		
		# Capture optional metadata
		var hint_text = setting.get("hint", "")
		var options_str = setting.get("options", "") 
		
		# Create Label
		var label = Label.new()
		label.text = key.capitalize() 
		if hint_text != "":
			label.tooltip_text = hint_text
			label.mouse_filter = Control.MOUSE_FILTER_STOP 
		settings_container.add_child(label)
		
		var control: Control
		
		# --- A. Check for Dropdown Options ---
		if options_str != "":
			var opt = OptionButton.new()
			var items = options_str.split(",")
			for i in range(items.size()):
				opt.add_item(items[i].strip_edges(), i) 
			
			opt.selected = int(default)
			control = opt
			
		# --- B. Standard Types ---
		else:
			match type:
				# CRITICAL FIX: Removed "int" and "float" strings from this line.
				# Comparing an INT variable to a STRING literal causes a crash.
				TYPE_INT, TYPE_FLOAT:
					var spin = SpinBox.new()
					spin.min_value = setting.get("min", 0)
					spin.max_value = setting.get("max", 100)
					
					if type == TYPE_FLOAT:
						spin.step = setting.get("step", 0.1)
					else:
						spin.step = 1.0
						
					spin.custom_arrow_step = spin.step
					spin.value = default
					control = spin
					
				# Same fix here: Removed "bool" string
				TYPE_BOOL:
					var chk = CheckBox.new()
					chk.text = "Enable"
					chk.button_pressed = bool(default)
					control = chk
		
		# Add to Container
		if control:
			if hint_text != "":
				control.tooltip_text = hint_text
			
			control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
		elif control is OptionButton:
			params[key] = control.selected
			
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
