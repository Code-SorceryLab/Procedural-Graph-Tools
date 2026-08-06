class_name ExperimentController
extends Node

# --- UI REFERENCES ---
@export_group("UI Elements")
@export var strategy_dropdown: OptionButton
@export var settings_container: VBoxContainer
@export var run_button: Button
@export var progress_bar: ProgressBar
@export var status_label: Label

@export_group("Data Dashboard")
@export var results_table: Tree
@export var export_btn: Button
@export var export_dialog: FileDialog

# Cache the results so the exporter can access them later
var _latest_results: Array[Dictionary] = []

# --- INTERNAL STATE ---
var available_strategies: Array[GraphStrategy] = []
var _current_schema: Dictionary = {}
var _input_refs: Dictionary = {} 
var _current_runner: ExperimentRunner
var _warning_dialog: ConfirmationDialog
var _pending_combinations: Array[Dictionary] = []

func _ready() -> void:
	if run_button: run_button.pressed.connect(_on_run_pressed)
	if strategy_dropdown: strategy_dropdown.item_selected.connect(_on_strategy_selected)
	
	if progress_bar: progress_bar.value = 0
	if status_label: status_label.text = "Ready to build experiment."
	
	if export_btn: 
		export_btn.pressed.connect(_on_export_pressed)
		export_btn.disabled = true
	if export_dialog:
		export_dialog.file_selected.connect(_on_export_file_selected)
	
	
	# INITIALIZE IN CODE (Mirrors StrategyController)
	available_strategies.append(StrategyGrid.new())
	available_strategies.append(StrategyWalker.new()) 
	available_strategies.append(StrategyMST.new())
	available_strategies.append(StrategyDLA.new())
	available_strategies.append(StrategyCA.new())
	available_strategies.append(StrategyPolar.new()) 
	available_strategies.append(StrategyAnalyze.new())
	available_strategies.append(StrategyGrammar.new())
	available_strategies.append(StrategyDAG.new())
	
	# Setup the dynamic warning dialog
	_warning_dialog = ConfirmationDialog.new()
	_warning_dialog.dialog_text = "Warning: large sweep detected."
	_warning_dialog.get_ok_button().text = "Run Anyway"
	_warning_dialog.confirmed.connect(_start_experiment)
	add_child(_warning_dialog)
	
	_populate_dropdown()

func _populate_dropdown() -> void:
	if not strategy_dropdown: return
	strategy_dropdown.clear()
	
	for i in range(available_strategies.size()):
		strategy_dropdown.add_item(available_strategies[i].strategy_name, i)
		
	if available_strategies.size() > 0:
		_on_strategy_selected(0)

func _on_strategy_selected(index: int) -> void:
	if index < 0 or index >= available_strategies.size(): return
	
	# We can just read the schema directly from the instantiated strategy!
	var selected_strategy = available_strategies[index]
	_current_schema = ExperimentBuilder.get_sweep_schema(selected_strategy.get_script())
	
	_build_ui_from_schema()

func _build_ui_from_schema() -> void:
	if not settings_container: return
	
	# Clear previous UI
	for child in settings_container.get_children():
		child.queue_free()
		
	_input_refs.clear()
	
	for key in _current_schema:
		var config = _current_schema[key]
		var row = _create_sweep_row(key, config)
		settings_container.add_child(row)

func _create_sweep_row(key: String, config: Dictionary) -> Control:
	var row = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var label = Label.new()
	label.text = config["label"]
	label.custom_minimum_size = Vector2(150, 0)
	row.add_child(label)
	
	var is_enum = config.get("is_enum", false)
	var refs = { "type": config["type"], "mode": "fixed", "is_enum": is_enum }
	var can_sweep = (config["type"] == TYPE_INT or config["type"] == TYPE_FLOAT) or is_enum
	
	var sweep_toggle = CheckBox.new()
	sweep_toggle.text = "Sweep"
	sweep_toggle.disabled = not can_sweep
	row.add_child(sweep_toggle)
	refs["toggle"] = sweep_toggle
	
	# --- FIXED INPUT CONTAINER ---
	var fixed_box = HBoxContainer.new()
	fixed_box.add_child(Label.new()); fixed_box.get_child(0).text = "Value:"
	
	var val_input
	if is_enum:
		val_input = OptionButton.new()
		for opt in config["options"]: val_input.add_item(opt)
		val_input.selected = int(config["value"])
	else:
		val_input = _create_input_for_type(config["type"], config["value"])
		
	fixed_box.add_child(val_input)
	row.add_child(fixed_box)
	refs["fixed_input"] = val_input
	
	# --- SWEEP INPUT CONTAINER ---
	var sweep_box = HBoxContainer.new()
	sweep_box.hide()
	
	if is_enum:
		# Use HFlowContainer so checklists wrap neatly to the next line if they are long
		var check_container = HFlowContainer.new()
		check_container.custom_minimum_size = Vector2(300, 0)
		var checkboxes = []
		for i in range(config["options"].size()):
			var chk = CheckBox.new()
			var opt_text = config["options"][i]
			chk.text = opt_text if opt_text != "" else "None"
			chk.button_pressed = (i == config["value"]) # Default check the currently active one
			check_container.add_child(chk)
			checkboxes.append(chk)
			
		sweep_box.add_child(check_container)
		refs["enum_checkboxes"] = checkboxes
	else:
		var min_input = _create_input_for_type(config["type"], config.get("min", 0))
		var max_input = _create_input_for_type(config["type"], config.get("max", 10))
		var step_input = _create_input_for_type(config["type"], config.get("step", 1))
		
		sweep_box.add_child(Label.new()); sweep_box.get_child(0).text = "Min:"
		sweep_box.add_child(min_input)
		sweep_box.add_child(Label.new()); sweep_box.get_child(2).text = "Max:"
		sweep_box.add_child(max_input)
		sweep_box.add_child(Label.new()); sweep_box.get_child(4).text = "Step:"
		sweep_box.add_child(step_input)
		
		refs["min_input"] = min_input
		refs["max_input"] = max_input
		refs["step_input"] = step_input
	
	row.add_child(sweep_box)
	
	# --- TOGGLE LOGIC ---
	sweep_toggle.toggled.connect(func(is_pressed: bool):
		if is_pressed:
			fixed_box.hide()
			sweep_box.show()
			refs["mode"] = "sweep"
		else:
			fixed_box.show()
			sweep_box.hide()
			refs["mode"] = "fixed"
	)
	
	_input_refs[key] = refs
	return row

func _create_input_for_type(type: int, default_val: Variant) -> Control:
	if type == TYPE_INT or type == TYPE_FLOAT:
		var spin = SpinBox.new()
		spin.min_value = -99999.0
		spin.max_value = 99999.0
		spin.step = 1.0 if type == TYPE_INT else 0.05
		spin.value = float(default_val)
		return spin
	elif type == TYPE_BOOL:
		var chk = CheckBox.new()
		chk.button_pressed = bool(default_val)
		return chk
	else:
		var txt = LineEdit.new()
		txt.text = str(default_val)
		return txt

# ==============================================================================
# DATA EXTRACTION & EXECUTION
# ==============================================================================

func _on_run_pressed() -> void:
	# CANCELLATION LOGIC
	if _current_runner != null and _current_runner.is_running:
		status_label.text = "Cancelling experiment... (Waiting for active threads to finish)"
		run_button.disabled = true # Prevent double-clicking cancel
		_current_runner.cancel()
		return
		
	if strategy_dropdown.selected < 0: return
	
	var sweep_def = {}
	for key in _input_refs:
		var refs = _input_refs[key]
		var is_enum = refs.get("is_enum", false)
		var param_def = { "type": refs["type"], "mode": refs["mode"], "is_enum": is_enum }
		
		if refs["mode"] == "fixed":
			if is_enum:
				param_def["value"] = refs["fixed_input"].selected
			else:
				param_def["value"] = _get_control_value(refs["fixed_input"], refs["type"])
		else:
			if is_enum:
				var selections = []
				var chks = refs["enum_checkboxes"]
				for i in range(chks.size()):
					if chks[i].button_pressed:
						selections.append(i)
				param_def["enum_selection"] = selections
			else:
				param_def["min"] = _get_control_value(refs["min_input"], refs["type"])
				param_def["max"] = _get_control_value(refs["max_input"], refs["type"])
				param_def["step"] = _get_control_value(refs["step_input"], refs["type"])
				
		sweep_def[key] = param_def
		
	var combinations = ExperimentBuilder.generate_combinations(sweep_def)
	_pending_combinations = combinations
	
	# WARNING LOGIC
	if combinations.size() > 1000:
		_warning_dialog.dialog_text = "Warning: You are about to execute %d procedural generations.\n\nThis will heavily utilize your CPU and may take significant time to complete.\n\nDo you want to proceed?" % combinations.size()
		_warning_dialog.popup_centered()
	else:
		_start_experiment()

# Dedicated start function called normally OR by the warning dialog confirmation
func _start_experiment() -> void:
	var strategy_script = available_strategies[strategy_dropdown.selected].get_script()
	
	status_label.text = "Running %d experiments..." % _pending_combinations.size()
	
	# Transform the Run button into a Cancel button
	run_button.text = "Cancel Experiment"
	run_button.modulate = Color(1.0, 0.4, 0.4) # Make it red for danger
	
	_current_runner = ExperimentRunner.new()
	_current_runner.progress_updated.connect(_on_progress_updated)
	_current_runner.experiment_finished.connect(_on_experiment_finished)
	
	_current_runner.run_batch(strategy_script, _pending_combinations)

func _on_progress_updated(completed: int, total: int) -> void:
	if progress_bar:
		progress_bar.max_value = total
		progress_bar.value = completed
	status_label.text = "Processing: %d / %d" % [completed, total]

func _on_experiment_finished(results: Array[Dictionary]) -> void:
	# Reset the Run/Cancel button
	run_button.text = "Run Experiment"
	run_button.modulate = Color.WHITE
	run_button.disabled = false
	
	# Let the user know if they aborted
	if _current_runner != null and _current_runner._cancel_flag:
		status_label.text = "Experiment aborted. Retrieved %d completed graphs." % results.size()
	else:
		status_label.text = "Experiment complete! Analyzed %d graphs." % results.size()
	
	if results.size() > 0:
		_latest_results = results
		if export_btn: export_btn.disabled = false
		_populate_results_table(results)

func _get_control_value(ctrl: Control, type: int) -> Variant:
	if ctrl is SpinBox:
		return int(ctrl.value) if type == TYPE_INT else ctrl.value
	elif ctrl is CheckBox:
		return ctrl.button_pressed
	elif ctrl is LineEdit:
		return ctrl.text
	return null

# ==============================================================================
# DASHBOARD & EXPORT
# ==============================================================================

func _populate_results_table(results: Array[Dictionary]) -> void:
	if not results_table or results.is_empty(): return
	
	results_table.clear()
	
	var first_row = results[0]
	var p_keys = first_row["params"].keys()
	var m_keys = first_row["metrics"].keys()
	
	# 1. Setup Columns (1 for ID, + Params, + Metrics)
	var total_cols = 1 + p_keys.size() + m_keys.size()
	results_table.columns = total_cols
	results_table.set_column_titles_visible(true)
	
	# Build Headers
	results_table.set_column_title(0, "ID")
	var col_idx = 1
	for k in p_keys:
		results_table.set_column_title(col_idx, k)
		col_idx += 1
	for k in m_keys:
		results_table.set_column_title(col_idx, k.capitalize())
		col_idx += 1
		
	# 2. Populate Data
	var root = results_table.create_item()
	results_table.hide_root = true
	
	for row in results:
		var item = results_table.create_item(root)
		item.set_text(0, str(row["run_id"]))
		
		col_idx = 1
		for k in p_keys:
			var val = row["params"].get(k, "")
			# Format floats cleanly for the UI
			if val is float: val = "%.2f" % val
			item.set_text(col_idx, str(val))
			# Make parameter columns slightly dimmer to separate them from metrics visually
			item.set_custom_color(col_idx, Color(0.7, 0.7, 0.7)) 
			col_idx += 1
			
		for k in m_keys:
			var val = row["metrics"].get(k, 0)
			if val is float: val = "%.2f" % val
			item.set_text(col_idx, str(val))
			col_idx += 1

func _on_export_pressed() -> void:
	if _latest_results.is_empty() or not export_dialog: return
	
	export_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	export_dialog.title = "Export Experiment Data"
	export_dialog.filters = ["*.csv ; CSV Data File"]
	export_dialog.popup_centered()

func _on_export_file_selected(path: String) -> void:
	if not path.ends_with(".csv"): path += ".csv"
	
	var csv_data = GraphSerializer.export_experiment_csv(_latest_results)
	var file = FileAccess.open(path, FileAccess.WRITE)
	
	if file:
		file.store_string(csv_data)
		file.close()
		status_label.text = "Exported %d rows to CSV!" % _latest_results.size()
	else:
		status_label.text = "Error saving CSV to disk!"
