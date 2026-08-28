class_name BiomeDesignerPopup
extends ConfirmationDialog

signal global_settings_changed(new_params: Dictionary)
signal biome_settings_changed(new_biomes: Dictionary)
signal spawn_decks_changed(new_decks: Dictionary)
signal room_decks_changed(new_decks: Dictionary)
signal trigger_settings_saved(trigger_id: String, trigger_data: Dictionary)




# --- DATA ---
var global_params: Dictionary = {}
var biome_overrides: Dictionary = {}
var custom_structures: Dictionary = {}
var scatter_sets: Dictionary = {}
var custom_rooms: Dictionary = {} 

var global_spawn_decks: Dictionary = {}
var global_room_decks: Dictionary = {} 

var current_biome_id: String = "" 
var _wfc_palettes_cache: Array = []

var _is_trigger_mode: bool = false
var _current_trigger_id: String = ""
var _current_trigger_data: Dictionary = {}

# --- UI REFS ---
var biome_dropdown: OptionButton
var toggle_panel: MarginContainer
var toggle_grid: GridContainer

var tab_container: TabContainer
var tab_shape: VBoxContainer
var tab_routing: VBoxContainer
var tab_spawn_decks: VBoxContainer
var tab_trigger: VBoxContainer
var content_trigger: VBoxContainer

var chk_override_shape: CheckBox
var chk_override_routing: CheckBox
var chk_override_spawn_decks: CheckBox
var chk_override_wfc: CheckBox

var inputs_shape: Dictionary = {}
var inputs_routing: Dictionary = {}
var inputs_wfc: Dictionary = {}

var content_shape: VBoxContainer
var content_routing: VBoxContainer
var content_wfc: VBoxContainer




# Dual Tree State
var _trees: Dictionary = {}
var _settings_containers: Dictionary = {}
var _current_deck_nodes: Dictionary = {"room": "", "spawn": ""}
var _btn_groups: Dictionary = {}

func _init() -> void:
	title = "Biome & Generation Designer"
	min_size = Vector2(850, 700)
	transient = true
	exclusive = true
	
	var main_vbox = VBoxContainer.new()
	add_child(main_vbox)
	
	# 1. TOP BAR: BIOME SELECTOR
	var top_hbox = HBoxContainer.new()
	main_vbox.add_child(top_hbox)
	var lbl_biome = Label.new(); lbl_biome.text = "Editing Target:"
	top_hbox.add_child(lbl_biome)
	
	biome_dropdown = OptionButton.new()
	biome_dropdown.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	biome_dropdown.item_selected.connect(_on_biome_selected)
	top_hbox.add_child(biome_dropdown)
	main_vbox.add_child(HSeparator.new())
	
	# 2. OVERRIDE TOGGLES
	toggle_panel = MarginContainer.new()
	toggle_panel.add_theme_constant_override("margin_bottom", 5)
	main_vbox.add_child(toggle_panel)
	toggle_grid = GridContainer.new()
	toggle_grid.columns = 2 # [CHANGED] from 3 to 2 so the 4 toggles form a perfect 2x2 square
	toggle_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_panel.add_child(toggle_grid)
	
	chk_override_shape = _create_override_toggle(toggle_grid, "Override Shape & Rooms", _rebuild_shape_tab)
	chk_override_routing = _create_override_toggle(toggle_grid, "Override Routing", _rebuild_routing_tab)
	chk_override_spawn_decks = _create_override_toggle(toggle_grid, "Override Spawn Decks", _refresh_tree.bind("spawn"))
	chk_override_wfc = _create_override_toggle(toggle_grid, "Override Textural WFC", _rebuild_wfc_tab)
	
	# 3. TABS
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(tab_container)
	
	tab_shape = _create_tab("Shape & Rooms")
	tab_routing = _create_tab("Routing & CA")
	tab_spawn_decks = _create_tab("Spawn Decks (Entities & Structures)")
	var tab_wfc = _create_tab("Textural WFC")
	
	# --- TRIGGER GLOBALS TAB ---
	tab_trigger = _create_tab("Trigger Globals")
	content_trigger = _create_scroll_box(tab_trigger)
	
	# Routing Tab
	content_routing = _create_scroll_box(tab_routing)
	
	# WFC Tab [NEW]
	content_wfc = _create_scroll_box(tab_wfc)
	
	# Shape Tab (Settings on top, Tree on bottom)
	content_shape = VBoxContainer.new()
	tab_shape.add_child(content_shape)
	tab_shape.add_child(HSeparator.new())
	_build_deck_ui(tab_shape, "room")
	
	# Spawn Deck Tab
	_build_deck_ui(tab_spawn_decks, "spawn")
	
	

func _create_tab(title_str: String) -> VBoxContainer:
	var margin = MarginContainer.new()
	margin.name = title_str
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	tab_container.add_child(margin)
	var vbox = VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
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
# DUAL DECK UI SETUP
# ==============================================================================
func _build_deck_ui(parent: Control, deck_type: String) -> void:
	var split = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 250
	parent.add_child(split)
	
	# LEFT: Tree & Controls
	var left_vbox = VBoxContainer.new()
	split.add_child(left_vbox)
	
	var tree = Tree.new()
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.hide_root = true
	tree.item_selected.connect(_on_tree_item_selected.bind(deck_type))
	left_vbox.add_child(tree)
	_trees[deck_type] = tree
	
	var btn_grid = GridContainer.new()
	btn_grid.columns = 2
	left_vbox.add_child(btn_grid)
	
	var btns = []
	var btn_pool = Button.new(); btn_pool.text = "+ Pool"; btn_pool.pressed.connect(_add_spawn_node.bind(deck_type, "pool"))
	btn_pool.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_grid.add_child(btn_pool); btns.append(btn_pool)
	
	if deck_type == "room":
		var btn_pre = Button.new(); btn_pre.text = "+ Preset"; btn_pre.pressed.connect(_add_spawn_node.bind(deck_type, "preset"))
		var btn_custom = Button.new(); btn_custom.text = "+ Custom Room"; btn_custom.pressed.connect(_add_spawn_node.bind(deck_type, "custom_room"))
		btn_pre.size_flags_horizontal = Control.SIZE_EXPAND_FILL; btn_custom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_grid.add_child(btn_pre); btn_grid.add_child(btn_custom)
		btns.append(btn_pre); btns.append(btn_custom)
	else:
		var btn_str = Button.new(); btn_str.text = "+ Structure"; btn_str.pressed.connect(_add_spawn_node.bind(deck_type, "structure"))
		var btn_scatter = Button.new(); btn_scatter.text = "+ Scatter"; btn_scatter.pressed.connect(_add_spawn_node.bind(deck_type, "scatter"))
		btn_str.size_flags_horizontal = Control.SIZE_EXPAND_FILL; btn_scatter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn_grid.add_child(btn_str); btn_grid.add_child(btn_scatter)
		btns.append(btn_str); btns.append(btn_scatter)
		
	var btn_del = Button.new(); btn_del.text = "Delete"; btn_del.modulate = Color(1, 0.5, 0.5)
	btn_del.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_del.pressed.connect(_on_delete_node.bind(deck_type))
	btn_grid.add_child(btn_del); btns.append(btn_del)
	
	_btn_groups[deck_type] = btns
	
	# RIGHT: Dynamic Settings
	var right_scroll = ScrollContainer.new()
	split.add_child(right_scroll)
	var right_margin = MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_left", 15)
	right_scroll.add_child(right_margin)
	
	var settings_vbox = VBoxContainer.new()
	settings_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.add_child(settings_vbox)
	_settings_containers[deck_type] = settings_vbox

# ==============================================================================
# LIFECYCLE & DATA
# ==============================================================================
func open(p_global_params: Dictionary) -> void:
	_is_trigger_mode = false
	title = "Biome & Generation Designer"
	
	# [FIXED] Fetch the MarginContainer (the direct child of the TabContainer)
	var trigger_tab_margin = tab_trigger.get_parent()
	tab_container.set_tab_hidden(tab_container.get_tab_idx_from_control(trigger_tab_margin), true)
	
	global_params = p_global_params.duplicate(true)
	biome_overrides = ConfigManager.load_biome_overrides().duplicate(true)
	global_spawn_decks = ConfigManager.load_spawn_decks().duplicate(true)
	global_room_decks = ConfigManager.load_room_decks().duplicate(true)
	custom_structures = ConfigManager.load_structures()
	scatter_sets = ConfigManager.load_scatter_sets()
	custom_rooms = ConfigManager.load_custom_rooms()
	
	# Auto-Populate Default Room Decks if entirely empty
	if global_room_decks.is_empty():
		var p_id = "node_" + str(Time.get_unix_time_from_system())
		global_room_decks[p_id] = { "id": p_id, "parent_id": "", "type": "pool", "name": "Standard Rooms", "mode": 0, "quota_min": 1, "quota_max": 1, "scope": 0 }
		global_room_decks[p_id+"sq"] = { "id": p_id+"sq", "parent_id": p_id, "type": "preset", "name": "Square Room", "ref_id": "preset_square", "weight": 10 }
		global_room_decks[p_id+"ci"] = { "id": p_id+"ci", "parent_id": p_id, "type": "preset", "name": "Circle Room", "ref_id": "preset_circle", "weight": 5 }
		global_room_decks[p_id+"tr"] = { "id": p_id+"tr", "parent_id": p_id, "type": "preset", "name": "Triangle Room", "ref_id": "preset_triangle", "weight": 0 }
	
	_populate_biome_dropdown()
	biome_dropdown.select(0)
	_on_biome_selected(0)
	popup_centered()

func open_for_trigger(trigger_id: String, trigger_data: Dictionary) -> void:
	_is_trigger_mode = true
	_current_trigger_id = trigger_id
	_current_trigger_data = trigger_data.duplicate(true)
	
	title = "Trigger Designer: " + trigger_data.get("name", "Trigger")
	
	var trigger_tab_margin = tab_trigger.get_parent()
	tab_container.set_tab_hidden(tab_container.get_tab_idx_from_control(trigger_tab_margin), false)
	
	# 1. MAP SANDBOX DATA (The Trigger's local memory)
	global_params = _current_trigger_data.get("global_overrides", {})
	biome_overrides = _current_trigger_data.get("biome_overrides", {})
	
	if _current_trigger_data.has("global_spawn_decks"):
		global_spawn_decks = _current_trigger_data["global_spawn_decks"].duplicate(true)
	else:
		global_spawn_decks = ConfigManager.load_spawn_decks()
		
	if _current_trigger_data.has("global_room_decks"):
		global_room_decks = _current_trigger_data["global_room_decks"].duplicate(true)
	else:
		global_room_decks = ConfigManager.load_room_decks()
	
	# 2. LOAD READ-ONLY REFERENCES (So dropdowns work)
	custom_structures = ConfigManager.load_structures()
	scatter_sets = ConfigManager.load_scatter_sets()
	custom_rooms = ConfigManager.load_custom_rooms()
	
	# 3. FALLBACKS & UI SETUP
	if global_room_decks.is_empty():
		var p_id = "node_fallback"
		global_room_decks[p_id] = { "id": p_id, "parent_id": "", "type": "pool", "name": "Standard Rooms", "mode": 0, "quota_min": 1, "quota_max": 1, "scope": 0 }
	
	_rebuild_trigger_tab()
	_populate_biome_dropdown()
	biome_dropdown.select(0)
	_on_biome_selected(0)
	popup_centered()

func _rebuild_trigger_tab() -> void:
	SettingsUIBuilder.clear_ui(content_trigger)
	var schema = [
		{ "name": "realizer_seed", "label": "Seed Override (Empty = Random)", "type": TYPE_STRING, "default": _get_val("realizer_seed", "") },
		{ "name": "progression_enabled", "label": "Enable Progression & Locks", "type": TYPE_BOOL, "default": _get_val("progression_enabled", true) },
		{ "name": "progression_max_locks", "label": "Max Locks", "type": TYPE_INT, "default": _get_val("progression_max_locks", 0), "min": 0, "max": 20 }
	]
	SettingsUIBuilder.render_dynamic_section(content_trigger, schema, _set_val)

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

func _on_biome_selected(idx: int) -> void:
	current_biome_id = biome_dropdown.get_item_metadata(idx)
	var is_global = (current_biome_id == "")
	toggle_panel.visible = not is_global
	
	if not is_global:
		if not biome_overrides.has(current_biome_id): biome_overrides[current_biome_id] = { "override_enabled": false }
		chk_override_shape.name = "override_shape"
		chk_override_routing.name = "override_routing"
		chk_override_spawn_decks.name = "override_spawn_decks"
		chk_override_wfc.name = "override_wfc"
		
		chk_override_shape.set_pressed_no_signal(biome_overrides[current_biome_id].get("override_shape", false))
		chk_override_routing.set_pressed_no_signal(biome_overrides[current_biome_id].get("override_routing", false))
		chk_override_spawn_decks.set_pressed_no_signal(biome_overrides[current_biome_id].get("override_spawn_decks", false))
		chk_override_wfc.set_pressed_no_signal(biome_overrides[current_biome_id].get("override_wfc", false))
		
		biome_overrides[current_biome_id]["override_enabled"] = chk_override_shape.button_pressed or chk_override_routing.button_pressed or chk_override_spawn_decks.button_pressed or chk_override_wfc.button_pressed
		
		if not biome_overrides[current_biome_id].has("spawn_decks"): biome_overrides[current_biome_id]["spawn_decks"] = global_spawn_decks.duplicate(true)
		if not biome_overrides[current_biome_id].has("room_decks"): biome_overrides[current_biome_id]["room_decks"] = global_room_decks.duplicate(true)
	
	_rebuild_shape_tab()
	_rebuild_routing_tab()
	_rebuild_wfc_tab()
	_refresh_tree("spawn")
	_refresh_tree("room")

func _get_val(key: String, default_val: Variant) -> Variant:
	if current_biome_id == "": return global_params.get(key, default_val)
	if biome_overrides.has(current_biome_id) and biome_overrides[current_biome_id].has(key): return biome_overrides[current_biome_id][key]
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
	biome_overrides[current_biome_id]["override_enabled"] = chk_override_shape.button_pressed or chk_override_routing.button_pressed or chk_override_spawn_decks.button_pressed or chk_override_wfc.button_pressed
	
	var selected_idx = biome_dropdown.selected
	var raw_name = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE][current_biome_id]["name"]
	biome_dropdown.set_item_text(selected_idx, ("[ ACTIVE ] " if biome_overrides[current_biome_id]["override_enabled"] else "") + raw_name)

# ==============================================================================
# TABS (Shape & Routing)
# ==============================================================================
func _rebuild_shape_tab() -> void:
	var is_locked = current_biome_id != "" and not chk_override_shape.button_pressed
	content_shape.modulate = Color(1,1,1, 0.4 if is_locked else 1.0)
	
	SettingsUIBuilder.clear_ui(content_shape)
	var schema = [
		{ "name": "room_radius_min", "label": "Min Room Radius", "type": TYPE_INT, "default": _get_val("room_radius_min", 2), "min": 1, "max": 20 },
		{ "name": "room_radius_max", "label": "Max Room Radius", "type": TYPE_INT, "default": _get_val("room_radius_max", 4), "min": 1, "max": 20 },
		{ "name": "enable_room_merging", "label": "Enable Room Merging", "type": TYPE_BOOL, "default": _get_val("enable_room_merging", true) },
		{ "name": "room_merge_tolerance", "label": "Merge Range", "type": TYPE_FLOAT, "default": _get_val("room_merge_tolerance", 0.8), "min": 0.5, "max": 2.0, "step": 0.05 }
	]
	inputs_shape = SettingsUIBuilder.render_dynamic_section(content_shape, schema, _set_val)
	_set_inputs_disabled(inputs_shape, is_locked)
	_refresh_tree("room") # Update tree lock state too

func _rebuild_routing_tab() -> void:
	var is_locked = current_biome_id != "" and not chk_override_routing.button_pressed
	content_routing.modulate = Color(1,1,1, 0.4 if is_locked else 1.0)
	
	var schema = [
		{ "name": "routing_mode", "label": "Routing Style", "type": TYPE_INT, "default": _get_val("routing_mode", 0), "hint": "enum", "hint_string": "Organic (A*),Orthogonal (L-Path)" },
		{ "name": "allow_diagonal_corridors", "label": "Diagonal Corridors", "type": TYPE_BOOL, "default": _get_val("allow_diagonal_corridors", false) },
		{ "name": "corridor_thickness", "label": "Corridor Thickness", "type": TYPE_INT, "default": _get_val("corridor_thickness", 1), "min": 1, "max": 10 },
		{ "name": "corridor_erosion", "label": "Corridor Erosion", "type": TYPE_FLOAT, "default": _get_val("corridor_erosion", 0.0), "min": 0.0, "max": 0.9, "step": 0.05 },
		{ "name": "ca_iterations", "label": "CA Smoothing Passes", "type": TYPE_INT, "default": _get_val("ca_iterations", 0), "min": 0, "max": 10 }
	]
	
	# --- Intercept the dropdown string and force it into an Integer ---
	var intercept = func(k, v):
		if k == "routing_mode":
			var val = max(0, ["Organic (A*)", "Orthogonal (L-Path)"].find(v)) if typeof(v) == TYPE_STRING else int(v)
			_set_val(k, val)
		else:
			_set_val(k, v)
			
	inputs_routing = SettingsUIBuilder.render_dynamic_section(content_routing, schema, intercept)
	_set_inputs_disabled(inputs_routing, is_locked)


func _rebuild_wfc_tab() -> void:
	var is_locked = current_biome_id != "" and not chk_override_wfc.button_pressed
	content_wfc.modulate = Color(1,1,1, 0.4 if is_locked else 1.0)
	
	SettingsUIBuilder.clear_ui(content_wfc)
	
	# Fetch all saved WFC patterns directly from the config manager
	var palettes = ConfigManager.load_textural_palettes().keys()
	_wfc_palettes_cache = ["None (Default Walls/Floors)"]
	_wfc_palettes_cache.append_array(palettes)
	
	var hint_str = ",".join(_wfc_palettes_cache)
	
	# Find which index we are currently set to
	var current_ref = _get_val("wfc_palette_ref", "")
	var current_idx = max(0, _wfc_palettes_cache.find(current_ref))
	
	var schema = [
		{ "name": "_wfc_palette_idx", "label": "Active Textural Palette", "type": TYPE_INT, "default": current_idx, "hint": "enum", "hint_string": hint_str }
	]
	
	var intercept = func(k, v):
		if k == "_wfc_palette_idx":
			var idx = int(v) if typeof(v) != TYPE_STRING else max(0, _wfc_palettes_cache.find(v))
			var ref_str = _wfc_palettes_cache[idx] if idx > 0 and idx < _wfc_palettes_cache.size() else ""
			_set_val("wfc_palette_ref", ref_str)
		else:
			_set_val(k, v)
			
	inputs_wfc = SettingsUIBuilder.render_dynamic_section(content_wfc, schema, intercept)
	_set_inputs_disabled(inputs_wfc, is_locked)
# ==============================================================================
# DUAL DECK LOGIC 
# ==============================================================================
func _get_active_decks(deck_type: String) -> Dictionary:
	var key = "spawn_decks" if deck_type == "spawn" else "room_decks"
	var glob = global_spawn_decks if deck_type == "spawn" else global_room_decks
	
	if current_biome_id == "": return glob
	if not biome_overrides[current_biome_id].has(key): biome_overrides[current_biome_id][key] = {}
	return biome_overrides[current_biome_id][key]

func _refresh_tree(deck_type: String) -> void:
	var tree = _trees[deck_type]
	tree.clear()
	var root = tree.create_item()
	var decks = _get_active_decks(deck_type)
	
	var is_locked = false
	if current_biome_id != "":
		is_locked = not chk_override_spawn_decks.button_pressed if deck_type == "spawn" else not chk_override_shape.button_pressed
		
	for btn in _btn_groups[deck_type]: btn.disabled = is_locked
	
	var item_map = {"": root}
	var pending_nodes = decks.keys()
	var safety_counter = 0
	
	while pending_nodes.size() > 0 and safety_counter < 1000:
		safety_counter += 1
		for i in range(pending_nodes.size() - 1, -1, -1):
			var n_id = pending_nodes[i]
			var data = decks[n_id]
			var p_id = data.get("parent_id", "")
			
			if item_map.has(p_id):
				var item = tree.create_item(item_map[p_id])
				item.set_metadata(0, n_id)
				var prefix = "🗂️ " if data["type"] == "pool" else ("🏠 " if data["type"] in ["structure", "preset"] else ("🍄 " if data["type"] == "scatter" else "🏰 "))
				item.set_text(0, prefix + data.get("name", "Unnamed Node"))
				item_map[n_id] = item
				pending_nodes.remove_at(i)
	
	_current_deck_nodes[deck_type] = ""
	_rebuild_deck_settings(deck_type)

func _add_spawn_node(deck_type: String, item_type: String) -> void:
	var new_id = "node_" + str(Time.get_unix_time_from_system()) + str(randi() % 1000)
	var parent_id = ""
	
	var curr_node = _current_deck_nodes[deck_type]
	var decks = _get_active_decks(deck_type)
	if curr_node != "" and decks.has(curr_node) and decks[curr_node]["type"] == "pool":
		parent_id = curr_node
	
	var new_node = {
		"id": new_id, "parent_id": parent_id, "type": item_type,
		"name": "New " + item_type.capitalize(), "ref_id": "",
		"mode": 0, "quota_min": 1, "quota_max": 1, "density": 0.1,
		"weight": 10, "scope": 0, "min_dist": 0, "max_dist": 99,
		"symmetry": 0, "clump_chance": 0.0, "clump_max": 3
	}
	decks[new_id] = new_node
	_refresh_tree(deck_type)

func _on_delete_node(deck_type: String) -> void:
	var curr_node = _current_deck_nodes[deck_type]
	if curr_node == "": return
	
	var decks = _get_active_decks(deck_type)
	var to_delete = [curr_node]
	var idx = 0
	while idx < to_delete.size():
		var target = to_delete[idx]
		for k in decks.keys():
			if decks[k].get("parent_id", "") == target: to_delete.append(k)
		idx += 1
		
	for d_id in to_delete: decks.erase(d_id)
	_current_deck_nodes[deck_type] = ""
	_refresh_tree(deck_type)

func _on_tree_item_selected(deck_type: String) -> void:
	var item = _trees[deck_type].get_selected()
	if item:
		_current_deck_nodes[deck_type] = item.get_metadata(0)
		_rebuild_deck_settings(deck_type)

func _rebuild_deck_settings(deck_type: String) -> void:
	var container = _settings_containers[deck_type]
	SettingsUIBuilder.clear_ui(container)
	var curr_node = _current_deck_nodes[deck_type]
	if curr_node == "": return
	
	var is_locked = false
	if current_biome_id != "":
		is_locked = not chk_override_spawn_decks.button_pressed if deck_type == "spawn" else not chk_override_shape.button_pressed
		
	var decks = _get_active_decks(deck_type)
	var node = decks[curr_node]
	var type = node.get("type", "pool")
	var is_root = node.get("parent_id", "") == ""
	
	var schema = []
	schema.append({ "name": "name", "label": "Node Name", "type": TYPE_STRING, "default": node.get("name", "") })
	
	var ref_keys = [""]
	var hint_str = "None" # [FIXED] Hoisted to outer scope so the lambda can access it safely!
	
	if type != "pool":
		hint_str = "None,"
		var src_dict = {}
		if type == "structure": src_dict = custom_structures
		elif type == "scatter": src_dict = scatter_sets
		elif type == "custom_room": src_dict = custom_rooms
		elif type == "preset": 
			src_dict = {"preset_square":{"name":"Square"}, "preset_circle":{"name":"Circle"}, "preset_triangle":{"name":"Triangle"}}
			
		for k in src_dict.keys():
			hint_str += src_dict[k].get("name", k) + ","
			ref_keys.append(k)
		hint_str = hint_str.trim_suffix(",")
		
		var current_ref = node.get("ref_id", "")
		var current_idx = max(0, ref_keys.find(current_ref))
		schema.append({ "name": "_ref_index", "label": "Target Asset", "type": TYPE_INT, "default": current_idx, "hint": "enum", "hint_string": hint_str })
		schema.append({ "name": "sep_ref", "type": TYPE_NIL, "hint": "separator" })

	if is_root:
		# [FIXED] Wrapped all data fetches in strict int/float casts
		var current_mode = int(node.get("mode", 0))
		schema.append({ "name": "mode", "label": "Root Mode", "type": TYPE_INT, "default": current_mode, "hint": "enum", "hint_string": "Fixed Quota,Organic Density" })
		if current_mode == 0:
			schema.append({ "name": "quota_min", "label": "Min Quota", "type": TYPE_INT, "default": int(node.get("quota_min", 1)), "min": 0, "max": 999 })
			schema.append({ "name": "quota_max", "label": "Max Quota", "type": TYPE_INT, "default": int(node.get("quota_max", 1)), "min": 0, "max": 999 })
		else:
			schema.append({ "name": "density", "label": "Density %", "type": TYPE_FLOAT, "default": float(node.get("density", 0.1)), "min": 0.0, "max": 1.0, "step": 0.01 })
		schema.append({ "name": "scope", "label": "Quota Scope", "type": TYPE_INT, "default": int(node.get("scope", 0)), "hint": "enum", "hint_string": "Per Room,Per Biome" })
	else:
		schema.append({ "name": "weight", "label": "Ratio Weight vs Siblings", "type": TYPE_INT, "default": int(node.get("weight", 10)), "min": 0, "max": 100 })
		
	if deck_type == "spawn":
		schema.append({ "name": "sep_sp", "type": TYPE_NIL, "hint": "separator" })
		schema.append({ "name": "min_dist", "label": "Min Wall Distance", "type": TYPE_INT, "default": node.get("min_dist", 0), "min": 0, "max": 20 })
		schema.append({ "name": "max_dist", "label": "Max Wall Distance", "type": TYPE_INT, "default": node.get("max_dist", 99), "min": 1, "max": 99 })
		schema.append({ "name": "symmetry", "label": "Symmetry", "type": TYPE_INT, "default": node.get("symmetry", 0), "hint": "enum", "hint_string": "None,X-Axis,Y-Axis,Radial,4-Way" })
		if type == "scatter":
			schema.append({ "name": "clump_chance", "label": "Clump Chance %", "type": TYPE_FLOAT, "default": node.get("clump_chance", 0.0), "min": 0.0, "max": 1.0, "step": 0.05 })
			schema.append({ "name": "clump_max", "label": "Max Clump Size", "type": TYPE_INT, "default": node.get("clump_max", 3), "min": 1, "max": 20 })

	var intercept = func(k, v):
		var act_decks = _get_active_decks(deck_type)
		if act_decks.has(curr_node):
			
			# Safely translate Strings back to Integers for dropdowns
			if k == "_ref_index":
				var idx = max(0, Array(hint_str.split(",")).find(v)) if typeof(v) == TYPE_STRING else int(v)
				act_decks[curr_node]["ref_id"] = ref_keys[idx]
			elif k == "mode":
				act_decks[curr_node][k] = max(0, ["Fixed Quota", "Organic Density"].find(v)) if typeof(v) == TYPE_STRING else int(v)
				_rebuild_deck_settings(deck_type)
			elif k == "scope":
				act_decks[curr_node][k] = max(0, ["Per Room", "Per Biome"].find(v)) if typeof(v) == TYPE_STRING else int(v)
			elif k == "symmetry":
				act_decks[curr_node][k] = max(0, ["None", "X-Axis", "Y-Axis", "Radial", "4-Way"].find(v)) if typeof(v) == TYPE_STRING else int(v)
			else: 
				act_decks[curr_node][k] = v
			
			if k == "name":
				var item = _trees[deck_type].get_selected()
				if item:
					var prefix = "🗂️ " if type == "pool" else ("🏠 " if type in ["structure", "preset"] else ("🍄 " if type == "scatter" else "🏰 "))
					item.set_text(0, prefix + v)
			elif k == "mode": _rebuild_deck_settings(deck_type)

	var inputs = SettingsUIBuilder.render_dynamic_section(container, schema, intercept)
	_set_inputs_disabled(inputs, is_locked)

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
			if _is_trigger_mode:
				# Sandbox Mode: Package the edits back into the trigger payload!
				_current_trigger_data["global_overrides"] = global_params
				_current_trigger_data["biome_overrides"] = biome_overrides
				_current_trigger_data["global_spawn_decks"] = global_spawn_decks
				_current_trigger_data["global_room_decks"] = global_room_decks
				trigger_settings_saved.emit(_current_trigger_id, _current_trigger_data)
			else:
				# Normal Mode: Save to Master Configurations
				global_settings_changed.emit(global_params)
				biome_settings_changed.emit(biome_overrides)
				spawn_decks_changed.emit(global_spawn_decks)
				room_decks_changed.emit(global_room_decks)
