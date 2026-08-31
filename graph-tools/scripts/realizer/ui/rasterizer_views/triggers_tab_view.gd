class_name TriggersTabView
extends MarginContainer

signal trigger_created()
signal trigger_deleted(trigger_id: String)
signal trigger_name_changed(trigger_id: String, new_name: String)
signal trigger_mode_changed(trigger_id: String, new_mode: int)
signal trigger_edit_mask_requested(trigger_id: String)
signal trigger_edit_settings_requested(trigger_id: String)
signal trigger_test_requested(trigger_id: String)

var _list_container: VBoxContainer
var _btn_create: Button

func _init() -> void:
	name = "Triggers"
	add_theme_constant_override("margin_top", 10)
	add_theme_constant_override("margin_left", 10)
	add_theme_constant_override("margin_right", 10)
	add_theme_constant_override("margin_bottom", 10)
	
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	_btn_create = Button.new()
	_btn_create.text = "+ Create New Trigger"
	_btn_create.pressed.connect(_on_create_pressed)
	vbox.add_child(_btn_create)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	_list_container = VBoxContainer.new()
	_list_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list_container)

func build_list(triggers: Dictionary) -> void:
	for child in _list_container.get_children():
		child.queue_free()
		
	for t_id in triggers:
		var t_data = triggers[t_id]
		# Fallback to 1 (Local) so new triggers default to being active!
		var current_mode = t_data.get("placement_mode", 1) 
		
		# --- OUTER CARD CONTAINER ---
		var trigger_card = VBoxContainer.new()
		trigger_card.modulate = Color(1, 1, 1, 0.4 if current_mode == 0 else 1.0)
		
		# --- ROW 1: Identity & Mode ---
		var row1 = HBoxContainer.new()
		
		var mode_opt = OptionButton.new()
		mode_opt.add_item("⏸️ Off", 0)
		mode_opt.add_item("📍 Local", 1)
		mode_opt.add_item("🗝️ Prog.", 2)
		mode_opt.selected = current_mode
		mode_opt.tooltip_text = "Placement Mode:\nOff: Inactive\nLocal: Placed by TriggerPlacer\nProg: Placed by ProgressionSolver"
		
		# Bulletproof Binding
		mode_opt.item_selected.connect(_on_mode_selected.bind(t_id, trigger_card))
		row1.add_child(mode_opt)
		
		var name_edit = LineEdit.new()
		name_edit.text = t_data.get("name", "Unnamed Trigger")
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.text_changed.connect(_on_name_changed.bind(t_id))
		row1.add_child(name_edit)
		
		var t_nodes = t_data.get("target_nodes", [])
		var t_edges = t_data.get("target_edges", [])
		var lbl_target = Label.new()
		lbl_target.text = " (%d N, %d E) " % [t_nodes.size(), t_edges.size()]
		lbl_target.add_theme_color_override("font_color", Color.GRAY)
		row1.add_child(lbl_target)
		
		var btn_del = Button.new()
		btn_del.text = "X"
		btn_del.add_theme_color_override("font_color", Color.RED)
		btn_del.pressed.connect(_on_delete_pressed.bind(t_id))
		row1.add_child(btn_del)
		
		trigger_card.add_child(row1)
		
		# --- ROW 2: Actions ---
		var row2 = HBoxContainer.new()
		
		var btn_mask = Button.new()
		btn_mask.text = "Mask"
		btn_mask.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_mask.tooltip_text = "Select nodes/edges in the graph for this trigger"
		btn_mask.pressed.connect(_on_mask_pressed.bind(t_id))
		row2.add_child(btn_mask)
		
		var btn_settings = Button.new()
		btn_settings.text = "Rules & Constraints"
		btn_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_settings.tooltip_text = "Edit Sandbox Rules & Placement Constraints"
		btn_settings.pressed.connect(_on_settings_pressed.bind(t_id))
		row2.add_child(btn_settings)
		
		var btn_test = Button.new()
		btn_test.text = "Test Fire"
		btn_test.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_test.tooltip_text = "Fire Trigger"
		btn_test.pressed.connect(_on_test_pressed.bind(t_id))
		row2.add_child(btn_test)
		
		trigger_card.add_child(row2)
		
		var sep = HSeparator.new()
		sep.add_theme_constant_override("separation", 15)
		trigger_card.add_child(sep)
		
		_list_container.add_child(trigger_card)

# ==============================================================================
# BOUND HANDLERS (Immune to Loop Capture Bugs)
# ==============================================================================
func _on_create_pressed() -> void: trigger_created.emit()
func _on_name_changed(new_text: String, t_id: String) -> void: trigger_name_changed.emit(t_id, new_text)
func _on_mask_pressed(t_id: String) -> void: trigger_edit_mask_requested.emit(t_id)
func _on_settings_pressed(t_id: String) -> void: trigger_edit_settings_requested.emit(t_id)
func _on_test_pressed(t_id: String) -> void: trigger_test_requested.emit(t_id)
func _on_delete_pressed(t_id: String) -> void: trigger_deleted.emit(t_id)

func _on_mode_selected(idx: int, t_id: String, card: Control) -> void:
	card.modulate = Color(1, 1, 1, 0.4 if idx == 0 else 1.0)
	trigger_mode_changed.emit(t_id, idx)
