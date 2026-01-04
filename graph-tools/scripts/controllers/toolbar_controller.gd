extends Node
class_name ToolbarController

# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor

@export_group("UI")
@export var toolbar: Toolbar

# --- INITIALIZATION ---
func _ready() -> void:
	# Connect the custom signal from the Toolbar component
	toolbar.tool_changed.connect(_on_tool_changed)

# --- EVENT HANDLERS ---
func _on_tool_changed(tool_id: int, _tool_name: String) -> void:
	# 1. Update the Editor's State Machine
	graph_editor.set_active_tool(tool_id)
	
	# 2. (Optional) Update UI context
	_update_context_options(tool_id)

func _update_context_options(_tool_id: int) -> void:
	# Placeholder: If you later want the sidebar to change when selecting "Rectangle",
	# you would implement that logic here (or emit a signal for another controller).
	pass
