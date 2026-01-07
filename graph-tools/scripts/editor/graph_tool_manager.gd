class_name GraphToolManager
extends RefCounted

# --- DATA ---
var current_tool: GraphTool
var _editor: GraphEditor

# --- INITIALIZATION ---
func _init(editor: GraphEditor) -> void:
	_editor = editor

# ==============================================================================
# 1. TOOL SWITCHING (Factory)
# ==============================================================================
func set_active_tool(tool_id: int) -> void:
	print("ToolManager: Switching to tool ", tool_id)
	
	# 1. Cleanup the old tool
	if current_tool:
		current_tool.exit()
	
	# 2. Instantiate the new tool
	match tool_id:
		GraphSettings.Tool.SELECT:
			current_tool = GraphToolSelect.new(_editor)
		GraphSettings.Tool.ADD_NODE:
			current_tool = GraphToolAddNode.new(_editor)
		GraphSettings.Tool.CONNECT:
			current_tool = GraphToolConnect.new(_editor)
		GraphSettings.Tool.DELETE:
			current_tool = GraphToolDelete.new(_editor)
		GraphSettings.Tool.PAINT:
			current_tool = GraphToolPaint.new(_editor)
		GraphSettings.Tool.CUT:
			current_tool = GraphToolCut.new(_editor)
		GraphSettings.Tool.TYPE_PAINT:
			current_tool = GraphToolPropertyPaint.new(_editor)
		_:
			push_warning("ToolManager: Unknown tool ID %d. Defaulting to Select." % tool_id)
			current_tool = GraphToolSelect.new(_editor)
			
	# 3. Initialize the new tool
	if current_tool:
		current_tool.enter()

# ==============================================================================
# 2. INPUT ROUTING
# ==============================================================================
func handle_input(event: InputEvent) -> void:
	if current_tool:
		current_tool.handle_input(event)

# ==============================================================================
# 3. UTILITY
# ==============================================================================
func update_tool_graph_reference(new_graph: Graph) -> void:
	if current_tool:
		current_tool._graph = new_graph
