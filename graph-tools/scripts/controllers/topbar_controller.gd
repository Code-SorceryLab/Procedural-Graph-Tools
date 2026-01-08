class_name TopbarController
extends Node

# --- REFERENCES ---
@export var graph_editor: GraphEditor
@export var status_label: Label
@export var tool_options_container: HBoxContainer # <--- LINK THIS in the Inspector!

# --- STATE ---
var _active_tool_inputs: Dictionary = {}

# --- INITIALIZATION ---
func _ready() -> void:
	if not graph_editor or not status_label:
		push_warning("TopbarController: Missing references.")
		return
		
	# 1. Listen for Status Updates (Existing)
	graph_editor.status_message_changed.connect(_on_status_changed)
	status_label.text = "Ready"
	
	
	# 2. Listen for Tool Changes
	# Note: We need the tool INSTANCE to get its settings schema.
	if graph_editor.tool_manager:
		graph_editor.tool_manager.tool_changed.connect(_on_tool_changed)
		print("DEBUG: Connected to ToolManager.")
	else:
		push_error("DEBUG ERROR: TopbarController could not find ToolManager!")
	# --- FIX END ---
	

# --- EVENT HANDLERS ---

func _on_status_changed(msg: String) -> void:
	status_label.text = msg

func _on_tool_changed(_tool_id: int, tool_instance: GraphTool) -> void:
	print("DEBUG: TopBar received signal!")
	# 1. Clear previous Tool Options
	if tool_options_container:
		for child in tool_options_container.get_children():
			child.queue_free()
	_active_tool_inputs.clear()
	
	# 2. Safety Check
	if not tool_instance: 
		return

	# 3. Get the Schema (Data) from the new tool
	# (We will add this function to GraphToolPaint next)
	var schema = tool_instance.get_options_schema()
	print("DEBUG: Schema received: ", schema)
	if schema.is_empty():
		return
		
	# 4. Build the UI automatically
	if tool_options_container:
		_active_tool_inputs = SettingsUIBuilder.build_ui(schema, tool_options_container)
		
		# 5. Connect UI changes back to the Tool
		SettingsUIBuilder.connect_live_updates(_active_tool_inputs, tool_instance.apply_option)
		
		# Optional styling: Add spacing between items
		tool_options_container.add_theme_constant_override("separation", 15)
