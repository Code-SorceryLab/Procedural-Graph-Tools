class_name LevelImporter
extends Node2D

signal level_completed

@export_file("*.json") var json_path: String
@export var floor_layer: TileMapLayer
@export var collision_layer: TileMapLayer
@export var entity_container: Node2D
@export var player_scene: PackedScene
@export var key_scene: PackedScene
@export var door_scene: PackedScene
@export var end_point_scene: PackedScene
@export var loot_scene: PackedScene
@export var pushbox_scene: PackedScene
@export var enemy_scene: PackedScene


# Map the raw Integer IDs from your JSON export to the actual atlas coords in this new project's TileSet
@export var default_floor_atlas: Vector2i = Vector2i(0, 0)
@export var collision_tile_atlas: Vector2i = Vector2i(1, 0)

func _ready() -> void:
	if json_path != "":
		load_and_build(json_path)

func clear_level() -> void:
	# Clear the TileMaps
	floor_layer.clear()
	collision_layer.clear()
	
	# Destroy all spawned entities, structures, and the player
	for child in entity_container.get_children():
		child.queue_free()
		
	# If the player was spawned directly as a child of LevelBuilder, remove them too
	for child in get_children():
		if child is Player:
			child.queue_free()

func load_and_build(path: String) -> void:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("LevelImporter: Could not open file: " + path)
		return
		
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	file.close()
	
	if err != OK:
		push_error("LevelImporter: JSON Parse Error on line %d: %s" % [json.get_error_line(), json.get_error_message()])
		return
		
	var data = json.get_data()
	_build_level(data)

func _build_level(data: Dictionary) -> void:
	var meta = data.get("meta", {})
	var grid_w = meta.get("grid_width", 0)
	var grid_h = meta.get("grid_height", 0)
	var tile_size = meta.get("tile_size", 16)
	
	# Grab the tile mapping dictionary
	var tile_mapping = data.get("definitions", {}).get("tile_mapping", {})
	
	#print("\n=== [DEBUG: LEVEL IMPORTER - RECEIVED MAPPING] ===")
	#for k in tile_mapping:
		#print("Imported Tile ID %s -> %s" % [k, str(tile_mapping[k])])
	#print("==================================================\n")
	
	var layers = data.get("layers", [])
	for layer in layers:
		var type = layer.get("type", "")
		if type == "IntGrid":
			_build_int_grid(layer, grid_w, grid_h, tile_mapping)
			
		elif type == "AtlasGrid":
			_build_atlas_grid(layer, grid_w, grid_h)
			
		elif type == "InstanceList":
			_build_instances(layer, tile_size)
			
	#print("Level Import Complete! Size: %dx%d" % [grid_w, grid_h])

# --- LAYER PROCESSORS ---

func _build_int_grid(layer: Dictionary, width: int, height: int, mapping: Dictionary) -> void:
	var l_name = layer.get("name", "")
	var arr = layer.get("data", [])
	
	var biome_debug_printed = false # Prevent console spam
	var fallback_debug_printed = false
	
	for y in range(height):
		for x in range(width):
			var idx = (y * width) + x
			if idx >= arr.size(): break
			
			var cell_val = arr[idx]
			if cell_val <= 0: continue 
			
			if l_name == "Terrain":
				# [FIX 1] Force the float into an int before stringifying! (3.0 -> 3 -> "3")
				var str_val = str(int(cell_val)) 
				
				if mapping.has(str_val):
					var map_data = mapping[str_val]
					var source_id = int(map_data.get("source_id", 0))
					var alt_tile = int(map_data.get("alternative_tile", 0))
					
					var atlas_coords = Vector2i.ZERO
					var raw_coords = map_data.get("atlas_coords")
					if typeof(raw_coords) == TYPE_ARRAY and raw_coords.size() >= 2:
						atlas_coords = Vector2i(int(raw_coords[0]), int(raw_coords[1]))
						
					var tile_set = floor_layer.tile_set
					if tile_set and tile_set.has_source(source_id):
						var source = tile_set.get_source(source_id) as TileSetAtlasSource
						if source:
							# [FIX 2] Just-In-Time (JIT) Base Tile Creation
							# If the target game's tileset doesn't have this coordinate defined, make it!
							if not source.has_tile(atlas_coords):
								source.create_tile(atlas_coords)
								
							# --- JUST-IN-TIME ALTERNATIVE TILE CREATION ---
							if alt_tile > 0:
								if not source.has_alternative_tile(atlas_coords, alt_tile):
									source.create_alternative_tile(atlas_coords, alt_tile)
									
									var new_data = source.get_tile_data(atlas_coords, alt_tile)
									if new_data and map_data.has("modulate_color"):
										var c_hex = map_data["modulate_color"]
										new_data.modulate = Color.html(c_hex) if typeof(c_hex) == TYPE_STRING else c_hex
					
					# Paint the specific visual tile
					floor_layer.set_cell(Vector2i(x, y), source_id, atlas_coords, alt_tile)
				else:
					if not fallback_debug_printed:
						print("[DEBUG] WARNING: Tile ID '%s' not found in mapping! Falling back to default." % str_val)
						fallback_debug_printed = true
					# Fallback for unknown tile IDs
					floor_layer.set_cell(Vector2i(x, y), 0, default_floor_atlas)
					
			elif l_name == "Collision_Mask":
				if int(cell_val) == 1:
					collision_layer.set_cell(Vector2i(x, y), 0, collision_tile_atlas)

func _build_atlas_grid(layer: Dictionary, width: int, height: int) -> void:
	var arr = layer.get("data", [])
	for y in range(height):
		for x in range(width):
			var idx = (y * width) + x
			if idx >= arr.size(): break
			
			var atlas_coord = arr[idx]
			# If the exporter saved [-1, -1], it means no override
			if atlas_coord[0] != -1 and atlas_coord[1] != -1:
				floor_layer.set_cell(Vector2i(x, y), 0, Vector2i(atlas_coord[0], atlas_coord[1]))

func _build_instances(layer: Dictionary, tile_size: int) -> void:
	var instances = layer.get("instances", [])
	var printed_debug = false
	
	for inst in instances:
		var grid_x = inst.get("x", 0)
		var grid_y = inst.get("y", 0)
		var c_data = inst.get("custom_data", {})
		var type = inst.get("type", "")
		
		var world_pos = Vector2(grid_x * tile_size + (tile_size / 2.0), grid_y * tile_size + (tile_size / 2.0))
		
		# 1. Spawn Player
		if type == "start_point" or c_data.get("is_forced_start", false):
			if player_scene:
				var player = player_scene.instantiate()
				player.position = world_pos
				add_child(player)
			continue 
			
		# --- Spawn Exit Tile ---
		if type == "end_point" or c_data.get("is_forced_end", false):
			if end_point_scene:
				var exit_node = end_point_scene.instantiate() as EndPoint
				exit_node.position = world_pos
				entity_container.add_child(exit_node)
				
				# Forward the signal to the importer so GamePlayer can hear it
				exit_node.player_entered.connect(func(): level_completed.emit())
			continue
			
		# --- DEBUG: Print the raw dictionary of the first scattered entity ---
		if type != "door" and type != "key" and type != "start_point" and type != "end_point" and not inst.get("is_structure", false):
			if not printed_debug:
				print("\n[DEBUG] Raw Scatter Instance Data: ", inst, "\n")
				printed_debug = true
		
		# 2. Create the dummy visual square
		var dummy = Sprite2D.new()
		var tex = PlaceholderTexture2D.new()
		tex.size = Vector2(tile_size * 0.8, tile_size * 0.8) 
		dummy.texture = tex
		dummy.position = world_pos
		
		# Serialize the entire dictionary to a string for a bulletproof keyword search
		var inst_str = str(inst).to_lower()
		
		# 3. Resolve Identity & Color
		if type == "key":
			if key_scene:
				var key_node = key_scene.instantiate() as DungeonKey
				# Grab the exact string from the JSON (e.g. "Tier 2" or "LavenderBlush")
				var k_type = inst.get("key_type", "Red")
				
				# Determine Color
				var k_col = Color.YELLOW
				if k_type.begins_with("Tier "):
					k_col = Color(0.8, 0.8, 0.8) # Silver for tiers
				else:
					k_col = Color.from_string(k_type, Color.YELLOW)
					
				key_node.position = world_pos
				entity_container.add_child(key_node)
				key_node.setup(k_type, k_col, tile_size)
			continue
			
		elif type == "door":
			if door_scene:
				var door_node = door_scene.instantiate() as DungeonDoor
				var l_type = inst.get("lock_type", "Red")
				
				var l_col = Color.RED
				if l_type.begins_with("Tier "):
					l_col = Color(0.4, 0.4, 0.4) # Dark gray for tier doors
				else:
					l_col = Color.from_string(l_type, Color.RED)
					
				door_node.position = world_pos
				entity_container.add_child(door_node)
				door_node.setup(l_type, l_col, tile_size)
			continue
			
		elif type == "structure":
			var s_color = Color.WEB_GRAY
			if inst.has("color"):
				var c_str = inst["color"].replace("(", "").replace(")", "")
				var c_parts = c_str.split(",")
				if c_parts.size() >= 3:
					s_color = Color(c_parts[0].to_float(), c_parts[1].to_float(), c_parts[2].to_float(), 0.8)
					
			if inst.has("footprint_world"):
				for pt in inst["footprint_world"]:
					var cx = 0
					var cy = 0
					
					if typeof(pt) == TYPE_STRING:
						var clean = pt.replace("(", "").replace(")", "")
						var parts = clean.split(",")
						if parts.size() == 2:
							cx = parts[0].to_int()
							cy = parts[1].to_int()
					
					var block = Sprite2D.new()
					var b_tex = PlaceholderTexture2D.new()
					b_tex.size = Vector2(tile_size, tile_size)
					block.texture = b_tex
					block.modulate = s_color
					block.position = Vector2(cx * tile_size + (tile_size / 2.0), cy * tile_size + (tile_size / 2.0))
					entity_container.add_child(block)
						
				dummy.queue_free()
				continue
				
		else:
			# Fuzzy search across the payload
			if inst_str.contains("default entity") or inst_str.contains("pushable"):
				if pushbox_scene:
					var box = pushbox_scene.instantiate()
					box.position = world_pos
					entity_container.add_child(box)
				continue
				
			elif inst_str.contains("enemy") or inst_str.contains("statue"):
				if enemy_scene:
					var enemy = enemy_scene.instantiate()
					enemy.position = world_pos
					entity_container.add_child(enemy)
				continue
				
			elif inst_str.contains("loot"):
				if loot_scene:
					var loot = loot_scene.instantiate()
					loot.position = world_pos
					entity_container.add_child(loot)
				continue
				
			else:
				# Absolute Fallback (Draw a green square for unknowns)
				dummy.modulate = Color.GREEN 
				entity_container.add_child(dummy)
				
		entity_container.add_child(dummy)
