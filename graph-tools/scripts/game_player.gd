extends Node

# --- References ---
@onready var graph_editor: Node2D = $GraphEditor

# UI References
@onready var algo_select: OptionButton = $UI/Sidebar/Margin/TabContainer/Generation/AlgoSelect
@onready var param1_label: Label = $UI/Sidebar/Margin/TabContainer/Generation/InputContainer/Param1Label
@onready var param1_input: SpinBox = $UI/Sidebar/Margin/TabContainer/Generation/InputContainer/Param1Input
@onready var param2_label: Label = $UI/Sidebar/Margin/TabContainer/Generation/InputContainer/Param2Label
@onready var param2_input: SpinBox = $UI/Sidebar/Margin/TabContainer/Generation/InputContainer/Param2Input
@onready var option_toggle: CheckBox = $UI/Sidebar/Margin/TabContainer/Generation/OptionToggle
@onready var grow_btn: Button = $UI/Sidebar/Margin/TabContainer/Generation/GrowBtn
@onready var generate_btn: Button = $UI/Sidebar/Margin/TabContainer/Generation/GenerateBtn
@onready var clear_btn: Button = $UI/Sidebar/Margin/TabContainer/Generation/ClearBtn

@onready var save_btn: Button = $UI/Sidebar/Margin/TabContainer/File/SaveBtn
@onready var load_btn: Button = $UI/Sidebar/Margin/TabContainer/File/LoadBtn
@onready var file_status: Label = $UI/Sidebar/Margin/TabContainer/File/FileStatus
@onready var file_dialog: FileDialog = $FileDialog

# State to track if we are saving or loading
var _is_saving: bool = true
# Registry of available strategies
var strategies: Array[GraphStrategy] = []
var current_strategy: GraphStrategy

func _ready() -> void:
	# 1. Load our strategies
	strategies.append(StrategyGrid.new())
	strategies.append(StrategyWalker.new())
	strategies.append(StrategyMST.new())
	strategies.append(StrategyDLA.new())
	
	# 2. Setup Dropdown
	algo_select.clear()
	for i in range(strategies.size()):
		algo_select.add_item(strategies[i].strategy_name, i)
	
	# 3. Connect ALL signals (Generate, Clear, and Dropdown)
	_connect_signals()
	
	# 4. Initialize UI state (Select default)
	_on_algo_selected(0)

func _connect_signals() -> void:
	# Connect the dropdown change event
	algo_select.item_selected.connect(_on_algo_selected)
	
	# Connect Generation Signals
	grow_btn.pressed.connect(_on_grow_pressed)
	generate_btn.pressed.connect(_on_generate_pressed)
	clear_btn.pressed.connect(_on_clear_pressed)
	# Connect File Signals
	save_btn.pressed.connect(_on_save_button_pressed)
	load_btn.pressed.connect(_on_load_button_pressed)
	file_dialog.file_selected.connect(_on_file_selected)

# --- UI Logic ---
func _on_save_button_pressed() -> void:
	_is_saving = true
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.popup_centered()

func _on_load_button_pressed() -> void:
	_is_saving = false
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.popup_centered()
	
func _on_file_selected(path: String) -> void:
	if _is_saving:
		_save_graph(path)
	else:
		_load_graph(path)

func _save_graph(path: String) -> void:
	# ResourceSaver is Godot's built-in magic.
	# It takes the 'graph_editor.graph' resource and writes it to disk.
	var error = ResourceSaver.save(graph_editor.graph, path)
	if error == OK:
		file_status.text = "Saved: " + path.get_file()
		file_status.modulate = Color.GREEN
	else:
		file_status.text = "Error saving!"
		file_status.modulate = Color.RED

func _load_graph(path: String) -> void:
	# ResourceLoader.CACHE_MODE_IGNORE tells Godot: 
	# "I don't care if you have this file in memory, read it from the disk anyway."
	
	var new_graph = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	
	if new_graph is Graph:
		graph_editor.load_new_graph(new_graph)
		file_status.text = "Loaded: " + path.get_file()
		file_status.modulate = Color.GREEN
	else:
		file_status.text = "Error: Not a valid Graph."
		file_status.modulate = Color.RED

func _on_algo_selected(index: int) -> void:
	current_strategy = strategies[index]
	_update_ui_for_strategy()

func _update_ui_for_strategy() -> void:
	# 1. Hide everything first
	param1_label.visible = false
	param1_input.visible = false
	param2_label.visible = false
	param2_input.visible = false
	
	# 2. Show only what is needed
	var params = current_strategy.required_params
	
	if ("width" in params or "steps" in params or "particles" in params):
		param1_label.visible = true
		param1_input.visible = true
		#Dynamic Labeling: If it's a walker: label it "Steps"; dla: "Particles"; else "Width"
		if "steps" in params:
			param1_label.text = "Steps"
		elif "particles" in params:
			param1_label.text = "Particles"
		else:
			param1_label.text = "Width"

	if ("height" in params):
		param2_label.visible = true
		param2_input.visible = true
		param2_label.text = "Height"
	
	#Toggle Logic
	if current_strategy.toggle_text != "":
		option_toggle.visible = true
		option_toggle.text = current_strategy.toggle_text
		option_toggle.button_pressed = false # Reset to unchecked by default
	else:
		option_toggle.visible = false # Hide if strategy doesn't use it
# NEW: Grow Button Visibility
	# Only show Grow button for strategies we know support it (DLA)
	if (current_strategy is StrategyDLA) or (current_strategy is StrategyWalker):
		grow_btn.visible = true
	else:
		grow_btn.visible = false

# --- Action Logic ---
func _on_grow_pressed() -> void:
	var params = {
		"width": int(param1_input.value),
		"height": int(param2_input.value),
		"steps": int(param1_input.value),
		"particles": int(param1_input.value),
		# NEW: Tell the strategy to append instead of clear
		"append": true 
	}
	
	if current_strategy.toggle_key != "":
		params[current_strategy.toggle_key] = option_toggle.button_pressed
	
	graph_editor.apply_strategy(current_strategy, params)

func _on_generate_pressed() -> void:
	# Pack current inputs into a generic dictionary
	var params = {
		"width": int(param1_input.value),
		"height": int(param2_input.value),
		"steps": int(param1_input.value), 
		"particles": int(param1_input.value)
	}
	
	#Inject the toggle value if applicable
	if current_strategy.toggle_key != "":
		params[current_strategy.toggle_key] = option_toggle.button_pressed
	
	# Send to Editor
	graph_editor.apply_strategy(current_strategy, params)

func _on_clear_pressed() -> void:
	graph_editor.clear_graph()
