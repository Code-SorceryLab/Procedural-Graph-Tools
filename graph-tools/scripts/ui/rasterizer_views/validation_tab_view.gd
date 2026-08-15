class_name ValidationTabView
extends MarginContainer

# [FIXED] Add the full_explore boolean to the signal
signal run_requested(visualize: bool, full_explore: bool)
signal stop_requested()
signal visualize_toggled(is_on: bool)

var _log_text: RichTextLabel
var _btn_run: Button
var _btn_stop: Button
var _chk_visualize: CheckBox
var _chk_full_explore: CheckBox

func _init() -> void:
	name = "Validator"
	add_theme_constant_override("margin_top", 10)
	add_theme_constant_override("margin_left", 10)
	add_theme_constant_override("margin_right", 10)
	add_theme_constant_override("margin_bottom", 10)
	
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	var btn_hbox = HBoxContainer.new()
	_btn_run = Button.new()
	_btn_run.text = "Run Validation Test"
	_btn_run.pressed.connect(func(): run_requested.emit(_chk_visualize.button_pressed, _chk_full_explore.button_pressed))
	
	_btn_stop = Button.new()
	_btn_stop.text = "Stop"
	_btn_stop.disabled = true
	_btn_stop.pressed.connect(func(): stop_requested.emit())
	
	btn_hbox.add_child(_btn_run)
	btn_hbox.add_child(_btn_stop)
	vbox.add_child(btn_hbox)
	
	# Place options vertically in a VBox
	var options_vbox = VBoxContainer.new()
	_chk_visualize = CheckBox.new()
	_chk_visualize.text = "Show Live Visualization"
	_chk_visualize.button_pressed = true
	_chk_visualize.toggled.connect(func(pressed): visualize_toggled.emit(pressed))

	_chk_full_explore = CheckBox.new()
	_chk_full_explore.text = "Full Grid Exploration"
	_chk_full_explore.button_pressed = false
	_chk_full_explore.tooltip_text = "If checked, the validator will not stop at the exit. It will explore all side branches until no moves remain."
	
	options_vbox.add_child(_chk_visualize)
	options_vbox.add_child(_chk_full_explore)
	vbox.add_child(options_vbox)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	_log_text = RichTextLabel.new()
	_log_text.bbcode_enabled = true
	_log_text.scroll_following = true 
	_log_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_text.text = "[color=gray]Ready to validate graph topology.[/color]"
	scroll.add_child(_log_text)

func append_log(msg: String) -> void:
	_log_text.text += "\n" + msg

func clear_logs() -> void:
	_log_text.text = ""

func set_running(is_running: bool) -> void:
	_btn_run.disabled = is_running
	_btn_stop.disabled = not is_running

func is_visualize_on() -> bool:
	return _chk_visualize.button_pressed
