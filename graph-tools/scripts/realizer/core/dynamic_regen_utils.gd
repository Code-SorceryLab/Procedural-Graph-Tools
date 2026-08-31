class_name DynamicRegenUtils
extends RefCounted

# ==============================================================================
# PHASE 1: EXACT SPATIAL OVERLAPS (Find Merges and Crossings)
# ==============================================================================
static func get_exact_overlapping_topology(realizer: GraphRealizer, nodes: Array, edges: Array) -> Dictionary:
	var inf_n = {}
	var inf_e = {}
	var target_cells = []

	# Find every single pixel owned by our targets
	for cell in realizer.cell_to_nodes:
		for n in nodes:
			if realizer.cell_to_nodes[cell].has(n):
				target_cells.append(cell); break
	for cell in realizer.cell_to_edges:
		for e in edges:
			if realizer.cell_to_edges[cell].has(e):
				target_cells.append(cell); break

	# Check if any OTHER nodes or edges share those exact same pixels
	for cell in target_cells:
		if realizer.cell_to_nodes.has(cell):
			for n in realizer.cell_to_nodes[cell]: inf_n[n] = true
		if realizer.cell_to_edges.has(cell):
			for e in realizer.cell_to_edges[cell]: inf_e[e] = true

	return {"nodes": inf_n.keys(), "edges": inf_e.keys()}

# ==============================================================================
# PHASE 2: FIND THE BLAST RADIUS (INCLUDING NEW POSITIONS)
# ==============================================================================
static func get_dirty_rect(realizer: GraphRealizer, graph: Graph, target_nodes: Array, target_edges: Array) -> Rect2i:
	var min_x = 999999
	var min_y = 999999
	var max_x = -999999
	var max_y = -999999
	var found_any = false

	# 1. Expand based on OLD pixels
	for cell in realizer.cell_to_nodes:
		for n_id in target_nodes:
			if realizer.cell_to_nodes[cell].has(n_id):
				if cell.x < min_x: min_x = cell.x
				if cell.y < min_y: min_y = cell.y
				if cell.x > max_x: max_x = cell.x
				if cell.y > max_y: max_y = cell.y
				found_any = true
				break 

	for cell in realizer.cell_to_edges:
		for e_id in target_edges:
			if realizer.cell_to_edges[cell].has(e_id):
				if cell.x < min_x: min_x = cell.x
				if cell.y < min_y: min_y = cell.y
				if cell.x > max_x: max_x = cell.x
				if cell.y > max_y: max_y = cell.y
				found_any = true
				break

	# 2. Expand based on NEW positions!
	# If the user moved a node far away, the DirtyRect MUST cover the new location!
	for n_id in target_nodes:
		if graph.nodes.has(n_id):
			var wp = graph.get_node_pos(n_id)
			var gp = realizer.world_to_grid(wp)
			var pad_gp = 15 # Heavy padding around the new center
			
			if gp.x - pad_gp < min_x: min_x = gp.x - pad_gp
			if gp.y - pad_gp < min_y: min_y = gp.y - pad_gp
			if gp.x + pad_gp > max_x: max_x = gp.x + pad_gp
			if gp.y + pad_gp > max_y: max_y = gp.y + pad_gp
			found_any = true

	if not found_any: 
		return Rect2i(0, 0, 0, 0)

	var rect = Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	var padding = 4
	rect.position -= Vector2i(padding, padding)
	rect.size += Vector2i(padding * 2, padding * 2)
	
	return rect

# ==============================================================================
# PHASE 3: THE "SMART" ERASE (BYSTANDER PROTECTION & DEBUGGING)
# ==============================================================================

# [NEW] Returns the exact mathematical lists without destroying anything!
static func get_wipe_map(realizer: GraphRealizer, dirty_rect: Rect2i, infected_nodes: Array, infected_edges: Array) -> Dictionary:
	var cells_to_wipe = []
	var protected_cells = []
	
	var inf_n_dict = {}
	for n in infected_nodes: inf_n_dict[n] = true
	var inf_e_dict = {}
	for e in infected_edges: inf_e_dict[e] = true

	for y in range(dirty_rect.position.y, dirty_rect.position.y + dirty_rect.size.y):
		for x in range(dirty_rect.position.x, dirty_rect.position.x + dirty_rect.size.x):
			var pt = Vector2i(x, y)
			var is_protected = false
			
			if realizer.cell_to_nodes.has(pt):
				for n in realizer.cell_to_nodes[pt]:
					if not inf_n_dict.has(n):
						is_protected = true; break
			if is_protected:
				protected_cells.append(pt); continue

			if realizer.cell_to_edges.has(pt):
				for e in realizer.cell_to_edges[pt]:
					if not inf_e_dict.has(e):
						is_protected = true; break
			if is_protected:
				protected_cells.append(pt); continue

			cells_to_wipe.append(pt)

	var add_forced = func(cell):
		if not cells_to_wipe.has(cell) and not protected_cells.has(cell):
			cells_to_wipe.append(cell)

	for cell in realizer.cell_to_nodes:
		for n in infected_nodes:
			if realizer.cell_to_nodes[cell].has(n):
				add_forced.call(cell); break
				
	for cell in realizer.cell_to_edges:
		for e in infected_edges:
			if realizer.cell_to_edges[cell].has(e):
				add_forced.call(cell); break

	return {"wipe": cells_to_wipe, "protected": protected_cells}


static func carve_dirty_rect(realizer: GraphRealizer, params: Dictionary, dirty_rect: Rect2i, infected_nodes: Array, infected_edges: Array) -> void:
	var map = get_wipe_map(realizer, dirty_rect, infected_nodes, infected_edges)
	
	# Fetch the toggles (defaulting to true so manual scripts don't break)
	var wipe_geo = params.get("regen_layer_geometry", true)
	var wipe_prog = params.get("regen_layer_progression", true)
	var wipe_struct = params.get("regen_layer_structures", true)
	var wipe_ents = params.get("regen_layer_entities", true)
	var wipe_tex = params.get("regen_layer_textures", true)
	
	for pt in map["wipe"]:
		if not realizer.grid.in_bounds_vec(pt): continue
		
		# --- 1. BASE GEOMETRY ---
		if wipe_geo:
			realizer.grid.set_cell(pt.x, pt.y, TilePalette.VOID_ID)
			realizer.critical_path_cells.erase(pt)
			realizer.room_cells.erase(pt)
			realizer.core_path_cells.erase(pt)
			realizer.distance_field.erase(pt)
			realizer.cell_to_nodes.erase(pt)
			realizer.cell_to_edges.erase(pt)
			realizer.reserved_cells.erase(pt) # Always clear reservations if the floor is gone
			if realizer.has_meta("custom_room_cells"):
				var c_rooms = realizer.get_meta("custom_room_cells")
				c_rooms.erase(pt)
				
		# --- 2. TEXTURES (WFC) ---
		if wipe_tex:
			realizer.grid.cell_atlas_overrides.erase(pt)
			
		# --- 3. ENTITIES & STRUCTURES ---
		if realizer.grid.entities.has(pt):
			var e_type = realizer.grid.entities[pt].get("type", "")
			var delete_ent = false
			
			# If the floor is gone, everything sitting on it dies. Otherwise, respect the toggles!
			if wipe_geo: delete_ent = true
			elif wipe_prog and e_type in ["start_point", "end_point", "key", "door"]: delete_ent = true
			elif wipe_struct and e_type == "structure": delete_ent = true
			elif wipe_ents and e_type in ["scatter_set", "trigger", "fringe"]: delete_ent = true
			
			if delete_ent:
				realizer.grid.entities.erase(pt)
				realizer.reserved_cells.erase(pt) # Free up the footprint for the new placements
