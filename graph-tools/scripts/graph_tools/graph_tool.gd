# res://scripts/graph_tools/graph_tool.gd
class_name GraphTool
extends RefCounted

# References to the main systems
var _editor: Node2D 
var _graph: Graph
var _renderer: GraphRenderer

func _init(editor: Node2D) -> void:
	_editor = editor
	_graph = editor.graph
	_renderer = editor.renderer

# Virtual methods to be overridden
func enter() -> void: pass
func exit() -> void: pass
func handle_input(_event: InputEvent) -> void: pass

# Shared Helpers
func _get_node_at_pos(pos: Vector2) -> String:
	return _graph.get_node_at_position(pos, _renderer.node_radius)

func _update_hover(mouse_pos: Vector2) -> void:
	var new_hovered = _get_node_at_pos(mouse_pos)
	if new_hovered != _renderer.hovered_id:
		_renderer.hovered_id = new_hovered
		_renderer.queue_redraw()
