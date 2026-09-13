class_name TimelineTabView
extends MarginContainer

signal snapshot_selected(index: int)

var _scroll_steps: ScrollContainer
var _step_list: VBoxContainer
var _buttons: Array[Button] = []

var _btn_first: Button
var _btn_prev: Button
var _btn_play_pause: Button
var _btn_next: Button
var _btn_last: Button

var _slider_speed: HSlider
var _lbl_speed: Label
var _autoplay_timer: Timer
var _is_playing: bool = false

var _snapshot_count: int = 0
var _current_index: int = -1

func _init() -> void:
	name = "Timeline"
	add_theme_constant_override("margin_top", 10)
	add_theme_constant_override("margin_left", 10)
	add_theme_constant_override("margin_right", 10)
	
	# --- AUTOPLAY TIMER ---
	_autoplay_timer = Timer.new()
	_autoplay_timer.one_shot = false
	_autoplay_timer.timeout.connect(_on_autoplay_tick)
	add_child(_autoplay_timer)
	
	var vcr_container = VBoxContainer.new()
	vcr_container.add_theme_constant_override("separation", 5)
	
	var header = Label.new()
	header.text = "Rasterization Steps"
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vcr_container.add_child(header)
	
	_scroll_steps = ScrollContainer.new()
	_scroll_steps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_steps.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vcr_container.add_child(_scroll_steps)
	
	_step_list = VBoxContainer.new()
	_step_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_step_list.add_theme_constant_override("separation", 2)
	_scroll_steps.add_child(_step_list)
	
	# --- TOOLBAR SETUP ---
	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	
	_btn_first = Button.new(); _btn_first.text = "|<"
	_btn_prev = Button.new(); _btn_prev.text = "< Prev"
	_btn_play_pause = Button.new(); _btn_play_pause.text = "Play"
	_btn_next = Button.new(); _btn_next.text = "Next >"
	_btn_last = Button.new(); _btn_last.text = ">|"
	
	# Manual clicks stop the autoplay!
	_btn_first.pressed.connect(func(): _stop_autoplay(); snapshot_selected.emit(0))
	_btn_prev.pressed.connect(func(): _stop_autoplay(); snapshot_selected.emit(_current_index - 1))
	_btn_play_pause.pressed.connect(_toggle_autoplay)
	_btn_next.pressed.connect(func(): _stop_autoplay(); snapshot_selected.emit(_current_index + 1))
	_btn_last.pressed.connect(func(): _stop_autoplay(); snapshot_selected.emit(_snapshot_count - 1))
	
	btn_row.add_child(_btn_first)
	btn_row.add_child(_btn_prev)
	btn_row.add_child(_btn_play_pause)
	btn_row.add_child(_btn_next)
	btn_row.add_child(_btn_last)
	vcr_container.add_child(btn_row)
	
	# --- SPEED SLIDER ---
	var speed_row = HBoxContainer.new()
	var lbl_speed_title = Label.new()
	lbl_speed_title.text = "Speed:"
	speed_row.add_child(lbl_speed_title)
	
	_slider_speed = HSlider.new()
	_slider_speed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider_speed.min_value = 0.1
	_slider_speed.max_value = 2.0
	_slider_speed.step = 0.1
	_slider_speed.value = 0.5
	
	_lbl_speed = Label.new()
	_lbl_speed.text = "0.5s"
	
	_slider_speed.value_changed.connect(func(v): 
		_lbl_speed.text = "%.1fs" % v
		if _is_playing: _autoplay_timer.start(v) # Update speed live
	)
	
	speed_row.add_child(_slider_speed)
	speed_row.add_child(_lbl_speed)
	vcr_container.add_child(speed_row)
	
	add_child(vcr_container)
	set_buttons_active(false)

# ==============================================================================
# AUTOPLAY LOGIC
# ==============================================================================
func _toggle_autoplay() -> void:
	if _is_playing:
		_stop_autoplay()
	else:
		if _current_index >= _snapshot_count - 1:
			snapshot_selected.emit(0) # Loop back to the start if we are at the end!
			
		_is_playing = true
		_btn_play_pause.text = "Pause"
		# Use the engine's built-in button color tinting for a nice active state
		_btn_play_pause.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2)) 
		_autoplay_timer.start(_slider_speed.value)

func _stop_autoplay() -> void:
	if not _is_playing: return
	_is_playing = false
	_btn_play_pause.text = "Play"
	_btn_play_pause.remove_theme_color_override("font_color")
	_autoplay_timer.stop()

func _on_autoplay_tick() -> void:
	if _current_index < _snapshot_count - 1:
		snapshot_selected.emit(_current_index + 1)
	else:
		_stop_autoplay() # Stop naturally when we hit the end

# ==============================================================================

func add_snapshot(step_name: String, duration_ms: int = 0) -> void:
	var btn = Button.new()
	btn.toggle_mode = true
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size.y = 42 if duration_ms > 0 else 30 
	
	var mc = MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", -2) 
	
	var lbl_name = Label.new()
	lbl_name.text = step_name
	lbl_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vbox.add_child(lbl_name)
	
	if duration_ms > 0:
		var lbl_time = Label.new()
		lbl_time.text = str(duration_ms) + "ms"
		lbl_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		lbl_time.add_theme_font_size_override("font_size", 11)
		lbl_time.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		vbox.add_child(lbl_time)
		
	mc.add_child(vbox)
	btn.add_child(mc)
	
	var idx = _snapshot_count
	# Manual selection stops autoplay
	btn.pressed.connect(func(): _stop_autoplay(); snapshot_selected.emit(idx))
	
	_step_list.add_child(btn)
	_buttons.append(btn)
	_snapshot_count += 1

func clear() -> void:
	_stop_autoplay()
	for child in _step_list.get_children():
		child.queue_free()
	_buttons.clear()
	_snapshot_count = 0
	_current_index = -1
	set_buttons_active(false)

func select_index(idx: int) -> void:
	_current_index = idx
	for i in range(_buttons.size()):
		_buttons[i].set_pressed_no_signal(i == idx)
		
	if idx >= 0 and idx < _buttons.size():
		_scroll_steps.ensure_control_visible(_buttons[idx])
		
	set_buttons_active(true)

func set_buttons_active(active: bool) -> void:
	_btn_first.disabled = not active or _current_index <= 0
	_btn_prev.disabled = not active or _current_index <= 0
	_btn_next.disabled = not active or _current_index >= _snapshot_count - 1
	_btn_last.disabled = not active or _current_index >= _snapshot_count - 1
	_btn_play_pause.disabled = not active or _snapshot_count == 0
