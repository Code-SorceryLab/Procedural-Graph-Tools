class_name BiomeDesignerPopup
extends ConfirmationDialog

signal global_settings_changed(new_params: Dictionary)
signal biome_settings_changed(new_biomes: Dictionary)

# --- DATA ---
var global_params: Dictionary = {}
var biome_overrides: Dictionary = {}
var custom_structures: Dictionary = {}
var scatter_sets: Dictionary = {}

var current_biome_id: String = "" # "" = Global Default
var current_struct_id: String = ""
var current_scatter_id: String = ""

# --- UI REFS ---
var biome_dropdown: OptionButton

var toggle_panel: MarginContainer
var toggle_grid: GridContainer

var tab_container: TabContainer
var tab_shape: VBoxContainer
var tab_routing: VBoxContainer
var tab_structures: VBoxContainer
var tab_scatter: VBoxContainer

# Override Toggles (Only visible when a specific Biome is selected)
var chk_override_shape: CheckBox
var chk_override_routing: CheckBox
var chk_override_structures: CheckBox
var chk_override_scatter: CheckBox

# Active Input trackers for SettingsUIBuilder
var inputs_shape: Dictionary = {}
var inputs_routing: Dictionary = {}
var inputs_struct_global: Dictionary = {}
var inputs_struct_specific: Dictionary = {}
var inputs_scatter_specific: Dictionary = {}

var opt_structure_select: OptionButton
var opt_scatter_select: OptionButton

var content_shape: VBoxContainer
var content_routing: VBoxContainer
var content_struct_global: VBoxContainer
var content_struct_specific: VBoxContainer
var content_scatter_specific: VBoxContainer

func _init() -> void:
	title = "Biome & Generation Designer"
	min_size = Vector2(650, 650)
	transient = true
	exclusive = true
	
	var main_vbox = VBoxContainer.new()
	add_child(main_vbox)
	
	# 1. TOP BAR: BIOME SELECTOR
	var top_hbox = HBoxContainer.new()
	main_vbox.add_child(top_hbox)
	
	var lbl_biome = Label.new()
	lbl_biome.text = "Editing Target:"
	top_hbox.add_child(lbl_biome)
	
	biome_dropdown = OptionButton.new()
	biome_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	biome_dropdown.item_selected.connect(_on_biome_selected)
	top_hbox.add_child(biome_dropdown)
	
	main_vbox.add_child(HSeparator.new())
	
	# --- [NEW] 2. OVERRIDE TOGGLES PANEL ---
	# This sits above the tabs so you can see all active overrides at a glance
	toggle_panel = MarginContainer.new()
	toggle_panel.add_theme_constant_override("margin_bottom", 5)
	main_vbox.add_child(toggle_panel)
	
	toggle_grid = GridContainer.new()
	toggle_grid.columns = 2
	toggle_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_panel.add_child(toggle_grid)
	
	chk_override_shape = _create_override_toggle(toggle_grid, "Override Shape & Rooms", _rebuild_shape_tab)
	chk_override_routing = _create_override_toggle(toggle_grid, "Override Routing & CA", _rebuild_routing_tab)
	chk_override_structures = _create_override_toggle(toggle_grid, "Override Structures", _rebuild_structures_tab)
	chk_override_scatter = _create_override_toggle(toggle_grid, "Override Scatter Sets", _rebuild_scatter_tab)
	
	# 3. TABS
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(tab_container)
	
	tab_shape = _create_tab("Shape & Rooms")
	tab_routing = _create_tab("Routing & CA")
	tab_structures = _create_tab("Structures")
	tab_scatter = _create_tab("Scatter Sets")
	
	# --- Content Containers ---
	content_shape = _create_scroll_box(tab_shape)
	content_routing = _create_scroll_box(tab_routing)
	
	# Structures needs a global config area + specific dropdown
	content_struct_global = _create_scroll_box(tab_structures)
	tab_structures.add_child(HSeparator.new())
	
	var hbox_struct = HBoxContainer.new()
	var lbl_struct = Label.new()
	lbl_struct.text = "Configure Structure:"
	hbox_struct.add_child(lbl_struct)
	
	opt_structure_select = OptionButton.new()
	opt_structure_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_structure_select.item_selected.connect(_on_struct_selected)
	hbox_struct.add_child(opt_structure_select)
	tab_structures.add_child(hbox_struct)
	content_struct_specific = _create_scroll_box(tab_structures)
	
	# Scatter needs specific dropdown
	var hbox_scatter = HBoxContainer.new()
	var lbl_scatter = Label.new()
	lbl_scatter.text = "Configure Scatter Set:"
	hbox_scatter.add_child(lbl_scatter)
	
	opt_scatter_select = OptionButton.new()
	opt_scatter_select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt_scatter_select.item_selected.connect(_on_scatter_selected)
	hbox_scatter.add_child(opt_scatter_select)
	tab_scatter.add_child(hbox_scatter)
	content_scatter_specific = _create_scroll_box(tab_scatter)

# --- UI BUILDER HELPERS ---
func _create_tab(title_str: String) -> VBoxContainer:
	var margin = MarginContainer.new()
	margin.name = title_str
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	tab_container.add_child(margin)
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	return vbox

func _create_override_toggle(parent: Control, text: String, callback: Callable) -> CheckBox:
	var chk = CheckBox.new()
	chk.text = text
	chk.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chk.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	chk.toggled.connect(func(v): 
		_set_biome_flag(chk.name, v)
		callback.call()
	)
	parent.add_child(chk)
	return chk

func _create_scroll_box(parent: Control) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)
	return vbox

# ==============================================================================
# LIFECYCLE & DATA
# ==============================================================================
func open(p_global_params: Dictionary) -> void:
	global_params = p_global_params.duplicate(true)
	biome_overrides = ConfigManager.load_biome_overrides().duplicate(true)
	custom_structures = ConfigManager.load_structures()
	scatter_sets = ConfigManager.load_scatter_sets()
	
	_populate_biome_dropdown()
	_populate_object_dropdowns()
	
	biome_dropdown.select(0)
	_on_biome_selected(0)
	popup_centered()

func _populate_biome_dropdown() -> void:
	biome_dropdown.clear()
	biome_dropdown.add_item("[ * ] Global Default Settings", 0)
	biome_dropdown.set_item_metadata(0, "")
	
	var node_cats = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE]
	var idx = 1
	for cat_key in node_cats:
		var cat = node_cats[cat_key]
		var display_name = cat["name"]
		if biome_overrides.has(cat_key) and biome_overrides[cat_key].get("override_enabled", false):
			display_name = "[ ACTIVE ] " + display_name
			
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(cat["color"])
		var tex = ImageTexture.create_from_image(img)
		
		biome_dropdown.add_icon_item(tex, display_name, idx)
		biome_dropdown.set_item_metadata(idx, cat_key)
		idx += 1

func _populate_object_dropdowns() -> void:
	opt_structure_select.clear()
	var s_keys = custom_structures.keys()
	if s_keys.is_empty():
		opt_structure_select.add_item("No Structures Created", 0)
		opt_structure_select.disabled = true
		current_struct_id = ""
	else:
		opt_structure_select.disabled = false
		for i in range(s_keys.size()):
			opt_structure_select.add_item(custom_structures[s_keys[i]].get("name", "Unnamed"), i)
			opt_structure_select.set_item_metadata(i, s_keys[i])
		current_struct_id = s_keys[0]
		opt_structure_select.select(0)
		
	opt_scatter_select.clear()
	var c_keys = scatter_sets.keys()
	if c_keys.is_empty():
		opt_scatter_select.add_item("No Scatter Sets Created", 0)
		opt_scatter_select.disabled = true
		current_scatter_id = ""
	else:
		opt_scatter_select.disabled = false
		for i in range(c_keys.size()):
			opt_scatter_select.add_item(scatter_sets[c_keys[i]].get("name", "Unnamed"), i)
			opt_scatter_select.set_item_metadata(i, c_keys[i])
		current_scatter_id = c_keys[0]
		opt_scatter_select.select(0)

# ==============================================================================
# UI ROUTING
# ==============================================================================
func _on_biome_selected(idx: int) -> void:
	current_biome_id = biome_dropdown.get_item_metadata(idx)
	var is_global = (current_biome_id == "")
	
	# [FIXED] Toggle visibility of the entire panel!
	toggle_panel.visible = not is_global
	
	if not is_global:
		if not biome_overrides.has(current_biome_id): biome_overrides[current_biome_id] = { "override_enabled": false }
		chk_override_shape.name = "override_shape"
		chk_override_routing.name = "override_routing"
		chk_override_structures.name = "override_structures"
		chk_override_scatter.name = "override_scatter"
		
		chk_override_shape.set_pressed_no_signal(biome_overrides[current_biome_id].get("override_shape", false))
		chk_override_routing.set_pressed_no_signal(biome_overrides[current_biome_id].get("override_routing", false))
		chk_override_structures.set_pressed_no_signal(biome_overrides[current_biome_id].get("override_structures", false))
		chk_override_scatter.set_pressed_no_signal(biome_overrides[current_biome_id].get("override_scatter", false))
		
		biome_overrides[current_biome_id]["override_enabled"] = chk_override_shape.button_pressed or chk_override_routing.button_pressed or chk_override_structures.button_pressed or chk_override_scatter.button_pressed
	
	_rebuild_shape_tab()
	_rebuild_routing_tab()
	_rebuild_structures_tab()
	_rebuild_scatter_tab()

func _on_struct_selected(idx: int) -> void:
	current_struct_id = opt_structure_select.get_item_metadata(idx)
	_rebuild_structures_tab()

func _on_scatter_selected(idx: int) -> void:
	current_scatter_id = opt_scatter_select.get_item_metadata(idx)
	_rebuild_scatter_tab()

# ==============================================================================
# DATA GETTERS/SETTERS
# ==============================================================================
func _get_val(key: String, default_val: Variant) -> Variant:
	if current_biome_id == "": return global_params.get(key, default_val)
	if biome_overrides.has(current_biome_id) and biome_overrides[current_biome_id].has(key):
		return biome_overrides[current_biome_id][key]
	return global_params.get(key, default_val)

func _set_val(key: String, val: Variant) -> void:
	if current_biome_id == "": global_params[key] = val
	else:
		if not biome_overrides.has(current_biome_id): biome_overrides[current_biome_id] = {}
		biome_overrides[current_biome_id][key] = val

func _set_biome_flag(key: String, val: bool) -> void:
	if current_biome_id == "": return
	if not biome_overrides.has(current_biome_id): biome_overrides[current_biome_id] = {}
	biome_overrides[current_biome_id][key] = val
	biome_overrides[current_biome_id]["override_enabled"] = chk_override_shape.button_pressed or chk_override_routing.button_pressed or chk_override_structures.button_pressed or chk_override_scatter.button_pressed
	
	var selected_idx = biome_dropdown.selected
	var raw_name = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE][current_biome_id]["name"]
	biome_dropdown.set_item_text(selected_idx, ("[ ACTIVE ] " if biome_overrides[current_biome_id]["override_enabled"] else "") + raw_name)

# ==============================================================================
# TAB REBUILDERS
# ==============================================================================
func _rebuild_shape_tab() -> void:
	var is_locked = current_biome_id != "" and not chk_override_shape.button_pressed
	content_shape.modulate = Color(1,1,1, 0.4 if is_locked else 1.0)
	
	var schema = [
		{ "name": "room_radius_min", "label": "Min Room Radius", "type": TYPE_INT, "default": _get_val("room_radius_min", 2), "min": 1, "max": 20 },
		{ "name": "room_radius_max", "label": "Max Room Radius", "type": TYPE_INT, "default": _get_val("room_radius_max", 4), "min": 1, "max": 20 },
		{ "name": "enable_room_merging", "label": "Enable Room Merging", "type": TYPE_BOOL, "default": _get_val("enable_room_merging", true) },
		{ "name": "room_merge_tolerance", "label": "Merge Range", "type": TYPE_FLOAT, "default": _get_val("room_merge_tolerance", 0.8), "min": 0.5, "max": 2.0, "step": 0.05 },
		{ "name": "sep_1", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "ratio_square", "label": "Square Weight", "type": TYPE_INT, "default": _get_val("ratio_square", 1), "min": 0 },
		{ "name": "ratio_circle", "label": "Circle Weight", "type": TYPE_INT, "default": _get_val("ratio_circle", 0), "min": 0 },
		{ "name": "ratio_triangle", "label": "Triangle Weight", "type": TYPE_INT, "default": _get_val("ratio_triangle", 0), "min": 0 }
	]
	inputs_shape = SettingsUIBuilder.render_dynamic_section(content_shape, schema, _set_val)
	_set_inputs_disabled(inputs_shape, is_locked)

func _rebuild_routing_tab() -> void:
	var is_locked = current_biome_id != "" and not chk_override_routing.button_pressed
	content_routing.modulate = Color(1,1,1, 0.4 if is_locked else 1.0)
	
	var schema = [
		{ "name": "routing_mode", "label": "Routing Style", "type": TYPE_INT, "default": _get_val("routing_mode", 0), "hint": "enum", "hint_string": "Organic (A*),Orthogonal (L-Path)" },
		{ "name": "allow_diagonal_corridors", "label": "Diagonal Corridors", "type": TYPE_BOOL, "default": _get_val("allow_diagonal_corridors", false) },
		{ "name": "corridor_thickness", "label": "Corridor Thickness", "type": TYPE_INT, "default": _get_val("corridor_thickness", 1), "min": 1, "max": 10 },
		{ "name": "corridor_erosion", "label": "Corridor Erosion", "type": TYPE_FLOAT, "default": _get_val("corridor_erosion", 0.0), "min": 0.0, "max": 0.9, "step": 0.05 },
		{ "name": "corridor_erosion_scale", "label": "Erosion Noise Scale", "type": TYPE_FLOAT, "default": _get_val("corridor_erosion_scale", 0.1), "min": 0.01, "max": 0.5, "step": 0.01 },
		{ "name": "sep_1", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "ca_iterations", "label": "CA Smoothing Passes", "type": TYPE_INT, "default": _get_val("ca_iterations", 0), "min": 0, "max": 10 },
		{ "name": "ca_survive_min", "label": "CA Survive Min", "type": TYPE_INT, "default": _get_val("ca_survive_min", 4), "min": 0, "max": 8 },
		{ "name": "ca_birth_min", "label": "CA Birth Min", "type": TYPE_INT, "default": _get_val("ca_birth_min", 5), "min": 0, "max": 8 }
	]
	inputs_routing = SettingsUIBuilder.render_dynamic_section(content_routing, schema, _set_val)
	_set_inputs_disabled(inputs_routing, is_locked)

func _rebuild_structures_tab() -> void:
	var is_locked = current_biome_id != "" and not chk_override_structures.button_pressed
	content_struct_global.modulate = Color(1,1,1, 0.4 if is_locked else 1.0)
	content_struct_specific.modulate = Color(1,1,1, 0.4 if is_locked else 1.0)
	opt_structure_select.disabled = is_locked
	
	var schema_global = [
		{ "name": "spawn_structure", "label": "Allow Spawning Structures", "type": TYPE_BOOL, "default": _get_val("spawn_structure", false) },
		{ "name": "structure_use_density", "label": "Spawning Mode", "type": TYPE_INT, "default": 1 if _get_val("structure_use_density", false) else 0, "hint": "enum", "hint_string": "Weighted Ratio (Lottery),Independent Density (Organic)" },
		{ "name": "sep_m1", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "master_struct_per_room", "label": "Max Structures Per Room", "type": TYPE_INT, "default": _get_val("master_struct_per_room", 1), "min": 1, "max": 10 },
		{ "name": "master_struct_per_biome", "label": "Max Structures Per Biome", "type": TYPE_INT, "default": _get_val("master_struct_per_biome", 0), "min": 0, "max": 999, "hint_text": "0 = Unlimited" }
	]
	
	var intercept_global = func(k, v):
		if k == "structure_use_density": _set_val(k, v == 1)
		else: _set_val(k, v)
		if k == "structure_use_density": _rebuild_structures_tab()
		
	inputs_struct_global = SettingsUIBuilder.render_dynamic_section(content_struct_global, schema_global, intercept_global)
	_set_inputs_disabled(inputs_struct_global, is_locked)
	
	if current_struct_id != "":
		var is_density = _get_val("structure_use_density", false)
		var k_weight = "weight_" + current_struct_id
		var k_dens = "density_" + current_struct_id
		
		# Quota Keys
		var k_min_spawns = "struct_min_spawns_" + current_struct_id
		var k_max_spawns = "struct_max_spawns_" + current_struct_id
		var k_sym = "struct_symmetry_" + current_struct_id 
		var k_min = "struct_min_dist_" + current_struct_id
		var k_max = "struct_max_dist_" + current_struct_id
		
		var schema_spec = []
		if is_density:
			schema_spec.append({ "name": k_dens, "label": "Spawn Density %", "type": TYPE_FLOAT, "default": _get_val(k_dens, 0.0), "min": 0.0, "max": 1.0, "step": 0.001 })
		else:
			schema_spec.append({ "name": k_weight, "label": "Lottery Weight", "type": TYPE_INT, "default": _get_val(k_weight, 0), "min": 0, "max": 100 })
			
		schema_spec.append({ "name": "sep_s1", "type": TYPE_NIL, "hint": "separator" })
		schema_spec.append({ "name": k_min_spawns, "label": "Guaranteed Minimum Spawns", "type": TYPE_INT, "default": _get_val(k_min_spawns, 0), "min": 0, "max": 99 })
		schema_spec.append({ "name": k_max_spawns, "label": "Maximum Allowed Spawns", "type": TYPE_INT, "default": _get_val(k_max_spawns, 0), "min": 0, "max": 99, "hint_text": "0 = Unlimited" })
		schema_spec.append({ "name": "sep_s2", "type": TYPE_NIL, "hint": "separator" })
		schema_spec.append({ "name": k_sym, "label": "Symmetry Spawning", "type": TYPE_INT, "default": _get_val(k_sym, 0), "hint": "enum", "hint_string": "None,X-Axis (Left/Right),Y-Axis (Top/Bottom),Radial (Point),4-Way Quad" })
		schema_spec.append({ "name": k_min, "label": "Min Wall Distance", "type": TYPE_INT, "default": _get_val(k_min, 0), "min": 0, "max": 20 })
		schema_spec.append({ "name": k_max, "label": "Max Wall Distance", "type": TYPE_INT, "default": _get_val(k_max, 99), "min": 1, "max": 99 })
		
		inputs_struct_specific = SettingsUIBuilder.render_dynamic_section(content_struct_specific, schema_spec, _set_val)
		_set_inputs_disabled(inputs_struct_specific, is_locked)

func _rebuild_scatter_tab() -> void:
	var is_locked = current_biome_id != "" and not chk_override_scatter.button_pressed
	content_scatter_specific.modulate = Color(1,1,1, 0.4 if is_locked else 1.0)
	opt_scatter_select.disabled = is_locked
	
	if current_scatter_id != "":
		var k_mode = "scatter_mode_" + current_scatter_id
		var k_dens = "scatter_density_" + current_scatter_id
		var k_qty = "scatter_qty_" + current_scatter_id
		var k_scope = "scatter_scope_" + current_scatter_id
		var k_min = "scatter_min_dist_" + current_scatter_id
		var k_max = "scatter_max_dist_" + current_scatter_id
		var k_sym = "scatter_symmetry_" + current_scatter_id
		var k_c_chance = "scatter_clump_chance_" + current_scatter_id
		var k_c_max = "scatter_max_clump_" + current_scatter_id
		
		var options_mode = _get_val(k_mode, 0)
		var schema_spec = [
			{ "name": k_mode, "label": "Spawn Mode", "type": TYPE_INT, "default": options_mode, "hint": "enum", "hint_string": "Density (Organic %),Fixed Quantity (Cap)" }
		]
		
		if options_mode == 0:
			schema_spec.append({ "name": k_dens, "label": "Spawn Density %", "type": TYPE_FLOAT, "default": _get_val(k_dens, 0.05), "min": 0.0, "max": 1.0, "step": 0.001 })
		else:
			schema_spec.append({ "name": k_qty, "label": "Fixed Spawn Quantity", "type": TYPE_INT, "default": _get_val(k_qty, 1), "min": 0, "max": 999 })
			schema_spec.append({ "name": k_scope, "label": "Quantity Scope", "type": TYPE_INT, "default": _get_val(k_scope, 0), "hint": "enum", "hint_string": "Per Room,Per Biome / Global" })
			
		schema_spec.append_array([
			{ "name": "sep_s1", "type": TYPE_NIL, "hint": "separator" },
			{ "name": k_min, "label": "Min Wall Distance", "type": TYPE_INT, "default": _get_val(k_min, 0), "min": 0, "max": 20 },
			{ "name": k_max, "label": "Max Wall Distance", "type": TYPE_INT, "default": _get_val(k_max, 99), "min": 1, "max": 99 },
			{ "name": k_sym, "label": "Symmetry Clumping", "type": TYPE_INT, "default": _get_val(k_sym, 0), "hint": "enum", "hint_string": "None,X-Axis (Left/Right),Y-Axis (Top/Bottom),Radial (Point),4-Way" },
			{ "name": "sep_s2", "type": TYPE_NIL, "hint": "separator" },
			{ "name": k_c_chance, "label": "Organic Clump Chance", "type": TYPE_FLOAT, "default": _get_val(k_c_chance, 0.0), "min": 0.0, "max": 1.0, "step": 0.05 },
			{ "name": k_c_max, "label": "Max Clump Size", "type": TYPE_INT, "default": _get_val(k_c_max, 3), "min": 2, "max": 25 }
		])
		
		var intercept = func(k, v):
			_set_val(k, v)
			if k == k_mode: _rebuild_scatter_tab()
			
		inputs_scatter_specific = SettingsUIBuilder.render_dynamic_section(content_scatter_specific, schema_spec, intercept)
		_set_inputs_disabled(inputs_scatter_specific, is_locked)

func _set_inputs_disabled(inputs: Dictionary, disabled: bool) -> void:
	for key in inputs:
		var control = inputs[key]
		if control is Range: control.editable = not disabled
		elif control is BaseButton: control.disabled = disabled
		elif control is LineEdit: control.editable = not disabled

# ==============================================================================
# SAVE HOOKS
# ==============================================================================
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_VISIBILITY_CHANGED:
		if not visible:
			global_settings_changed.emit(global_params)
			biome_settings_changed.emit(biome_overrides)
