class_name CapPainter
extends AgentCapability

# --- STATE ---
var target_type: String = "empty"       # empty = Do not change type
var target_data: Dictionary = {} # keys to modify (e.g. {"is_visited": true})

# --- CONFIGURATION ---

# Standard "Paint Brush" (Color/Type)
func set_paint_type(type_idx: String) -> void:
	target_type = type_idx

# Advanced "Data Stamp" (Semantic Data)
func set_paint_data(key: String, value: Variant) -> void:
	target_data[key] = value

func clear_paint_data() -> void:
	target_data.clear()

# --- ACTION ---

# Applies the current brush settings to a specific node
func paint(graph: Graph, node_id: String) -> void:
	if node_id == "" or not graph.nodes.has(node_id): 
		return
		
	# 1. Apply Visual Type (Color)
	if target_type != "empty":
		# Only paint if different (optimization)
		var current = graph.nodes[node_id].type
		if current != target_type:
			graph.set_node_type(node_id, target_type)
			
	# 2. Apply Semantic Data
	if not target_data.is_empty():
		var node = graph.nodes[node_id]
		
		# Ensure the node has storage
		if not "custom_data" in node:
			return
			
		var modified = false
		for key in target_data:
			# Check if value actually changed
			if node.custom_data.get(key) != target_data[key]:
				node.custom_data[key] = target_data[key]
				modified = true
		
		# Notify system only if data actually changed
		if modified:
			# If the graph has a method for this, use it. 
			# Otherwise, mark modified manually if the editor requires it.
			if graph.has_method("mark_modified"):
				graph.mark_modified()
