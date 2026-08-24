class_name WFCPatternExtractor
extends RefCounted

const CELL_EMPTY = Vector2i(-1, -1)
const CELL_BOUNDARY = Vector2i(-2, -2)
const CELL_GENERIC_FLOOR = Vector2i(-3, -3)

# [CHANGED] Added allow_rotations and allow_reflections parameters
static func extract(sample_grid: Dictionary, w: int, h: int, n: int, periodic: bool = true, base_fill_mode: int = 1, allow_rotations: bool = false, allow_reflections: bool = false) -> Dictionary:
	var patterns = {} 
	var modules = {}  

	var min_x = 0 if periodic else -(n - 1)
	var max_x = w if periodic else w
	var min_y = 0 if periodic else -(n - 1)
	var max_y = h if periodic else h

	var p_idx = 0
	
	var get_cell = func(gx: int, gy: int) -> Vector2i:
		if periodic:
			gx = posmod(gx, w)
			gy = posmod(gy, h)
		else:
			if gx < 0 or gx >= w or gy < 0 or gy >= h:
				return CELL_BOUNDARY
				
		var pos = Vector2i(gx, gy)
		if sample_grid.has(pos): return sample_grid[pos]
			
		match base_fill_mode:
			1: return CELL_GENERIC_FLOOR
			2: return CELL_BOUNDARY
			_: return CELL_EMPTY

	for y in range(min_y, max_y):
		for x in range(min_x, max_x):
			var base_pat = []
			
			for dy in range(n):
				for dx in range(n):
					base_pat.append(get_cell.call(x + dx, y + dy))

			# --- [NEW] GENERATE SYMMETRY VARIANTS ---
			var variants = [base_pat]
			
			if allow_rotations:
				var r1 = _rotate_pattern_90(base_pat, n)
				var r2 = _rotate_pattern_90(r1, n)
				var r3 = _rotate_pattern_90(r2, n)
				variants.append_array([r1, r2, r3])
				
			if allow_reflections:
				var flipped_variants = []
				for v in variants:
					flipped_variants.append(_reflect_pattern_x(v, n))
				variants.append_array(flipped_variants)
				
			# Register all generated variants!
			for v_pat in variants:
				var p_str = str(v_pat)
				if not patterns.has(p_str):
					var mod_id = "pat_" + str(p_idx)
					p_idx += 1
					patterns[p_str] = mod_id
					
					var exact_floors = {}
					for dy in range(n):
						for dx in range(n):
							exact_floors[Vector2i(dx, dy)] = v_pat[dy * n + dx]

					modules[mod_id] = {
						"weight": 0.0,
						"edges": {
							"N": _get_edge_string(v_pat, "N", n),
							"E": _get_edge_string(v_pat, "E", n),
							"S": _get_edge_string(v_pat, "S", n),
							"W": _get_edge_string(v_pat, "W", n)
						},
						"exact_floors": exact_floors
					}

				# Symmetrical patterns inherently gain higher weight (which is mathematically correct!)
				modules[patterns[p_str]]["weight"] += 1.0

	return modules

static func _get_edge_string(pat: Array, dir: String, n: int) -> String:
	var edge = []
	if dir == "N":
		for y in range(n - 1):
			for x in range(n): edge.append(pat[y * n + x])
	elif dir == "S":
		for y in range(1, n):
			for x in range(n): edge.append(pat[y * n + x])
	elif dir == "W":
		for y in range(n):
			for x in range(n - 1): edge.append(pat[y * n + x])
	elif dir == "E":
		for y in range(n):
			for x in range(1, n): edge.append(pat[y * n + x])
			
	return str(edge)

# --- [NEW] MATH HELPERS ---
static func _rotate_pattern_90(pat: Array, n: int) -> Array:
	var res = []
	res.resize(n * n)
	for y in range(n):
		for x in range(n):
			res[x * n + (n - 1 - y)] = pat[y * n + x]
	return res

static func _reflect_pattern_x(pat: Array, n: int) -> Array:
	var res = []
	res.resize(n * n)
	for y in range(n):
		for x in range(n):
			res[y * n + (n - 1 - x)] = pat[y * n + x]
	return res
