class_name BiomeDesignerPopup
extends ConfirmationDialog

signal global_settings_changed(new_params: Dictionary)
signal biome_settings_changed(new_biomes: Dictionary)
signal spawn_decks_changed(new_decks: Dictionary)

# --- DATA ---
var global_params: Dictionary = {}
var biome_overrides: Dictionary = {}
var custom_structures: Dictionary = {}
var scatter_sets: Dictionary = {}

var global_spawn_decks: Dictionary = {}

var current_biome_id: String = "" 
var current_deck_node_id: String = ""

# --- UI REFS ---
var biome_dropdown: OptionButton
var toggle_panel: MarginContainer
var toggle_grid: GridContainer

var tab_container: TabContainer
var tab_shape: VBoxContainer
var tab_routing: VBoxContainer
var tab_spawn_decks: VBoxContainer

var chk_override_shape: CheckBox
var chk_override_routing: CheckBox
var chk_override_spawn_decks: CheckBox

var inputs_shape: Dictionary = {}
var inputs_routing: Dictionary = {}
var inputs_deck_node: Dictionary = {}

var content_shape: VBoxContainer
var content_routing: VBoxContainer

# Spawn Deck Specific UI
var deck_tree: Tree
var deck_settings_container: VBoxContainer
var btn_add_pool: Button
var btn_add_struct: Button
var btn_add_scatter: Button
var btn_del_node: Button

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
	var lbl_biome = Label.new()
	lbl_biome.text = "Editing Target:"
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
	toggle_grid.columns = 3
	toggle_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toggle_panel.add_child(toggle_grid)
	
	chk_override_shape = _create_override_toggle(toggle_grid, "Override Shape", _rebuild_shape_tab)
	chk_override_routing = _create_override_toggle(toggle_grid, "Override Routing", _rebuild_routing_tab)
	chk_override_spawn_decks = _create_override_toggle(toggle_grid, "Override Spawn Decks", _refresh_tree)
	
	# 3. TABS
	tab_container = TabContainer.new()
	tab_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(tab_container)
	
	tab_shape = _create_tab("Shape & Rooms")
	tab_routing = _create_tab("Routing & CA")
	tab_spawn_decks = _create_tab("Spawn Decks (Entities & Structures)")
	
	content_shape = _create_scroll_box(tab_shape)
	content_routing = _create_scroll_box(tab_routing)
	_build_spawn_decks_ui()

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
# SPAWN DECK UI SETUP
# ==============================================================================
func _build_spawn_decks_ui() -> void:
	var split = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 250
	tab_spawn_decks.add_child(split)
	
	# LEFT: Tree & Controls
	var left_vbox = VBoxContainer.new()
	split.add_child(left_vbox)
	
	deck_tree = Tree.new()
	deck_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	deck_tree.hide_root = true
	deck_tree.item_selected.connect(_on_tree_item_selected)
	left_vbox.add_child(deck_tree)
	
	var btn_grid = GridContainer.new()
	btn_grid.columns = 2
	left_vbox.add_child(btn_grid)
	
	btn_add_pool = Button.new(); btn_add_pool.text = "+ Pool"
	btn_add_pool.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_add_pool.pressed.connect(func(): _add_spawn_node("pool"))
	btn_grid.add_child(btn_add_pool)
	
	btn_add_struct = Button.new(); btn_add_struct.text = "+ Structure"
	btn_add_struct.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_add_struct.pressed.connect(func(): _add_spawn_node("structure"))
	btn_grid.add_child(btn_add_struct)
	
	btn_add_scatter = Button.new(); btn_add_scatter.text = "+ Scatter"
	btn_add_scatter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_add_scatter.pressed.connect(func(): _add_spawn_node("scatter"))
	btn_grid.add_child(btn_add_scatter)
	
	btn_del_node = Button.new(); btn_del_node.text = "Delete"
	btn_del_node.modulate = Color(1, 0.5, 0.5)
	btn_del_node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_del_node.pressed.connect(_on_delete_node)
	btn_grid.add_child(btn_del_node)
	
	# RIGHT: Dynamic Settings
	var right_scroll = ScrollContainer.new()
	split.add_child(right_scroll)
	
	var right_margin = MarginContainer.new()
	right_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.add_theme_constant_override("margin_left", 15)
	right_scroll.add_child(right_margin)
	
	deck_settings_container = VBoxContainer.new()
	deck_settings_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_margin.add_child(deck_settings_container)

# ==============================================================================
# LIFECYCLE & DATA
# ==============================================================================
func open(p_global_params: Dictionary) -> void:
	global_params = p_global_params.duplicate(true)
	biome_overrides = ConfigManager.load_biome_overrides().duplicate(true)
	global_spawn_decks = ConfigManager.load_spawn_decks().duplicate(true)
	custom_structures = ConfigManager.load_structures()
	scatter_sets = ConfigManager.load_scatter_sets()
	
	_populate_biome_dropdown()
	
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

func _on_biome_selected(idx: int) -> void:
	current_biome_id = biome_dropdown.get_item_metadata(idx)
	var is_global = (current_biome_id == "")
	
	toggle_panel.visible = not is_global
	
	if not is_global:
		if not biome_overrides.has(current_biome_id): biome_overrides[current_biome_id] = { "override_enabled": false }
		chk_override_shape.name = "override_shape"
		chk_override_routing.name = "override_routing"
		chk_override_spawn_decks.name = "override_spawn_decks"
		
		chk_override_shape.set_pressed_no_signal(biome_overrides[current_biome_id].get("override_shape", false))
		chk_override_routing.set_pressed_no_signal(biome_overrides[current_biome_id].get("override_routing", false))
		chk_override_spawn_decks.set_pressed_no_signal(biome_overrides[current_biome_id].get("override_spawn_decks", false))
		
		biome_overrides[current_biome_id]["override_enabled"] = chk_override_shape.button_pressed or chk_override_routing.button_pressed or chk_override_spawn_decks.button_pressed
		
		# Ensure the biome has its own spawn deck dictionary if overriding
		if not biome_overrides[current_biome_id].has("spawn_decks"):
			biome_overrides[current_biome_id]["spawn_decks"] = global_spawn_decks.duplicate(true)
	
	_rebuild_shape_tab()
	_rebuild_routing_tab()
	_refresh_tree()

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
	biome_overrides[current_biome_id]["override_enabled"] = chk_override_shape.button_pressed or chk_override_routing.button_pressed or chk_override_spawn_decks.button_pressed
	
	var selected_idx = biome_dropdown.selected
	var raw_name = SemanticRegistry.categories[SemanticRegistry.TARGET_NODE][current_biome_id]["name"]
	biome_dropdown.set_item_text(selected_idx, ("[ ACTIVE ] " if biome_overrides[current_biome_id]["override_enabled"] else "") + raw_name)

# ==============================================================================
# TABS (Shape & Routing)
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
		{ "name": "ca_iterations", "label": "CA Smoothing Passes", "type": TYPE_INT, "default": _get_val("ca_iterations", 0), "min": 0, "max": 10 }
	]
	inputs_routing = SettingsUIBuilder.render_dynamic_section(content_routing, schema, _set_val)
	_set_inputs_disabled(inputs_routing, is_locked)

# ==============================================================================
# SPAWN DECK LOGIC (Infinite Recursion Tree)
# ==============================================================================
func _get_active_decks() -> Dictionary:
	if current_biome_id == "": return global_spawn_decks
	if not biome_overrides[current_biome_id].has("spawn_decks"):
		biome_overrides[current_biome_id]["spawn_decks"] = {}
	return biome_overrides[current_biome_id]["spawn_decks"]

func _refresh_tree() -> void:
	deck_tree.clear()
	var root = deck_tree.create_item()
	var decks = _get_active_decks()
	
	var is_locked = current_biome_id != "" and not chk_override_spawn_decks.button_pressed
	btn_add_pool.disabled = is_locked
	btn_add_struct.disabled = is_locked
	btn_add_scatter.disabled = is_locked
	btn_del_node.disabled = is_locked
	
	# Pass 1: Build a dictionary of TreeItems
	var item_map = {"": root}
	
	# Find all roots first (parent_id == "")
	var pending_nodes = decks.keys()
	var safety_counter = 0
	
	while pending_nodes.size() > 0 and safety_counter < 1000:
		safety_counter += 1
		for i in range(pending_nodes.size() - 1, -1, -1):
			var n_id = pending_nodes[i]
			var data = decks[n_id]
			var p_id = data.get("parent_id", "")
			
			if item_map.has(p_id):
				var item = deck_tree.create_item(item_map[p_id])
				item.set_metadata(0, n_id)
				
				# Formulate display name
				var prefix = "🗂️ " if data["type"] == "pool" else ("🏠 " if data["type"] == "structure" else "🍄 ")
				item.set_text(0, prefix + data.get("name", "Unnamed Node"))
				
				item_map[n_id] = item
				pending_nodes.remove_at(i)
	
	current_deck_node_id = ""
	_rebuild_spawn_decks_tab()

func _add_spawn_node(type: String) -> void:
	var new_id = "node_" + str(Time.get_unix_time_from_system()) + str(randi() % 1000)
	var parent_id = ""
	
	# If a pool is selected, add to it!
	if current_deck_node_id != "":
		var decks = _get_active_decks()
		if decks.has(current_deck_node_id) and decks[current_deck_node_id]["type"] == "pool":
			parent_id = current_deck_node_id
	
	var new_node = {
		"id": new_id,
		"parent_id": parent_id,
		"type": type,
		"name": "New " + type.capitalize(),
		"ref_id": "",
		"mode": 0, # 0 = Quota/Ratio, 1 = Density
		"quota_min": 1,
		"quota_max": 1,
		"density": 0.1,
		"weight": 10,
		"scope": 0, # 0 = Per Room, 1 = Per Biome
		"min_dist": 0,
		"max_dist": 99,
		"symmetry": 0,
		"clump_chance": 0.0,
		"clump_max": 3
	}
	
	_get_active_decks()[new_id] = new_node
	_refresh_tree()

func _on_delete_node() -> void:
	if current_deck_node_id == "": return
	
	var decks = _get_active_decks()
	
	# Recursively delete children
	var to_delete = [current_deck_node_id]
	var idx = 0
	while idx < to_delete.size():
		var target = to_delete[idx]
		for k in decks.keys():
			if decks[k].get("parent_id", "") == target:
				to_delete.append(k)
		idx += 1
		
	for d_id in to_delete:
		decks.erase(d_id)
		
	current_deck_node_id = ""
	_refresh_tree()

func _on_tree_item_selected() -> void:
	var item = deck_tree.get_selected()
	if item:
		current_deck_node_id = item.get_metadata(0)
		_rebuild_spawn_decks_tab()

func _rebuild_spawn_decks_tab() -> void:
	SettingsUIBuilder.clear_ui(deck_settings_container)
	if current_deck_node_id == "": return
	
	var is_locked = current_biome_id != "" and not chk_override_spawn_decks.button_pressed
	var decks = _get_active_decks()
	var node = decks[current_deck_node_id]
	var type = node.get("type", "pool")
	var is_root = node.get("parent_id", "") == ""
	
	var schema = []
	schema.append({ "name": "name", "label": "Node Name", "type": TYPE_STRING, "default": node.get("name", "") })
	
	# --- [UPDATED] Reference Dropdown Generation ---
	var ref_keys = [""] # Index 0 is always "None"
	if type != "pool":
		var hint_str = "None,"
		var src_dict = custom_structures if type == "structure" else scatter_sets
		
		for k in src_dict.keys():
			hint_str += src_dict[k].get("name", "Unnamed") + ","
			ref_keys.append(k)
			
		hint_str = hint_str.trim_suffix(",")
		
		# Find the integer index of our currently saved string ID
		var current_ref = node.get("ref_id", "")
		var current_idx = ref_keys.find(current_ref)
		if current_idx == -1: current_idx = 0
		
		# We use TYPE_INT so SettingsUIBuilder gives us a dropdown!
		schema.append({ "name": "_ref_index", "label": "Target Asset", "type": TYPE_INT, "default": current_idx, "hint": "enum", "hint_string": hint_str })
		schema.append({ "name": "sep_ref", "type": TYPE_NIL, "hint": "separator" })

	# Mathematical Distribution
	if is_root:
		schema.append({ "name": "mode", "label": "Root Mode", "type": TYPE_INT, "default": node.get("mode", 0), "hint": "enum", "hint_string": "Fixed Quota,Organic Density" })
		if node.get("mode", 0) == 0:
			schema.append({ "name": "quota_min", "label": "Min Quota", "type": TYPE_INT, "default": node.get("quota_min", 1), "min": 0, "max": 999 })
			schema.append({ "name": "quota_max", "label": "Max Quota", "type": TYPE_INT, "default": node.get("quota_max", 1), "min": 0, "max": 999 })
		else:
			schema.append({ "name": "density", "label": "Density %", "type": TYPE_FLOAT, "default": node.get("density", 0.1), "min": 0.0, "max": 1.0, "step": 0.01 })
		schema.append({ "name": "scope", "label": "Quota Scope", "type": TYPE_INT, "default": node.get("scope", 0), "hint": "enum", "hint_string": "Per Room,Per Biome" })
	else:
		schema.append({ "name": "weight", "label": "Ratio Weight vs Siblings", "type": TYPE_INT, "default": node.get("weight", 10), "min": 0, "max": 100 })
		
	# Placement Constraints
	schema.append({ "name": "sep_sp", "type": TYPE_NIL, "hint": "separator" })
	schema.append({ "name": "min_dist", "label": "Min Wall Distance", "type": TYPE_INT, "default": node.get("min_dist", 0), "min": 0, "max": 20 })
	schema.append({ "name": "max_dist", "label": "Max Wall Distance", "type": TYPE_INT, "default": node.get("max_dist", 99), "min": 1, "max": 99 })
	schema.append({ "name": "symmetry", "label": "Symmetry", "type": TYPE_INT, "default": node.get("symmetry", 0), "hint": "enum", "hint_string": "None,X-Axis,Y-Axis,Radial,4-Way" })
	
	if type == "scatter":
		schema.append({ "name": "clump_chance", "label": "Clump Chance %", "type": TYPE_FLOAT, "default": node.get("clump_chance", 0.0), "min": 0.0, "max": 1.0, "step": 0.05 })
		schema.append({ "name": "clump_max", "label": "Max Clump Size", "type": TYPE_INT, "default": node.get("clump_max", 3), "min": 1, "max": 20 })

	# Intercept changes to update specific node
	var intercept = func(k, v):
		var act_decks = _get_active_decks()
		if act_decks.has(current_deck_node_id):
			
			# Catch the fake "_ref_index" property and translate it back to the string ID!
			if k == "_ref_index":
				act_decks[current_deck_node_id]["ref_id"] = ref_keys[v]
			else:
				act_decks[current_deck_node_id][k] = v
			
			# If name or mode changed, rebuild visually
			if k == "name":
				var item = deck_tree.get_selected()
				if item:
					var prefix = "🗂️ " if type == "pool" else ("🏠 " if type == "structure" else "🍄 ")
					item.set_text(0, prefix + v)
			elif k == "mode":
				_rebuild_spawn_decks_tab()

	inputs_deck_node = SettingsUIBuilder.render_dynamic_section(deck_settings_container, schema, intercept)
	_set_inputs_disabled(inputs_deck_node, is_locked)

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
			spawn_decks_changed.emit(global_spawn_decks)
