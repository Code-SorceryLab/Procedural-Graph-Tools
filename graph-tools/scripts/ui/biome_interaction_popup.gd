class_name BiomeInteractionPopup
extends AcceptDialog

var interactions: Dictionary = {}

# --- GLOBAL UI REFS ---
var opt_global_path: OptionButton
var opt_global_seam: OptionButton

# --- PAIR UI REFS ---
var opt_biome_a: OptionButton
var opt_biome_b: OptionButton
var chk_override: CheckBox
var opt_pair_path: OptionButton
var opt_pair_seam: OptionButton
var pair_settings_panel: VBoxContainer
var lbl_invalid: Label

var semantic_keys: Array[String] = []

func _init() -> void:
	title = "Biome Interaction Matrix"
	size = Vector2i(480, 420)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(vbox)
	
	# ==========================================================================
	# GLOBAL DEFAULTS SECTION
	# ==========================================================================
	var lbl_global_title = Label.new()
	lbl_global_title.text = "--- Global Default Rules ---"
	lbl_global_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_global_title.modulate = Color(0.8, 0.8, 1.0)
	vbox.add_child(lbl_global_title)
	
	var box_g_path = HBoxContainer.new()
	var lbl_g_path = Label.new()
	lbl_g_path.text = "On Critical Path:"
	lbl_g_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_g_path.add_child(lbl_g_path)
	
	opt_global_path = OptionButton.new()
	_populate_path_options(opt_global_path)
	opt_global_path.item_selected.connect(func(idx): _save_global("path_style", idx))
	box_g_path.add_child(opt_global_path)
	vbox.add_child(box_g_path)
	
	var box_g_seam = HBoxContainer.new()
	var lbl_g_seam = Label.new()
	lbl_g_seam.text = "On General Boundary:"
	lbl_g_seam.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_g_seam.add_child(lbl_g_seam)
	
	opt_global_seam = OptionButton.new()
	_populate_seam_options(opt_global_seam)
	opt_global_seam.item_selected.connect(func(idx): _save_global("seam_style", idx))
	box_g_seam.add_child(opt_global_seam)
	vbox.add_child(box_g_seam)
	
	var sep = HSeparator.new()
	sep.custom_minimum_size.y = 20
	vbox.add_child(sep)
	
	# ==========================================================================
	# SPECIFIC OVERRIDE SECTION
	# ==========================================================================
	var lbl_pair_title = Label.new()
	lbl_pair_title.text = "--- Specific Biome Overrides ---"
	lbl_pair_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_pair_title.modulate = Color(1.0, 0.8, 0.8)
	vbox.add_child(lbl_pair_title)
	
	var hbox_select = HBoxContainer.new()
	hbox_select.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox_select)
	
	opt_biome_a = OptionButton.new()
	opt_biome_a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_biome_a.item_selected.connect(_on_selection_changed)
	hbox_select.add_child(opt_biome_a)
	
	var lbl_meets = Label.new()
	lbl_meets.text = " meets "
	lbl_meets.modulate = Color(1, 1, 1, 0.6)
	hbox_select.add_child(lbl_meets)
	
	opt_biome_b = OptionButton.new()
	opt_biome_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_biome_b.item_selected.connect(_on_selection_changed)
	hbox_select.add_child(opt_biome_b)
	
	# --- WARNING LABEL (Same Biome) ---
	lbl_invalid = Label.new()
	lbl_invalid.text = "\nSelect two different biomes."
	lbl_invalid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_invalid.modulate = Color(1, 1, 1, 0.5)
	vbox.add_child(lbl_invalid)
	
	# --- PAIR SETTINGS PANEL ---
	pair_settings_panel = VBoxContainer.new()
	pair_settings_panel.visible = false
	vbox.add_child(pair_settings_panel)
	
	var margin_top = MarginContainer.new()
	margin_top.add_theme_constant_override("margin_top", 10)
	pair_settings_panel.add_child(margin_top)
	
	chk_override = CheckBox.new()
	chk_override.text = "Enable Custom Rules For This Pair"
	chk_override.toggled.connect(_on_override_toggled)
	pair_settings_panel.add_child(chk_override)
	
	var box_p_path = HBoxContainer.new()
	var lbl_p_path = Label.new()
	lbl_p_path.text = "On Critical Path:"
	lbl_p_path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_p_path.add_child(lbl_p_path)
	
	opt_pair_path = OptionButton.new()
	_populate_path_options(opt_pair_path)
	opt_pair_path.item_selected.connect(func(idx): _save_current_pair("path_style", idx))
	box_p_path.add_child(opt_pair_path)
	pair_settings_panel.add_child(box_p_path)
	
	var box_p_seam = HBoxContainer.new()
	var lbl_p_seam = Label.new()
	lbl_p_seam.text = "On General Boundary:"
	lbl_p_seam.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box_p_seam.add_child(lbl_p_seam)
	
	opt_pair_seam = OptionButton.new()
	_populate_seam_options(opt_pair_seam)
	opt_pair_seam.item_selected.connect(func(idx): _save_current_pair("seam_style", idx))
	box_p_seam.add_child(opt_pair_seam)
	pair_settings_panel.add_child(box_p_seam)

# ==============================================================================
# HELPERS
# ==============================================================================

func _populate_path_options(opt: OptionButton) -> void:
	opt.add_item("Open (Empty)", 0)
	opt.add_item("Door + Walls", 1)
	opt.add_item("Decorated", 2)

func _populate_seam_options(opt: OptionButton) -> void:
	opt.add_item("Open (Allows Shortcuts)", 0)
	opt.add_item("Walled", 1)
	opt.add_item("Decorated", 2)

func _get_pair_key() -> String:
	if opt_biome_a.selected < 0 or opt_biome_b.selected < 0: return ""
	var a = semantic_keys[opt_biome_a.selected]
	var b = semantic_keys[opt_biome_b.selected]
	if a == b: return ""
	var arr = [a, b]
	arr.sort() 
	return arr[0] + "|" + arr[1]

# ==============================================================================
# LIFECYCLE & LOGIC
# ==============================================================================

func open() -> void:
	interactions = ConfigManager.load_biome_interactions()
	
	# Initialize Global Data if missing
	if not interactions.has("global_default"):
		interactions["global_default"] = { "path_style": 0, "seam_style": 1 }
		
	var g_data = interactions["global_default"]
	opt_global_path.select(g_data.get("path_style", 0))
	opt_global_seam.select(g_data.get("seam_style", 1))
	
	opt_biome_a.clear()
	opt_biome_b.clear()
	semantic_keys.clear()
	
	var node_cats = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE]
	for key in node_cats:
		semantic_keys.append(key)
		var cat_name = node_cats[key]["name"]
		
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(node_cats[key]["color"])
		var tex = ImageTexture.create_from_image(img)
		
		opt_biome_a.add_icon_item(tex, cat_name)
		opt_biome_b.add_icon_item(tex, cat_name)
		
	if opt_biome_a.item_count > 0:
		opt_biome_a.select(0)
		opt_biome_b.select(min(1, opt_biome_b.item_count - 1))
		
	_on_selection_changed(0)
	popup_centered()

func _save_global(setting_key: String, value: int) -> void:
	interactions["global_default"][setting_key] = value
	_refresh_pair_ui() # Update the grayed-out dropdowns instantly if they are tracking the global

func _on_selection_changed(_idx: int) -> void:
	_refresh_pair_ui()

func _refresh_pair_ui() -> void:
	var key = _get_pair_key()
	
	if key == "":
		pair_settings_panel.visible = false
		lbl_invalid.visible = true
	else:
		pair_settings_panel.visible = true
		lbl_invalid.visible = false
		
		var is_overridden = interactions.has(key)
		chk_override.set_pressed_no_signal(is_overridden)
		
		# If it's overridden, enable inputs and load specific data
		# If not, disable inputs and visually show the global fallback data!
		opt_pair_path.disabled = not is_overridden
		opt_pair_seam.disabled = not is_overridden
		
		var data = interactions.get(key, interactions["global_default"])
		opt_pair_path.select(data.get("path_style", 0))
		opt_pair_seam.select(data.get("seam_style", 1))

func _on_override_toggled(toggled_on: bool) -> void:
	var key = _get_pair_key()
	if key == "": return
	
	if toggled_on:
		# Copy the current global settings as a starting point
		interactions[key] = interactions["global_default"].duplicate()
	else:
		# Delete the custom rule so it falls back
		interactions.erase(key)
		
	_refresh_pair_ui()

func _save_current_pair(setting_key: String, value: int) -> void:
	var key = _get_pair_key()
	if key == "" or not interactions.has(key): return
	interactions[key][setting_key] = value
