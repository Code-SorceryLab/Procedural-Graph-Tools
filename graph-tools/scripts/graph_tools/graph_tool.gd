# res://scripts/graph_tools/graph_tool.gd
class_name GraphTool
extends RefCounted

# References to the main systems
var _editor: GraphEditor
var _graph: Graph
var _renderer: GraphRenderer

func _init(editor: Node2D) -> void:
	_editor = editor
	_graph = editor.graph
	_renderer = editor.renderer

# Virtual methods to be overridden
func enter() -> void: pass
# Optional: Auto-clear status when switching tools
# You can override this in specific tools if you want the message to persist
func exit() -> void:
	_show_status("")
func handle_input(_event: InputEvent) -> void: pass

# --- TOOL OPTIONS API ---

# Returns an Array of Dictionaries (Schema) for the UI Builder
# Override this in specific tools
func get_options_schema() -> Array:
	return []

# Called when the user changes a value in the Top Bar
# Override this to apply the changes (e.g., update brush size)
func apply_option(_param_name: String, _value: Variant) -> void:
	pass

# Shared Helpers
func _get_node_at_pos(pos: Vector2) -> String:
	return _graph.get_node_at_position(pos, _renderer.node_radius)

func _update_hover(mouse_pos: Vector2) -> void:
	var new_hovered = _get_node_at_pos(mouse_pos)
	if new_hovered != _renderer.hovered_id:
		_renderer.hovered_id = new_hovered
		_renderer.queue_redraw()

# --- NEW SHARED HELPER ---
func _show_status(message: String) -> void:
	# Calls the method we just made in Step 1
	if _editor.has_method("send_status_message"):
		_editor.send_status_message(message)
