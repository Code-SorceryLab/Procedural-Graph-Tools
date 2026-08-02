class_name CapPainter
extends AgentCapability

# --- STATE ---
var _paint_target: String = "NODE"
var _paint_field: String = "type"
var _paint_value: Variant = "empty"

# --- CONFIGURATION ---

# Universal Brush Configuration
func configure(target: String, field: String, value: Variant) -> void:
	_paint_target = target
	_paint_field = field
	_paint_value = value

# --- ACTION ---

# Applies the current brush settings. Uses prev_node to target edges.
func paint(graph: Graph, current_node: String, prev_node: String = "") -> void:
	if current_node == "" or not graph.nodes.has(current_node): 
		return
		
	match _paint_target:
		"NODE":
			if _paint_field == "type":
				graph.set_node_type(current_node, str(_paint_value))
			else:
				# Uses the new GraphRecorder method we added!
				graph.set_node_property(current_node, _paint_field, _paint_value)
				
		"EDGE":
			# Only paint if we actually traversed an edge to get here
			if prev_node != "" and graph.has_edge(prev_node, current_node):
				graph.set_edge_property(prev_node, current_node, _paint_field, _paint_value)
				
				# Mirror to the reverse edge if it's a bi-directional corridor
				if graph.has_edge(current_node, prev_node):
					graph.set_edge_property(current_node, prev_node, _paint_field, _paint_value)
