class_name MutateGrowPatterns extends GraphModifier

# ==============================================================================
# GROW TOPOLOGICAL PATTERNS (attach-only, DLA-shaped)
# ==============================================================================
# Growth model:
#   1. Gather perimeter nodes: any node with at least one free adjacent grid slot.
#   2. Uniformly pick a perimeter anchor.
#   3. Compute a LOCAL outward vector from the anchor's free directions.
#   4. Stamp a rotated copy of the picked pattern, attached at the anchor.
#
# A pattern is rejected (and the anchor retried) if:
#   - enforce_planarity is on AND proposed nodes collide with non-anchor nodes,
#   - enforce_planarity is on AND proposed edges cross existing edges,
#   - the pattern has fewer than 2 nodes (degenerate).
#
# Note: `get_required_semantics()` is NOT overridden — pattern custom_data keys are
# only known at execute() time (they come from pipeline_context), so we can't
# pre-register them on the main thread. Scrubbed mode avoids the issue entirely.
# ==============================================================================

var _local_id_counter: int = 0

func _init() -> void:
	super._init()
	modifier_name = "Grow Topological Patterns"
	category = Category.TOPOLOGY

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{
			"name": "btn_extract",
			"label": "Pattern Editor",
			"type": TYPE_NIL,
			"default": "Open Extractor Popup",
			"hint_string": "button"
		},
		{
			"name": "iterations",
			"label": "Growth Iterations",
			"type": TYPE_INT,
			"default": 10,
			"min": 1,
			"max": 1000
		},
		{
			"name": "enforce_planarity",
			"label": "Enforce Planarity",
			"type": TYPE_BOOL,
			"default": true
		},
		{
			"name": "max_attempts",
			"label": "Max Anchor Attempts / Iteration",
			"type": TYPE_INT,
			"default": 10,
			"min": 1,
			"max": 200,
			"hint_text": "How many perimeter anchors to try before giving up on this iteration."
		},
		{
			"name": "orthogonal_only",
			"label": "Orthogonal (90°) Mode",
			"type": TYPE_BOOL,
			"default": true,
			"hint_text": "Constrain rotations to 90°. Also disables post-rotation jitter."
		},
		{
			"name": "snap_to_grid",
			"label": "Snap to Grid",
			"type": TYPE_BOOL,
			"default": true,
			"hint_text": "Force new nodes onto GraphSettings.GRID_SPACING."
		},
		{
			"name": "min_node_spacing",
			"label": "Min Node Spacing (grid units)",
			"type": TYPE_FLOAT,
			"default": 0.0,
			"min": 0.0,
			"max": 10.0,
			"step": 0.25,
			"hint_text": "Minimum center-to-center distance from any existing node, in grid-spacing units. 0 = disabled. Useful when nodes become room scenes that need clearance."
		},
		{
			"name": "scrub_metadata",
			"label": "Scrub Semantic Data",
			"type": TYPE_BOOL,
			"default": true,
			"hint_text": "When on, new nodes are plain 'empty' nodes. When off, type + custom_data are copied from the pattern."
		}
	])
	return s

# ==============================================================================
# MAIN
# ==============================================================================

func execute(recorder: GraphRecorder) -> void:
	setup_rng()
	_local_id_counter = 0
	
	var pattern_dict = pipeline_context.get("extracted_topo_patterns", {})
	if not pattern_dict.has("patterns") or pattern_dict["patterns"].is_empty():
		print("MutateGrowPatterns: No patterns available. Skipping.")
		return

	var iterations: int        = local_settings.get("iterations", 10)
	var enforce_planarity: bool = local_settings.get("enforce_planarity", true)
	var max_attempts: int      = local_settings.get("max_attempts", 10)
	var orthogonal_only: bool  = local_settings.get("orthogonal_only", true)
	var snap_grid: bool        = local_settings.get("snap_to_grid", true)
	var min_spacing_units: float = local_settings.get("min_node_spacing", 0.0)
	var min_spacing_px: float = 0.0
	if min_spacing_units > 0.0:
		var gs: Vector2 = GraphSettings.GRID_SPACING
		min_spacing_px = min(gs.x, gs.y) * min_spacing_units
	var scrub: bool            = local_settings.get("scrub_metadata", true)

	# Filter and weight active patterns.
	var active_patterns: Array = []
	var total_weight: int = 0
	for p in pattern_dict["patterns"]:
		if p.get("active", true):
			active_patterns.append(p)
			total_weight += max(1, int(p.get("weight", 1)))

	if active_patterns.is_empty():
		print("MutateGrowPatterns: All patterns marked inactive. Skipping.")
		return

	# Pre-deserialize all patterns ONCE per execute().
	# This collapses the worker-thread exposure of GraphSerializer.deserialize to a
	# single batch, and it's cheaper than re-deserializing each iteration.
	var pattern_graphs: Dictionary = {}  # signature -> Graph
	for p in active_patterns:
		var sig: String = p.get("signature", "")
		if sig == "":
			push_warning("MutateGrowPatterns: Pattern without signature — skipped.")
			continue
		var rg: Graph = _deserialize_pattern(p)
		if rg != null:
			pattern_graphs[sig] = rg

	if pattern_graphs.is_empty():
		print("MutateGrowPatterns: No deserializable patterns. Skipping.")
		return

	# Seed an empty graph so growth has somewhere to start.
	if recorder.nodes.is_empty():
		var seed_id := _make_new_id(recorder)
		recorder.add_node(seed_id, Vector2.ZERO)
		recorder.set_node_type(seed_id, "empty")
		print("MutateGrowPatterns: Empty graph — seeded origin node '%s'." % seed_id)

	print("\n--- GROW: %d patterns active, %d iterations ---" % [active_patterns.size(), iterations])

	var applied_count := 0
	for gen in range(iterations):
		var pattern: Dictionary = _pick_weighted_pattern(active_patterns, total_weight)
		var sig: String = pattern.get("signature", "")
		var rule_graph: Graph = pattern_graphs.get(sig, null)
		if rule_graph == null:
			continue

		var candidates: Array = _gather_perimeter_candidates(recorder, orthogonal_only)
		if candidates.is_empty():
			# Graph is fully packed — no room to grow anywhere.
			break

		SeedUtils.shuffle(candidates, rng)

		var attempts: int = min(max_attempts, candidates.size())
		for i in range(attempts):
			var anchor: Dictionary = candidates[i]
			if _attempt_transformation(recorder, anchor, rule_graph,
		enforce_planarity, orthogonal_only, snap_grid, scrub, min_spacing_px):
				applied_count += 1
				break

	print("--- GROW COMPLETE: applied %d / %d iterations ---" % [applied_count, iterations])

# ==============================================================================
# PERIMETER CANDIDATES
# ==============================================================================

# Returns [{id, pos, outward, free_count}, ...] for every node with at least
# one free adjacent grid slot. `outward` is a normalized Vector2 pointing into
# the nearest free space from that node's perspective.
func _gather_perimeter_candidates(recorder: GraphRecorder, orthogonal_only: bool) -> Array:
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	# Diagonals included only in non-orthogonal mode; they're not real adjacency
	# in grid-aligned graphs but can be real if snap_grid is off.
	if not orthogonal_only:
		dirs.append_array([
			Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
		])

	var spacing: Vector2 = GraphSettings.GRID_SPACING
	var check_radius: float = GraphSettings.NODE_RADIUS * 2.0
	var candidates: Array = []

	for id in recorder.nodes:
		var pos: Vector2 = recorder.get_node_pos(id)
		var free_dirs: Array[Vector2i] = []

		for d in dirs:
			var probe: Vector2 = pos + Vector2(d) * spacing
			if recorder.get_nodes_near_position(probe, check_radius).is_empty():
				free_dirs.append(d)

		if free_dirs.is_empty():
			continue  # Interior node — nowhere to grow.

		# Average the free directions. If they cancel, pick one at random
		# (this is the "node on a straight line" case — grows either way).
		var outward := Vector2.ZERO
		for d in free_dirs:
			outward += Vector2(d)
		if outward == Vector2.ZERO:
			outward = Vector2(SeedUtils.pick_random(free_dirs, rng))
		outward = outward.normalized()

		candidates.append({
			"id": id,
			"pos": pos,
			"outward": outward,
			"free_count": free_dirs.size()
		})

	return candidates

# ==============================================================================
# PATTERN SELECTION
# ==============================================================================

func _pick_weighted_pattern(patterns: Array, total_weight: int) -> Dictionary:
	var roll: int = rng.randi_range(1, total_weight)
	var cursor: int = 0
	for p in patterns:
		cursor += max(1, int(p.get("weight", 1)))
		if roll <= cursor:
			return p
	return patterns.back()

# ==============================================================================
# DESERIALIZATION
# ==============================================================================

func _deserialize_pattern(p: Dictionary) -> Graph:
	if p.has("graph_json"):
		return GraphSerializer.deserialize(p["graph_json"], false)
	if p.has("graph") and p["graph"] is Graph:
		# Defensive: if the popup stored the mini-graph directly, duplicate it
		# so a concurrent modifier can't mutate our reference.
		return p["graph"].duplicate()
	push_warning("MutateGrowPatterns: Pattern has neither graph_json nor graph.")
	return null

# ==============================================================================
# TRANSFORMATION
# ==============================================================================

func _attempt_transformation(
		recorder: GraphRecorder,
		anchor: Dictionary,
		rule_graph: Graph,
		enforce_planarity: bool,
		orthogonal_only: bool,
		snap_grid: bool,
		scrub: bool,
		min_spacing_px: float
) -> bool:

	if rule_graph.nodes.size() < 2:
		return false  # Degenerate pattern — nothing to grow.

	var seed_real_id: String  = anchor["id"]
	var seed_real_pos: Vector2 = anchor["pos"]
	var outward_vector: Vector2 = anchor["outward"]

	# Pick which rule node is the seed (attach point). Random per call for variety.
	var rule_ids: Array = rule_graph.nodes.keys()
	SeedUtils.shuffle(rule_ids, rng)
	var seed_rule_id: String = rule_ids[0]
	var seed_rule_pos: Vector2 = rule_graph.get_node_pos(seed_rule_id)

	# Rotation: align the vector from seed-rule-node toward the pattern's centroid
	# with the local outward vector. Fallback to another rule node if seed sits
	# at the centroid (avoids degenerate zero-length vector).
	var rule_center := Vector2.ZERO
	for rid in rule_graph.nodes:
		rule_center += rule_graph.nodes[rid].position
	rule_center /= float(rule_graph.nodes.size())

	var pattern_vector: Vector2 = (rule_center - seed_rule_pos)
	if pattern_vector.length_squared() < 0.0001:
		for rid in rule_graph.nodes:
			if rid == seed_rule_id:
				continue
			pattern_vector = rule_graph.get_node_pos(rid) - seed_rule_pos
			break
	pattern_vector = pattern_vector.normalized() if pattern_vector.length_squared() > 0.0001 else Vector2.RIGHT

	var rotation_angle: float = pattern_vector.angle_to(outward_vector)
	if orthogonal_only:
		rotation_angle = snappedf(rotation_angle, PI / 2.0)

	# Build proposed positions for every non-seed rule node.
	var grid_spacing: Vector2 = GraphSettings.GRID_SPACING
	var proposed_nodes: Dictionary = {}
	for rule_id in rule_graph.nodes:
		if rule_id == seed_rule_id:
			continue
		var offset: Vector2 = rule_graph.get_node_pos(rule_id) - seed_rule_pos
		var rotated: Vector2 = offset.rotated(rotation_angle)
		var spawn_pos: Vector2 = seed_real_pos + rotated
		if snap_grid:
			spawn_pos = spawn_pos.snapped(grid_spacing)
		elif not orthogonal_only:
			spawn_pos += Vector2(rng.randf_range(-5, 5), rng.randf_range(-5, 5))
		proposed_nodes[rule_id] = spawn_pos

	# Build proposed edges (dedup by position pair — undirected edges appear twice
	# in rule_graph.edge_store).
	var proposed_edges: Array = []
	var seen_pairs: Dictionary = {}
	for key in rule_graph.edge_store:
		var e: Dictionary = rule_graph.edge_store[key]
		if not rule_graph.nodes.has(e.u) or not rule_graph.nodes.has(e.v):
			push_warning("MutateGrowPatterns: Rule edge references missing node.")
			continue
		var pos_u: Vector2 = seed_real_pos if e.u == seed_rule_id else proposed_nodes[e.u]
		var pos_v: Vector2 = seed_real_pos if e.v == seed_rule_id else proposed_nodes[e.v]
		var k: Array = [pos_u, pos_v]
		k.sort()
		if seen_pairs.has(k):
			continue
		seen_pairs[k] = true
		proposed_edges.append([pos_u, pos_v])

	# --- Planarity ---
	if enforce_planarity:
		if not _check_planarity(recorder, proposed_nodes, proposed_edges, [seed_real_id]):
			return false

	# --- Minimum spacing (independent of planarity) ---
	if min_spacing_px > 0.0:
		if not _check_min_spacing(recorder, proposed_nodes, [seed_real_id], min_spacing_px):
			return false

	# --- Commit ---
	var id_mapping: Dictionary = { seed_rule_id: seed_real_id }
	var anchor_set: Dictionary = { seed_real_id: true }

	for rule_id in proposed_nodes:
		var spawn_pos: Vector2 = proposed_nodes[rule_id]
		var new_id: String = _make_new_id(recorder)
		id_mapping[rule_id] = new_id
		anchor_set[new_id] = true

		recorder.add_node(new_id, spawn_pos)

		if scrub:
			# set_node_type to "empty" is a no-op on fresh NodeData (already "empty"),
			# so it costs nothing and produces no command. Skip custom_data entirely.
			pass
		else:
			var r_node: NodeData = rule_graph.nodes[rule_id]
			recorder.set_node_type(new_id, r_node.type)
			for k in r_node.custom_data:
				recorder.set_node_property(new_id, k, r_node.custom_data[k])

	# Edges.
	for key in rule_graph.edge_store:
		var e: Dictionary = rule_graph.edge_store[key]
		var live_u: String = id_mapping.get(e.u, "")
		var live_v: String = id_mapping.get(e.v, "")
		if live_u == "" or live_v == "":
			continue
		if recorder.has_edge(live_u, live_v):
			continue
		var extra: Dictionary = {} if scrub else e.custom.duplicate(true)
		# NOTE: directed-pattern information is intentionally flattened here.
		# If you later want directed patterns to preserve direction, this is the
		# line to change (and rule_graph's per-edge `direction` becomes relevant).
		recorder.add_edge(live_u, live_v, e.weight, false, extra)

	return true

# Returns true if the proposal is planar-safe (no collisions, no crossings).
# `exempt_ids` are nodes we're allowed to overlap (the seed anchor).
func _check_planarity(
		recorder: GraphRecorder,
		proposed_nodes: Dictionary,
		proposed_edges: Array,
		exempt_ids: Array
) -> bool:
	var exempt: Dictionary = {}
	for id in exempt_ids:
		exempt[id] = true

	var col_radius: float = GraphSettings.NODE_RADIUS * 2.5

	# A. Node collisions.
	for rule_id in proposed_nodes:
		var p_pos: Vector2 = proposed_nodes[rule_id]
		var nearby: Array[String] = recorder.get_nodes_near_position(p_pos, col_radius)
		for hit_id in nearby:
			if exempt.has(hit_id):
				continue
			# Exact-position overlap — collision even if exempt set missed it.
			if recorder.get_node_pos(hit_id).distance_squared_to(p_pos) < 0.01:
				return false
			return false

	# B. Edge crossings.
	var grow: float = GraphSettings.NODE_RADIUS
	for p_edge in proposed_edges:
		var rect: Rect2 = Rect2(p_edge[0], p_edge[1] - p_edge[0]).abs().grow(grow)
		var existing: Array = recorder.get_edges_in_rect(rect)
		for ex_e in existing:
			var ex_a: Vector2 = recorder.get_node_pos(ex_e[0])
			var ex_b: Vector2 = recorder.get_node_pos(ex_e[1])
			# Shared endpoint = legitimate joint, not a crossing.
			if p_edge[0].distance_squared_to(ex_a) < 1.0 or p_edge[0].distance_squared_to(ex_b) < 1.0:
				continue
			if p_edge[1].distance_squared_to(ex_a) < 1.0 or p_edge[1].distance_squared_to(ex_b) < 1.0:
				continue
			if Geometry2D.segment_intersects_segment(p_edge[0], p_edge[1], ex_a, ex_b) != null:
				return false

	return true


# Returns true if every proposed node is at least `min_spacing_px` from any
# existing node not in `exempt_ids`. Uses the spatial grid for the broad phase
# and an explicit distance check for the boundary.
func _check_min_spacing(
		recorder: GraphRecorder,
		proposed_nodes: Dictionary,
		exempt_ids: Array,
		min_spacing_px: float
) -> bool:
	var exempt: Dictionary = {}
	for id in exempt_ids:
		exempt[id] = true

	for rule_id in proposed_nodes:
		var p_pos: Vector2 = proposed_nodes[rule_id]
		var nearby: Array[String] = recorder.get_nodes_near_position(p_pos, min_spacing_px)
		for hit_id in nearby:
			if exempt.has(hit_id):
				continue
			if p_pos.distance_to(recorder.get_node_pos(hit_id)) < min_spacing_px:
				return false
	return true

func _make_new_id(recorder: GraphRecorder) -> String:
	while true:
		_local_id_counter += 1
		var candidate: String = "grow:%d" % _local_id_counter
		if not recorder.nodes.has(candidate):
			return candidate
	return ""
