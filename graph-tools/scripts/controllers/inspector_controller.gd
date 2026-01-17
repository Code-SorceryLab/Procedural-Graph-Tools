class_name InspectorController
extends Node

# --- REFERENCES ---
@export_group("Core Systems")
@export var graph_editor: GraphEditor
@export var strategy_controller: StrategyController

@export_group("UI Inspector Tab")
@export var inspector_vbox: VBoxContainer    

@export var property_wizard_scene: PackedScene
var _wizard_instance: PropertyWizard
var _algo_settings_popup: AlgorithmSettingsPopup

# 1. VIEW CONTAINERS
@export var lbl_no_selection: Label      
@export var single_container: Control       
@export var group_container: Control        
@export var zone_container: Control
@export var agent_container: VBoxContainer 
@export var edge_container: Control

# --- STATE ---
var _strategies: Array[InspectorStrategy] = []

# Raw Selection State (Cached for context)
var _sel_nodes: Array[String] = []
var _sel_edges: Array = []
var _sel_agents: Array = []
var _sel_zones: Array = []

func _ready() -> void:
	# 1. Initialize Tools
	if property_wizard_scene:
		_wizard_instance = property_wizard_scene.instantiate()
		add_child(_wizard_instance)
		_wizard_instance.property_defined.connect(func(_n): _refresh_all_views())
		_wizard_instance.purge_requested.connect(_on_purge_requested)
	
	_algo_settings_popup = AlgorithmSettingsPopup.new()
	add_child(_algo_settings_popup)

	# 2. Initialize Strategies
	# Note: The order here determines the visual order in the stack (Top to Bottom)
	_strategies.append(InspectorAgent.new(graph_editor, agent_container, _algo_settings_popup))
	_strategies.append(InspectorZone.new(graph_editor, zone_container))
	_strategies.append(InspectorNode.new(graph_editor, single_container, group_container))
	_strategies.append(InspectorEdge.new(graph_editor, edge_container))
	
	# 3. Connect Strategy Signals
	for strat in _strategies:
		strat.request_wizard.connect(_on_wizard_requested)
		strat.request_refresh_ui.connect(_refresh_all_views)

	# 4. Connect Core Signals
	if graph_editor:
		graph_editor.selection_changed.connect(_on_nodes_selected)
		graph_editor.graph_modified.connect(_on_graph_modified)
		graph_editor.graph_loaded.connect(func(_g): _clear_selection())
		
		if graph_editor.has_signal("edge_selection_changed"):
			graph_editor.edge_selection_changed.connect(_on_edges_selected)
			
		if graph_editor.has_signal("request_inspector_view"):
			graph_editor.request_inspector_view.connect(_on_inspector_view_requested)

	if SignalManager.has_signal("agent_selection_changed"):
		SignalManager.agent_selection_changed.connect(_on_agents_selected)
	
	if SignalManager.has_signal("zone_selection_changed"):
		SignalManager.zone_selection_changed.connect(_on_zones_selected)
		
	_clear_selection()

# --- SELECTION HANDLERS ---

func _on_nodes_selected(nodes: Array[String]) -> void:
	_sel_nodes = nodes
	_refresh_all_views()

func _on_edges_selected(edges: Array) -> void:
	_sel_edges = edges
	_refresh_all_views()

func _on_agents_selected(agents: Array) -> void:
	_sel_agents = agents
	_refresh_all_views()

func _on_zones_selected(zones: Array) -> void:
	_sel_zones = zones
	_refresh_all_views()

func _on_graph_modified() -> void:
	# [FIX] Update ALL active strategies, not just one.
	# This ensures that if you are looking at a Node AND an Agent, both update.
	for strat in _strategies:
		if strat.can_handle(_sel_nodes, _sel_edges, _sel_agents, _sel_zones):
			strat.update(_sel_nodes, _sel_edges, _sel_agents, _sel_zones)

# --- ROUTER LOGIC ---

func _refresh_all_views() -> void:
	var something_visible = false
	
	# [FIX] Iterate ALL strategies and allow multiple to activate.
	# This creates a "Stack" of inspectors instead of an exclusive switch.
	for strat in _strategies:
		if strat.can_handle(_sel_nodes, _sel_edges, _sel_agents, _sel_zones):
			strat.enter(_sel_nodes, _sel_edges, _sel_agents, _sel_zones)
			something_visible = true
		else:
			strat.exit()
			
	lbl_no_selection.visible = not something_visible

func _clear_selection() -> void:
	_sel_nodes.clear()
	_sel_edges.clear()
	_sel_agents.clear()
	_sel_zones.clear()
	_refresh_all_views()

# --- WIZARD HANDLER ---

func _on_wizard_requested(target_type: String) -> void:
	if not _wizard_instance: return
	
	var idx = 0
	match target_type:
		"NODE": idx = 0
		"EDGE": idx = 1
		"AGENT": idx = 2
		"ZONE": idx = 3
		
	_wizard_instance.input_target.selected = idx
	_wizard_instance.popup_wizard()

func _on_purge_requested(key: String, target: String) -> void:
	var graph = graph_editor.graph
	if not graph: return
	
	match target:
		"NODE":
			for id in graph.nodes:
				var node = graph.nodes[id]
				if node.data.has(key): node.data.erase(key)
		"EDGE":
			for a in graph.edge_data:
				for b in graph.edge_data[a]:
					var d = graph.edge_data[a][b]
					if d.has(key): d.erase(key)
		"AGENT":
			for agent in graph.agents:
				if key in agent: agent.set(key, null) 
	
	print("InspectorController: Purged property '%s' from target '%s'" % [key, target])
	_refresh_all_views()

# --- UTILITY ---

func _on_inspector_view_requested() -> void:
	if not inspector_vbox: return
	var parent = inspector_vbox.get_parent()
	if parent is TabContainer:
		parent.current_tab = inspector_vbox.get_index()
	else:
		inspector_vbox.visible = true
