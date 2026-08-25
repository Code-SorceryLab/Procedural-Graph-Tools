class_name RealizerOverlayRenderer
extends Node

var tile_map_layer: TileMapLayer
var floor_source_id: int = 0

# --- STATE & CACHES ---
var _texture_cache: Dictionary = {}
var _ghost_web_layer: Node2D
var _ghost_tween: Tween
var _door_centers_cache: Dictionary = {}
var _key_centers_cache: Dictionary = {}

func setup(p_tile_map_layer: TileMapLayer, p_floor_source_id: int) -> void:
	tile_map_layer = p_tile_map_layer
	floor_source_id = p_floor_source_id
	
	_ghost_web_layer = Node2D.new()
	_ghost_web_layer.z_index = 5 # Float above all entities
	tile_map_layer.add_child(_ghost_web_layer)

func clear_overlays() -> void:
	if not tile_map_layer: return
	for child in tile_map_layer.get_children():
		if child.is_in_group("realizer_entity") or child.is_in_group("realizer_critical_path") or child.is_in_group("validator_overlay"):
			child.queue_free()
	if _ghost_web_layer:
		for child in _ghost_web_layer.get_children():
			child.queue_free()

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
# ENTITY & CRITICAL PATH RENDERING
# ==============================================================================
# --- [CHANGED] Added is_rasterizing flag to signature
func render_overlays(realizer: GraphRealizer, entities: Dictionary, params: Dictionary, is_rasterizing: bool = false) -> void:
	clear_overlays() # Safely clears old groups
			
	if not tile_map_layer.tile_set: return
	var cell_size = float(tile_map_layer.tile_set.tile_size.x)
	
	# A. Render Critical Path Overlays
	var show_path = params.get("debug_routing", false)
	
	# --- [FIXED] THREAD SAFETY GUARD ---
	# We strictly forbid reading the realizer's dictionaries while the background thread is mutating them!
	if realizer and not is_rasterizing: 
		for pos in realizer.critical_path_cells:
			var rect = ColorRect.new()
			rect.color = Color(1.0, 0.0, 1.0, 0.4)
			rect.size = Vector2(cell_size, cell_size) 
			rect.position = Vector2(pos.x * cell_size, pos.y * cell_size)
			rect.visible = show_path
			rect.add_to_group("realizer_critical_path")
			tile_map_layer.add_child(rect)

	# B. Master Visibility Check
	var master_vis = params.get("show_entities", true)
	if not master_vis: return
	
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
		
		# 1. Route the exact toggles based on Entity Type
		var show_sprite = false
		var show_footprint = false
		
		if e_type == "structure":
			show_sprite = params.get("show_struct_sprites", true)
			show_footprint = params.get("show_struct_footprints", true)
		elif e_type in ["door", "key", "fringe"]:
			if not params.get("show_progression", true): continue
			show_footprint = true
		elif e_type in ["start_point", "end_point"]:
			if not params.get("show_endpoints", true): continue
			show_footprint = true
		else: # Scatter Sets & Generic
			show_sprite = params.get("show_scatter_sprites", true)
			show_footprint = params.get("show_scatter_footprints", true)

		var tex_path = entity_data.get("texture_path", "")
		var has_sprite = (tex_path != "")
		
		# 2. Render Visual Sprites (Structures & Scatter Sets)
		if has_sprite and show_sprite:
			var tex = _get_cached_texture(tex_path)
			if tex:
				var sprite = Sprite2D.new()
				sprite.texture = tex
				
				var t_off = entity_data.get("texture_offset", Vector2.ZERO)
				var t_scale = entity_data.get("texture_scale", Vector2.ONE)
				var t_filter = entity_data.get("texture_filter", 0)
				var rot_idx = entity_data.get("rot", 0)
				
				var base_scale_x = cell_size / tex.get_size().x
				var base_scale_y = cell_size / tex.get_size().y
				sprite.scale = Vector2(base_scale_x * t_scale.x, base_scale_y * t_scale.y)
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if t_filter == 0 else CanvasItem.TEXTURE_FILTER_LINEAR
				sprite.rotation = rot_idx * (PI / 2.0)
				
				sprite.position = Vector2(pos.x * cell_size + (cell_size / 2.0), pos.y * cell_size + (cell_size / 2.0))
				sprite.offset = (t_off * cell_size) / sprite.scale
				sprite.z_index = 1
				sprite.add_to_group("realizer_entity")
				tile_map_layer.add_child(sprite)

		# 3. Render Hitboxes & Indicators
		if show_footprint or (show_sprite and not has_sprite):
			if e_type == "structure":
				var struct_color = entity_data.get("color", Color(0.2, 0.6, 1.0, 0.7))
				var footprint_world = entity_data.get("footprint_world", [])
				for pt in footprint_world:
					var pt_rect = ColorRect.new()
					pt_rect.color = struct_color
					pt_rect.size = Vector2(cell_size, cell_size)
					pt_rect.position = Vector2(pt.x * cell_size, pt.y * cell_size)
					pt_rect.add_to_group("realizer_entity")
					tile_map_layer.add_child(pt_rect)
			else:
				var rect = ColorRect.new()
				var label_to_add = null 
				var pid = -1 
				
				if e_type == "door":
					var l_type = entity_data.get("lock_type", "Unlocked")
					if l_type == "Unlocked": 
						rect.color = Color(0.8, 0.5, 0.2, 0.9)
					elif l_type.begins_with("Tier "): 
						rect.color = Color(0.35, 0.35, 0.35, 0.9) # Darker Iron for Contrast
						
						# Run exactly once per door clump
						pid = entity_data.get("portal_id", -1)
						if pid != -1 and not drawn_door_labels.has(pid):
							drawn_door_labels[pid] = true
							
							label_to_add = Label.new()
							label_to_add.text = l_type.trim_prefix("Tier ")
							label_to_add.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
							label_to_add.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
							label_to_add.add_theme_color_override("font_color", Color.WHITE)
							label_to_add.add_theme_color_override("font_outline_color", Color.BLACK)
							label_to_add.add_theme_constant_override("outline_size", 16)
							label_to_add.add_theme_font_size_override("font_size", 100)
					else: 
						rect.color = Color.from_string(l_type, Color(0.8, 0.5, 0.2, 0.9))
						
				elif e_type == "start_point": rect.color = Color(0.2, 1.0, 0.2, 0.9)
				elif e_type == "end_point": rect.color = Color(1.0, 0.2, 0.2, 0.9)
				elif e_type == "key":
					rect.color = Color.BLACK
					var inner_rect = ColorRect.new()
					
					var k_col = entity_data.get("key_type", "Red")
					if k_col.begins_with("Tier "): 
						inner_rect.color = Color.WHITE
						
						label_to_add = Label.new()
						label_to_add.text = k_col.trim_prefix("Tier ")
						label_to_add.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
						label_to_add.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
						label_to_add.add_theme_color_override("font_color", Color.BLACK)
						label_to_add.add_theme_font_size_override("font_size", 100) 
					else: 
						inner_rect.color = Color.from_string(k_col, Color.WHITE)
						
					rect.add_child(inner_rect)
				elif e_type == "fringe": rect.color = Color(0.2, 0.9, 0.2, 0.8)
				else: rect.color = entity_data.get("color", Color(1.0, 0.8, 0.0, 0.4))
				
				var s_mult = 1.0 if e_type == "door" else (0.8 if e_type in ["start_point", "end_point"] else (0.4 if e_type == "fringe" else 0.5))
				rect.size = Vector2(cell_size * s_mult, cell_size * s_mult)
				var center_offset = (cell_size - rect.size.x) / 2.0
				rect.position = Vector2(pos.x * cell_size + center_offset, pos.y * cell_size + center_offset)
				
				if rect.get_child_count() > 0 and rect.get_child(0) is ColorRect:
					var inner = rect.get_child(0)
					var b_size = max(1.0, cell_size * 0.06) 
					inner.position = Vector2(b_size, b_size)
					inner.size = rect.size - Vector2(b_size * 2, b_size * 2)

				rect.add_to_group("realizer_entity")
				tile_map_layer.add_child(rect)
				
				if label_to_add:
					label_to_add.size = Vector2(200, 200) 
					if e_type == "key":
						label_to_add.scale = rect.size / 200.0
						label_to_add.position = rect.position
					else: 
						label_to_add.scale = Vector2(cell_size, cell_size) / 200.0
						var center_grid = portal_centers[pid]
						var center_world = center_grid * cell_size + Vector2(cell_size / 2.0, cell_size / 2.0)
						label_to_add.position = center_world - (label_to_add.size * label_to_add.scale / 2.0)
						
					label_to_add.z_index = 2
					label_to_add.add_to_group("realizer_entity")
					tile_map_layer.add_child(label_to_add)

# ==============================================================================
# GHOST WEB RENDERING
# ==============================================================================
func draw_ghost_web(lock_str: String) -> void:
	if not _ghost_web_layer: return
	for child in _ghost_web_layer.get_children():
		child.queue_free()
		
	if lock_str == "" or lock_str == "Unlocked": return
	
	var key_positions = _key_centers_cache.get(lock_str, [])
	var door_positions = _door_centers_cache.get(lock_str, [])
	
	if key_positions.is_empty() or door_positions.is_empty(): return
	
	var web_color = Color.WHITE
	if not lock_str.begins_with("Tier "):
		web_color = Color.from_string(lock_str, Color.WHITE)
		
	for k_pos in key_positions:
		for d_pos in door_positions:
			var line = Line2D.new()
			line.add_point(k_pos)
			line.add_point(d_pos)
			line.width = 6.0
			line.default_color = web_color
			line.modulate.a = 0.5
			line.antialiased = true
			
			var core = Line2D.new()
			core.add_point(k_pos)
			core.add_point(d_pos)
			core.width = 2.0
			core.default_color = Color.WHITE
			core.antialiased = true
			
			line.add_child(core)
			_ghost_web_layer.add_child(line)
			
	if _ghost_tween: _ghost_tween.kill()
	_ghost_tween = create_tween().set_loops()
	_ghost_web_layer.modulate.a = 0.2
	_ghost_tween.tween_property(_ghost_web_layer, "modulate:a", 1.0, 0.6).set_trans(Tween.TRANS_SINE)
	_ghost_tween.tween_property(_ghost_web_layer, "modulate:a", 0.2, 0.6).set_trans(Tween.TRANS_SINE)
