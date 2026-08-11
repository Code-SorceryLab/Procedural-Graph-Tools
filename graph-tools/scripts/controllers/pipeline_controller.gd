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
var available_modifiers: Array[Script] = [] # The catalog of all written modifier scripts
var modifier_stack: Array[GraphModifier] = [] # The active pipeline
var selected_stack_index: int = -1

# --- UI REFERENCES (Built Programmatically) ---
var _add_dropdown: OptionButton
var _stack_list: ItemList
var _settings_container: VBoxContainer
var _active_inputs: Dictionary = {}
var _palette_popup: AlgorithmSettingsPopup

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
	var btn_run = Button.new()
	btn_run.text = "▶ RUN PIPELINE"
	btn_run.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_run.add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
	btn_run.pressed.connect(_on_run_pipeline_pressed)
	
	var btn_clear = Button.new()
	btn_clear.text = "Clear Graph"
	btn_clear.pressed.connect(func(): graph_editor.clear_graph())
	
	macro_hbox.add_child(btn_run)
	macro_hbox.add_child(btn_clear)
	ui_container.add_child(macro_hbox)
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
	
	# 4. STACK CONTROLS (Up/Down/Delete)
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
	if available_modifiers.is_empty(): return
	var idx = _add_dropdown.selected
	if idx < 0: return
	
	# Instantiate the chosen modifier script
	var new_mod = available_modifiers[idx].new() as GraphModifier
	new_mod.apply_defaults()
	
	modifier_stack.append(new_mod)
	_refresh_stack_ui()
	_on_stack_item_selected(modifier_stack.size() - 1) # Auto-select new item

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
	if selected_stack_index > 0:
		var temp = modifier_stack[selected_stack_index]
		modifier_stack[selected_stack_index] = modifier_stack[selected_stack_index - 1]
		modifier_stack[selected_stack_index - 1] = temp
		selected_stack_index -= 1
		_refresh_stack_ui()

func _on_move_down_pressed() -> void:
	if selected_stack_index >= 0 and selected_stack_index < modifier_stack.size() - 1:
		var temp = modifier_stack[selected_stack_index]
		modifier_stack[selected_stack_index] = modifier_stack[selected_stack_index + 1]
		modifier_stack[selected_stack_index + 1] = temp
		selected_stack_index += 1
		_refresh_stack_ui()

func _on_delete_pressed() -> void:
	if selected_stack_index >= 0:
		modifier_stack.remove_at(selected_stack_index)
		selected_stack_index = -1
		_refresh_stack_ui()

# ==============================================================================
# SETTINGS UI ROUTING
# ==============================================================================

func _on_stack_item_selected(index: int) -> void:
	selected_stack_index = index
	_stack_list.select(index)
	_build_settings_ui_for_modifier(modifier_stack[index])

func _clear_settings_ui() -> void:
	for child in _settings_container.get_children():
		child.queue_free()
	_active_inputs.clear()

func _build_settings_ui_for_modifier(modifier: GraphModifier) -> void:
	_clear_settings_ui()
	
	var header = Label.new()
	header.text = "--- " + modifier.modifier_name + " Settings ---"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_settings_container.add_child(header)
	
	var schema = modifier.get_settings()
	
	# Inject the modifier's isolated local_settings into the UI defaults!
	for setting in schema:
		if modifier.local_settings.has(setting["name"]):
			setting["default"] = modifier.local_settings[setting["name"]]
			
	_active_inputs = SettingsUIBuilder.build_ui(schema, _settings_container)
	SettingsUIBuilder.connect_live_updates(_active_inputs, _on_live_setting_changed)

func _on_live_setting_changed(key: String, value: Variant) -> void:
	if selected_stack_index >= 0 and selected_stack_index < modifier_stack.size():
		var active_mod = modifier_stack[selected_stack_index]
		
		# Intercept Popup Button!
		if key == "btn_biome_palette":
			if active_mod.has_method("get_palette_schema"):
				var schema = active_mod.get_palette_schema()
				# Pass the modifier's local settings so the popup remembers what was chosen last time
				_palette_popup.open_settings(active_mod.modifier_name + " Details", schema, active_mod.local_settings)
			return
			
		active_mod.local_settings[key] = value

func _on_palette_popup_confirmed(new_settings: Dictionary) -> void:
	if selected_stack_index >= 0 and selected_stack_index < modifier_stack.size():
		var active_mod = modifier_stack[selected_stack_index]
		# Merge the popup settings directly into the modifier's memory
		active_mod.local_settings.merge(new_settings, true)

# ==============================================================================
# EXECUTION
# ==============================================================================

func _on_run_pipeline_pressed() -> void:
	if modifier_stack.is_empty(): return
	
	print("\n========== PIPELINE START ==========")
	
	# 1. Open the master undo transaction so the whole pipeline is 1 Undo step!
	graph_editor.start_undo_transaction("Run Pipeline")
	var graph = graph_editor.graph
	
	for i in range(modifier_stack.size()):
		var mod = modifier_stack[i]
		print("[%d] Executing: %s" % [i, mod.modifier_name])
		
		# A. GENERATOR WIPE
		# We must clear the graph using commands so the wipe is undoable!
		if mod.category == GraphModifier.Category.GENERATOR:
			var clear_batch = CmdBatch.new(graph, "Clear Graph", false)
			for id in graph.nodes.keys():
				clear_batch.add_command(CmdDeleteNode.new(graph, id))
			for z in graph.zones.duplicate():
				clear_batch.add_command(CmdRemoveZone.new(graph, z))
				
			if clear_batch.get_command_count() > 0:
				graph_editor._commit_command(clear_batch)
				
		# B. RECORD MODIFICATIONS
		var recorder = GraphRecorder.new(graph)
		mod.execute(recorder)
		
		# C. COMMIT IMMEDIATELY
		# We MUST execute the commands right now so the NEXT modifier in the loop can see them!
		var mod_batch = CmdBatch.new(graph, mod.modifier_name, false)
		for cmd in recorder.recorded_commands:
			mod_batch.add_command(cmd)
			
		if mod_batch.get_command_count() > 0:
			graph_editor._commit_command(mod_batch)
			
	# 2. Close the master transaction
	graph_editor.commit_undo_transaction()
	
	# 3. Final Validation & Screen Update
	GraphValidator.validate(graph, true) # Auto-heals any weird topological breaks
	graph_editor.mark_modified()
	graph_editor.request_redraw()
	graph_editor._center_camera_on_graph()
	graph_editor.set_selection_batch([], [], true) # Clear the inspector
	
	print("========== PIPELINE COMPLETE ==========\n")
