extends GraphStrategy
class_name StrategyMST

func _init() -> void:
	strategy_name = "MST Maze"
	required_params = ["width", "height"]

func execute(graph: Graph, params: Dictionary) -> void:
	var rows = params.get("height", 10)
	var cols = params.get("width", 10)
	var cell_size = GraphSettings.CELL_SIZE

	# 1. Reset Graph & Generate Base Grid (Fully Connected)
	graph.nodes.clear()
	
	# Create Nodes
	for y in range(rows):
		for x in range(cols):
			var id := "%d_%d" % [x, y]
			var pos := Vector2(x * cell_size, y * cell_size)
			graph.add_node(id, pos)

	# 2. Collect All Potential Edges (Grid Neighbor Logic)
	# We store them as objects temporarily to sort them
	var potential_edges: Array[Dictionary] = []
	
	for y in range(rows):
		for x in range(cols):
			var u_id := "%d_%d" % [x, y]
			
			# Check Right (x+1) and Down (y+1) neighbors
			var neighbors = [Vector2i(1, 0), Vector2i(0, 1)]
			for dir in neighbors:
				var nx = x + dir.x
				var ny = y + dir.y
				
				if nx >= 0 and nx < cols and ny >= 0 and ny < rows:
					var v_id := "%d_%d" % [nx, ny]
					potential_edges.append({
						"u": u_id,
						"v": v_id,
						"weight": randf() # Random weight is key for random maze!
					})

	# 3. Kruskal's Algorithm
	# Sort edges by weight (effectively shuffling them)
	potential_edges.sort_custom(func(a, b): return a["weight"] < b["weight"])
	
	var ds = DisjointSet.new(graph.nodes.keys())
	
	for edge in potential_edges:
		var u = edge["u"]
		var v = edge["v"]
		
		# If connecting u and v doesn't create a cycle...
		if ds.find(u) != ds.find(v):
			ds.union(u, v)
			graph.add_edge(u, v)

# --- Inner Helper Class: Disjoint Set (Union-Find) ---
class DisjointSet:
	var parent: Dictionary = {}
	
	func _init(node_ids: Array) -> void:
		for id in node_ids:
			parent[id] = id

	func find(i: String) -> String:
		if parent[i] != i:
			parent[i] = find(parent[i]) # Path compression
		return parent[i]

	func union(i: String, j: String) -> void:
		var root_i = find(i)
		var root_j = find(j)
		if root_i != root_j:
			parent[root_i] = root_j
