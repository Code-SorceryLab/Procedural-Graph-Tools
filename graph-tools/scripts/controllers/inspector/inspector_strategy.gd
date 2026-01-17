# scripts/controllers/inspector/strategies/InspectorStrategy.gd
class_name InspectorStrategy
extends RefCounted

# Dependencies
var graph_editor: GraphEditor
var container: Control

# Signals (To communicate back to Main Controller)
signal request_wizard(target_type: String) 
signal request_refresh_ui()

func _init(p_editor: GraphEditor, p_container: Control) -> void:
	graph_editor = p_editor
	container = p_container

# --- VIRTUAL METHODS ---

# Does this strategy handle the current selection?
func can_handle(nodes: Array, edges: Array, agents: Array, zones: Array) -> bool:
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

# Internal build logic
func _update_ui(_nodes, _edges, _agents, _zones) -> void:
	pass
