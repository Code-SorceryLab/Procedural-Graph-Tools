class_name InspectorStrategy
extends RefCounted

# --- DEPENDENCIES ---
var graph_editor: GraphEditor
var container: Control

# --- SIGNALS ---
signal request_wizard(target_type: String) 
signal request_refresh_ui()

# ==============================================================================
# 1. LIFECYCLE
# ==============================================================================

func _init(p_editor: GraphEditor, p_container: Control) -> void:
	graph_editor = p_editor
	container = p_container

# --- VIRTUAL METHODS (Override these) ---

# Does this strategy handle the current selection?
func can_handle(_nodes: Array, _edges: Array, _agents: Array, _zones: Array) -> bool:
	return false

# Called when this strategy becomes active
func enter(nodes: Array, edges: Array, agents: Array, zones: Array) -> void:
	container.visible = true
	_update_ui(nodes, edges, agents, zones)

# Called when selection changes but this strategy remains active
func update(nodes: Array, edges: Array, agents: Array, zones: Array) -> void:
	_update_ui(nodes, edges, agents, zones)

# Called when this strategy loses focus
func exit() -> void:
	container.visible = false
	# Optional: Clear UI on exit to save memory, though keeping it allows persistent state
	# _clear_container() 

# Internal build logic
func _update_ui(_nodes, _edges, _agents, _zones) -> void:
	pass

# ==============================================================================
# 2. UI HELPERS
# ==============================================================================

# Wipes the container clean. Call this at the start of _update_ui.
func _clear_container() -> void:
	SettingsUIBuilder.clear_ui(container)

# Creates a standard collapsible header + content box.
# Usage: 
#   var content_box = _create_section("Agent Properties")
#   SettingsUIBuilder.render_dynamic_section(content_box, ...)
func _create_section(title: String, start_expanded: bool = true) -> VBoxContainer:
	_clear_container() # Ensure we don't stack duplicates on update
	return SettingsUIBuilder.create_collapsible_section(container, title, start_expanded)
