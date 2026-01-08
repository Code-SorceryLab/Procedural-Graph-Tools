class_name GraphInputHandler
extends RefCounted

var _editor: GraphEditor
var _clipboard: GraphClipboard

func _init(editor: GraphEditor, clipboard: GraphClipboard) -> void:
	_editor = editor
	_clipboard = clipboard

func handle_input(event: InputEvent) -> void:
	# Optimization: Only process key presses
	if not event is InputEventKey or not event.pressed:
		return

	# 1. VIEW OPERATIONS
	if event.keycode == KEY_F:
		_editor._center_camera_on_graph()
		
	# 2. FILE OPERATIONS
	if event.is_action_pressed("file_save"):
		_editor.request_save_graph.emit(_editor.graph)
		_editor.get_viewport().set_input_as_handled()
		return
		
	if event.is_action_pressed("file_undo"):
		_editor.undo()
		_editor.get_viewport().set_input_as_handled()
		return
		
	if event.is_action_pressed("file_redo"):
		_editor.redo()
		_editor.get_viewport().set_input_as_handled()
		return
		
	# 3. CLIPBOARD OPERATIONS
	if event.is_action_pressed("edit_copy"):
		_clipboard.copy()
		_editor.get_viewport().set_input_as_handled()
		return
		
	if event.is_action_pressed("edit_cut"):
		_clipboard.cut()
		_editor.get_viewport().set_input_as_handled()
		return
		
	if event.is_action_pressed("edit_paste"):
		_clipboard.paste()
		_editor.get_viewport().set_input_as_handled()
		return
		
	if event.is_action_pressed("edit_delete"):
		_handle_delete()
		return

	# 4. TOOL SWITCHING (Dynamic)
	_handle_tool_switching(event)

# --- INTERNAL HELPERS ---

func _handle_delete() -> void:
	if not _editor.selected_nodes.is_empty():
		var batch = CmdBatch.new(_editor.graph, "Delete Selection")
		for id in _editor.selected_nodes:
			batch.add_command(CmdDeleteNode.new(_editor.graph, id))
		
		_editor._commit_command(batch)
		_editor._reset_local_state()
		_editor.get_viewport().set_input_as_handled()

func _handle_tool_switching(event: InputEvent) -> void:
	# Iterate through ALL defined tools in the dictionary
	for tool_id in GraphSettings.TOOL_DATA:
		var action = GraphSettings.TOOL_DATA[tool_id].get("action", "")
		
		# If the event matches the tool's SPECIFIC action (e.g. "tool_select")
		if action != "" and event.is_action_pressed(action):
			_editor.set_active_tool(tool_id) 
			_editor.get_viewport().set_input_as_handled()
			return
