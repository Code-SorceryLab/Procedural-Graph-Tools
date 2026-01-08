class_name GraphClipboard
extends RefCounted

var _editor: GraphEditor

func _init(editor: GraphEditor) -> void:
	_editor = editor

func copy() -> void:
	var selected_nodes = _editor.selected_nodes
	var graph = _editor.graph
	
	if selected_nodes.is_empty():
		return

	var clipboard_data = {
		"nodes": [],
		"edges": []
	}
	
	# 1. Calculate Center (for relative pasting)
	var center = Vector2.ZERO
	for id in selected_nodes:
		center += graph.nodes[id].position
	center /= selected_nodes.size()
	
	# 2. Serialize Nodes
	var node_set = {} 
	
	for id in selected_nodes:
		node_set[id] = true
		var node = graph.nodes[id]
		clipboard_data["nodes"].append({
			"id": id,
			"type": node.type,
			"offset_x": node.position.x - center.x,
			"offset_y": node.position.y - center.y
		})
		
	# 3. Serialize Internal Edges
	var checked_edges = {}
	
	for id_a in selected_nodes:
		if not graph.edge_data.has(id_a): continue
		
		for id_b in graph.edge_data[id_a]:
			if node_set.has(id_b):
				var pair = [id_a, id_b]
				pair.sort()
				if checked_edges.has(pair): continue
				checked_edges[pair] = true
				
				var w = graph.get_edge_weight(id_a, id_b)
				var is_directed = not graph.has_edge(id_b, id_a)
				
				clipboard_data["edges"].append({
					"u": id_a,
					"v": id_b,
					"w": w,
					"dir": is_directed
				})
	
	# 4. Send to OS Clipboard
	var json_str = JSON.stringify(clipboard_data)
	DisplayServer.clipboard_set(json_str)
	_editor.send_status_message("Copied %d items." % selected_nodes.size())

func cut() -> void:
	if _editor.selected_nodes.is_empty():
		return
		
	# 1. Copy
	copy()
	
	# 2. Delete (Construct Batch)
	var graph = _editor.graph
	var batch = CmdBatch.new(graph, "Cut Selection")
	
	for id in _editor.selected_nodes:
		var cmd = CmdDeleteNode.new(graph, id)
		batch.add_command(cmd)
		
	_editor._commit_command(batch)
	_editor._reset_local_state()
	_editor.send_status_message("Cut Selection.")

func paste() -> void:
	var json_str = DisplayServer.clipboard_get()
	if json_str.is_empty(): return
	
	var json = JSON.new()
	if json.parse(json_str) != OK: return 
	
	var data = json.get_data()
	if not data is Dictionary or not data.has("nodes"): return 
	
	var graph = _editor.graph
	var paste_center = _editor.get_global_mouse_position()
	
	# Prepare Batch
	var batch = CmdBatch.new(graph, "Paste")
	var new_selection: Array[String] = []
	var id_map = {} 
	
	# Create Nodes
	for node_data in data["nodes"]:
		var old_id = node_data["id"]
		
		# Generate new ID via Editor to ensure counter sync
		_editor._manual_counter += 1
		var new_id = "man:%d" % _editor._manual_counter
		while graph.nodes.has(new_id) or id_map.values().has(new_id):
			_editor._manual_counter += 1
			new_id = "man:%d" % _editor._manual_counter
			
		id_map[old_id] = new_id
		new_selection.append(new_id)
		
		var pos = paste_center + Vector2(node_data["offset_x"], node_data["offset_y"])
		
		var cmd_add = CmdAddNode.new(graph, new_id, pos)
		batch.add_command(cmd_add)
		
		if node_data["type"] != 0:
			var cmd_type = CmdSetType.new(graph, new_id, 0, int(node_data["type"]))
			batch.add_command(cmd_type)
			
	# Reconstruct Edges
	for edge in data["edges"]:
		var old_u = edge["u"]
		var old_v = edge["v"]
		
		if id_map.has(old_u) and id_map.has(old_v):
			var new_u = id_map[old_u]
			var new_v = id_map[old_v]
			var w = edge["w"]
			var cmd_conn = CmdConnect.new(graph, new_u, new_v, w)
			batch.add_command(cmd_conn)
	
	# Execute
	if not batch._commands.is_empty():
		_editor._commit_command(batch)
		# Use the batch API
		_editor.set_selection_batch(new_selection, [], true)
		_editor.send_status_message("Pasted %d items." % new_selection.size())
