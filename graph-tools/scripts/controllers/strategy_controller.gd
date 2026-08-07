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
@export var grow_btn: Button      # "Extend Branch"
@export var generate_btn: Button  # "Create New Graph"
@export var clear_btn: Button
@export var spawn_btn: Button
@export var clear_agents_btn: Button # "Clear Agents Only"

# --- STATE ---
var strategies: Array[GraphStrategy] = []
var current_strategy: GraphStrategy
var _active_inputs: Dictionary = {} 
var _current_schema: Array[Dictionary] = [] 
var _hidden_params: Dictionary = {} # Stores popup data

# Preset State
var preset_dialog: FileDialog
var _preset_save_mode: bool = false
var _loaded_preset: Dictionary = {}

# Popup State for Biome Filler
var _biome_palette_popup: AlgorithmSettingsPopup

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
	strategies.append(StrategyBiomeFiller.new())
	strategies.append(StrategyGrammar.new())
	strategies.append(StrategyDAG.new())
	
	algo_select.clear()
	for i in range(strategies.size()):
		algo_select.add_item(strategies[i].strategy_name, i)
	
	algo_select.item_selected.connect(_on_algo_selected)
	
	# Setup the popup
	_biome_palette_popup = AlgorithmSettingsPopup.new()
	add_child(_biome_palette_popup)
	_biome_palette_popup.settings_confirmed.connect(_on_biome_palette_confirmed)
	
	# Setup the Preset File Dialog
	preset_dialog = FileDialog.new()
	preset_dialog.access = FileDialog.ACCESS_FILESYSTEM # Allows saving anywhere on the computer
	preset_dialog.add_filter("*.json", "Strategy Preset")
	preset_dialog.file_selected.connect(_on_preset_file_selected)
	add_child(preset_dialog)
	
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
	_hidden_params.clear() # Reset hidden parameters when changing tools
	_loaded_preset.clear() # Wipe preset memory when swapping tools
	_build_ui_for_strategy()
	_update_button_states()

func _build_ui_for_strategy() -> void:
	# 1. Grab base schema
	_current_schema = current_strategy.get_settings()
	
	# --- [NEW] INJECT PRESET OVERRIDES ---
	if not _loaded_preset.is_empty():
		for setting in _current_schema:
			if _loaded_preset.has(setting["name"]):
				setting["default"] = _loaded_preset[setting["name"]]
		
		# Transfer hidden parameters (like biome palettes) directly to the staging buffer
		_hidden_params = _loaded_preset.duplicate()
		_hidden_params.erase("strategy_type") # Don't pass the metadata to the generator!

	# 2. Build Inputs
	_active_inputs = SettingsUIBuilder.build_ui(_current_schema, settings_container)
	
	# --- [NEW] ADD PRESET BUTTONS ---
	var preset_hbox = HBoxContainer.new()
	var btn_load = Button.new()
	var btn_save = Button.new()
	
	btn_load.text = "Load Preset"
	btn_save.text = "Save Preset"
	btn_load.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	btn_load.pressed.connect(_on_load_preset_pressed)
	btn_save.pressed.connect(_on_save_preset_pressed)
	
	preset_hbox.add_child(btn_load)
	preset_hbox.add_child(btn_save)
	
	settings_container.add_child(preset_hbox)
	settings_container.move_child(preset_hbox, 0) # Force to top!

	# 3. Add "Advanced Settings" Toggle AFTER
	var has_advanced_settings = false
	for setting in _current_schema:
		if setting.get("advanced", false):
			has_advanced_settings = true
			break
			
	if has_advanced_settings:
		_advanced_toggle_btn = CheckButton.new()
		_advanced_toggle_btn.text = "Advanced Settings"
		_advanced_toggle_btn.button_pressed = _show_advanced
		_advanced_toggle_btn.toggled.connect(_on_advanced_toggled)
		settings_container.add_child(_advanced_toggle_btn)
		# Move to index 1 (Right beneath the Preset buttons)
		settings_container.move_child(_advanced_toggle_btn, 1) 
	else:
		_advanced_toggle_btn = null

	# 4. Connect Signals
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
	# 1. Update Buttons if Behavior Mode changes (Grow vs Paint)
	if key == "global_behavior":
		_update_button_states()
		
	# Intercept the Biome Palette Button
	elif key == "btn_biome_palette":
		if current_strategy and current_strategy.has_method("get_palette_schema"):
			var schema = current_strategy.call("get_palette_schema")
			# We pass the currently active inputs as the default values
			var current_params = _collect_params()
			_biome_palette_popup.open_settings("Flood Fill Palette", schema, current_params)
		return

	# --- START NODE PICKER ---
	if key == "action_pick_node":
		graph_editor.request_node_pick(_on_start_node_picked)
		return

	if key == "start_pos_node":
		SettingsUIBuilder.sync_picker_button(_active_inputs, "action_pick_node", "Start Node", value)

	# --- TARGET NODE PICKER ---
	if key == "action_pick_target":
		graph_editor.request_node_pick(_on_target_node_picked)
		return

	if key == "target_node":
		SettingsUIBuilder.sync_picker_button(_active_inputs, "action_pick_target", "Target Node", value)

func _on_start_node_picked(node_id: String) -> void:
	if _active_inputs.has("start_pos_node"):
		_active_inputs["start_pos_node"].text = node_id
		# Trigger sync manually
		_on_live_setting_changed("start_pos_node", node_id)
		print("StrategyController: Set Start Node -> ", node_id)

func _on_target_node_picked(node_id: String) -> void:
	if _active_inputs.has("target_node"):
		_active_inputs["target_node"].text = node_id
		# Trigger sync manually
		_on_live_setting_changed("target_node", node_id)
		print("StrategyController: Set Target Node -> ", node_id)

# Popup Data Handler
func _on_biome_palette_confirmed(new_settings: Dictionary) -> void:
	# Store popup settings safely in our hidden dictionary
	_hidden_params.merge(new_settings, true)
	
	# Optional: Automatically trigger the generation when they hit OK!
	# _on_create_new_pressed()

# --- HELPER WRAPPER ---
func _collect_params() -> Dictionary:
	var params = SettingsUIBuilder.collect_params(_active_inputs)
	# Merge the hidden params (from popups) into the final dictionary
	params.merge(_hidden_params, true)
	return params

# --- EVENT HANDLERS ---

# Button 2: "Create New Graph" (Destructive)
func _on_create_new_pressed() -> void:
	var params = _collect_params()
	
	if current_strategy is StrategyWalker:
		graph_editor.clear_graph()
	elif current_strategy.reset_on_generate:
		graph_editor.clear_graph()
		
	graph_editor.apply_strategy(current_strategy, params)

# Button 1: "Extend Branch" (Additive)
func _on_extend_pressed() -> void:
	var params = _collect_params()
	params["append"] = true 
	graph_editor.apply_strategy(current_strategy, params)

func _on_clear_pressed() -> void:
	graph_editor.clear_graph()

# Button 3: "Spawn Agents" (Additive, No Sim)
func _on_spawn_pressed() -> void:
	var params = _collect_params()
	params["spawn_only"] = true
	graph_editor.apply_strategy(current_strategy, params)

# Button 4: "Clear Agents" (Destructive, Agents Only)
func _on_clear_agents_pressed() -> void:
	if not graph_editor or graph_editor.graph.agents.is_empty():
		return
		
	var agents_to_nuke = graph_editor.graph.agents.duplicate()
	
	# Wrap all agent removals in a single Undo step
	graph_editor.start_undo_transaction("Clear All Agents")
	
	for agent in agents_to_nuke:
		graph_editor.remove_agent(agent)
		
	graph_editor.commit_undo_transaction()
	
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
		var key = setting.get("name", "")
		if key == "": continue
		
		var is_advanced = setting.get("advanced", false)
		if _active_inputs.has(key):
			var control = _active_inputs[key]
			var row = control.get_parent()
			
			# [CRITICAL FIX] Action buttons don't have row wrappers, 
			# so their parent is the main settings_container. 
			# We must NOT hide the main container!
			if row == settings_container or row == null:
				control.visible = not is_advanced or _show_advanced
			else:
				row.visible = not is_advanced or _show_advanced

func _on_debug_depth_toggled(toggled: bool) -> void:
	graph_editor.set_debug_depth(toggled)


# ==============================================================================
# PRESET FILE I/O LOGIC
# ==============================================================================

func _on_save_preset_pressed() -> void:
	_preset_save_mode = true
	preset_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	preset_dialog.title = "Save Strategy Preset"
	preset_dialog.popup_centered_ratio(0.5)

func _on_load_preset_pressed() -> void:
	_preset_save_mode = false
	preset_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	preset_dialog.title = "Load Strategy Preset"
	preset_dialog.popup_centered_ratio(0.5)

func _on_preset_file_selected(path: String) -> void:
	if _preset_save_mode:
		# Save Mode: Collect everything and tag it with the strategy type
		var params = _collect_params()
		params["strategy_type"] = current_strategy.strategy_name
		
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(params, "\t"))
			file.close()
			
			if SignalManager.has_signal("status_message_changed"):
				SignalManager.status_message_changed.emit("Preset saved: " + path.get_file())
	else:
		# Load Mode: Read JSON and rebuild the UI
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var data = json.data
				var target_type = data.get("strategy_type", "Unknown")
				
				if target_type == current_strategy.strategy_name:
					_loaded_preset = data
					_build_ui_for_strategy() # Rebuilds the UI with the injected defaults!
					
					if SignalManager.has_signal("status_message_changed"):
						SignalManager.status_message_changed.emit("Preset loaded: " + path.get_file())
				else:
					# Attempt to find the correct strategy and switch to it automatically
					var found_idx = -1
					for i in range(strategies.size()):
						if strategies[i].strategy_name == target_type:
							found_idx = i
							break
							
					if found_idx != -1:
						# Manually switch state to bypass _on_algo_selected's preset wipe
						algo_select.selected = found_idx
						current_strategy = strategies[found_idx]
						_hidden_params.clear()
						
						# Inject the preset and build!
						_loaded_preset = data 
						_build_ui_for_strategy()
						_update_button_states()
						
						if SignalManager.has_signal("status_message_changed"):
							SignalManager.status_message_changed.emit("Switched to '%s' and loaded preset." % target_type)
					else:
						# The strategy was renamed or deleted from the codebase
						push_error("Cannot load preset: The strategy '%s' no longer exists." % target_type)
			file.close()
