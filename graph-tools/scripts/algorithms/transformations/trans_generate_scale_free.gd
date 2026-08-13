class_name GenerateScaleFree
extends GraphModifier

func _init() -> void:
	super._init()
	modifier_name = "Generate Scale-Free Graph"
	category = Category.GENERATOR

func get_settings() -> Array[Dictionary]:
	var s = super.get_settings()
	s.append_array([
		{ "name": "node_count", "label": "Node Count", "type": TYPE_INT, "default": 50, "min": 3, "max": 1000 },
		{ "name": "initial_clique_size", "label": "Initial Hub Size", "type": TYPE_INT, "default": 3, "min": 1, "max": 20, "hint_text": "Number of fully connected seed nodes. Larger values create a bigger core." },
		{ "name": "attachment_edges", "label": "Edges per New Node", "type": TYPE_INT, "default": 2, "min": 1, "max": 20, "hint_text": "How many existing nodes each new node connects to (m)." },
		{ "name": "degree_power", "label": "Preferential Power", "type": TYPE_FLOAT, "default": 1.0, "min": 0.0, "max": 3.0, "step": 0.1, "hint_text": "Exponent for degree-based attachment. 1.0 = classic Barabási–Albert. Higher values strengthen hubs." },
		{ "name": "layout_mode", "label": "Layout Mode", "type": TYPE_INT, "default": 0, "hint": "enum", "hint_string": "Phyllotaxis Circle,Random Cloud" },
		{ "name": "hub_type", "label": "Hub Type", "type": TYPE_STRING, "default": "hub", "hint_text": "Node category assigned to the highest-degree nodes." },
		{ "name": "mark_hub_count", "label": "Mark Hub Count", "type": TYPE_INT, "default": 3, "min": 0, "max": 100, "hint_text": "How many of the top hubs to mark with the Hub Type." }
	])
	return s

func get_required_semantics() -> Array[Dictionary]:
	var hub_type: String = local_settings.get("hub_type", "hub")
	return [
		{
			"type": "category",
			"target": SemanticRegistry.TARGET_NODE,
			"key": hub_type,
			"name": hub_type.capitalize(),
			"color": Color(0.95, 0.8, 0.2),
			"is_core": false
		}
	]

func execute(recorder: GraphRecorder) -> void:
	setup_rng()

	var target_count = int(local_settings.get("node_count", 50))
	var initial_count = int(local_settings.get("initial_clique_size", 3))
	var m = int(local_settings.get("attachment_edges", 2))
	var power = float(local_settings.get("degree_power", 1.0))
	var layout_mode = int(local_settings.get("layout_mode", 0))
	var hub_type = str(local_settings.get("hub_type", "hub"))
	var hub_mark_count = int(local_settings.get("mark_hub_count", 3))

	# Clamp initial clique to at least 1 and not exceed target count
	initial_count = max(1, min(initial_count, target_count))
	# Each new node connects to at most the number of existing nodes
	m = max(1, min(m, target_count - 1))

	# We'll store node IDs in order of creation
	var created_nodes: Array[String] = []
	var degrees: Dictionary = {}  # node_id -> int

	# Helper to generate unique IDs using recorder's local display id
	var id_counter = 0

	# --- 1. Create the initial clique ---
	for i in range(initial_count):
		var new_id = "sf:%d" % recorder.get_next_display_id()
		var pos = _get_position(i, target_count, layout_mode)
		recorder.add_node(new_id, pos)
		created_nodes.append(new_id)
		degrees[new_id] = 0

	# Fully connect the initial clique
	for i in range(initial_count):
		for j in range(i + 1, initial_count):
			var u = created_nodes[i]
			var v = created_nodes[j]
			recorder.add_edge(u, v, 1.0, false)
			degrees[u] += 1
			degrees[v] += 1

	# --- 2. Add remaining nodes via preferential attachment ---
	for i in range(initial_count, target_count):
		var new_id = "sf:%d" % recorder.get_next_display_id()
		var pos = _get_position(i, target_count, layout_mode)
		recorder.add_node(new_id, pos)

		# Choose m distinct existing nodes based on degree^power
		var chosen: Array[String] = []
		var attempts = 0
		var max_attempts = m * 10 + 10

		while chosen.size() < m and attempts < max_attempts:
			attempts += 1

			# Build weighted pool on each attempt (inefficient but fine for typical counts)
			var total_weight = 0.0
			var weights = []
			for id in created_nodes:
				var w = pow(float(degrees[id]) + 1.0, power)  # +1 avoids zero weight
				weights.append(w)
				total_weight += w

			var r = rng.randf() * total_weight
			var cumulative = 0.0
			var selected_index = 0
			for idx in range(weights.size()):
				cumulative += weights[idx]
				if r <= cumulative:
					selected_index = idx
					break

			var selected_id = created_nodes[selected_index]
			if not chosen.has(selected_id):
				chosen.append(selected_id)

		# Create edges to chosen nodes
		for target_id in chosen:
			recorder.add_edge(new_id, target_id, 1.0, false)
			degrees[new_id] = degrees.get(new_id, 0) + 1
			degrees[target_id] = degrees[target_id] + 1

		created_nodes.append(new_id)
		degrees[new_id] = 0  # ensure key exists if new_id not in degrees

	# --- 3. Mark top hubs ---
	if hub_mark_count > 0 and hub_type != "":
		# Sort created_nodes by degree descending
		var sorted_nodes = created_nodes.duplicate()
		sorted_nodes.sort_custom(func(a, b):
			return degrees[b] < degrees[a]
		)

		var marked = 0
		for node_id in sorted_nodes:
			if marked >= hub_mark_count:
				break
			recorder.set_node_type(node_id, hub_type)
			marked += 1

# ------------------------------------------------------------------------------
# LAYOUT HELPERS
# ------------------------------------------------------------------------------

func _get_position(index: int, total: int, mode: int) -> Vector2:
	if mode == 0:
		# Phyllotaxis circle using golden angle
		var golden_angle = PI * (3.0 - sqrt(5.0))
		var radius = 80.0 * sqrt(index + 1)
		var angle = index * golden_angle
		return Vector2(cos(angle) * radius, sin(angle) * radius)
	else:
		# Random cloud within a loose disc
		var radius = 150.0 * sqrt(index + 1)
		var angle = rng.randf() * TAU
		var dist = rng.randf() * radius
		return Vector2(cos(angle) * dist, sin(angle) * dist)
