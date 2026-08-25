class_name CosinePaletteEditor
extends VBoxContainer

signal palette_changed

var tex_preview: TextureRect
var params: Dictionary = {}

var sliders: Dictionary = {}

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# 1. Preview Gradient
	tex_preview = TextureRect.new()
	tex_preview.custom_minimum_size.y = 40
	tex_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(tex_preview)
	
	var btn_random = Button.new()
	btn_random.text = "🎲 Randomize Palette"
	btn_random.pressed.connect(_randomize_all)
	add_child(btn_random)
	
	add_child(HSeparator.new())
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	
	var controls = VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(controls)
	
	_create_vector_sliders(controls, "a", "Base Color (Bias)", 0.0, 1.0)
	_create_vector_sliders(controls, "b", "Amplitude (Contrast)", 0.0, 1.0)
	_create_vector_sliders(controls, "c", "Frequency (Oscillations)", 0.0, 3.0)
	_create_vector_sliders(controls, "d", "Phase (Color Shift)", 0.0, 1.0)
	
	controls.add_child(HSeparator.new())
	
	var box = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = "Wall Phase Shift (t + offset):"
	box.add_child(lbl)
	var s = HSlider.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.min_value = -0.5
	s.max_value = 0.5
	s.step = 0.01
	s.value_changed.connect(func(v): params["wall_shift"] = v; _update_preview())
	box.add_child(s)
	sliders["wall_shift"] = s
	controls.add_child(box)
	
	_randomize_all() # Init with random nice colors

func _create_vector_sliders(parent: Control, key: String, label: String, min_v: float, max_v: float) -> void:
	var lbl = Label.new()
	lbl.text = label
	parent.add_child(lbl)
	
	params[key] = Vector3.ZERO
	sliders[key] = []
	
	var colors = [Color.RED, Color.GREEN, Color.BLUE]
	for i in range(3):
		var box = HBoxContainer.new()
		var s_lbl = Label.new()
		s_lbl.text = ["R", "G", "B"][i]
		s_lbl.modulate = colors[i]
		box.add_child(s_lbl)
		
		var slider = HSlider.new()
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.min_value = min_v
		slider.max_value = max_v
		slider.step = 0.01
		slider.value_changed.connect(func(v): params[key][i] = v; _update_preview())
		box.add_child(slider)
		
		sliders[key].append(slider)
		parent.add_child(box)

func _randomize_all() -> void:
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	
	params["a"] = Vector3(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.8))
	params["b"] = Vector3(rng.randf_range(0.2, 0.5), rng.randf_range(0.2, 0.5), rng.randf_range(0.2, 0.5))
	
	# Keep frequencies as clean integers or halves for looping palettes
	params["c"] = Vector3(rng.randi_range(0, 2), rng.randi_range(0, 2), rng.randi_range(0, 2))
	params["d"] = Vector3(rng.randf(), rng.randf(), rng.randf())
	params["wall_shift"] = rng.randf_range(0.05, 0.2)
	
	_sync_ui_to_params()

func _sync_ui_to_params() -> void:
	for key in ["a", "b", "c", "d"]:
		for i in range(3):
			sliders[key][i].set_value_no_signal(params[key][i])
	sliders["wall_shift"].set_value_no_signal(params["wall_shift"])
	_update_preview()

func _update_preview() -> void:
	var img = Image.create(256, 1, false, Image.FORMAT_RGBA8)
	for x in range(256):
		var t = float(x) / 255.0
		img.set_pixel(x, 0, get_iq_color(t, params))
	
	tex_preview.texture = ImageTexture.create_from_image(img)
	palette_changed.emit()

# --- THE IQ COSINE FORMULA ---
static func get_iq_color(t: float, p: Dictionary) -> Color:
	var a = p["a"]; var b = p["b"]; var c = p["c"]; var d = p["d"]
	var r = a.x + b.x * cos(TAU * (c.x * t + d.x))
	var g = a.y + b.y * cos(TAU * (c.y * t + d.y))
	var bl = a.z + b.z * cos(TAU * (c.z * t + d.z))
	return Color(clamp(r, 0.0, 1.0), clamp(g, 0.0, 1.0), clamp(bl, 0.0, 1.0))
