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

var _is_saving: bool = true

func _ready() -> void:
	save_btn.pressed.connect(_on_save_button_pressed)
	load_btn.pressed.connect(_on_load_button_pressed)
	file_dialog.file_selected.connect(_on_file_selected)

func _on_save_button_pressed() -> void:
	_is_saving = true
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.popup_centered()

func _on_load_button_pressed() -> void:
	_is_saving = false
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.popup_centered()
	
func _on_file_selected(path: String) -> void:
	if _is_saving:
		_save_graph(path)
	else:
		_load_graph(path)

func _save_graph(path: String) -> void:
	var error = ResourceSaver.save(graph_editor.graph, path)
	if error == OK:
		file_status.text = "Saved: " + path.get_file()
		file_status.modulate = GraphSettings.COLOR_UI_SUCCESS
	else:
		file_status.text = "Error saving!"
		file_status.modulate = GraphSettings.COLOR_UI_ERROR

func _load_graph(path: String) -> void:
	var new_graph = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if new_graph is Graph:
		graph_editor.load_new_graph(new_graph)
		file_status.text = "Loaded: " + path.get_file()
		file_status.modulate = GraphSettings.COLOR_UI_SUCCESS
	else:
		file_status.text = "Error: Not a valid Graph."
		file_status.modulate = GraphSettings.COLOR_UI_ERROR
