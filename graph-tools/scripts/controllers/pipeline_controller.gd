class_name PipelineController
extends Node

# --- STATIC INSTANCE ---
static var instance: PipelineController
func _enter_tree() -> void: if instance == null: instance = self
func _exit_tree() -> void: if instance == self: instance = null

# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor
@export var ui_container: VBoxContainer

# --- PIPELINE STATE ---
var available_modifiers: Array[Script] = [] 
var modifier_stack: Array[GraphModifier] = [] 
var selected_stack_index: int = -1

# --- THREADING STATE ---
var _pipeline_active: bool = false
var _current_mod_index: int = 0
var _current_task_id: int = -1
var _active_recorder: GraphRecorder
var _step_start_time: int
var _total_start_time: int
var _profiling_log: String = ""

# --- UI REFERENCES ---
var _add_dropdown: OptionButton
var _stack_list: ItemList
var _settings_container: VBoxContainer
var _active_inputs: Dictionary = {}
var _palette_popup: AlgorithmSettingsPopup

var _btn_run: Button
var _btn_clear: Button
var _progress_bar: ProgressBar
var _status_label: Label

func _ready() -> void:
	available_modifiers.append(GenerateGrid) 
	available_modifiers.append(GeneratePolar)
	available_modifiers.append(GenerateDAG)
	
	available_modifiers.append(MutateDLA)
	available_modifiers.append(MutateMST)
	available_modifiers.append(MutateBraid)
	available_modifiers.append(MutateCA)
	available_modifiers.append(MutateFlowDirect)
	available_modifiers.append(MutateWalker)
	available_modifiers.append(MutateGrammar)

	available_modifiers.append(GeoJitter)
	available_modifiers.append(GeoRelaxBuoyancy)
	
	available_modifiers.append(SemanticBiomeFill)
	available_modifiers.append(SemanticDAGLocks)
	available_modifiers.append(SemanticLogicGates)
	
	_palette_popup = AlgorithmSettingsPopup.new()
	add_child(_palette_popup)
	_palette_popup.settings_confirmed.connect(_on_palette_popup_confirmed)
	
	_build_pipeline_ui()
	_refresh_stack_ui()

# ==============================================================================
# UI GENERATION
# ==============================================================================
func _build_pipeline_ui() -> void:
	if not ui_container: return
	
	# 1. MACRO CONTROLS
	var macro_hbox = HBoxContainer.new()
	_btn_run = Button.new()
	_btn_run.text = "▶ RUN PIPELINE"
	_btn_run.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_run.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
	_btn_run.pressed.connect(_on_run_pipeline_pressed)
	
	_btn_clear = Button.new()
	_btn_clear.text = "Clear Graph"
	_btn_clear.pressed.connect(func(): if not _pipeline_active: graph_editor.clear_graph())
	
	macro_hbox.add_child(_btn_run)
	macro_hbox.add_child(_btn_clear)
	ui_container.add_child(macro_hbox)
	
	# PROGRESS & STATUS UI
	_progress_bar = ProgressBar.new()
	_progress_bar.visible = false
	_progress_bar.custom_minimum_size.y = 15
	ui_container.add_child(_progress_bar)
	
	_status_label = Label.new()
	_status_label.text = "Pipeline Ready."
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status_label.add_theme_font_size_override("font_size", 12)
	ui_container.add_child(_status_label)
	
	ui_container.add_child(HSeparator.new())
	
	# 2. ADD MODIFIER BAR
	var add_hbox = HBoxContainer.new()
	_add_dropdown = OptionButton.new()
	_add_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for script in available_modifiers:
		var temp = script.new()
		_add_dropdown.add_item(temp.modifier_name)
		
	var btn_add = Button.new()
	btn_add.text = "Add"
	btn_add.pressed.connect(_on_add_modifier_pressed)
	
	add_hbox.add_child(_add_dropdown)
	add_hbox.add_child(btn_add)
	ui_container.add_child(add_hbox)
	
	# 3. THE STACK LIST
	_stack_list = ItemList.new()
	_stack_list.custom_minimum_size.y = 150
	_stack_list.item_selected.connect(_on_stack_item_selected)
	ui_container.add_child(_stack_list)
	
	# 4. STACK CONTROLS
	var ctrl_hbox = HBoxContainer.new()
	var btn_up = Button.new(); btn_up.text = "▲ Up"
	var btn_down = Button.new(); btn_down.text = "▼ Down"
	var btn_del = Button.new(); btn_del.text = "✖ Delete"
	
	btn_up.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_down.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_del.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	btn_up.pressed.connect(_on_move_up_pressed)
	btn_down.pressed.connect(_on_move_down_pressed)
	btn_del.pressed.connect(_on_delete_pressed)
	
	ctrl_hbox.add_child(btn_up)
	ctrl_hbox.add_child(btn_down)
	ctrl_hbox.add_child(btn_del)
	ui_container.add_child(ctrl_hbox)
	ui_container.add_child(HSeparator.new())
	
	# 5. MODIFIER SETTINGS AREA
	_settings_container = VBoxContainer.new()
	ui_container.add_child(_settings_container)

# ==============================================================================
# PIPELINE MANAGEMENT
# ==============================================================================

func _on_add_modifier_pressed() -> void:
	if _pipeline_active or available_modifiers.is_empty(): return
	var idx = _add_dropdown.selected
	if idx < 0: return
	
	var new_mod = available_modifiers[idx].new() as GraphModifier
	new_mod.apply_defaults()
	
	modifier_stack.append(new_mod)
	_refresh_stack_ui()
	_on_stack_item_selected(modifier_stack.size() - 1)

func _refresh_stack_ui() -> void:
	_stack_list.clear()
	for i in range(modifier_stack.size()):
		var mod = modifier_stack[i]
		var prefix = ""
		match mod.category:
			GraphModifier.Category.GENERATOR: prefix = "[GEN] "
			GraphModifier.Category.TOPOLOGY: prefix = "[TOP] "
			GraphModifier.Category.GEOMETRY: prefix = "[GEO] "
			GraphModifier.Category.SEMANTIC: prefix = "[SEM] "
			
		_stack_list.add_item(prefix + mod.modifier_name)
		
	if selected_stack_index >= 0 and selected_stack_index < modifier_stack.size():
		_stack_list.select(selected_stack_index)
	else:
		_clear_settings_ui()

func _on_move_up_pressed() -> void:
	if _pipeline_active: return
	if selected_stack_index > 0:
		var temp = modifier_stack[selected_stack_index]
		modifier_stack[selected_stack_index] = modifier_stack[selected_stack_index - 1]
		modifier_stack[selected_stack_index - 1] = temp
		selected_stack_index -= 1
		_refresh_stack_ui()

func _on_move_down_pressed() -> void:
	if _pipeline_active: return
	if selected_stack_index >= 0 and selected_stack_index < modifier_stack.size() - 1:
		var temp = modifier_stack[selected_stack_index]
		modifier_stack[selected_stack_index] = modifier_stack[selected_stack_index + 1]
		modifier_stack[selected_stack_index + 1] = temp
		selected_stack_index += 1
		_refresh_stack_ui()

func _on_delete_pressed() -> void:
	if _pipeline_active: return
	if selected_stack_index >= 0:
		modifier_stack.remove_at(selected_stack_index)
		selected_stack_index = -1
		_refresh_stack_ui()

func _on_stack_item_selected(index: int) -> void:
	selected_stack_index = index
	_stack_list.select(index)
	_build_settings_ui_for_modifier(modifier_stack[index])

func _clear_settings_ui() -> void:
	for child in _settings_container.get_children(): child.queue_free()
	_active_inputs.clear()

func _build_settings_ui_for_modifier(modifier: GraphModifier) -> void:
	_clear_settings_ui()
	
	var header = Label.new()
	header.text = "--- " + modifier.modifier_name + " Settings ---"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_container.add_child(header)
	
	var schema = modifier.get_settings()
	for setting in schema:
		if modifier.local_settings.has(setting["name"]):
			setting["default"] = modifier.local_settings[setting["name"]]
			
	_active_inputs = SettingsUIBuilder.build_ui(schema, _settings_container)
	SettingsUIBuilder.connect_live_updates(_active_inputs, _on_live_setting_changed)

func _on_live_setting_changed(key: String, value: Variant) -> void:
	if selected_stack_index >= 0 and selected_stack_index < modifier_stack.size():
		var active_mod = modifier_stack[selected_stack_index]
		if key == "btn_biome_palette":
			if active_mod.has_method("get_palette_schema"):
				var schema = active_mod.get_palette_schema()
				_palette_popup.open_settings(active_mod.modifier_name + " Details", schema, active_mod.local_settings)
			return
		active_mod.local_settings[key] = value

func _on_palette_popup_confirmed(new_settings: Dictionary) -> void:
	if selected_stack_index >= 0 and selected_stack_index < modifier_stack.size():
		var active_mod = modifier_stack[selected_stack_index]
		active_mod.local_settings.merge(new_settings, true)

# ==============================================================================
# TRUE MULTITHREADED EXECUTION
# ==============================================================================

func _on_run_pipeline_pressed() -> void:
	if modifier_stack.is_empty() or _pipeline_active: return
	
	_pipeline_active = true
	_btn_run.disabled = true
	_btn_clear.disabled = true
	
	_progress_bar.visible = true
	_progress_bar.max_value = modifier_stack.size()
	_progress_bar.value = 0
	
	_profiling_log = ""
	_total_start_time = Time.get_ticks_msec()
	
	# HIDE GRAPH TO PREVENT CRASHES AND FLICKERING DURING CALCULATION
	if graph_editor.renderer:
		graph_editor.renderer.visible = false
		
	print("\n========== PIPELINE START ==========")
	graph_editor.start_undo_transaction("Run Pipeline")
	
	_current_mod_index = 0
	_start_next_modifier()

func _start_next_modifier() -> void:
	if _current_mod_index >= modifier_stack.size():
		_finish_pipeline()
		return
		
	var mod = modifier_stack[_current_mod_index]
	_status_label.text = "Executing [%d/%d]: %s..." % [_current_mod_index + 1, modifier_stack.size(), mod.modifier_name]
	
	var graph = graph_editor.graph
	
	# 1. FAST SYNCHRONOUS WIPE (Generators only)
	if mod.category == GraphModifier.Category.GENERATOR:
		var clear_batch = CmdBatch.new(graph, "Clear Graph", false)
		for id in graph.nodes.keys():
			clear_batch.add_command(CmdDeleteNode.new(graph, id))
		for z in graph.zones.duplicate():
			clear_batch.add_command(CmdRemoveZone.new(graph, z))
		if clear_batch.get_command_count() > 0:
			graph_editor._commit_command(clear_batch)
			
	# 2. SETUP SANDBOX
	_active_recorder = GraphRecorder.new(graph)
	_step_start_time = Time.get_ticks_msec()
	
	# 3. DISPATCH HEAVY MATH TO BACKGROUND THREAD
	_current_task_id = WorkerThreadPool.add_task(_thread_execute_modifier.bind(mod, _active_recorder), true, "Pipeline Mod")

# This function runs isolated on a background CPU core!
func _thread_execute_modifier(mod: GraphModifier, recorder: GraphRecorder) -> void:
	mod.execute(recorder)

func _process(_delta: float) -> void:
	# Poll for background task completion to keep the UI perfectly responsive
	if not _pipeline_active or _current_task_id == -1: return
	
	if WorkerThreadPool.is_task_completed(_current_task_id):
		# Safely close the thread
		WorkerThreadPool.wait_for_task_completion(_current_task_id)
		_current_task_id = -1
		
		var mod = modifier_stack[_current_mod_index]
		var elapsed = Time.get_ticks_msec() - _step_start_time
		_profiling_log += "%s: %d ms\n" % [mod.modifier_name, elapsed]
		print("[%d/%d] %s (%d ms)" % [_current_mod_index + 1, modifier_stack.size(), mod.modifier_name, elapsed])
		
		# FAST SYNCHRONOUS COMMIT: Push changes to Undo Stack & Live Graph Memory
		var mod_batch = CmdBatch.new(graph_editor.graph, mod.modifier_name, false)
		for cmd in _active_recorder.recorded_commands:
			mod_batch.add_command(cmd)
		if mod_batch.get_command_count() > 0:
			graph_editor._commit_command(mod_batch)
			
		_current_mod_index += 1
		_progress_bar.value = _current_mod_index
		
		# Fire next step!
		_start_next_modifier()

func _finish_pipeline() -> void:
	# 1. Close out the Undo Stack
	graph_editor.commit_undo_transaction()
	GraphValidator.validate(graph_editor.graph, true) 
	
	# 2. Reveal Graph and Redraw
	if graph_editor.renderer:
		graph_editor.renderer.visible = true
		
	graph_editor.mark_modified()
	graph_editor.request_redraw()
	graph_editor._center_camera_on_graph()
	graph_editor.set_selection_batch([], [], true) 
	
	var total_time = Time.get_ticks_msec() - _total_start_time
	_status_label.text = "Pipeline Complete! (%d ms)\n%s" % [total_time, _profiling_log]
	
	# 3. Unlock UI
	_pipeline_active = false
	_progress_bar.visible = false
	_btn_run.disabled = false
	_btn_clear.disabled = false
	print("========== PIPELINE COMPLETE (%d ms) ==========\n" % total_time)
