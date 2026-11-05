class_name PatternCard
extends VBoxContainer

var _mini_renderer: GraphRenderer
var _graph_data: Graph
var signature_key: String = ""

# UI Refs
var chk_active: CheckBox
var spin_weight: SpinBox

func setup(signature: String, graph_data: Graph, frequency: int) -> void:
	signature_key = signature
	_graph_data = graph_data
	
	# --- HEADER UI ---
	var header = HBoxContainer.new()
	
	chk_active = CheckBox.new()
	chk_active.button_pressed = true
	chk_active.text = "On"
	header.add_child(chk_active)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	
	var lbl_w = Label.new()
	lbl_w.text = "Wt:"
	header.add_child(lbl_w)
	
	spin_weight = SpinBox.new()
	spin_weight.min_value = 1
	spin_weight.max_value = 999
	spin_weight.value = frequency
	spin_weight.custom_minimum_size.x = 60
	header.add_child(spin_weight)
	
	add_child(header)
	
	# --- RENDERER UI ---
	var render_container = ColorRect.new() # Dark background for the card
	render_container.color = Color(0.1, 0.1, 0.12, 1.0)
	render_container.custom_minimum_size = Vector2(200, 200)
	render_container.clip_contents = true
	
	_mini_renderer = GraphRenderer.new()
	_mini_renderer.graph_ref = _graph_data
	_mini_renderer.is_graph_visible = true
	_mini_renderer.is_preview_mode = true
	
	_calculate_preview_transforms(render_container.custom_minimum_size)
	
	render_container.add_child(_mini_renderer)
	add_child(render_container)

func _calculate_preview_transforms(box_size: Vector2) -> void:
	if _graph_data.nodes.is_empty(): return
	
	# 1. Find the bounding box of the sub-graph
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	
	for id in _graph_data.nodes:
		var p = _graph_data.nodes[id].position
		min_pos.x = min(min_pos.x, p.x)
		min_pos.y = min(min_pos.y, p.y)
		max_pos.x = max(max_pos.x, p.x)
		max_pos.y = max(max_pos.y, p.y)
		
	var graph_size = max_pos - min_pos
	
	# 2. Add padding so nodes don't clip the edges of the box
	var padding = 40.0
	var padded_size = graph_size + Vector2(padding * 2, padding * 2)
	
	# 3. Calculate Scale (Fit to box)
	var scale_x = box_size.x / max(1.0, padded_size.x)
	var scale_y = box_size.y / max(1.0, padded_size.y)
	
	# Use the smaller scale to maintain aspect ratio
	_mini_renderer.preview_scale = min(scale_x, scale_y)
	
	# 4. Calculate Offset (Center it)
	var scaled_graph_size = graph_size * _mini_renderer.preview_scale
	var center_offset = (box_size - scaled_graph_size) / 2.0
	
	# Subtract the scaled min_pos to anchor the top-left of the graph to 0,0, then add the center offset
	_mini_renderer.preview_offset = center_offset - (min_pos * _mini_renderer.preview_scale)

# Helper to fetch data when saving the dictionary
func get_export_data() -> Dictionary:
	return {
		"signature": signature_key,
		"weight": int(spin_weight.value),
		"active": chk_active.button_pressed,
		"graph_json": GraphSerializer.serialize(_graph_data) 
	}
