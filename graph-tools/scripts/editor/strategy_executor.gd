class_name StrategyExecutor
extends RefCounted

# Executes a strategy safely using the Recorder/Command pattern.
# Returns the CmdBatch if successful (so the Editor can commit it), or null.
static func execute(editor: GraphEditor, strategy: GraphStrategy, params: Dictionary) -> CmdBatch:
	var graph = editor.graph
	
	# 1. Prepare the Batch
	var batch = CmdBatch.new(graph, "Run %s" % strategy.strategy_name)
	
	# 2. Handle "Reset on Generate" (Destructive Start)
	# If not appending, we clear the board first.
	if strategy.reset_on_generate and not params.get("append", false):
		for id in graph.nodes.keys():
			batch.add_command(CmdDeleteNode.new(graph, id))
	
	# 3. Setup the Sandbox (Recorder)
	# We initialize it with the CURRENT state of the graph.
	var recorder = GraphRecorder.new(graph)
	
	# 4. Run the Strategy
	strategy.execute(recorder, params)
	
	# 5. Harvest Commands
	for cmd in recorder.recorded_commands:
		batch.add_command(cmd)
	
	# 6. Return the batch (The Editor will decide to commit/visualize it)
	if batch._commands.is_empty():
		return null
		
	return batch

# Handles the complex visual feedback (Cyan nodes, Green/Red rings)
static func process_visualization(editor: GraphEditor, params: Dictionary, original_node_ids: Dictionary) -> void:
	var new_nodes: Array[String] = []
	var graph = editor.graph
	
	# A. Get Highlight Path (Prioritize Strategy Output)
	if params.has("out_highlight_nodes"):
		# FIX: Use .assign() to convert generic Array -> Array[String]
		var raw_list = params["out_highlight_nodes"]
		if raw_list is Array:
			new_nodes.assign(raw_list)
	else:
		# B. Fallback Diff Logic
		for id in graph.nodes:
			if not original_node_ids.has(id):
				new_nodes.append(id)
	
	# C. Set Indicators
	if params.has("out_head_node"):
		editor.set_path_end(params["out_head_node"])
	else:
		editor.set_path_end("")

	if params.has("out_start_node"):
		editor.set_path_start(params["out_start_node"])
	else:
		editor.set_path_start("")
	
	# Apply to Editor
	editor.new_nodes = new_nodes
	editor.renderer.new_nodes_ref = new_nodes
