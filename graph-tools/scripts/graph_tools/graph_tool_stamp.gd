class_name GraphToolStamp
extends GraphTool

var _clipboard_data: Dictionary = {}
var _is_valid: bool = false
var _preview_pos: Vector2 = Vector2.ZERO

func enter() -> void:
	_is_valid = false
	var json_str = DisplayServer.clipboard_get()
	if json_str.is_empty(): return
		
	var json = JSON.new()
	if json.parse(json_str) == OK:
		var data = json.get_data()
		if data is Dictionary and data.has("nodes"):
			_clipboard_data = data
			_is_valid = true
			_show_status("Click to stamp prefab. Hold ALT to snap to grid.")

func exit() -> void:
	super.exit()
	_clipboard_data.clear()
	_is_valid = false
	# Tell renderer to clear the ghost preview
	if "stamp_preview_data" in _renderer:
		_renderer.stamp_preview_data = {}
		_editor.request_redraw()

func handle_input(event: InputEvent) -> void:
	if not _is_valid: return
		
	if event is InputEventMouseMotion:
		_preview_pos = _editor.get_global_mouse_position()
		if Input.is_key_pressed(KEY_ALT):
			_preview_pos = _preview_pos.snapped(GraphSettings.GRID_SPACING)
			
		# Send preview data to renderer
		_renderer.stamp_preview_pos = _preview_pos
		_renderer.stamp_preview_data = _clipboard_data
		_renderer.queue_redraw()
		
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_execute_stamp()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			# Cancel stamp tool
			if _editor.has_method("set_tool"): _editor.set_tool("select")

func _execute_stamp() -> void:
	var batch = CmdBatch.new(_graph, "Stamp Prefab")
	var new_selection: Array[String] = []
	var id_map = {} 
	
	# 1. Create Nodes
	for node_data in _clipboard_data["nodes"]:
		var old_id = node_data["id"]
		
		_editor._manual_counter += 1
		var new_id = "man:%d" % _editor._manual_counter
		while _graph.nodes.has(new_id) or id_map.values().has(new_id):
			_editor._manual_counter += 1
			new_id = "man:%d" % _editor._manual_counter
			
		id_map[old_id] = new_id
		new_selection.append(new_id)
		
		var pos = _preview_pos + Vector2(node_data["offset_x"], node_data["offset_y"])
		batch.add_command(CmdAddNode.new(_graph, new_id, pos))
		
		var p_type = str(node_data.get("type", "empty"))
		if p_type != "empty":
			batch.add_command(CmdSetProperty.new(_graph, "NODE", new_id, "type", p_type, "empty"))
			
		if node_data.has("custom_data"):
			var n_data = node_data["custom_data"]
			for key in n_data:
				batch.add_command(CmdSetProperty.new(_graph, "NODE", new_id, key, n_data[key], null))
				
	# 2. Reconstruct Edges
	for edge in _clipboard_data["edges"]:
		var old_u = edge["u"]
		var old_v = edge["v"]
		if id_map.has(old_u) and id_map.has(old_v):
			var new_u = id_map[old_u]
			var new_v = id_map[old_v]
			batch.add_command(CmdConnect.new(_graph, new_u, new_v, edge["w"]))
			
			if edge.has("data"):
				var e_data = edge["data"]
				for key in e_data:
					if key == "weight": continue 
					batch.add_command(CmdSetProperty.new(_graph, "EDGE", [new_u, new_v], key, e_data[key], null))
	
	if not batch._commands.is_empty():
		_editor._commit_command(batch)
		_editor.set_selection_batch(new_selection, [], true)
		
		# Ensure injected IDs and edges didn't cross any wires
		GraphValidator.validate(_graph, true)
		
		_show_status("Stamped %d nodes." % new_selection.size())
