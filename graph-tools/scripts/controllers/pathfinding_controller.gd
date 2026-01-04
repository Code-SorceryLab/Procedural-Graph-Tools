extends Node
class_name PathfindingController

# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor

@export_group("UI Pathfinding Tab")
@export var btn_set_start: Button
@export var btn_set_end: Button
@export var btn_run_path: Button

func _ready() -> void:
	# Listen to Editor State changes
	graph_editor.selection_changed.connect(_on_selection_changed)
	
	# UI Signals
	btn_set_start.pressed.connect(_on_set_start_pressed)
	btn_set_end.pressed.connect(_on_set_end_pressed)
	btn_run_path.pressed.connect(_on_run_path_pressed)
	
	# Initial State
	_update_button_states([])

func _on_selection_changed(selected_nodes: Array[String]) -> void:
	_update_button_states(selected_nodes)

func _update_button_states(selected_nodes: Array[String]) -> void:
	var is_single_select = (selected_nodes.size() == 1)
	btn_set_start.disabled = not is_single_select
	btn_set_end.disabled = not is_single_select
	
	if is_single_select:
		btn_set_start.modulate = GraphSettings.COLOR_UI_ACTIVE
	else:
		btn_set_start.modulate = GraphSettings.COLOR_UI_DISABLED

func _on_set_start_pressed() -> void:
	if graph_editor.selected_nodes.size() == 1:
		graph_editor.set_path_start(graph_editor.selected_nodes[0])

func _on_set_end_pressed() -> void:
	if graph_editor.selected_nodes.size() == 1:
		graph_editor.set_path_end(graph_editor.selected_nodes[0])

func _on_run_path_pressed() -> void:
	graph_editor.run_pathfinding()
