class_name AnalysisController
extends Node

# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor

@export_group("UI Analysis Tab")
@export var btn_calculate: Button
@export var btn_export: Button
@export var btn_copy: Button
@export var results_label: RichTextLabel
@export var file_dialog: FileDialog
# The dynamic UI container
@export var analysis_settings_container: VBoxContainer

# --- STATE ---
var _latest_report: Dictionary = {}
var _analysis_params: Dictionary = {} # Stores live settings

const METRIC_TOOLTIPS: Dictionary = {
	# Topological
	"node_count": "Total number of vertices (rooms/points) in the graph.",
	"edge_count": "Total number of unique connections between nodes.",
	"density": "Ratio of actual edges to the maximum possible edges. 1.0 means every node is connected to every other node.",
	"connected_components": "Number of isolated graph islands. 1 means the entire graph is connected.",
	"cyclomatic_complexity": "Number of independent cyclical loops (Edges - Nodes + Islands). 0 means a strict branching tree with no loops.",
	"disconnected": "Nodes with 0 connections.",
	"dead_ends": "Nodes with exactly 1 connection (Terminal points).",
	"corridors": "Nodes with exactly 2 connections (Pathways).",
	"intersections": "Nodes with 3 or more connections (Branching points).",
	"articulation_points": "Nodes that, if removed, would split the graph into separate disconnected islands (Critical Chokepoints).",
	"bridges": "Edges that, if removed, would split the graph into separate disconnected islands (Critical Pathways).",
	"max_betweenness": "The centrality score of the most heavily trafficked node. High scores indicate a central thoroughfare that connects many branches.",
	"average_betweenness": "The mean centrality across all nodes. Indicates how distributed the routing is across the entire graph.",
	"hub_node_id": "The exact unique identifier of the node with the highest Betweenness Centrality.",
	"graph_degeneracy": "The maximum k-core of the graph. A high number indicates the presence of a densely tangled central arena.",
	"max_core_size": "The number of nodes that belong to the graph's densest tangled region.",
	# Planarity
	"is_planar": "Whether the graph can mathematically be drawn on a 2D plane without any edges crossing.",
	"planarity_reason": "The mathematical proof. Tests executed in order: 1) Trivial Size (V <= 3). 2) Euler's Maximal Bound (E <= 3V-6). 3) Bipartite Tight Bound (E <= 2V-4). 4) Kuratowski Subgraph Detection (Left-Right DFS back-edge interlacing).",
	
	# Spectral
	"algebraic_connectivity": "The Fiedler Value (2nd smallest eigenvalue of the Laplacian). A low number indicates a severe bottleneck separating two halves of the graph. A 0 means the graph is completely disconnected.",
	"bisection_side_a": "The number of nodes residing in the first mathematical half of the graph's optimal cut.",
	"bisection_side_b": "The number of nodes residing in the second mathematical half of the graph's optimal cut.",
	"bisection_cut_edges": "The specific edges that act as the structural bottleneck between Side A and Side B.",
	
	# Information Theory
	"structural_entropy": "Shannon Entropy of the graph's degree distribution. 0.0 means perfect uniformity (e.g., a perfect grid where every room has exactly the same number of doors). Higher values mean a chaotic, unpredictable mixture of corridors, dead-ends, and hubs.",
	
	# Spatial
	"total_cells_used": "Number of internal spatial grid cells containing at least one node.",
	"avg_nodes_per_cell": "Average node density per populated spatial cell.",
	"area": "Total square area of the graph's bounding box.",
	
	# Tangles & Treewidth
	"tangle_treewidth": "The Treewidth of the graph, which corresponds directly to its Tangle Order. A tree has a width of 1. A grid has a width equal to its shortest side. High numbers mathematically prove the existence of dense, highly intertwined 'arenas' that cannot be easily cut.",
	"tangle_calculation_method": "Because exact Treewidth is NP-Hard, the engine dynamically falls back to a Greedy Min-Degree Heuristic if the exact Bitwise Branch & Bound solver hits its iteration limit or if N > 63.",
	
	# Agents
	"total_spawned": "Total number of agents instantiated during the run.",
	"total_completed": "Agents that successfully reached their step limit or target.",
	"completion_rate_percent": "Percentage of agents that finished successfully without getting trapped.",
	"average_steps": "Average number of movements taken per agent.",
	"total_aggregate_steps": "Sum of all steps taken by all agents combined.",
	
	# Markov Flow
	"absorbing_states": "Nodes where flow terminates (e.g., dead-ends or explicit exits). If this is 0, the graph is a closed loop and flow analysis is skipped.",
	"transient_states": "Nodes where flow is active (intersections and corridors).",
	"average_expected_steps": "The exact mathematical average of steps an agent will take before hitting a dead-end, calculated via Fundamental Matrix inversion.",
	"max_expected_visits": "The highest expected number of visits any single room will receive. High numbers indicate extreme traffic congestion.",
	"flow_bottleneck_id": "The specific transient node that receives the most mathematical traffic. Clicking this highlights the ultimate chokepoint of your level.",
	
	# Zones
	"total_zones": "Number of defined geographical regions (biomes).",
	"aggregate_area_size": "Total number of nodes registered to a zone."
}

func _ready() -> void:
	if btn_calculate: btn_calculate.pressed.connect(_on_calculate_pressed)
	if btn_export: btn_export.pressed.connect(_on_export_pressed)
	if btn_copy: btn_copy.pressed.connect(_on_copy_pressed)
	if file_dialog: file_dialog.file_selected.connect(_on_file_selected)
		
	if results_label:
		results_label.meta_clicked.connect(_on_meta_clicked)
		results_label.text = "[center][color=#666666]Ready for analysis.[/color][/center]"
		
	# [NEW] Build the Dynamic Options Menu
	var schema = GraphMetrics.get_analysis_options_schema()
	for item in schema:
		_analysis_params[item.name] = item.default
		
	if analysis_settings_container:
		var ui_elements = SettingsUIBuilder.build_ui(schema, analysis_settings_container)
		SettingsUIBuilder.connect_live_updates(ui_elements, _on_analysis_setting_changed)

# ==============================================================================
# 1. METRICS GENERATION & UI
# ==============================================================================
# Live update receiver
func _on_analysis_setting_changed(key: String, value: Variant) -> void:
	_analysis_params[key] = value

func _on_calculate_pressed() -> void:
	if not graph_editor or not graph_editor.graph: return
		
	# Pass the fully populated dynamic settings dictionary!
	_latest_report = GraphMetrics.generate_report(graph_editor.graph, _analysis_params) 
	_populate_results_ui(_latest_report)
	
	if btn_export: btn_export.disabled = false
	if btn_copy: btn_copy.disabled = false

func _populate_results_ui(report: Dictionary) -> void:
	if not results_label: return
	
	var bbcode = "[center][b]Graph Analysis Report[/b][/center]\n"
	bbcode += "[right][color=#888888]" + report.get("timestamp", "") + "[/color][/right]\n\n"
	
	bbcode += _build_category_bbcode("Topological Data", report.get("topological", {}))
	
	# Add the Tangles rendering block right here!
	if report.has("robertson_seymour_tangles"):
		bbcode += _build_category_bbcode("Tangles & Treewidth", report.get("robertson_seymour_tangles", {}))
		
	bbcode += _build_category_bbcode("Spatial Footprint", report.get("spatial", {}))
	bbcode += _build_category_bbcode("Agent Simulation", report.get("agents", {}))
	bbcode += _build_category_bbcode("Markov Flow Analysis", report.get("markov_flow", {}))
	bbcode += _build_category_bbcode("Zone Composition", report.get("zones", {}))
	
	results_label.text = bbcode

func _build_category_bbcode(title: String, data: Dictionary) -> String:
	if data.is_empty(): return ""
	
	var text = "[color=#42f5a4][b]--- " + title + " ---[/b][/color]\n"
	var sel_data = _latest_report.get("_selection_data", {}) # [NEW] Grab hidden data
	
	for key in data:
		var val = data[key]
		
		if val is Dictionary:
			var parent_key_formatted = key.capitalize().replace("_", " ")
			if METRIC_TOOLTIPS.has(key):
				parent_key_formatted = "[hint=\"%s\"]%s[/hint]" % [METRIC_TOOLTIPS[key], parent_key_formatted]
				
			text += "[color=#aaaaaa]" + parent_key_formatted + ":[/color]\n"
			
			for sub_key in val:
				var sub_key_formatted = sub_key.capitalize().replace("_", " ")
				if METRIC_TOOLTIPS.has(sub_key):
					sub_key_formatted = "[hint=\"%s\"]%s[/hint]" % [METRIC_TOOLTIPS[sub_key], sub_key_formatted]
					
				# [NEW] Inject Select buttons for nested properties
				var val_str = "[b]" + str(val[sub_key]) + "[/b]"
				if sel_data.has(sub_key) and (not sel_data[sub_key].get("nodes", []).is_empty() or not sel_data[sub_key].get("edges", []).is_empty()):
					val_str += " [url=%s][color=#f5d142](Select)[/color][/url]" % sub_key
					
				text += "    " + sub_key_formatted + ": " + val_str + "\n"
		else:
			var key_formatted = key.capitalize().replace("_", " ")
			if METRIC_TOOLTIPS.has(key):
				key_formatted = "[hint=\"%s\"]%s[/hint]" % [METRIC_TOOLTIPS[key], key_formatted]
				
			# [NEW] Inject Select buttons for root properties
			var val_str = "[b]" + str(val) + "[/b]"
			
			# Special case for string-based IDs (like hub_node_id)
			if key == "hub_node_id" and val != "None":
				val_str += " [url=hub_node_id][color=#f5d142](Select)[/color][/url]"
			# Normal case for array-backed data
			elif sel_data.has(key) and (not sel_data[key].get("nodes", []).is_empty() or not sel_data[key].get("edges", []).is_empty()):
				val_str += " [url=%s][color=#f5d142](Select)[/color][/url]" % key
				
			text += key_formatted + ": " + val_str + "\n"
			
	return text + "\n"

# [NEW] The Magic Click Handler!
func _on_meta_clicked(meta: Variant) -> void:
	var key = str(meta)
	var sel_data = _latest_report.get("_selection_data", {})
	
	var nodes_to_select: Array[String] = []
	var edges_to_select: Array = []
	
	# Special Hardcoded case for the string ID
	if key == "hub_node_id":
		var hub_id = _latest_report.get("topological", {}).get("hub_node_id", "None")
		if hub_id != "None": nodes_to_select.append(hub_id)
	# Normal case: Look up the arrays we saved
	elif sel_data.has(key):
		nodes_to_select.assign(sel_data[key].get("nodes", []))
		edges_to_select.assign(sel_data[key].get("edges", []))
		
	if graph_editor and (not nodes_to_select.is_empty() or not edges_to_select.is_empty()):
		# Instantly highlight them in the editor!
		graph_editor.set_selection_batch(nodes_to_select, edges_to_select, true)
		graph_editor.send_status_message("Selected elements for: " + key)

# ==============================================================================
# 2. EXPORT LOGIC
# ==============================================================================

# [NEW] Helper to strip the hidden arrays so JSON remains clean
func _get_clean_report() -> Dictionary:
	var clean = _latest_report.duplicate(true)
	clean.erase("_selection_data")
	return clean

func _on_export_pressed() -> void:
	if _latest_report.is_empty() or not file_dialog: return
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	file_dialog.title = "Export Metrics to JSON"
	file_dialog.filters = ["*.json ; Graph Metrics JSON"]
	file_dialog.popup_centered()

func _on_file_selected(path: String) -> void:
	if file_dialog.title != "Export Metrics to JSON": return
	if not path.ends_with(".json"): path += ".json"
		
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_get_clean_report(), "\t"))
		file.close()

func _on_copy_pressed() -> void:
	if _latest_report.is_empty(): return
	
	var json_string = JSON.stringify(_get_clean_report(), "\t")
	DisplayServer.clipboard_set(json_string)
	
	if btn_copy:
		var original_text = btn_copy.text
		btn_copy.text = "Copied!"
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(btn_copy): 
			btn_copy.text = original_text
