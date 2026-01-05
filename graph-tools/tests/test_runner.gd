extends Node
class_name TestRunner

# Configuration
var _tests_passed: int = 0
var _tests_failed: int = 0

func _ready() -> void:
	print("\n=== STARTING TEST SUITE ===\n")
	
	# --- EXECUTE TESTS HERE ---
	# We run them one by one.
	_test_id_reconstruction()
	_test_strategy_append_logic()
	_test_mst_decorator()
	_test_dla_generation()
	_test_analyze_rooms()
	# --------------------------
	
	print("\n=== TEST SUITE COMPLETE ===")
	print("Passed: %d | Failed: %d" % [_tests_passed, _tests_failed])
	if _tests_failed == 0:
		print("RESULT: ALL SYSTEMS GREEN ✅")
	else:
		print("RESULT: FAILURES DETECTED ❌")
	
	# Optional: Quit automatically if running from command line
	# get_tree().quit()

# ==============================================================================
# TEST CASES
# ==============================================================================

# TEST 1: The "Save/Load Amnesia" Fix
func _test_id_reconstruction() -> void:
	print("TEST: ID State Reconstruction (GraphEditor)...")
	
	# 1. Setup
	var editor = GraphEditor.new()
	
	# --- MOCK DEPENDENCIES ---
	# Since we used .new() instead of loading the .tscn scene, 
	# the children ($Renderer, $Camera) don't exist. We must inject them manually.
	editor.renderer = GraphRenderer.new()
	editor.camera = GraphCamera.new()
	# -------------------------
	
	var mock_graph = Graph.new()
	
	# Add a node that mimics a saved "Manual Node #5"
	mock_graph.add_node("man:5", Vector2.ZERO)
	
	# 2. Act (Load the graph)
	# This triggers '_reconstruct_state_from_ids()'
	# It also talks to the renderer/camera, which now exist (as mocks).
	editor.load_new_graph(mock_graph)
	
	# 3. Assert behavior
	# We temporarily create a node to see what ID it generates
	editor.create_node(Vector2(100, 100))
	
	# Scan for the new ID
	var keys = editor.graph.nodes.keys()
	var new_id = ""
	for id in keys:
		if id != "man:5":
			new_id = id
			break
			
	# Expectation: "man:6"
	var expected_id = "man:6"
	
	if new_id == expected_id:
		_pass("Counter correctly restored. Generated %s after man:5." % new_id)
	else:
		_fail("Counter Reset Bug detected. Expected %s, got %s." % [expected_id, new_id])
	
	# Cleanup (Free the mocks too since they aren't in the tree)
	editor.renderer.free()
	editor.camera.free()
	editor.free()

# TEST 2: Strategy Append Logic
# Verifies that we can layer a Walker on top of a Grid without deleting the Grid.
func _test_strategy_append_logic() -> void:
	print("TEST: Strategy Append Logic (Grid + Walker)...")
	
	# 1. Setup Mock Editor
	var editor = GraphEditor.new()
	editor.renderer = GraphRenderer.new()
	editor.camera = GraphCamera.new()
	
	# 2. Run Strategy A: GRID (Should clear/init the graph)
	var strategy_grid = StrategyGrid.new()
	var params_grid = {"width": 5, "height": 5}
	
	# Simulate "Generate" button click (Grid is a resetter)
	if strategy_grid.reset_on_generate:
		editor.clear_graph()
	editor.apply_strategy(strategy_grid, params_grid)
	
	# Checkpoint: Grid should have 25 nodes
	var count_after_grid = editor.graph.nodes.size()
	if count_after_grid != 25:
		_fail("Grid failed to generate. Expected 25 nodes, got %d." % count_after_grid)
		editor.renderer.free(); editor.camera.free(); editor.free(); return

	# 3. Run Strategy B: WALKER (With Append Mode)
	var strategy_walker = StrategyWalker.new()
	var params_walker = {
		"steps": 10, 
		"merge_overlaps": false, # Force new nodes so we can count them easily
		"append": true           # CRITICAL FLAG
	}
	
	# Simulate "Grow" button click (We explicitly SKIP clear_graph)
	editor.apply_strategy(strategy_walker, params_walker)
	
	# 4. Assert
	# We expect 25 Grid Nodes + 10 Walker Nodes = 35 Total
	# (Note: Walker might generate fewer if it walks on itself, but count should be > 25)
	
	var count_final = editor.graph.nodes.size()
	
	if count_final > 25:
		_pass("Append successful. Node count increased from 25 to %d." % count_final)
	elif count_final == 10:
		_fail("Append Failed. The Grid was deleted! Only Walker nodes remain.")
	else:
		_fail("Unknown state. Expected > 25 nodes, got %d." % count_final)

	# Cleanup
	editor.renderer.free()
	editor.camera.free()
	editor.free()

# TEST 3: MST Decorator Logic
# Verifies that MST can run on an existing graph without crashing
# and effectively reduces the edge count (removes cycles).
func _test_mst_decorator() -> void:
	print("TEST: MST Decorator (Prim's Algorithm)...")
	
	# 1. Setup Mock Editor
	var editor = GraphEditor.new()
	editor.renderer = GraphRenderer.new()
	editor.camera = GraphCamera.new()
	
	# 2. Create a "Cycle Heavy" Graph (A Box with X in middle)
	# 0-1
	# |X|
	# 2-3
	var graph = editor.graph
	graph.add_node("n0", Vector2(0,0))
	graph.add_node("n1", Vector2(100,0))
	graph.add_node("n2", Vector2(0,100))
	graph.add_node("n3", Vector2(100,100))
	
	# Connect everyone to everyone (6 edges)
	graph.add_edge("n0", "n1")
	graph.add_edge("n0", "n2")
	graph.add_edge("n0", "n3") # Diagonal
	graph.add_edge("n1", "n2") # Diagonal
	graph.add_edge("n1", "n3")
	graph.add_edge("n2", "n3")
	
	# Verify setup
	# Note: In an undirected graph, our implementation might store double entries or single.
	# Let's count connections manually.
	var edge_count_start = 0
	for id in graph.nodes:
		edge_count_start += graph.get_neighbors(id).size()
	# 4 nodes connected to 3 others = 12 connections (6 bidirectional edges)
	
	# 3. Apply MST
	var strategy = StrategyMST.new()
	# This line would CRASH if clear_edges() was missing:
	editor.apply_strategy(strategy, {}) 
	
	# 4. Assert
	# A Minimum Spanning Tree for V nodes always has V-1 edges.
	# 4 nodes -> should have 3 edges.
	# 3 edges * 2 (bidirectional) = 6 connections total.
	
	var edge_count_final = 0
	for id in graph.nodes:
		edge_count_final += graph.get_neighbors(id).size()
		
	if edge_count_final == 6:
		_pass("MST successfully reduced edges from %d to 6." % edge_count_start)
	elif edge_count_final == edge_count_start:
		_fail("MST did nothing! Edges remain at %d." % edge_count_final)
	else:
		_fail("MST produced unexpected edge count: %d (Expected 6)." % edge_count_final)

	# Cleanup
	editor.renderer.free()
	editor.camera.free()
	editor.free()

# TEST 4: DLA Generation
# Verifies DLA runs, respects particle count, and generates valid IDs.
func _test_dla_generation() -> void:
	print("TEST: DLA Generation (Simulation)...")
	
	var editor = GraphEditor.new()
	editor.renderer = GraphRenderer.new()
	editor.camera = GraphCamera.new()
	
	# 1. Run DLA Strategy
	var strategy = StrategyDLA.new()
	var target_particles = 20
	var params = {
		"particles": target_particles,
		"use_box": true,  # Test the "Box" logic specifically
		"append": false   # Clear board first
	}
	
	# Execute
	if strategy.reset_on_generate:
		editor.clear_graph()
	editor.apply_strategy(strategy, params)
	
	# 2. Assert
	# Count should be exactly target_particles + 1 (The Seed) OR just target_particles
	# depending on implementation. 
	# Our DLA script usually adds a seed if empty, then adds particles.
	var final_count = editor.graph.nodes.size()
	
	# We allow a small margin because DLA sometimes merges overlaps
	if final_count >= target_particles:
		_pass("DLA generated %d nodes (Target: %d)." % [final_count, target_particles])
	else:
		_fail("DLA Under-generated! Got %d, Expected at least %d." % [final_count, target_particles])
		
	# 3. ID Check
	# Check strictly for the new ID schema "dla:x:y"
	var has_valid_id = false
	for id in editor.graph.nodes:
		if id.begins_with("dla:"):
			has_valid_id = true
			break
	
	assert_true(has_valid_id, "Nodes have correct 'dla:' ID prefix.")
	
	editor.renderer.free(); editor.camera.free(); editor.free()

# TEST 5: Analyze Rooms (BFS & Game Logic)
# Verifies depth calculation and automatic room typing.
func _test_analyze_rooms() -> void:
	print("TEST: Analyze Rooms (BFS & Auto-Typing)...")
	
	var editor = GraphEditor.new()
	editor.renderer = GraphRenderer.new()
	editor.camera = GraphCamera.new()
	var graph = editor.graph
	
	# 1. Setup a "Line" Graph (Chain)
	# n0 (0,0) <-> n1 (10,0) <-> n2 (20,0) <-> n3 (30,0)
	# Center is (0,0), so n0 should be SPAWN.
	# n3 is furthest, so n3 should be BOSS.
	
	graph.add_node("n0", Vector2(0,0))
	graph.add_node("n1", Vector2(100,0))
	graph.add_node("n2", Vector2(200,0))
	graph.add_node("n3", Vector2(300,0))
	
	graph.add_edge("n0", "n1")
	graph.add_edge("n1", "n2")
	graph.add_edge("n2", "n3")
	
	# 2. Run Analysis
	var strategy = StrategyAnalyze.new()
	var params = {"auto_types": true}
	
	editor.apply_strategy(strategy, params)
	
	# 3. Assert Depth
	# n0 should be depth 0, n3 should be depth 3
	var depth_0 = graph.nodes["n0"].depth
	var depth_3 = graph.nodes["n3"].depth
	
	assert_eq(depth_0, 0, "Node n0 Depth (Spawn)")
	assert_eq(depth_3, 3, "Node n3 Depth (End)")
	
	# 4. Assert Room Types
	# We need to access the Enum values from NodeData
	var type_0 = graph.nodes["n0"].type
	var type_3 = graph.nodes["n3"].type
	
	# NodeData.RoomType.SPAWN usually = 1
	# NodeData.RoomType.BOSS usually = 4
	# (Adjust integers based on your Enum order if this fails)
	
	if type_0 == NodeData.RoomType.SPAWN:
		_pass("n0 correctly identified as SPAWN.")
	else:
		_fail("n0 is not SPAWN. Got Enum Value: %d" % type_0)
		
	if type_3 == NodeData.RoomType.BOSS:
		_pass("n3 correctly identified as BOSS.")
	else:
		_fail("n3 is not BOSS. Got Enum Value: %d" % type_3)

	editor.renderer.free(); editor.camera.free(); editor.free()

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

func _pass(msg: String) -> void:
	_tests_passed += 1
	print("  [PASS] " + msg)

func _fail(msg: String) -> void:
	_tests_failed += 1
	push_error("  [FAIL] " + msg)

func assert_eq(actual, expected, msg: String = "") -> void:
	if actual == expected:
		_pass(msg)
	else:
		_fail("%s [Expected: %s, Got: %s]" % [msg, str(expected), str(actual)])

func assert_true(condition: bool, msg: String) -> void:
	if condition:
		_pass(msg)
	else:
		_fail(msg)
