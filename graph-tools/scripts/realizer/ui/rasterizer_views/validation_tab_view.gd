class_name ValidationTabView
extends MarginContainer

# Media Control Signals
signal play_requested()
signal pause_requested()
signal step_requested()
signal skip_requested()
signal stop_requested()

# Option Signals
signal settings_changed(full_explore: bool, delay_doors: bool)
signal speed_changed(tick_rate_seconds: float)
signal batch_size_changed(tiles_per_step: int)
signal constant_speed_toggled(is_on: bool)
signal visualize_toggled(is_on: bool)

var _log_text: RichTextLabel
var _btn_play: Button
var _btn_pause: Button
var _btn_step: Button
var _btn_skip: Button
var _btn_stop: Button

var _chk_visualize: CheckBox
var _chk_full_explore: CheckBox
var _chk_delay_doors: CheckBox
var _chk_constant_speed: CheckBox

var _slider_speed: HSlider
var _slider_batch: HSlider
var _lbl_speed: Label
var _lbl_batch: Label

func _init() -> void:
	name = "Validator"
	add_theme_constant_override("margin_top", 10)
	add_theme_constant_override("margin_left", 10)
	add_theme_constant_override("margin_right", 10)
	add_theme_constant_override("margin_bottom", 10)
	
	var vbox = VBoxContainer.new()
	add_child(vbox)
	
	# --- 1. VCR MEDIA CONTROLS ---
	var vcr_hbox = HBoxContainer.new()
	
	_btn_play = Button.new()
	_btn_play.text = "Play"
	_btn_play.pressed.connect(func(): play_requested.emit())
	
	_btn_pause = Button.new()
	_btn_pause.text = "Pause"
	_btn_pause.disabled = true
	_btn_pause.pressed.connect(func(): pause_requested.emit())
	
	
	_btn_stop = Button.new()
	_btn_stop.text = "Stop & Clear"
	_btn_stop.disabled = true
	_btn_stop.pressed.connect(func(): stop_requested.emit())
	
	vcr_hbox.add_child(_btn_play)
	vcr_hbox.add_child(_btn_pause)
	vcr_hbox.add_child(_btn_stop)
	
	var vcr_step_hbox = HBoxContainer.new()
	
	_btn_step = Button.new()
	_btn_step.text = "Step"
	_btn_step.pressed.connect(func(): step_requested.emit())
	
	_btn_skip = Button.new()
	_btn_skip.text = "Skip (Fast-Forward)"
	_btn_skip.pressed.connect(func(): skip_requested.emit())
	
	vcr_step_hbox.add_child(_btn_step)
	vcr_step_hbox.add_child(_btn_skip)
	
	vbox.add_child(vcr_hbox)
	vbox.add_child(vcr_step_hbox)
	
	# --- 2. SPEED & BATCH SLIDERS ---
	var sliders_grid = GridContainer.new()
	sliders_grid.columns = 2
	sliders_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	_lbl_speed = Label.new()
	_lbl_speed.text = "Tick Speed: 0.05s"
	_slider_speed = HSlider.new()
	_slider_speed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider_speed.min_value = 0.01
	_slider_speed.max_value = 0.5
	_slider_speed.step = 0.01
	_slider_speed.value = 0.05
	_slider_speed.value_changed.connect(func(v): 
		_lbl_speed.text = "Tick Speed: %.2fs" % v
		speed_changed.emit(v)
	)
	
	_lbl_batch = Label.new()
	_lbl_batch.text = "Tiles Per Step: 10"
	_slider_batch = HSlider.new()
	_slider_batch.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider_batch.min_value = 1
	_slider_batch.max_value = 100
	_slider_batch.step = 1
	_slider_batch.value = 10
	_slider_batch.value_changed.connect(func(v): 
		_lbl_batch.text = "Tiles Per Step: %d" % v
		batch_size_changed.emit(int(v))
	)
	
	sliders_grid.add_child(_lbl_speed)
	sliders_grid.add_child(_slider_speed)
	sliders_grid.add_child(_lbl_batch)
	sliders_grid.add_child(_slider_batch)
	vbox.add_child(sliders_grid)
	
	# --- 3. OPTIONS ---
	var options_vbox = VBoxContainer.new()
	
	_chk_visualize = CheckBox.new()
	_chk_visualize.text = "Show Live Visualization"
	_chk_visualize.button_pressed = true
	_chk_visualize.toggled.connect(func(pressed): visualize_toggled.emit(pressed))
	options_vbox.add_child(_chk_visualize)
	
	_chk_full_explore = CheckBox.new()
	_chk_full_explore.text = "Full Grid Exploration"
	_chk_full_explore.toggled.connect(func(_p): settings_changed.emit(_chk_full_explore.button_pressed, _chk_delay_doors.button_pressed))
	
	_chk_delay_doors = CheckBox.new()
	_chk_delay_doors.text = "Exhaustive Exploration (Delay Doors)"
	_chk_delay_doors.toggled.connect(func(_p): settings_changed.emit(_chk_full_explore.button_pressed, _chk_delay_doors.button_pressed))
	
	# --- CONSTANT SPEED TOGGLE ---
	_chk_constant_speed = CheckBox.new()
	_chk_constant_speed.text = "Constant Visual Expansion Rate"
	_chk_constant_speed.button_pressed = false
	_chk_constant_speed.tooltip_text = "Dynamically increases the batch size in open areas so the fluid expands at a constant visual speed."
	_chk_constant_speed.toggled.connect(func(pressed): constant_speed_toggled.emit(pressed))
	
	options_vbox.add_child(_chk_full_explore)
	options_vbox.add_child(_chk_delay_doors)
	options_vbox.add_child(_chk_constant_speed)
	vbox.add_child(options_vbox)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	# --- 4. LOGS ---
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

func _ready() -> void:
	# Guarantee the tree is built before setting these, avoiding Godot's silent clamping bug!
	_slider_speed.value = 0.05
	_slider_batch.value = 10
	
	# Trigger the UI labels to match
	_lbl_speed.text = "Tick Speed: %.2fs" % _slider_speed.value
	_lbl_batch.text = "Tiles Per Step: %d" % _slider_batch.value

func append_log(msg: String) -> void:
	if msg != "": _log_text.text += "\n" + msg

func clear_logs() -> void:
	_log_text.text = ""

func set_state(state: String) -> void:
	match state:
		"IDLE":
			_btn_play.disabled = false
			_btn_pause.disabled = true
			_btn_step.disabled = false
			_btn_skip.disabled = false
			_btn_stop.disabled = true
		"PLAYING":
			_btn_play.disabled = true
			_btn_pause.disabled = false
			_btn_step.disabled = true
			_btn_skip.disabled = true
			_btn_stop.disabled = false
		"PAUSED":
			_btn_play.disabled = false
			_btn_pause.disabled = true
			_btn_step.disabled = false
			_btn_skip.disabled = false
			_btn_stop.disabled = false

func get_settings() -> Dictionary:
	return {
		"full_explore": _chk_full_explore.button_pressed,
		"delay_doors": _chk_delay_doors.button_pressed,
		"batch_size": int(_slider_batch.value),
		"tick_speed": float(_slider_speed.value),
		"constant_speed": _chk_constant_speed.button_pressed
	}

func is_visualize_on() -> bool:
	return _chk_visualize.button_pressed
