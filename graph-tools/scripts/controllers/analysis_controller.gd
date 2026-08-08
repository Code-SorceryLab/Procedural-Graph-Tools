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
@export var btn_settings: Button

# --- STATE ---
var _latest_report: Dictionary = {}
var _analysis_params: Dictionary = {} # Stores live settings
var _settings_popup: AlgorithmSettingsPopup # The dynamic popup instance
var _is_calculating: bool = false # Tracks calculation state

# analysis_controller.gd (Tooltips Update)
const METRIC_TOOLTIPS: Dictionary = {
	# Topological
	"node_count": "Total number of vertices (rooms/points) in the graph.",
	"edge_count": "Total number of unique connections between nodes.",
	"density": "Ratio of actual edges to the maximum possible edges.\n1.0 means every node is connected to every other node.",
	"connected_components": "Number of isolated graph islands.\n1 means the entire graph is connected.",
	"cyclomatic_complexity": "Number of independent cyclical loops (Edges - Nodes + Islands).\n0 means a strict branching tree with no loops.",
	"disconnected": "Nodes with 0 connections.",
	"dead_ends": "Nodes with exactly 1 connection (Terminal points).",
	"corridors": "Nodes with exactly 2 connections (Pathways).",
	"intersections": "Nodes with 3 or more connections (Branching points).",
	"articulation_points": "Nodes that, if removed, would split the graph\ninto separate disconnected islands (Critical Chokepoints).",
	"bridges": "Edges that, if removed, would split the graph\ninto separate disconnected islands (Critical Pathways).",
	"max_betweenness": "The centrality score of the most heavily trafficked node.\nHigh scores indicate a central thoroughfare connecting many branches.",
	"average_betweenness": "The mean centrality across all nodes.\nIndicates how distributed the routing is across the entire graph.",
	"hub_node_id": "The exact unique identifier of the node\nwith the highest Betweenness Centrality.",
	"graph_degeneracy": "The maximum k-core of the graph.\nA high number indicates a densely tangled central arena.",
	"max_core_size": "The number of nodes that belong to the graph's densest tangled region.",
	
	# Planarity
	"is_planar": "Whether the graph can mathematically be drawn\non a 2D plane without any edges crossing.",
	"planarity_reason": "The mathematical proof. Tests executed in order:\n1) Trivial Size (V <= 3).\n2) Euler's Maximal Bound (E <= 3V-6).\n3) Bipartite Tight Bound (E <= 2V-4).\n4) Kuratowski Subgraph Detection (Left-Right DFS back-edge interlacing).",
	
	# Spectral
	"algebraic_connectivity": "The Fiedler Value (2nd smallest eigenvalue of the Laplacian).\nA low number indicates a severe bottleneck separating two halves of the graph.\nA 0 means the graph is completely disconnected.",
	"bisection_side_a": "The number of nodes residing in the first mathematical half\nof the graph's optimal cut.",
	"bisection_side_b": "The number of nodes residing in the second mathematical half\nof the graph's optimal cut.",
	"bisection_cut_edges": "The specific edges that act as the structural bottleneck\nbetween Side A and Side B.",
	
	# Information Theory
	"structural_entropy": "Shannon Entropy of the graph's degree distribution.\n0.0 means perfect uniformity (e.g., a perfect grid).\nHigher values mean a chaotic, unpredictable mixture of corridors, dead-ends, and hubs.",
	
	# Spatial
	"total_cells_used": "Number of internal spatial grid cells containing at least one node.",
	"avg_nodes_per_cell": "Average node density per populated spatial cell.",
	"area": "Total square area of the graph's bounding box.",
	
	# Tangles & Treewidth
	"tangle_treewidth": "The Treewidth of the graph, corresponding directly to its Tangle Order.\nA tree has a width of 1. A grid has a width equal to its shortest side.\nHigh numbers prove the existence of dense 'arenas' that cannot be easily cut.",
	"tangle_calculation_method": "Because exact Treewidth is NP-Hard, the engine dynamically falls back\nto a Greedy Min-Degree Heuristic if the solver hits its limit or N > 63.",
	
	# Graph Coloring
	"chromatic_number": "The exact minimum number of colors needed to paint every node\nsuch that no two connected nodes share a color.\nMaximum distinct factions perfectly dispersed across the map.",
	"chromatic_calculation_method": "Because Chromatic Number is NP-Hard, the engine uses a Welsh-Powell\ngreedy algorithm bound, then Threaded Branch-and-Bound.",
	
	# Longest Path
	"max_path_length": "Maximum nodes an agent can visit in a single continuous journey\nwithout revisiting a node. Clicking this highlights the exact route.",
	"is_hamiltonian": "Whether a 'Hamiltonian Path' exists.\nA path that perfectly visits every node exactly once.",
	"longest_path_calculation_method": "Longest Path is NP-Hard. The engine explores deep branches first,\nensuring timeouts return a highly optimized approximation.",
	
	# Eulerian Traversal
	"has_eulerian_circuit": "Perfect Loop: Can an agent visit every single corridor\nexactly once, and end up back where they started? (0 odd-degree nodes).",
	"has_eulerian_path": "Complete Sweep: Can an agent visit every single corridor\nexactly once? (0 or 2 odd-degree nodes).",
	"odd_degree_nodes": "Number of rooms with an odd number of doors.\nTo fix a broken Eulerian path, this must be 0 or 2.",
	"full_traversal_route_length": "The sequence of nodes that perfectly sweeps the graph.\nClicking this will highlight the route.",
	
	# Community Detection
	"modularity_score": "Measures how well the graph divides into distinct clusters (0.0 to 1.0).\nHigh values (>0.4) indicate dense communities ideal for distinct biomes.",
	"detected_communities": "The number of optimal clusters (districts/biomes)\nthe Louvain algorithm mathematically extracted.",
	
	# Agents
	"total_spawned": "Total number of agents instantiated during the run.",
	"total_completed": "Agents that successfully reached their step limit or target.",
	"completion_rate_percent": "Percentage of agents that finished successfully without getting trapped.",
	"average_steps": "Average number of movements taken per agent.",
	"total_aggregate_steps": "Sum of all steps taken by all agents combined.",
	
	# Markov Flow
	"absorbing_states": "Nodes where flow terminates (e.g., dead-ends or explicit exits).\nIf 0, the graph is a closed loop and analysis is skipped.",
	"transient_states": "Nodes where flow is active (intersections and corridors).",
	"average_expected_steps": "Exact mathematical average of steps an agent will take\nbefore hitting a dead-end (Fundamental Matrix inversion).",
	"max_expected_visits": "Highest expected visits any single room will receive.\nHigh numbers indicate extreme traffic congestion.",
	"flow_bottleneck_id": "The transient node receiving the most mathematical traffic.\nClicking this highlights the ultimate chokepoint.",
	
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
		
	# 1. Initialize Default Parameters from Schema
	var schema = GraphMetrics.get_analysis_options_schema()
	for item in schema:
		# Skip UI separators (TYPE_NIL)
		if item.get("type") == TYPE_NIL:
			continue
			
		# Safely get the default value, falling back to null if it doesn't exist
		_analysis_params[item.name] = item.get("default")
		
	# 2. Instantiate and hook up the Popup
	_settings_popup = AlgorithmSettingsPopup.new()
	add_child(_settings_popup)
	_settings_popup.settings_confirmed.connect(_on_settings_confirmed)
	
	if btn_settings:
		btn_settings.pressed.connect(_on_settings_pressed)

# ==============================================================================
# 1. METRICS GENERATION & UI
# ==============================================================================
# Live update receiver
# Open the popup when the gear button is clicked
func _on_settings_pressed() -> void:
	var schema = GraphMetrics.get_analysis_options_schema()
	_settings_popup.open_settings("Advanced Math Engines", schema, _analysis_params)

# Receive the batch settings dictionary when the user clicks OK
func _on_settings_confirmed(new_settings: Dictionary) -> void:
	_analysis_params = new_settings

func _on_calculate_pressed() -> void:
	if not graph_editor or not graph_editor.graph: return
		
	# --- CANCELLATION LOGIC ---
	if _is_calculating:
		results_label.text = "[center][color=#ff4444]Cancelling... (Waiting for active threads to abort)[/color][/center]"
		btn_calculate.disabled = true 
		

		GraphMetrics.cancel_analysis()
		
		return
		
	# --- START CALCULATION ---
	_is_calculating = true
	
	# Transform the calculate button into a Cancel button
	btn_calculate.text = "Cancel Analysis"
	btn_calculate.modulate = Color(1.0, 0.4, 0.4) # Danger Red
	
	if btn_settings: btn_settings.disabled = true
	if btn_export: btn_export.disabled = true
	if btn_copy: btn_copy.disabled = true
	
	if results_label:
		results_label.text = "[center][color=#f5d142]Calculating... (Background Threads Active)[/color][/center]"
		
	# Await the heavy threading...
	var report = await GraphMetrics.generate_report(graph_editor.graph, _analysis_params) 
	
	# --- FINISH / RESTORE UI ---
	_is_calculating = false
	btn_calculate.text = "Run Analysis"
	btn_calculate.modulate = Color.WHITE
	btn_calculate.disabled = false
	
	if btn_settings: btn_settings.disabled = false
	
	# If the report is null or marked as cancelled, show aborted state
	if report == null or report.get("_was_cancelled", false) == true:
		results_label.text = "[center][color=#ff4444]Analysis Aborted by User.[/color][/center]"
		if btn_export: btn_export.disabled = true
		if btn_copy: btn_copy.disabled = true
	else:
		_latest_report = report
		_populate_results_ui(_latest_report)
		if btn_export: btn_export.disabled = false
		if btn_copy: btn_copy.disabled = false


func _populate_results_ui(report: Dictionary) -> void:
	if not results_label: return
	
	var bbcode = "[center][b]Graph Analysis Report[/b][/center]\n"
	bbcode += "[right][color=#888888]" + report.get("timestamp", "") + "[/color][/right]\n\n"
	
	bbcode += _build_category_bbcode("Topological Data", report.get("topological", {}))
	
	# Add Tangles rendering block
	if report.has("robertson_seymour_tangles"):
		bbcode += _build_category_bbcode("Tangles & Treewidth", report.get("robertson_seymour_tangles", {}))
	
	# Add Chromatic rendering block
	if report.has("chromatic_coloring"):
		bbcode += _build_category_bbcode("Graph Coloring", report.get("chromatic_coloring", {}))
	
	# Add Longest Path block
	if report.has("max_exploration_path"):
		bbcode += _build_category_bbcode("Maximum Exploration Path", report.get("max_exploration_path", {}))
	
	# Add Eulerian Block
	if report.has("eulerian_edge_traversal"):
		bbcode += _build_category_bbcode("Eulerian Edge Traversal", report.get("eulerian_edge_traversal", {}))
	
	# Add Community Detection Block
	if report.has("community_detection"):
		bbcode += _build_category_bbcode("Biome Clustering (Louvain)", report.get("community_detection", {}))
	
	bbcode += _build_category_bbcode("Spatial Footprint", report.get("spatial", {}))
	bbcode += _build_category_bbcode("Agent Simulation", report.get("agents", {}))
	bbcode += _build_category_bbcode("Markov Flow Analysis", report.get("markov_flow", {}))
	bbcode += _build_category_bbcode("Zone Composition", report.get("zones", {}))
	
	results_label.text = bbcode

func _build_category_bbcode(title: String, data: Dictionary) -> String:
	if data.is_empty(): return ""
	
	var text = "[color=#42f5a4][b]--- " + title + " ---[/b][/color]\n"
	var sel_data = _latest_report.get("_selection_data", {}) # Grab hidden data
	
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
					
				# Inject Select buttons for nested properties
				var val_str = "[b]" + str(val[sub_key]) + "[/b]"
				if sel_data.has(sub_key) and (not sel_data[sub_key].get("nodes", []).is_empty() or not sel_data[sub_key].get("edges", []).is_empty()):
					val_str += " [url=%s][color=#f5d142](Select)[/color][/url]" % sub_key
					
				text += "    " + sub_key_formatted + ": " + val_str + "\n"
		else:
			var key_formatted = key.capitalize().replace("_", " ")
			if METRIC_TOOLTIPS.has(key):
				key_formatted = "[hint=\"%s\"]%s[/hint]" % [METRIC_TOOLTIPS[key], key_formatted]
				
			# Inject Select buttons for root properties
			var val_str = "[b]" + str(val) + "[/b]"
			
			# Special case for string-based IDs (like hub_node_id)
			if key == "hub_node_id" and val != "None":
				val_str += " [url=hub_node_id][color=#f5d142](Select)[/color][/url]"
			# Normal case for array-backed data
			elif sel_data.has(key) and (not sel_data[key].get("nodes", []).is_empty() or not sel_data[key].get("edges", []).is_empty()):
				val_str += " [url=%s][color=#f5d142](Select)[/color][/url]" % key
				
			text += key_formatted + ": " + val_str + "\n"
			
	return text + "\n"

# The Magic Click Handler!
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

# Helper to strip the hidden arrays so JSON remains clean
func _get_clean_report() -> Dictionary:
	var clean = _latest_report.duplicate(true)
	clean.erase("_selection_data")
	clean.erase("_was_cancelled")
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
