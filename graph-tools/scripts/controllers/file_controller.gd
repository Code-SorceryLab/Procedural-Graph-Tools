extends Node
class_name FileController

# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor

@export_group("UI File Tab")
@export var save_btn: Button
@export var load_btn: Button
@export var file_status: Label
@export var file_dialog: FileDialog

@export var settings_btn: Button
@export var confirm_discard: ConfirmationDialog

@export var settings_window: PanelContainer

var _is_saving: bool = true
var _is_dirty: bool = false
var _pending_action: Callable # Stores the function we paused

# Track the current file for Quick Save (Ctrl+S)
var _current_path: String = ""

func _ready() -> void:
	save_btn.pressed.connect(_on_save_button_pressed)
	load_btn.pressed.connect(_on_load_button_pressed)
	settings_btn.pressed.connect(_on_settings_button_pressed)
	
	file_dialog.file_selected.connect(_on_file_selected)
	
	# Connect the Gatekeeper
	confirm_discard.confirmed.connect(_on_discard_confirmed)
	
	# Listen for changes
	graph_editor.graph_modified.connect(_on_graph_modified)
	
	# Listen for Ctrl+S from Editor
	# We discard the graph argument since we have access to it via the export var
	graph_editor.request_save_graph.connect(func(_g): _on_quick_save_requested())
	
	# Initialize
	_update_dirty_state(false)

# --- DIRTY STATE LOGIC ---

func _on_graph_modified() -> void:
	if not _is_dirty:
		_update_dirty_state(true)

func _update_dirty_state(dirty: bool) -> void:
	_is_dirty = dirty
	
	# Visual Feedback
	if _is_dirty:
		if not file_status.text.ends_with("(*)"):
			file_status.text += " (*)"
			file_status.modulate = Color(1, 0.8, 0.4) # Warning Orange
	else:
		# Clean state (usually set after save/load)
		# We don't clear text here because "Saved: file.json" is useful info.
		pass

# --- THE GATEKEEPER ---

func _try_action(action: Callable) -> void:
	if _is_dirty:
		# Stop! Ask permission.
		_pending_action = action
		confirm_discard.popup_centered()
	else:
		# Safe to proceed
		action.call()

func _on_discard_confirmed() -> void:
	# User said "Yes, Discard". Run the paused action.
	if _pending_action.is_valid():
		_pending_action.call()
		_pending_action = Callable()

# --- BUTTON HANDLERS ---

func _on_save_button_pressed() -> void:
	# "Save As..." unified behavior
	_is_saving = true
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.title = "Save As..."
	file_dialog.filters = [
		"*.json ; JSON Data", 
		"*.graphml ; GraphML Network", 
		"*.gexf ; GEXF Network"
	]
	file_dialog.popup_centered()

# Quick Save Handler (Ctrl+S)
func _on_quick_save_requested() -> void:
	if _current_path != "":
		# We know the file, save directly using the universal router!
		_execute_save(_current_path)
	else:
		# We don't know the file, treat as "Save As..."
		_on_save_button_pressed()

func _on_load_button_pressed() -> void:
	# Loading destroys current data -> Use Gatekeeper
	_try_action(_open_load_dialog)

func _open_load_dialog() -> void:
	_is_saving = false
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.title = "Load Dungeon Layout"
	file_dialog.filters = [
		"*.json ; JSON Data",
		"*.graphml ; GraphML Network",
		"*.gexf ; GEXF Network"
	]
	file_dialog.popup_centered()

func _on_settings_button_pressed() -> void:
	settings_window.show_settings()


# --- FILE OPERATIONS ---

func _on_file_selected(path: String) -> void:
	# 1. Handle Unified Save As
	if file_dialog.title == "Save As...":
		_execute_save(path)
		return

	# 2. Handle Load Router
	if file_dialog.title == "Load Dungeon Layout":
		if path.ends_with(".graphml"):
			_load_graphml(path)
		elif path.ends_with(".gexf"):
			_load_gexf(path)
		else:
			if not path.ends_with(".json"): path += ".json"
			_load_graph(path)

# Universal save routing function
func _execute_save(path: String) -> void:
	var output_string = ""
	
	# Route serialization based on extension
	if path.ends_with(".graphml"):
		output_string = GraphSerializer.export_graphml(graph_editor.graph)
	elif path.ends_with(".gexf"):
		output_string = GraphSerializer.export_gexf(graph_editor.graph)
	else:
		if not path.ends_with(".json"): path += ".json"
		output_string = GraphSerializer.serialize(graph_editor.graph)
		
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(output_string)
		file.close()
		
		file_status.text = "Saved: " + path.get_file()
		file_status.modulate = GraphSettings.COLOR_UI_SUCCESS
		
		# SUCCESS! We are clean now.
		_current_path = path # Remember this file
		_update_dirty_state(false)
	else:
		file_status.text = "Error writing file!"
		file_status.modulate = GraphSettings.COLOR_UI_ERROR

func _load_graph(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	var json_str = file.get_as_text()
	var new_graph = GraphSerializer.deserialize(json_str)
	
	if new_graph != null:
		graph_editor.load_new_graph(new_graph)
		
		file_status.text = "Loaded: " + path.get_file()
		file_status.modulate = GraphSettings.COLOR_UI_SUCCESS
		
		# SUCCESS! We are clean now.
		_current_path = path # Remember this file
		_update_dirty_state(false)
	else:
		file_status.text = "Error parsing JSON!"
		file_status.modulate = GraphSettings.COLOR_UI_ERROR

func _load_graphml(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	var xml_str = file.get_as_text()
	var new_graph = GraphSerializer.import_graphml(xml_str)
	
	if new_graph != null:
		graph_editor.load_new_graph(new_graph)
		
		file_status.text = "Loaded: " + path.get_file()
		file_status.modulate = GraphSettings.COLOR_UI_SUCCESS
		
		# SUCCESS! We are clean now.
		_current_path = path # Remember this file
		_update_dirty_state(false)
	else:
		file_status.text = "Error parsing GraphML!"
		file_status.modulate = GraphSettings.COLOR_UI_ERROR

func _load_gexf(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	var xml_str = file.get_as_text()
	var new_graph = GraphSerializer.import_gexf(xml_str)
	
	if new_graph != null:
		graph_editor.load_new_graph(new_graph)
		
		file_status.text = "Loaded: " + path.get_file()
		file_status.modulate = GraphSettings.COLOR_UI_SUCCESS
		
		# SUCCESS! We are clean now.
		_current_path = path 
		_update_dirty_state(false)
	else:
		file_status.text = "Error parsing GEXF!"
		file_status.modulate = GraphSettings.COLOR_UI_ERROR
