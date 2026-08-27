class_name TriggersTabView
extends MarginContainer

signal trigger_created()
signal trigger_deleted(trigger_id: String)
signal trigger_name_changed(trigger_id: String, new_name: String)
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
	_btn_create.pressed.connect(func(): trigger_created.emit())
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
		var item_hbox = HBoxContainer.new()
		
		var name_edit = LineEdit.new()
		name_edit.text = t_data.get("name", "Unnamed Trigger")
		name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_edit.text_changed.connect(func(new_text): trigger_name_changed.emit(t_id, new_text))
		item_hbox.add_child(name_edit)
		
		var t_nodes = t_data.get("target_nodes", [])
		var t_edges = t_data.get("target_edges", [])
		var lbl_target = Label.new()
		lbl_target.text = " (%d N, %d E) " % [t_nodes.size(), t_edges.size()]
		lbl_target.add_theme_color_override("font_color", Color.GRAY)
		item_hbox.add_child(lbl_target)
		
		var btn_mask = Button.new()
		btn_mask.text = "Mask"
		btn_mask.tooltip_text = "Select nodes/edges in the graph for this trigger"
		btn_mask.pressed.connect(func(): trigger_edit_mask_requested.emit(t_id))
		item_hbox.add_child(btn_mask)
		
		var btn_settings = Button.new()
		btn_settings.text = "Set"
		btn_settings.tooltip_text = "Edit Overrides (Seed & Biomes)"
		btn_settings.pressed.connect(func(): trigger_edit_settings_requested.emit(t_id))
		item_hbox.add_child(btn_settings)
		
		var btn_test = Button.new()
		btn_test.text = "Test"
		btn_test.tooltip_text = "Fire Trigger"
		btn_test.pressed.connect(func(): trigger_test_requested.emit(t_id))
		item_hbox.add_child(btn_test)
		
		var btn_del = Button.new()
		btn_del.text = "X"
		btn_del.add_theme_color_override("font_color", Color.RED)
		btn_del.pressed.connect(func(): trigger_deleted.emit(t_id))
		item_hbox.add_child(btn_del)
		
		_list_container.add_child(item_hbox)
