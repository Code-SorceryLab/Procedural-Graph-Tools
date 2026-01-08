extends Node
class_name ToolbarController

# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor

@export_group("UI")
@export var toolbar: Toolbar

# --- INITIALIZATION ---
func _ready() -> void:
	# 1. UI -> Logic (User Clicks Button)
	toolbar.tool_changed.connect(_on_ui_tool_changed)
	
	# 2. Logic -> UI (User Presses Shortcut Key 1-7)
	# This ensures the button highlights even if we didn't click it
	graph_editor.active_tool_changed.connect(_on_editor_tool_changed)

# --- EVENT HANDLERS ---

# Flow: UI Click -> Controller -> Editor Logic
func _on_ui_tool_changed(tool_id: int, _tool_name: String) -> void:
	graph_editor.set_active_tool(tool_id)
	
	# Optional: Update context menus / sidebars
	_update_context_options(tool_id)

# Flow: Editor Logic (Shortcut) -> Controller -> UI Visuals
func _on_editor_tool_changed(tool_id: int) -> void:
	# We update the VISUALS of the toolbar without triggering the logic again
	# (Your Toolbar.gd 'set_active_tool' handles this safe update)
	toolbar.set_active_tool(tool_id)
	_update_context_options(tool_id)

func _update_context_options(_tool_id: int) -> void:
	pass
