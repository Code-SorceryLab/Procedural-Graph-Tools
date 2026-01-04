extends Node
class_name GamePlayer

# ==============================================================================
# 1. SCENE REFERENCES
# ==============================================================================

# Core Systems
@onready var graph_editor: GraphEditor = $GraphEditor
@onready var file_dialog: FileDialog = $FileDialog

# Sidebar UI
@onready var toolbar: Toolbar = $UI/Toolbar

# --- Generation Tab ---
@onready var algo_select: OptionButton = $UI/Sidebar/Margin/TabContainer/Generation/AlgoSelect
@onready var param1_label: Label = $UI/Sidebar/Margin/TabContainer/Generation/InputContainer/Param1Label
@onready var param1_input: SpinBox = $UI/Sidebar/Margin/TabContainer/Generation/InputContainer/Param1Input
@onready var param2_label: Label = $UI/Sidebar/Margin/TabContainer/Generation/InputContainer/Param2Label
@onready var param2_input: SpinBox = $UI/Sidebar/Margin/TabContainer/Generation/InputContainer/Param2Input
@onready var option_toggle: CheckBox = $UI/Sidebar/Margin/TabContainer/Generation/OptionToggle
@onready var debug_depth_chk: CheckBox = $UI/Sidebar/Margin/TabContainer/Generation/DebugDepthChk
@onready var grow_btn: Button = $UI/Sidebar/Margin/TabContainer/Generation/GrowBtn
@onready var generate_btn: Button = $UI/Sidebar/Margin/TabContainer/Generation/GenerateBtn
@onready var clear_btn: Button = $UI/Sidebar/Margin/TabContainer/Generation/ClearBtn

# --- File Tab ---
@onready var save_btn: Button = $UI/Sidebar/Margin/TabContainer/File/SaveBtn
@onready var load_btn: Button = $UI/Sidebar/Margin/TabContainer/File/LoadBtn
@onready var file_status: Label = $UI/Sidebar/Margin/TabContainer/File/FileStatus

# --- Pathfinding Tab ---
@onready var btn_set_start: Button = $UI/Sidebar/Margin/TabContainer/Pathfinding/BtnSetStart
@onready var btn_set_end: Button = $UI/Sidebar/Margin/TabContainer/Pathfinding/BtnSetEnd
@onready var btn_run_path: Button = $UI/Sidebar/Margin/TabContainer/Pathfinding/BtnRunPath


# ==============================================================================
# 2. STATE VARIABLES
# ==============================================================================

# File I/O State
var _is_saving: bool = true

# Strategy State
var strategies: Array[GraphStrategy] = []
var current_strategy: GraphStrategy


# ==============================================================================
# 3. INITIALIZATION
# ==============================================================================

func _ready() -> void:
	# 1. Register available generation strategies
	_register_strategies()
	
	# 2. Populate UI dropdowns
	_setup_ui_dropdowns()
	
	# 3. Connect internal signals
	_connect_signals()
	
	# 4. Initialize UI state
	# Select the first strategy by default
	_on_algo_selected(0)
	# Reset button states (disable pathfinding buttons initially)
	_update_button_states([])


func _register_strategies() -> void:
	strategies.append(StrategyGrid.new())
	strategies.append(StrategyWalker.new())
	strategies.append(StrategyMST.new())
	strategies.append(StrategyDLA.new())
	strategies.append(StrategyAnalyze.new())


func _setup_ui_dropdowns() -> void:
	algo_select.clear()
	for i in range(strategies.size()):
		algo_select.add_item(strategies[i].strategy_name, i)


func _connect_signals() -> void:
	# --- Core Editor Signals ---
	graph_editor.selection_changed.connect(_on_selection_changed)
	
	# --- Toolbar ---
	toolbar.tool_changed.connect(_on_tool_changed)
	
	# --- Generation Tab ---
	algo_select.item_selected.connect(_on_algo_selected)
	grow_btn.pressed.connect(_on_grow_pressed)
	debug_depth_chk.toggled.connect(_on_debug_depth_toggled)
	generate_btn.pressed.connect(_on_generate_pressed)
	clear_btn.pressed.connect(_on_clear_pressed)
	
	# --- File Tab ---
	save_btn.pressed.connect(_on_save_button_pressed)
	load_btn.pressed.connect(_on_load_button_pressed)
	file_dialog.file_selected.connect(_on_file_selected)
	
	# --- Pathfinding Tab ---
	btn_set_start.pressed.connect(_on_set_start_pressed)
	btn_set_end.pressed.connect(_on_set_end_pressed)
	btn_run_path.pressed.connect(_on_run_path_pressed)


# ==============================================================================
# 4. UI EVENT HANDLERS
# ==============================================================================

# --- Toolbar Interaction ---
func _on_tool_changed(tool_id: int, tool_name: String) -> void:
	# Pass the command to the GraphEditor
	graph_editor.set_active_tool(tool_id)
	
	# Future Hook: Update sidebar options based on tool
	_update_tool_options(tool_id)

func _update_tool_options(_tool_id: int) -> void:
	# Placeholder: Show/Hide context-sensitive settings in the sidebar
	pass


# --- Selection & Button States ---
func _on_selection_changed(selected_nodes: Array[String]) -> void:
	_update_button_states(selected_nodes)

func _update_button_states(selected_nodes: Array[String]) -> void:
	# Strict Policy: Only enable Start/End buttons if EXACTLY 1 node is selected
	var is_single_select = (selected_nodes.size() == 1)
	
	btn_set_start.disabled = not is_single_select
	btn_set_end.disabled = not is_single_select
	
	# Visual Feedback: Dim the buttons when disabled
	if is_single_select:
		btn_set_start.modulate = GraphSettings.COLOR_UI_ACTIVE
	else:
		btn_set_start.modulate = GraphSettings.COLOR_UI_DISABLED


# --- Pathfinding ---
func _on_set_start_pressed() -> void:
	if graph_editor.selected_nodes.size() == 1:
		var id = graph_editor.selected_nodes[0]
		graph_editor.set_path_start(id)
		print("Path Start set to: ", id)
	else:
		print("Error: Please select exactly one node to set as Start.")

func _on_set_end_pressed() -> void:
	if graph_editor.selected_nodes.size() == 1:
		var id = graph_editor.selected_nodes[0]
		graph_editor.set_path_end(id)
		print("Path End set to: ", id)
	else:
		print("Error: Please select exactly one node to set as End.")

func _on_run_path_pressed() -> void:
	graph_editor.run_pathfinding()


# --- Generation Strategy ---
func _on_algo_selected(index: int) -> void:
	current_strategy = strategies[index]
	_update_ui_for_strategy()

func _update_ui_for_strategy() -> void:
	# 1. Reset Visibility
	param1_label.visible = false
	param1_input.visible = false
	param2_label.visible = false
	param2_input.visible = false
	option_toggle.visible = false
	grow_btn.visible = false
	
	# 2. Configure Inputs based on Strategy requirements
	var params = current_strategy.required_params
	
	# Parameter 1 (Width/Steps/Particles)
	if ("width" in params or "steps" in params or "particles" in params):
		param1_label.visible = true
		param1_input.visible = true
		
		if "steps" in params:
			param1_label.text = "Steps"
		elif "particles" in params:
			param1_label.text = "Particles"
		else:
			param1_label.text = "Width"

	# Parameter 2 (Height)
	if ("height" in params):
		param2_label.visible = true
		param2_input.visible = true
		param2_label.text = "Height"
	
	# Toggle Option
	if current_strategy.toggle_text != "":
		option_toggle.visible = true
		option_toggle.text = current_strategy.toggle_text
		option_toggle.button_pressed = false 

	# Grow Button Availability
	# Allow 'Grow' for incremental algorithms (DLA, Walker) or filters (MST)
	if (current_strategy is StrategyDLA) or \
	   (current_strategy is StrategyWalker) or \
	   (current_strategy is StrategyMST):
		grow_btn.visible = true


func _on_generate_pressed() -> void:
	var params = _collect_strategy_params()
	graph_editor.apply_strategy(current_strategy, params)

func _on_grow_pressed() -> void:
	var params = _collect_strategy_params()
	params["append"] = true # Key flag for incremental generation
	graph_editor.apply_strategy(current_strategy, params)

func _collect_strategy_params() -> Dictionary:
	var params = {
		"width": int(param1_input.value),
		"height": int(param2_input.value),
		"steps": int(param1_input.value), 
		"particles": int(param1_input.value)
	}
	
	if current_strategy.toggle_key != "":
		params[current_strategy.toggle_key] = option_toggle.button_pressed
		
	return params


# --- General Actions ---
func _on_clear_pressed() -> void:
	graph_editor.clear_graph()

func _on_debug_depth_toggled(toggled: bool) -> void:
	graph_editor.renderer.debug_show_depth = toggled
	graph_editor.renderer.queue_redraw()


# ==============================================================================
# 5. FILE I/O OPERATIONS
# ==============================================================================

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
	# ResourceSaver writes the Graph resource to disk
	var error = ResourceSaver.save(graph_editor.graph, path)
	if error == OK:
		file_status.text = "Saved: " + path.get_file()
		file_status.modulate = GraphSettings.COLOR_UI_SUCCESS
	else:
		file_status.text = "Error saving!"
		file_status.modulate = GraphSettings.COLOR_UI_ERROR

func _load_graph(path: String) -> void:
	# Force reload from disk to ensure freshness
	var new_graph = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	
	if new_graph is Graph:
		graph_editor.load_new_graph(new_graph)
		file_status.text = "Loaded: " + path.get_file()
		file_status.modulate = GraphSettings.COLOR_UI_SUCCESS
	else:
		file_status.text = "Error: Not a valid Graph."
		file_status.modulate = GraphSettings.COLOR_UI_ERROR
