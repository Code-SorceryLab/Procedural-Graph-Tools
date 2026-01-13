extends AcceptDialog
class_name PropertyWizard

# Signal to request heavy cleanup
signal purge_requested(key: String, target: String)
signal property_defined(name: String)

# --- UI REFS ---
# We use get_node_or_null to be safe if you haven't perfectly matched the scene tree yet
@onready var tab_container: TabContainer = $TabContainer

@onready var input_name: LineEdit = $"TabContainer/Create New/GridContainer/InputName"
@onready var input_target: OptionButton = $"TabContainer/Create New/GridContainer/InputTarget"
@onready var input_type: OptionButton = $"TabContainer/Create New/GridContainer/InputType"
@onready var lbl_error: Label = $"TabContainer/Create New/LblError"
@onready var create_new: VBoxContainer = $"TabContainer/Create New"

# Manage Tab
@onready var manage: VBoxContainer = $TabContainer/Manage
@onready var schema_tree: Tree = $TabContainer/Manage/SchemaTree
@onready var btn_delete: Button = $TabContainer/Manage/BtnDelete





# --- CONSTANTS ---
const TYPES = [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_COLOR]
const TARGETS = ["NODE", "EDGE", "AGENT", "ZONE"]
const TYPE_NAMES = {
	TYPE_BOOL: "Boolean", TYPE_INT: "Integer", 
	TYPE_FLOAT: "Float", TYPE_STRING: "String", 
	TYPE_COLOR: "Color"
}

func _ready() -> void:
	# 1. SETUP CREATE TAB
	# Re-add the "OK/Create" button manually since we switched to AcceptDialog
	# or just use a button inside the Create VBox.
	# Actually, AcceptDialog has a built-in "OK" button. We can hijack it.
	get_ok_button().text = "Close"
	get_ok_button().pressed.connect(hide)
	
	# We add a custom "Create" button inside the Create Tab for clarity
	var btn_create = Button.new()
	btn_create.text = "Create Property"
	btn_create.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_create.pressed.connect(_on_create_pressed)
	# Add it to the Create VBox (assuming it's the first child of TabContainer)
	create_new.add_child(btn_create)
	
	# [NEW] Create "Purge" Button dynamically (or add in Scene)
	var btn_purge = Button.new()
	btn_purge.text = "Delete Definition & Purge Data (Slower)"
	btn_purge.modulate = Color(1, 0.4, 0.4) # Bright Red
	btn_purge.tooltip_text = "Removes the definition AND iterates through the entire graph to delete values."
	btn_purge.pressed.connect(_on_purge_pressed)
	
	# Add to the Manage VBox (Assuming 'Manage' is the parent of btn_delete)
	manage.add_child(btn_purge)
	
	
	input_target.clear()
	
	for t in TARGETS: input_target.add_item(t.capitalize())
	
	input_type.clear()
	for t in TYPES: input_type.add_item(TYPE_NAMES[t])
	
	input_name.text_changed.connect(func(_t): _validate())
	
	# 2. SETUP MANAGE TAB
	tab_container.tab_changed.connect(_on_tab_changed)
	btn_delete.pressed.connect(_on_delete_pressed)
	
	_setup_tree_columns()

func popup_wizard() -> void:
	input_name.text = ""
	input_target.selected = 0
	input_type.selected = 0
	lbl_error.text = ""
	
	# Refresh List
	_refresh_schema_list()
	
	popup_centered(Vector2(400, 350))
	input_name.grab_focus()

# ==============================================================================
# TAB 1: CREATE LOGIC
# ==============================================================================

func _validate() -> bool:
	var p_name = input_name.text.strip_edges()
	
	if p_name == "":
		lbl_error.text = "Name cannot be empty."
		return false
		
	var regex = RegEx.new()
	regex.compile("^[a-zA-Z0-9_]+$")
	if regex.search(p_name) == null:
		lbl_error.text = "Use only letters, numbers, and _"
		return false
		
	var target = TARGETS[input_target.selected]
	var existing = GraphSettings.get_properties_for_target(target)
	if existing.has(p_name):
		lbl_error.text = "Property '%s' already exists on %s." % [p_name, target]
		return false
		
	lbl_error.text = ""
	return true

func _on_create_pressed() -> void:
	if not _validate(): return
	
	var p_name = input_name.text.strip_edges()
	var target = TARGETS[input_target.selected]
	var type_idx = TYPES[input_type.selected]
	
	var default_val
	match type_idx:
		TYPE_BOOL: default_val = false
		TYPE_INT: default_val = 0
		TYPE_FLOAT: default_val = 0.0
		TYPE_STRING: default_val = ""
		TYPE_COLOR: default_val = Color.WHITE
	
	# Register
	GraphSettings.register_property(p_name, target, type_idx, default_val)
	
	# Notify
	property_defined.emit(p_name)
	
	# Feedback
	lbl_error.text = "Created '%s'!" % p_name
	lbl_error.modulate = Color.GREEN
	await get_tree().create_timer(1.0).timeout
	lbl_error.text = ""
	lbl_error.modulate = Color.RED
	input_name.text = "" # Reset for next entry

# ==============================================================================
# TAB 2: MANAGE LOGIC
# ==============================================================================

func _on_tab_changed(tab: int) -> void:
	if tab == 1: # Manage Tab
		_refresh_schema_list()

func _setup_tree_columns() -> void:
	schema_tree.set_column_title(0, "Property Name")
	schema_tree.set_column_title(1, "Target")
	schema_tree.set_column_title(2, "Type")
	schema_tree.set_column_expand(0, true)
	schema_tree.set_column_expand(1, false)
	schema_tree.set_column_expand(2, false)
	schema_tree.set_column_custom_minimum_width(1, 80)
	schema_tree.set_column_custom_minimum_width(2, 80)

func _refresh_schema_list() -> void:
	schema_tree.clear()
	
	# [FIX] Hide the technical root item so only your actual data is visible
	schema_tree.hide_root = true
	
	var root = schema_tree.create_item()
	
	# Iterate all definitions in GraphSettings
	var all_defs = GraphSettings.property_definitions
	
	for key in all_defs:
		var def = all_defs[key]
		var item = schema_tree.create_item(root)
		item.set_text(0, key)
		item.set_text(1, def.target)
		
		# Convert type int to string name
		var type_name = "Unknown"
		if TYPE_NAMES.has(int(def.type)):
			type_name = TYPE_NAMES[int(def.type)]
		item.set_text(2, type_name)
		
		# Store key metadata for deletion
		item.set_metadata(0, key)

func _on_delete_pressed() -> void:
	var item = schema_tree.get_selected()
	if not item: return
	
	# [FIX] Crash Guard: Ensure this item actually represents a property
	var key = item.get_metadata(0)
	if key == null: return
	

	GraphSettings.unregister_property(key)
	
	_refresh_schema_list()
	property_defined.emit(key) 

func _on_purge_pressed() -> void:
	var item = schema_tree.get_selected()
	if not item: return
	
	# [FIX] Crash Guard: Ensure this item actually represents a property
	var key = item.get_metadata(0)
	if key == null: return
	var target = item.get_text(1) # We stored Target in Column 1 ("NODE", "EDGE", etc.)
	
	# 1. Trigger the Heavy Loop in Controller
	purge_requested.emit(key, target)
	
	# 2. Unregister Definition
	GraphSettings.unregister_property(key)
	
	_refresh_schema_list()
	property_defined.emit(key)
