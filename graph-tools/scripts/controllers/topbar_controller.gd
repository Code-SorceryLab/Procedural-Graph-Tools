class_name TopbarController
extends Node

# --- REFERENCES ---
@export var graph_editor: GraphEditor
@export var status_label: Label

# --- INITIALIZATION ---
func _ready() -> void:
	# Wait for dependencies to be valid
	if not graph_editor or not status_label:
		push_warning("TopbarController: Missing references.")
		return
		
	# Wire the signal
	graph_editor.status_message_changed.connect(_on_status_changed)
	
	# Set initial state
	status_label.text = "Ready"

# --- EVENT HANDLERS ---
func _on_status_changed(msg: String) -> void:
	status_label.text = msg
