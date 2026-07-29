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

# --- STATE ---
var _latest_report: Dictionary = {}

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
	
	# Spatial
	"total_cells_used": "Number of internal spatial grid cells containing at least one node.",
	"avg_nodes_per_cell": "Average node density per populated spatial cell.",
	"area": "Total square area of the graph's bounding box.",
	
	# Agents
	"total_spawned": "Total number of agents instantiated during the run.",
	"total_completed": "Agents that successfully reached their step limit or target.",
	"completion_rate_percent": "Percentage of agents that finished successfully without getting trapped.",
	"average_steps": "Average number of movements taken per agent.",
	"total_aggregate_steps": "Sum of all steps taken by all agents combined.",
	
	# Zones
	"total_zones": "Number of defined geographical regions (biomes).",
	"aggregate_area_size": "Total number of nodes registered to a zone."
}

func _ready() -> void:
	if btn_calculate:
		btn_calculate.pressed.connect(_on_calculate_pressed)
		
	if btn_export:
		btn_export.pressed.connect(_on_export_pressed)
		btn_export.disabled = true 
		
	if btn_copy:
		btn_copy.pressed.connect(_on_copy_pressed)
		btn_copy.disabled = true
		
	if file_dialog:
		file_dialog.file_selected.connect(_on_file_selected)
		
	if results_label:
		results_label.text = "[center][color=#666666]Ready for analysis.[/color][/center]"

# ==============================================================================
# 1. METRICS GENERATION & UI
# ==============================================================================

func _on_calculate_pressed() -> void:
	if not graph_editor or not graph_editor.graph:
		return
		
	_latest_report = GraphMetrics.generate_report(graph_editor.graph)
	_populate_results_ui(_latest_report)
	
	if btn_export: btn_export.disabled = false
	if btn_copy: btn_copy.disabled = false

func _populate_results_ui(report: Dictionary) -> void:
	if not results_label: return
	
	var bbcode = "[center][b]Graph Analysis Report[/b][/center]\n"
	bbcode += "[right][color=#888888]" + report.get("timestamp", "") + "[/color][/right]\n\n"
	
	bbcode += _build_category_bbcode("Topological Data", report.get("topological", {}))
	bbcode += _build_category_bbcode("Spatial Footprint", report.get("spatial", {}))
	bbcode += _build_category_bbcode("Agent Simulation", report.get("agents", {}))
	bbcode += _build_category_bbcode("Zone Composition", report.get("zones", {}))
	
	results_label.text = bbcode

func _build_category_bbcode(title: String, data: Dictionary) -> String:
	if data.is_empty(): return ""
	
	var text = "[color=#42f5a4][b]--- " + title + " ---[/b][/color]\n"
	
	for key in data:
		var val = data[key]
		
		if val is Dictionary:
			var parent_key_formatted = key.capitalize().replace("_", " ")
			if METRIC_TOOLTIPS.has(key):
				# [FIX] Added escaped double quotes around the hint text
				parent_key_formatted = "[hint=\"%s\"]%s[/hint]" % [METRIC_TOOLTIPS[key], parent_key_formatted]
				
			text += "[color=#aaaaaa]" + parent_key_formatted + ":[/color]\n"
			
			for sub_key in val:
				var sub_key_formatted = sub_key.capitalize().replace("_", " ")
				if METRIC_TOOLTIPS.has(sub_key):
					# [FIX] Added escaped double quotes around the hint text
					sub_key_formatted = "[hint=\"%s\"]%s[/hint]" % [METRIC_TOOLTIPS[sub_key], sub_key_formatted]
					
				text += "    " + sub_key_formatted + ": [b]" + str(val[sub_key]) + "[/b]\n"
		else:
			var key_formatted = key.capitalize().replace("_", " ")
			if METRIC_TOOLTIPS.has(key):
				# [FIX] Added escaped double quotes around the hint text
				key_formatted = "[hint=\"%s\"]%s[/hint]" % [METRIC_TOOLTIPS[key], key_formatted]
				
			text += key_formatted + ": [b]" + str(val) + "[/b]\n"
			
	return text + "\n"

# ==============================================================================
# 2. EXPORT LOGIC
# ==============================================================================
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
		file.store_string(JSON.stringify(_latest_report, "\t"))
		file.close()

func _on_copy_pressed() -> void:
	if _latest_report.is_empty(): return
	
	var json_string = JSON.stringify(_latest_report, "\t")
	DisplayServer.clipboard_set(json_string)
	
	if btn_copy:
		var original_text = btn_copy.text
		btn_copy.text = "Copied!"
		await get_tree().create_timer(1.5).timeout
		if is_instance_valid(btn_copy): # Safety check in case UI is closed
			btn_copy.text = original_text
