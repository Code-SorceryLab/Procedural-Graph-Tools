class_name RealizerOverlayRenderer
extends Node2D

var tile_map_layer: TileMapLayer
var floor_source_id: int = 0
var cell_size: float = 50.0

# --- RENDER LISTS (GPU Batching) ---
var _show_path: bool = false
var _crit_path: Array = []
var _footprints: Array = []
var _sprites: Array = []
var _labels: Array = []

# --- STATE & CACHES ---
var _texture_cache: Dictionary = {}
var _ghost_web_layer: Node2D
var _ghost_tween: Tween
var _door_centers_cache: Dictionary = {}
var _key_centers_cache: Dictionary = {}
var _debug_regen_layer: Node2D

var _active_ghost_lock: String = ""
var _debug_wipe_map: Dictionary = {}
var _debug_dirty_rect: Rect2i = Rect2i()

func setup(p_tile_map_layer: TileMapLayer, p_floor_source_id: int) -> void:
	tile_map_layer = p_tile_map_layer
	floor_source_id = p_floor_source_id
	
	# --- Force crisp nearest-neighbor filtering for all drawn textures ---
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	
	# Add THIS renderer to the tree to handle Entities & Critical Paths
	z_index = 1
	tile_map_layer.add_child(self)
	
	# Add dedicated sub-canvases for specific effects
	_ghost_web_layer = Node2D.new()
	_ghost_web_layer.z_index = 5 
	_ghost_web_layer.draw.connect(_on_ghost_web_draw)
	tile_map_layer.add_child(_ghost_web_layer)
	
	_debug_regen_layer = Node2D.new()
	_debug_regen_layer.z_index = 10 
	_debug_regen_layer.draw.connect(_on_debug_regen_draw)
	tile_map_layer.add_child(_debug_regen_layer)

func clear_overlays() -> void:
	_crit_path.clear()
	_footprints.clear()
	_sprites.clear()
	_labels.clear()
	queue_redraw()
	
	_active_ghost_lock = ""
	_ghost_web_layer.queue_redraw()
	clear_debug_regen()

func _get_cached_texture(path: String) -> Texture2D:
	if _texture_cache.has(path): return _texture_cache[path]
	if FileAccess.file_exists(path):
		var img = Image.load_from_file(path)
		if img:
			var tex = ImageTexture.create_from_image(img)
			_texture_cache[path] = tex
			return tex
	return null

# ==============================================================================
# DYNAMIC TILESET GENERATION
# ==============================================================================
func rebuild_dynamic_tileset_and_mapping(realizer: GraphRealizer, custom_rooms: Dictionary, atlas_mappings: Dictionary, tileset_image_path: String, tileset_tile_size: Vector2i, procedural_flags: Dictionary, palette_params: Dictionary) -> Dictionary:
	var dynamic_tileset = TileSet.new()
	dynamic_tileset.tile_size = tileset_tile_size
	
	var active_proc_keys = []
	for key in realizer.semantic_floor_ids:
		if procedural_flags.get(key, false): active_proc_keys.append(key)
	active_proc_keys.sort() 
	
	var biome_colors = {}
	var wall_shift = palette_params.get("wall_shift", 0.1)
	for i in range(active_proc_keys.size()):
		var key = active_proc_keys[i]
		var t = float(i) / max(1.0, float(active_proc_keys.size() - 1))
		biome_colors[key + "_floor"] = CosinePaletteEditor.get_iq_color(t, palette_params)
		biome_colors[key + "_wall"] = CosinePaletteEditor.get_iq_color(t + wall_shift, palette_params)

	var def_floor_atlas = atlas_mappings.get("default_floor", Vector2i(0,0))
	var def_wall_atlas = atlas_mappings.get("default_wall", Vector2i(1,0))
	var debug_path_atlas = atlas_mappings.get("debug_path", Vector2i(2,0)) 
	var biome_alt_ids = {}
	
	if tileset_image_path != "" and FileAccess.file_exists(tileset_image_path):
		var img = Image.load_from_file(tileset_image_path)
		if img:
			var source = TileSetAtlasSource.new()
			source.texture = ImageTexture.create_from_image(img)
			source.texture_region_size = tileset_tile_size
			
			var ensure_base_tile = func(coord: Vector2i):
				if not source.has_tile(coord): source.create_tile(coord)
			
			ensure_base_tile.call(def_floor_atlas)
			ensure_base_tile.call(def_wall_atlas)
			ensure_base_tile.call(debug_path_atlas)
			for mapping_key in atlas_mappings:
				ensure_base_tile.call(atlas_mappings[mapping_key])
				
			# --- REGISTER CUSTOM ROOM EXACT TILES ---
			for r_key in custom_rooms:
				var r_data = custom_rooms[r_key]
				if r_data.has("exact_floors"):
					for pos in r_data["exact_floors"]: ensure_base_tile.call(r_data["exact_floors"][pos])
				if r_data.has("exact_walls"):
					for pos in r_data["exact_walls"]: ensure_base_tile.call(r_data["exact_walls"][pos])
			# ----------------------------------------------
				
			var next_alt_id = {}
			for cat_key in realizer.semantic_floor_ids:
				if procedural_flags.get(cat_key, false):
					var f_coord = atlas_mappings.get(cat_key + "_floor", def_floor_atlas)
					var w_coord = atlas_mappings.get(cat_key + "_wall", def_wall_atlas)
					
					var f_alt = next_alt_id.get(f_coord, 1); next_alt_id[f_coord] = f_alt + 1
					source.create_alternative_tile(f_coord, f_alt)
					source.get_tile_data(f_coord, f_alt).modulate = biome_colors[cat_key + "_floor"]
					biome_alt_ids[cat_key + "_floor"] = f_alt
					
					var w_alt = next_alt_id.get(w_coord, 1); next_alt_id[w_coord] = w_alt + 1
					source.create_alternative_tile(w_coord, w_alt)
					source.get_tile_data(w_coord, w_alt).modulate = biome_colors[cat_key + "_wall"]
					biome_alt_ids[cat_key + "_wall"] = w_alt
					
			dynamic_tileset.add_source(source, floor_source_id)
			
	tile_map_layer.tile_set = dynamic_tileset
	
	var get_mapping_data = func(atlas_coord: Vector2i, alt_id: int = 0) -> Dictionary:
		return { "is_terrain": false, "source_id": floor_source_id, "atlas_coords": atlas_coord, "alternative_tile": alt_id }

	var active_mapping = {
		realizer.floor_id: get_mapping_data.call(def_floor_atlas),
		realizer.wall_id: get_mapping_data.call(def_wall_atlas),
		realizer.debug_path_id: get_mapping_data.call(debug_path_atlas)
	}
	
	for cat_key in realizer.semantic_floor_ids:
		var s_floor_id = realizer.semantic_floor_ids[cat_key]
		var s_wall_id = realizer.semantic_wall_map[s_floor_id]
		
		var custom_floor = atlas_mappings.get(cat_key + "_floor", def_floor_atlas)
		var custom_wall = atlas_mappings.get(cat_key + "_wall", def_wall_atlas)
		var floor_alt = biome_alt_ids.get(cat_key + "_floor", 0)
		var wall_alt = biome_alt_ids.get(cat_key + "_wall", 0)
		
		active_mapping[s_floor_id] = get_mapping_data.call(custom_floor, floor_alt)
		active_mapping[s_wall_id] = get_mapping_data.call(custom_wall, wall_alt)
		
	return active_mapping

# ==============================================================================
# ENTITY & CRITICAL PATH RENDERING (GPU OPTIMIZED)
# ==============================================================================
func render_overlays(realizer: GraphRealizer, entities: Dictionary, params: Dictionary, is_rasterizing: bool = false) -> void:
	_crit_path.clear()
	_footprints.clear()
	_sprites.clear()
	_labels.clear()
			
	if not tile_map_layer.tile_set: return
	cell_size = float(tile_map_layer.tile_set.tile_size.x)
	
	# A. Route Critical Path
	_show_path = params.get("debug_routing", false)
	if realizer and not is_rasterizing and _show_path:
		_crit_path = realizer.critical_path_cells.keys()

	# B. Master Visibility Check
	var master_vis = params.get("show_entities", true)
	if not master_vis: 
		queue_redraw()
		return
	
	_door_centers_cache.clear()
	_key_centers_cache.clear()

	# --- DOOR & KEY CENTROID PRE-PASS ---
	var portal_centers = {}
	var portal_counts = {}
	var portal_locks = {}
	
	for p in entities:
		var e_type = entities[p].get("type", "")
		if e_type == "door":
			var pid = entities[p].get("portal_id", -1)
			var l_type = entities[p].get("lock_type", "Unlocked")
			if pid != -1:
				if not portal_centers.has(pid):
					portal_centers[pid] = Vector2.ZERO
					portal_counts[pid] = 0
					portal_locks[pid] = l_type
				portal_centers[pid] += Vector2(p)
				portal_counts[pid] += 1
				
		elif e_type == "key":
			var k_type = entities[p].get("key_type", "")
			if k_type != "":
				if not _key_centers_cache.has(k_type): _key_centers_cache[k_type] = []
				var k_world = Vector2(p) * cell_size + Vector2(cell_size / 2.0, cell_size / 2.0)
				_key_centers_cache[k_type].append(k_world)
				
		# --- TRICK THE CACHE INTO CONNECTING TRIGGERS TO DOORS ---
		elif e_type == "trigger":
			var t_id = entities[p].get("trigger_id", "")
			if t_id != "":
				var k_type = "TemporalLock_" + t_id
				if not _key_centers_cache.has(k_type): _key_centers_cache[k_type] = []
				var k_world = Vector2(p) * cell_size + Vector2(cell_size / 2.0, cell_size / 2.0)
				_key_centers_cache[k_type].append(k_world)
				
	for pid in portal_centers:
		var center_grid = portal_centers[pid] / float(portal_counts[pid])
		var center_world = center_grid * cell_size + Vector2(cell_size / 2.0, cell_size / 2.0)
		portal_centers[pid] = center_grid 
		
		var l_type = portal_locks[pid]
		if not _door_centers_cache.has(l_type): _door_centers_cache[l_type] = []
		_door_centers_cache[l_type].append(center_world)

	var drawn_door_labels = {}

	for pos in entities:
		var entity_data = entities[pos]
		var e_type = entity_data.get("type", "generic_entity")
		
		var show_sprite = false
		var show_footprint = false
		
		if e_type == "structure":
			show_sprite = params.get("show_struct_sprites", true)
			show_footprint = params.get("show_struct_footprints", true)
		elif e_type in ["door", "key", "fringe", "trigger"]:
			if not params.get("show_progression", true): continue
			show_footprint = true
		elif e_type in ["door", "key", "fringe"]:
			if not params.get("show_progression", true): continue
			show_footprint = true
		elif e_type in ["start_point", "end_point"]:
			if not params.get("show_endpoints", true): continue
			show_footprint = true
		else: 
			show_sprite = params.get("show_scatter_sprites", true)
			show_footprint = params.get("show_scatter_footprints", true)

		var tex_path = entity_data.get("texture_path", "")
		var has_sprite = (tex_path != "")
		
		# 1. Package Visual Sprites
		if has_sprite and show_sprite:
			var tex = _get_cached_texture(tex_path)
			if tex:
				var t_off = entity_data.get("texture_offset", Vector2.ZERO)
				var t_scale = entity_data.get("texture_scale", Vector2.ONE)
				var base_scale_x = cell_size / tex.get_size().x
				var base_scale_y = cell_size / tex.get_size().y
				
				_sprites.append({
					"tex": tex, 
					"pos": Vector2(pos.x * cell_size + (cell_size / 2.0), pos.y * cell_size + (cell_size / 2.0)),
					"scale": Vector2(base_scale_x * t_scale.x, base_scale_y * t_scale.y),
					"rot": entity_data.get("rot", 0) * (PI / 2.0),
					"offset": t_off * cell_size
				})

		# 2. Package Hitboxes & Indicators
		if show_footprint or (show_sprite and not has_sprite):
			if e_type == "structure":
				var struct_color = entity_data.get("color", Color(0.2, 0.6, 1.0, 0.7))
				for pt in entity_data.get("footprint_world", []):
					_footprints.append({ "rect": Rect2(Vector2(pt) * cell_size, Vector2(cell_size, cell_size)), "color": struct_color })
			else:
				var r_color = Color(1.0, 0.8, 0.0, 0.4)
				var label_text = ""
				var label_pos = Vector2.ZERO
				var is_key = false
				var pid = -1 
				
				if e_type == "door":
					var l_type = entity_data.get("lock_type", "Unlocked")
					if l_type == "Unlocked": 
						r_color = Color(0.8, 0.5, 0.2, 0.9)
					elif l_type.begins_with("Tier "): 
						r_color = Color(0.35, 0.35, 0.35, 0.9) 
						pid = entity_data.get("portal_id", -1)
						if pid != -1 and not drawn_door_labels.has(pid):
							drawn_door_labels[pid] = true
							label_text = l_type.trim_prefix("Tier ")
							var center_grid = portal_centers[pid]
							label_pos = center_grid * cell_size + Vector2(cell_size / 2.0, cell_size / 2.0)
					# --- TEMPORAL DOOR STYLING ---
					elif l_type.begins_with("TemporalLock_"):
						r_color = Color.FUCHSIA # Match the Trigger Color
						pid = entity_data.get("portal_id", -1)
						if pid != -1 and not drawn_door_labels.has(pid):
							drawn_door_labels[pid] = true
							label_text = "T-Gate" # Distinct visual tag
							var center_grid = portal_centers[pid]
							label_pos = center_grid * cell_size + Vector2(cell_size / 2.0, cell_size / 2.0)
					else: 
						r_color = Color.from_string(l_type, Color(0.8, 0.5, 0.2, 0.9))
						
				elif e_type == "start_point": r_color = Color(0.2, 1.0, 0.2, 0.9)
				elif e_type == "end_point": r_color = Color(1.0, 0.2, 0.2, 0.9)
				elif e_type == "fringe": r_color = Color(0.2, 0.9, 0.2, 0.8)
				elif e_type == "key":
					r_color = Color.BLACK
					is_key = true
					var k_col = entity_data.get("key_type", "Red")
					var inner_c = Color.WHITE
					
					if k_col.begins_with("Tier "): 
						label_text = k_col.trim_prefix("Tier ")
						label_pos = Vector2(pos.x * cell_size + (cell_size / 2.0), pos.y * cell_size + (cell_size / 2.0))
					# --- TEMPORAL KEY STYLING ---
					elif k_col.begins_with("TemporalLock_"):
						inner_c = Color.FUCHSIA
						label_text = "T-Key"
						label_pos = Vector2(pos.x * cell_size + (cell_size / 2.0), pos.y * cell_size + (cell_size / 2.0))
					else: 
						inner_c = Color.from_string(k_col, Color.WHITE)
						
					var s_mult = 0.5
					var b_size = max(1.0, cell_size * 0.06) 
					var out_size = cell_size * s_mult
					var offset = (cell_size - out_size) / 2.0
					_footprints.append({ "rect": Rect2(Vector2(pos.x * cell_size + offset + b_size, pos.y * cell_size + offset + b_size), Vector2(out_size - (b_size*2), out_size - (b_size*2))), "color": inner_c })
				
				elif e_type == "trigger":
					r_color = Color.FUCHSIA
					label_text = entity_data.get("name", "Trigger")
					label_pos = Vector2(pos.x * cell_size + (cell_size / 2.0), pos.y * cell_size + (cell_size / 2.0))
				
				var s_mult = 1.0 if e_type == "door" else (0.8 if e_type in ["start_point", "end_point", "trigger"] else (0.4 if e_type == "fringe" else 0.5))
				var out_size = cell_size * s_mult
				var offset = (cell_size - out_size) / 2.0
				_footprints.insert(0, { "rect": Rect2(Vector2(pos.x * cell_size + offset, pos.y * cell_size + offset), Vector2(out_size, out_size)), "color": r_color })
				
				if label_text != "":
					_labels.append({ "text": label_text, "pos": label_pos, "is_key": is_key })
					
	queue_redraw()


func _draw() -> void:
	if _show_path:
		for pt in _crit_path:
			draw_rect(Rect2(Vector2(pt) * cell_size, Vector2(cell_size, cell_size)), Color(1.0, 0.0, 1.0, 0.4))
			
	for fp in _footprints:
		draw_rect(fp["rect"], fp["color"])
		
	for s in _sprites:
		draw_set_transform(s["pos"], s["rot"], s["scale"])
		draw_texture(s["tex"], -s["tex"].get_size() / 2.0 + (s["offset"] / s["scale"]))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		
	var font = ThemeDB.fallback_font
	for l in _labels:
		var scale_factor = cell_size / 200.0 if not l["is_key"] else (cell_size * 0.5) / 200.0
		var color = Color.WHITE if not l["is_key"] else Color.BLACK
		var outline_color = Color.BLACK if not l["is_key"] else Color.TRANSPARENT
		var y_nudge = Vector2(0, font.get_ascent(100) / 2.0)
		
		draw_set_transform(l["pos"], 0.0, Vector2(scale_factor, scale_factor))
		if outline_color != Color.TRANSPARENT: draw_string_outline(font, y_nudge, l["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 100, 16, outline_color)
		draw_string(font, y_nudge, l["text"], HORIZONTAL_ALIGNMENT_CENTER, -1, 100, color)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		

# ==============================================================================
# GHOST WEB RENDERING
# ==============================================================================
func draw_ghost_web(lock_str: String) -> void:
	_active_ghost_lock = lock_str
	_ghost_web_layer.queue_redraw()
	
	if _active_ghost_lock == "" or _active_ghost_lock == "Unlocked": return
		
	if _ghost_tween: _ghost_tween.kill()
	_ghost_tween = create_tween().set_loops()
	_ghost_web_layer.modulate.a = 0.2
	_ghost_tween.tween_property(_ghost_web_layer, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	_ghost_tween.tween_property(_ghost_web_layer, "modulate:a", 0.2, 0.6).set_trans(Tween.TRANS_SINE)

func _on_ghost_web_draw() -> void:
	if _active_ghost_lock == "" or _active_ghost_lock == "Unlocked": return
	
	var key_positions = _key_centers_cache.get(_active_ghost_lock, [])
	var door_positions = _door_centers_cache.get(_active_ghost_lock, [])
	
	if key_positions.is_empty() or door_positions.is_empty(): return
	
	var web_color = Color.WHITE
	# --- OVERRIDE GHOST WEB COLOR FOR TEMPORAL LOCKS ---
	if _active_ghost_lock.begins_with("TemporalLock_"):
		web_color = Color.FUCHSIA
	elif not _active_ghost_lock.begins_with("Tier "):
		web_color = Color.from_string(_active_ghost_lock, Color.WHITE)
		
	for k_pos in key_positions:
		for d_pos in door_positions:
			_ghost_web_layer.draw_line(k_pos, d_pos, Color(web_color, 0.5), 6.0, true)
			_ghost_web_layer.draw_line(k_pos, d_pos, Color.WHITE, 2.0, true)



# ==============================================================================
# DEBUG REGEN PREVIEW
# ==============================================================================
func clear_debug_regen() -> void:
	_debug_dirty_rect = Rect2i()
	_debug_wipe_map.clear()
	if _debug_regen_layer: _debug_regen_layer.queue_redraw()

func draw_regen_preview(dirty_rect: Rect2i, wipe_map: Dictionary) -> void:
	_debug_dirty_rect = dirty_rect
	_debug_wipe_map = wipe_map
	_debug_regen_layer.queue_redraw()

func _on_debug_regen_draw() -> void:
	if _debug_dirty_rect.size == Vector2i.ZERO: return
	
	for pt in _debug_wipe_map.get("wipe", []):
		_debug_regen_layer.draw_rect(Rect2(Vector2(pt) * cell_size, Vector2(cell_size, cell_size)), Color(1.0, 0.0, 0.0, 0.6))
		
	for pt in _debug_wipe_map.get("protected", []):
		_debug_regen_layer.draw_rect(Rect2(Vector2(pt) * cell_size, Vector2(cell_size, cell_size)), Color(0.0, 1.0, 0.0, 0.6))
		
	var p = _debug_dirty_rect.position
	var s = _debug_dirty_rect.size
	var points = PackedVector2Array([
		Vector2(p.x, p.y) * cell_size,
		Vector2(p.x + s.x, p.y) * cell_size,
		Vector2(p.x + s.x, p.y + s.y) * cell_size,
		Vector2(p.x, p.y + s.y) * cell_size,
		Vector2(p.x, p.y) * cell_size
	])
	_debug_regen_layer.draw_polyline(points, Color.YELLOW, 4.0)
