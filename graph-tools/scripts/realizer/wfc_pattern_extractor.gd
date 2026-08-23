class_name WFCPatternExtractor
extends RefCounted

# Scans a sample grid and generates a dictionary of modules perfectly formatted for wfc_solver.gd
static func extract(sample_grid: Dictionary, w: int, h: int, n: int, periodic: bool = true) -> Dictionary:
	var patterns = {} # Raw String -> Module ID
	var modules = {}  # Module ID -> WFC Module Data

	var max_x = w if periodic else w - n + 1
	var max_y = h if periodic else h - n + 1

	var p_idx = 0
	
	# Slide the NxN window over every pixel in the sample image
	for y in range(max_y):
		for x in range(max_x):
			var pat = []
			var exact_floors = {}
			
			# Extract the specific NxN block
			for dy in range(n):
				for dx in range(n):
					var sx = (x + dx) % w if periodic else x + dx
					var sy = (y + dy) % h if periodic else y + dy
					
					var cell = sample_grid.get(Vector2i(sx, sy), Vector2i(-1, -1)) # -1 is void
					pat.append(cell)
					exact_floors[Vector2i(dx, dy)] = cell

			var p_str = str(pat)
			
			# If we haven't seen this pattern before, catalog it and build its Edge Rules
			if not patterns.has(p_str):
				var mod_id = "pat_" + str(p_idx)
				p_idx += 1
				patterns[p_str] = mod_id

				modules[mod_id] = {
					"weight": 0.0,
					"edges": {
						"N": _get_edge_string(pat, "N", n),
						"E": _get_edge_string(pat, "E", n),
						"S": _get_edge_string(pat, "S", n),
						"W": _get_edge_string(pat, "W", n)
					},
					"exact_floors": exact_floors
				}

			# Increase the weight every time we see this pattern
			modules[patterns[p_str]]["weight"] += 1.0

	return modules

# Converts the overlapping boundary of a pattern into a raw String for the Solver to match
static func _get_edge_string(pat: Array, dir: String, n: int) -> String:
	var edge = []
	if dir == "N":
		# The North plug is the top (N-1) rows
		for y in range(n - 1):
			for x in range(n): edge.append(pat[y * n + x])
	elif dir == "S":
		# The South plug is the bottom (N-1) rows
		for y in range(1, n):
			for x in range(n): edge.append(pat[y * n + x])
	elif dir == "W":
		# The West plug is the left (N-1) columns
		for y in range(n):
			for x in range(n - 1): edge.append(pat[y * n + x])
	elif dir == "E":
		# The East plug is the right (N-1) columns
		for y in range(n):
			for x in range(1, n): edge.append(pat[y * n + x])
			
	return str(edge)
