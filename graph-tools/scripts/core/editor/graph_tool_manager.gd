class_name GraphToolManager
extends RefCounted

# --- SIGNALS ---
# Emitted whenever the active tool changes. 
# We pass the INSTANCE so the UI can read its specific settings schema.
signal tool_changed(tool_id: int, tool_instance: GraphTool)

# --- DATA ---
var current_tool: GraphTool
var active_tool_id: int = GraphSettings.Tool.SELECT
var _editor: GraphEditor

# --- INITIALIZATION ---
func _init(editor: GraphEditor) -> void:
	_editor = editor

# ==============================================================================
# 1. TOOL SWITCHING (Factory)
# ==============================================================================
func set_active_tool(tool_id: int) -> void:
	# Update the tracker
	active_tool_id = tool_id
	#print("ToolManager: Switching to tool ", tool_id)
	
	if current_tool:
		current_tool.exit()
	
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
		GraphSettings.Tool.SPAWN:
			current_tool = GraphToolSpawner.new(_editor)
		GraphSettings.Tool.ZONE_BRUSH:
			current_tool = GraphToolZoneBrush.new(_editor)
		_:
			push_warning("ToolManager: Unknown tool ID %d. Defaulting to Select." % tool_id)
			current_tool = GraphToolSelect.new(_editor)
			
	if current_tool:
		current_tool.enter()
		#print("DEBUG: Manager Emitting tool_changed for ID: ", tool_id)
		# CRITICAL: Notify the system (Toolbar, Topbar, etc.)
		tool_changed.emit(tool_id, current_tool)

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
