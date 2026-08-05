extends Node
class_name FileController

# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor

@export_group("UI File Tab")
@export var save_btn: Button
@export var save_as_btn: Button
@export var save_selection_btn: Button
@export var load_btn: Button
@export var load_prefab_btn: Button
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
	# Button Connections
	if save_btn: save_btn.pressed.connect(_on_save_button_pressed)
	if save_as_btn: save_as_btn.pressed.connect(_on_save_as_button_pressed)
	if load_btn: load_btn.pressed.connect(_on_load_button_pressed)
	if settings_btn: settings_btn.pressed.connect(_on_settings_button_pressed)
	if save_selection_btn: save_selection_btn.pressed.connect(_on_save_selection_pressed)
	if load_prefab_btn: load_prefab_btn.pressed.connect(_on_load_prefab_pressed)
	
	
	file_dialog.file_selected.connect(_on_file_selected)
	
	# Connect the Gatekeeper
	confirm_discard.confirmed.connect(_on_discard_confirmed)
	
	# Listen for changes
	graph_editor.graph_modified.connect(_on_graph_modified)
	
	# Listen for Ctrl+S from Editor
	# We discard the graph argument since we have access to it via the export var
	graph_editor.request_save_graph.connect(func(_g): _on_save_button_pressed())
	
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

# Standard Save Handler (Used by the Save Button AND Ctrl+S)
func _on_save_button_pressed() -> void:
	if _current_path != "":
		# We know the file, save directly using the universal router!
		_execute_save(_current_path)
	else:
		# We don't know the file, treat as "Save As..."
		_on_save_as_button_pressed()

# Save As Handler (Always prompts the dialog)
func _on_save_as_button_pressed() -> void:
	_is_saving = true
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.title = "Save As..."
	file_dialog.filters = [
		"*.json ; JSON Data", 
		"*.graphml ; GraphML Network", 
		"*.gexf ; GEXF Network"
	]
	
	# If we already have a path, pre-fill it in the dialog!
	if _current_path != "":
		file_dialog.current_path = _current_path
		
	file_dialog.popup_centered()

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

func _on_save_selection_pressed() -> void:
	if graph_editor.selected_nodes.is_empty():
		file_status.text = "Select nodes to save a Prefab!"
		file_status.modulate = GraphSettings.COLOR_UI_ERROR
		return
		
	_is_saving = true
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.title = "Save Selection As Template..."
	file_dialog.filters = ["*.json ; JSON Prefab"]
	file_dialog.popup_centered()

func _on_load_prefab_pressed() -> void:
	_is_saving = false
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.title = "Load Prefab to Stamp"
	file_dialog.filters = ["*.json ; JSON Prefab"]
	file_dialog.popup_centered()


# Public entry point for New Graph (Protected by the Discard Gatekeeper)
func request_new_graph() -> void:
	_try_action(_execute_new_graph)

func _execute_new_graph() -> void:
	if graph_editor:
		graph_editor.new_graph()
	
	_current_path = ""
	if file_status:
		file_status.text = "Ready"
		file_status.modulate = Color.WHITE
		
	_update_dirty_state(false)

# --- FILE OPERATIONS ---

func _on_file_selected(path: String) -> void:
	if file_dialog.title == "Save As...":
		_execute_save(path)
		return
		
	# Save Selection Route
	if file_dialog.title == "Save Selection As Template...":
		if not path.ends_with(".json"): path += ".json"
		var output = GraphSerializer.serialize_selection(graph_editor.graph, graph_editor.selected_nodes)
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(output)
			file.close()
			file_status.text = "Template Saved: " + path.get_file()
			file_status.modulate = GraphSettings.COLOR_UI_SUCCESS
		return
		
	# Load Prefab Route
	if file_dialog.title == "Load Prefab to Stamp":
		_load_prefab_into_clipboard(path)
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

# Converts a saved Graph JSON directly into Clipboard format!
func _load_prefab_into_clipboard(path: String) -> void:
	if not FileAccess.file_exists(path): return
		
	var file = FileAccess.open(path, FileAccess.READ)
	var prefab_graph = GraphSerializer.deserialize(file.get_as_text())
	if not prefab_graph: return
		
	var clip_data = { "nodes": [], "edges": [] }
	
	# Because we used serialize_selection(), the node coordinates ARE the offsets!
	for id in prefab_graph.nodes:
		var n = prefab_graph.nodes[id]
		clip_data["nodes"].append({
			"id": id,
			"type": n.type,
			"offset_x": n.position.x,
			"offset_y": n.position.y,
			"custom_data": n.custom_data.duplicate(true)
		})
		
	for key in prefab_graph.edge_store:
		var e = prefab_graph.edge_store[key]
		clip_data["edges"].append({
			"u": e.u, "v": e.v, "w": e.weight, "dir": true, "data": e.custom.duplicate(true)
		})
		
	DisplayServer.clipboard_set(JSON.stringify(clip_data))
	file_status.text = "Loaded into Stamp Tool!"
	file_status.modulate = GraphSettings.COLOR_UI_SUCCESS
	
	# Automatically switch the user to the Stamp tool!
	# (Ensure your GraphEditor has a method to change tools, or emit a signal here)
	if graph_editor.has_method("set_tool"):
		graph_editor.set_tool("stamp")

func _load_graph(path: String) -> void:
	if not FileAccess.file_exists(path):
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	var json_str = file.get_as_text()
	var new_graph = GraphSerializer.deserialize(json_str)
	
	if new_graph != null:
		graph_editor.load_new_graph(new_graph)
		# SILENT VALIDATION PASS
		GraphValidator.validate(graph_editor.graph, true)
		
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
		# SILENT VALIDATION PASS
		GraphValidator.validate(graph_editor.graph, true)
		
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
		# SILENT VALIDATION PASS
		GraphValidator.validate(graph_editor.graph, true)
		
		file_status.text = "Loaded: " + path.get_file()
		file_status.modulate = GraphSettings.COLOR_UI_SUCCESS
		
		# SUCCESS! We are clean now.
		_current_path = path 
		_update_dirty_state(false)
	else:
		file_status.text = "Error parsing GEXF!"
		file_status.modulate = GraphSettings.COLOR_UI_ERROR
