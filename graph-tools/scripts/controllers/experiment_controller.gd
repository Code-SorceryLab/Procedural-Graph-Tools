class_name ExperimentController
extends Node

# --- UI REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor

@export_group("UI Elements")
@export var strategy_dropdown: OptionButton # (Will be dynamically hidden)
@export var settings_container: VBoxContainer
@export var run_button: Button
@export var progress_bar: ProgressBar
@export var status_label: Label

@export_group("Popup Triggers")
@export var metrics_btn: Button      
@export var view_results_btn: Button 
@export var export_dialog: FileDialog

# --- INTERNAL STATE ---
var available_modifiers: Array[Script] = GraphSettings.available_modifiers
var _active_pipeline: Array[GraphModifier] = []

var _latest_results: Array[Dictionary] = []
var _current_schema: Dictionary = {}
var _input_refs: Dictionary = {} 
var _current_runner: ExperimentRunner

var _warning_dialog: ConfirmationDialog
var _metrics_popup: AlgorithmSettingsPopup
var _results_popup: AcceptDialog
var _results_table: Tree
var _metrics_config: Dictionary = {}
var _pending_combinations: Array[Dictionary] = []

# Dynamic UI
var _btn_load_pipeline: Button
var _pipeline_dialog: FileDialog

func _ready() -> void:
	if run_button: run_button.pressed.connect(_on_run_pressed)
	if progress_bar: progress_bar.value = 0
	if status_label: status_label.text = "Load a Pipeline Recipe to build an experiment."
	
	if view_results_btn: 
		view_results_btn.disabled = true
		view_results_btn.pressed.connect(func(): _results_popup.popup_centered())
		
	if export_dialog: export_dialog.file_selected.connect(_on_export_file_selected)
		
	# Load default metrics
	for def in GraphMetrics.get_analysis_options_schema():
		_metrics_config[def.name] = def.get("default")
	
	_setup_popups()
	_setup_pipeline_loader()

func _setup_pipeline_loader() -> void:
	# Hide the legacy dropdown
	if strategy_dropdown: strategy_dropdown.visible = false
	
	_btn_load_pipeline = Button.new()
	_btn_load_pipeline.text = "📂 Load Pipeline Recipe"
	_btn_load_pipeline.pressed.connect(_on_load_pipeline_pressed)
	
	# Insert it where the dropdown used to be
	if strategy_dropdown and strategy_dropdown.get_parent():
		strategy_dropdown.get_parent().add_child(_btn_load_pipeline)
		strategy_dropdown.get_parent().move_child(_btn_load_pipeline, strategy_dropdown.get_index())
		
	_pipeline_dialog = FileDialog.new()
	_pipeline_dialog.access = FileDialog.ACCESS_FILESYSTEM
	_pipeline_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	_pipeline_dialog.add_filter("*.json", "Pipeline Preset")
	_pipeline_dialog.file_selected.connect(_on_pipeline_file_selected)
	_pipeline_dialog.set("use_native_dialog", true)
	add_child(_pipeline_dialog)

# ==============================================================================
# PIPELINE LOADING & UI GENERATION
# ==============================================================================

func _on_load_pipeline_pressed() -> void:
	if _current_runner != null and _current_runner.is_running: return
	_pipeline_dialog.popup_centered_ratio(0.5)

func _on_pipeline_file_selected(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return
	var json_str = file.get_as_text()
	file.close()
	
	_active_pipeline = GraphSerializer.deserialize_pipeline(json_str, available_modifiers)
	
	if _active_pipeline.is_empty():
		status_label.text = "Error: Invalid or empty pipeline preset."
		return
		
	_btn_load_pipeline.text = "Pipeline: " + path.get_file()
	status_label.text = "Loaded Pipeline with %d stages. Select sweep parameters." % _active_pipeline.size()
	_build_ui_from_pipeline()

func _build_ui_from_pipeline() -> void:
	if not settings_container: return
	for child in settings_container.get_children(): child.queue_free()
	_input_refs.clear()
	_current_schema.clear()
	
	for i in range(_active_pipeline.size()):
		var mod = _active_pipeline[i]
		
		# Add a beautiful header for this modifier
		var header = Label.new()
		header.text = "▼ [%d] %s" % [i + 1, mod.modifier_name]
		header.add_theme_color_override("font_color", Color(0.4, 0.8, 1.0))
		settings_container.add_child(header)
		settings_container.add_child(HSeparator.new())
		
		var raw_settings = mod.get_settings()
		var namespaced_settings = []
		
		# Namespace the keys so multiple modifiers don't overwrite each other's parameters
		for s in raw_settings:
			var new_s = s.duplicate(true)
			var original_name = new_s.get("name", "")
			if original_name == "" or original_name.begins_with("sep_") or new_s.get("hint") == "action": 
				continue
				
			var namespaced_key = "mod_%d_%s" % [i, original_name]
			new_s["name"] = namespaced_key
			
			# Inject the preset's value as the default!
			if mod.local_settings.has(original_name):
				new_s["default"] = mod.local_settings[original_name]
				
			namespaced_settings.append(new_s)
			
		var mod_schema = ExperimentBuilder.get_sweep_schema(namespaced_settings)
		_current_schema.merge(mod_schema, true)
		
		for key in mod_schema:
			var config = mod_schema[key]
			var row = _create_sweep_row(key, config)
			settings_container.add_child(row)

# ==============================================================================
# POPUP CONSTRUCTION
# ==============================================================================
func _setup_popups() -> void:
	# 1. Warning Dialog
	_warning_dialog = ConfirmationDialog.new()
	_warning_dialog.dialog_text = "Warning: large sweep detected."
	_warning_dialog.get_ok_button().text = "Run Anyway"
	_warning_dialog.confirmed.connect(_start_experiment)
	add_child(_warning_dialog)
	
	# 2. Metrics Popup (Using your existing class!)
	_metrics_popup = AlgorithmSettingsPopup.new()
	_metrics_popup.settings_confirmed.connect(func(new_settings): _metrics_config = new_settings)
	add_child(_metrics_popup)
	
	if metrics_btn:
		metrics_btn.pressed.connect(func(): 
			_metrics_popup.open_settings("Advanced Metrics", GraphMetrics.get_analysis_options_schema(), _metrics_config)
		)
		
	# 3. Results Dashboard Popup (Dynamically Built)
	_results_popup = AcceptDialog.new()
	_results_popup.title = "Experiment Dashboard"
	_results_popup.size = Vector2(900, 600)
	_results_popup.get_ok_button().text = "Close"
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_results_popup.add_child(vbox)
	
	_results_table = Tree.new()
	_results_table.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Listen for double-clicks on the table rows!
	_results_table.item_activated.connect(_on_result_row_double_clicked)
	
	vbox.add_child(_results_table)
	
	var export_btn = Button.new()
	export_btn.text = "Export to CSV"
	export_btn.custom_minimum_size = Vector2(0, 40)
	export_btn.pressed.connect(_on_export_pressed)
	vbox.add_child(export_btn)
	
	add_child(_results_popup)

# ==============================================================================
# UI GENERATION
# ==============================================================================


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
		
		# Safely fallback to 0 if default_val is null
		spin.value = float(default_val) if default_val != null else 0.0
		return spin
		
	elif type == TYPE_BOOL:
		var chk = CheckBox.new()
		
		# Safely fallback to false if default_val is null
		# In Godot 4, we must explicitly check for null before casting to bool
		chk.button_pressed = default_val if (default_val != null and typeof(default_val) == TYPE_BOOL) else false
		return chk
		
	else:
		var txt = LineEdit.new()
		txt.text = str(default_val) if default_val != null else ""
		return txt

# ==============================================================================
# DATA EXTRACTION & EXECUTION
# ==============================================================================

func _on_run_pressed() -> void:
	if _current_runner != null and _current_runner.is_running:
		status_label.text = "Cancelling experiment... (Waiting for active threads to finish)"
		run_button.disabled = true 
		_current_runner.cancel()
		return
		
	if _active_pipeline.is_empty(): return
	
	var sweep_def = {}
	for key in _input_refs:
		var refs = _input_refs[key]
		var is_enum = refs.get("is_enum", false)
		var param_def = { "type": refs["type"], "mode": refs["mode"], "is_enum": is_enum }
		
		if refs["mode"] == "fixed":
			if is_enum: param_def["value"] = refs["fixed_input"].selected
			else: param_def["value"] = _get_control_value(refs["fixed_input"], refs["type"])
		else:
			if is_enum:
				var selections = []
				var chks = refs["enum_checkboxes"]
				for i in range(chks.size()):
					if chks[i].button_pressed: selections.append(i)
				param_def["enum_selection"] = selections
			else:
				param_def["min"] = _get_control_value(refs["min_input"], refs["type"])
				param_def["max"] = _get_control_value(refs["max_input"], refs["type"])
				param_def["step"] = _get_control_value(refs["step_input"], refs["type"])
				
		sweep_def[key] = param_def
		
	var combinations = ExperimentBuilder.generate_combinations(sweep_def)
	for comb in combinations: comb.merge(_metrics_config, true)
	_pending_combinations = combinations
	
	if combinations.size() > 1000:
		_warning_dialog.dialog_text = "Warning: Executing %d pipelines across multiple threads.\nDo you want to proceed?" % combinations.size()
		_warning_dialog.popup_centered()
	else:
		_start_experiment()

# Dedicated start function called normally OR by the warning dialog confirmation
func _start_experiment() -> void:
	status_label.text = "Running %d experiments..." % _pending_combinations.size()
	run_button.text = "Cancel Experiment"
	run_button.modulate = Color(1.0, 0.4, 0.4)
	
	# Pre-register semantic fields on the main thread.
	GraphModifier.preregister_semantics(_active_pipeline)
	
	_current_runner = ExperimentRunner.new()
	_current_runner.progress_updated.connect(_on_progress_updated)
	_current_runner.experiment_finished.connect(_on_experiment_finished)
	
	# Pass the active pipeline instead of a single script!
	_current_runner.run_batch(_active_pipeline, _pending_combinations)

func _on_progress_updated(completed: int, total: int) -> void:
	if progress_bar:
		progress_bar.max_value = total
		progress_bar.value = completed
	status_label.text = "Processing: %d / %d" % [completed, total]

func _on_experiment_finished(results: Array[Dictionary]) -> void:
	run_button.text = "Run Experiment"
	run_button.modulate = Color.WHITE
	run_button.disabled = false
	
	if _current_runner != null and _current_runner._cancel_flag:
		status_label.text = "Experiment aborted. Retrieved %d completed graphs." % results.size()
	else:
		status_label.text = "Experiment complete! Analyzed %d graphs." % results.size()
	
	if results.size() > 0:
		_latest_results = results
		if view_results_btn: view_results_btn.disabled = false
		_populate_results_table(results)

func _get_control_value(ctrl: Control, type: int) -> Variant:
	if ctrl is SpinBox: return int(ctrl.value) if type == TYPE_INT else ctrl.value
	elif ctrl is CheckBox: return ctrl.button_pressed
	elif ctrl is LineEdit: return ctrl.text
	return null

# ==============================================================================
# DASHBOARD & EXPORT
# ==============================================================================
func _populate_results_table(results: Array[Dictionary]) -> void:
	if not _results_table or results.is_empty(): return
	
	_results_table.clear()
	var first_row = results[0]
	var p_keys = first_row["params"].keys()
	var m_keys = first_row["metrics"].keys()
	
	# Filter out the metrics config from the params list so they don't bloat the CSV/Table
	var filtered_p_keys = []
	for k in p_keys:
		if not _metrics_config.has(k): filtered_p_keys.append(k)
	
	var total_cols = 1 + filtered_p_keys.size() + m_keys.size()
	_results_table.columns = total_cols
	_results_table.set_column_titles_visible(true)
	
	_results_table.set_column_title(0, "ID")
	var col_idx = 1
	for k in filtered_p_keys:
		_results_table.set_column_title(col_idx, k)
		col_idx += 1
	for k in m_keys:
		_results_table.set_column_title(col_idx, k.capitalize())
		col_idx += 1
		
	var root = _results_table.create_item()
	_results_table.hide_root = true
	
	for row in results:
		var item = _results_table.create_item(root)
		item.set_text(0, str(row["run_id"]))
		
		col_idx = 1
		for k in filtered_p_keys:
			var val = row["params"].get(k, "")
			if val is float: val = "%.2f" % val
			item.set_text(col_idx, str(val))
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


# ==============================================================================
# VISUALIZATION MAPPING
# ==============================================================================
func _on_result_row_double_clicked() -> void:
	if not graph_editor or _active_pipeline.is_empty(): return
	var selected_item = _results_table.get_selected()
	if not selected_item: return
	
	var run_id_str = selected_item.get_text(0)
	if run_id_str == "": return
	var run_id = int(run_id_str)
	var target_result = null
	
	for res in _latest_results:
		if res["run_id"] == run_id:
			target_result = res
			break
			
	if not target_result: return
	_results_popup.hide()
	
	var params = target_result["params"].duplicate()
	status_label.text = "Visualizing Run ID %d..." % run_id
	
	# Re-create the pipeline explicitly for visualization
	graph_editor.start_undo_transaction("Visualize Experiment")
	graph_editor.clear_graph()
	var graph = graph_editor.graph
	
	for i in range(_active_pipeline.size()):
		var template = _active_pipeline[i]
		var mod = template.get_script().new() as GraphModifier
		mod.local_settings = template.local_settings.duplicate(true)
		
		# Inject the specific swept values
		for k in params.keys():
			var prefix = "mod_%d_" % i
			if k.begins_with(prefix):
				var real_key = k.substr(prefix.length())
				mod.local_settings[real_key] = params[k]
				
		# Execute
		var recorder = GraphRecorder.new(graph)
		mod.execute(recorder)
		var batch = CmdBatch.new(graph, mod.modifier_name, false)
		for cmd in recorder.recorded_commands: batch.add_command(cmd)
		if batch.get_command_count() > 0: graph_editor._commit_command(batch)
		
	graph_editor.commit_undo_transaction()
	GraphValidator.validate(graph, true)
	graph_editor.mark_modified()
	graph_editor.request_redraw()
	graph_editor._center_camera_on_graph()
