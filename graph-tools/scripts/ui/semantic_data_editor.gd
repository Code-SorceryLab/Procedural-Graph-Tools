extends AcceptDialog
class_name SemanticDataEditor

# --- SIGNALS (Preserved for your Editor Controller) ---
signal purge_requested(key: String, target: String)
signal property_defined(name: String)

# --- CONSTANTS ---
const TYPES = [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_COLOR]
const TYPE_NAMES = {
	TYPE_BOOL: "Boolean", TYPE_INT: "Integer", 
	TYPE_FLOAT: "Float", TYPE_STRING: "String", 
	TYPE_COLOR: "Color"
}

# --- UI REFS ---
@onready var tab_container: TabContainer = $TabContainer

# Internal references to the dynamically generated trees
var _category_trees: Dictionary = {}
var _property_trees: Dictionary = {}
var _category_del_btns: Dictionary = {} 
var _property_del_btns: Dictionary = {}

# ==============================================================================
# 1. LIFECYCLE & DYNAMIC UI GENERATION
# ==============================================================================

func _ready() -> void:
	get_ok_button().text = "Close"
	
	# 1. Nuke the old legacy UI tabs to save manual editor work
	for child in tab_container.get_children():
		child.queue_free()
		
	# 2. Dynamically build the new Architecture Tabs
	var targets = [
		SemanticRegistry.TARGET_NODE, SemanticRegistry.TARGET_EDGE, 
		SemanticRegistry.TARGET_AGENT, SemanticRegistry.TARGET_ZONE
	]
	
	for target in targets:
		tab_container.add_child(_build_target_tab(target))

func popup_wizard(force_target: String = "") -> void:
	_refresh_all_tabs()
	
	if force_target != "":
		for i in range(tab_container.get_child_count()):
			if tab_container.get_child(i).name.to_upper() == force_target:
				tab_container.current_tab = i
				break
				
	popup_centered(Vector2(550, 600))

# ==============================================================================
# 2. UI BUILDER
# ==============================================================================

func _build_target_tab(target: String) -> Control:
	var vb = VBoxContainer.new()
	vb.name = target.capitalize()
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 15)
	
	# Add some padding
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(margin)
	
	var content = VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(content)

	# --- 1. CATEGORIES SECTION (Types/Tags) ---
	var lbl_cat = Label.new()
	lbl_cat.text = "Categories (Types / Tags)"
	lbl_cat.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	content.add_child(lbl_cat)

	var tree_cat = Tree.new()
	tree_cat.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_cat.columns = 3
	tree_cat.set_column_title(0, "System Key")
	tree_cat.set_column_title(1, "Display Name")
	tree_cat.set_column_title(2, "Color")
	tree_cat.set_column_titles_visible(true)
	tree_cat.hide_root = true
	_category_trees[target] = tree_cat
	content.add_child(tree_cat)

	# Category Inputs
	var hb_cat = HBoxContainer.new()
	var cat_key = LineEdit.new(); cat_key.placeholder_text = "key (e.g. boss)"; cat_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cat_name = LineEdit.new(); cat_name.placeholder_text = "Name (e.g. Boss Room)"; cat_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cat_color = ColorPickerButton.new(); cat_color.custom_minimum_size = Vector2(40, 0); cat_color.color = Color.WHITE
	var cat_add = Button.new(); cat_add.text = "Add"
	var cat_del = Button.new(); cat_del.text = "Delete"
	cat_del.disabled = true # Start disabled
	cat_del.modulate = Color(1, 1, 1, 0.5) # Start grayed out
	_category_del_btns[target] = cat_del # Track it

	hb_cat.add_child(cat_key); hb_cat.add_child(cat_name); hb_cat.add_child(cat_color); hb_cat.add_child(cat_add); hb_cat.add_child(cat_del)
	content.add_child(hb_cat)

	# Bind category signals
	cat_add.pressed.connect(_on_add_category.bind(target, cat_key, cat_name, cat_color))
	cat_del.pressed.connect(_on_del_category.bind(target))
	tree_cat.item_selected.connect(_on_category_selected.bind(target, cat_del))

	content.add_child(HSeparator.new())

	# --- 2. PROPERTIES SECTION (Variables) ---
	var lbl_prop = Label.new()
	lbl_prop.text = "Custom Properties (Variables)"
	lbl_prop.add_theme_color_override("font_color", Color(0.7, 1.0, 0.7))
	content.add_child(lbl_prop)

	var tree_prop = Tree.new()
	tree_prop.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree_prop.columns = 4 # [FIX] Expanded to 4 columns!
	tree_prop.set_column_title(0, "System Key")
	tree_prop.set_column_title(1, "Display Label")
	tree_prop.set_column_title(2, "Data Type")
	tree_prop.set_column_title(3, "Visual Mode")
	tree_prop.set_column_titles_visible(true)
	tree_prop.hide_root = true
	_property_trees[target] = tree_prop
	content.add_child(tree_prop)

	# Property Inputs
	var hb_prop = HBoxContainer.new()
	var prop_key = LineEdit.new(); prop_key.placeholder_text = "key (e.g. lock_lvl)"; prop_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var prop_label = LineEdit.new(); prop_label.placeholder_text = "Label"; prop_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var prop_type = OptionButton.new()
	for t in TYPES: prop_type.add_item(TYPE_NAMES[t])
	
	# [FIX] Add Display Mode Dropdown!
	var prop_display = OptionButton.new()
	prop_display.add_item("Hidden")
	prop_display.add_item("Label")
	prop_display.add_item("Badge")
	
	var prop_add = Button.new(); prop_add.text = "Add"
	var prop_del = Button.new(); prop_del.text = "Delete"
	prop_del.disabled = true # Start disabled
	prop_del.modulate = Color(1, 1, 1, 0.5) # Start grayed out
	_property_del_btns[target] = prop_del # Track it

	hb_prop.add_child(prop_key); hb_prop.add_child(prop_label); hb_prop.add_child(prop_type); hb_prop.add_child(prop_display)
	hb_prop.add_child(prop_add); hb_prop.add_child(prop_del)
	content.add_child(hb_prop)

	# Bind property signals
	prop_add.pressed.connect(_on_add_property.bind(target, prop_key, prop_label, prop_type, prop_display))
	prop_del.pressed.connect(_on_del_property.bind(target))
	tree_prop.item_selected.connect(_on_property_selected.bind(target, prop_del))

	return vb

# ==============================================================================
# 3. REFRESH LOGIC
# ==============================================================================

func _refresh_all_tabs() -> void:
	for target in _category_trees.keys():
		_refresh_category_tree(target)
		_refresh_property_tree(target)

func _refresh_category_tree(target: String) -> void:
	# Lock button because selection is cleared!
	if _category_del_btns.has(target):
		_category_del_btns[target].disabled = true
		_category_del_btns[target].modulate = Color(1, 1, 1, 0.5)
		
	var tree: Tree = _category_trees[target]
	tree.clear()
	var root = tree.create_item()

	var cats = SemanticRegistry.categories[target]
	for key in cats:
		var cat = cats[key]
		var item = tree.create_item(root)
		
		# Add padlock for Core data
		var display_key = key + (" 🔒" if cat.get("is_core", false) else "")
		
		item.set_text(0, display_key)
		item.set_text(1, cat["name"])
		item.set_custom_bg_color(2, cat["color"])
		item.set_metadata(0, key)

func _refresh_property_tree(target: String) -> void:
	# Lock button because selection is cleared!
	if _property_del_btns.has(target):
		_property_del_btns[target].disabled = true
		_property_del_btns[target].modulate = Color(1, 1, 1, 0.5)

	var tree: Tree = _property_trees[target]
	tree.clear()
	var root = tree.create_item()
	var display_names = ["Hidden", "Label", "Badge"]

	var props = SemanticRegistry.properties[target]
	for key in props:
		var prop = props[key]
		var item = tree.create_item(root)
		
		# Add padlock for Core data
		var display_key = key + (" 🔒" if prop.get("is_core", false) else "")
		
		item.set_text(0, display_key)
		item.set_text(1, prop["label"])
		item.set_text(2, TYPE_NAMES.get(prop["type"], "Unknown"))
		item.set_text(3, display_names[prop.get("display", 0)])
		item.set_metadata(0, key)

# ==============================================================================
# 4. INPUT HANDLERS & VALIDATION
# ==============================================================================

func _validate_key(key: String) -> bool:
	if key.strip_edges() == "": return false
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9_]+$")
	return regex.search(key) != null

# ==============================================================================
# SELECTION HANDLERS
# ==============================================================================

func _on_category_selected(target: String, del_btn: Button) -> void:
	var item = _category_trees[target].get_selected()
	if item:
		var key = item.get_metadata(0)
		var is_core = SemanticRegistry.categories[target][key].get("is_core", false)
		del_btn.disabled = is_core
		# Visually gray out if locked, bright red if deletable
		del_btn.modulate = Color(1, 1, 1, 0.5) if is_core else Color(1, 0.4, 0.4)

func _on_property_selected(target: String, del_btn: Button) -> void:
	var item = _property_trees[target].get_selected()
	if item:
		var key = item.get_metadata(0)
		var is_core = SemanticRegistry.properties[target][key].get("is_core", false)
		del_btn.disabled = is_core
		# Visually gray out if locked, bright red if deletable
		del_btn.modulate = Color(1, 1, 1, 0.5) if is_core else Color(1, 0.4, 0.4)

# --- CATEGORY ACTIONS ---

func _on_add_category(target: String, key_edit: LineEdit, name_edit: LineEdit, color_btn: ColorPickerButton) -> void:
	var key = key_edit.text.strip_edges()
	if not _validate_key(key): return
	if SemanticRegistry.categories[target].has(key): return

	var d_name = name_edit.text.strip_edges()
	if d_name == "": d_name = key.capitalize()

	SemanticRegistry.register_category(target, key, d_name, color_btn.color)
	
	key_edit.text = ""
	name_edit.text = ""
	
	SemanticRegistry.save_user_data() # Persist to disk
	_refresh_category_tree(target)
	property_defined.emit(key)

func _on_del_category(target: String) -> void:
	var tree: Tree = _category_trees[target]
	var item = tree.get_selected()
	if not item: return
	var key = item.get_metadata(0)

	SemanticRegistry.remove_category(target, key)
	purge_requested.emit(key, target)
	
	SemanticRegistry.save_user_data() # Persist to disk
	_refresh_category_tree(target)
	property_defined.emit(key)

# --- PROPERTY ACTIONS ---

func _on_add_property(target: String, key_edit: LineEdit, label_edit: LineEdit, type_btn: OptionButton, display_btn: OptionButton) -> void:
	var key = key_edit.text.strip_edges()
	if not _validate_key(key): return
	if SemanticRegistry.properties[target].has(key): return

	var d_label = label_edit.text.strip_edges()
	if d_label == "": d_label = key.capitalize()

	var type_idx = TYPES[type_btn.selected]
	var default_val
	match type_idx:
		TYPE_BOOL: default_val = false
		TYPE_INT: default_val = 0
		TYPE_FLOAT: default_val = 0.0
		TYPE_STRING: default_val = ""
		TYPE_COLOR: default_val = Color.WHITE

	var display_mode = display_btn.selected
	SemanticRegistry.register_property(target, key, d_label, type_idx, default_val, display_mode)
	
	key_edit.text = ""
	label_edit.text = ""
	
	SemanticRegistry.save_user_data() # Persist to disk
	_refresh_property_tree(target)
	property_defined.emit(key)

func _on_del_property(target: String) -> void:
	var tree: Tree = _property_trees[target]
	var item = tree.get_selected()
	if not item: return
	var key = item.get_metadata(0)

	SemanticRegistry.remove_property(target, key)
	purge_requested.emit(key, target)
	
	SemanticRegistry.save_user_data() # Persist to disk
	_refresh_property_tree(target)
	property_defined.emit(key)
