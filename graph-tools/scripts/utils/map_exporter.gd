class_name MapExporter
extends Node

# Emitted so the Controller knows when to unlock the UI
signal export_finished(success: bool)

func begin_export(target_layer: TileMapLayer, scale_factor: float = 1.0) -> void:
	var used_rect = target_layer.get_used_rect()
	if used_rect.size == Vector2i.ZERO:
		export_finished.emit(false)
		return
		
	var fd = FileDialog.new()
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	fd.add_filter("*.png", "PNG Images")
	fd.current_file = "dungeon_map_" + str(Time.get_unix_time_from_system()) + ".png"
	fd.size = Vector2(600, 400)
	
	fd.file_selected.connect(func(path: String):
		_run_chunked_export(target_layer, used_rect, scale_factor, path)
		fd.queue_free()
	)
	fd.canceled.connect(func():
		export_finished.emit(false)
		fd.queue_free()
	)
	
	add_child(fd)
	fd.popup_centered()

func _run_chunked_export(layer: TileMapLayer, used_rect: Rect2i, scale_factor: float, save_path: String) -> void:
	# --- [FIX] THE TRANSFORM RESET ---
	# Save the UI's visual scale and position
	var original_transform = layer.global_transform
	
	# Force the map to 0,0 at 1:1 scale so local coordinates perfectly match global camera coordinates!
	layer.global_transform = Transform2D.IDENTITY
	
	# Wait one frame for the physics/rendering server to catch up with the teleport
	await get_tree().process_frame
	
	# Add a 2-tile margin so floating text/sprites on the borders don't get clipped!
	used_rect = used_rect.grow(2)
	
	var cell_size = float(layer.tile_set.tile_size.x)
	var world_min = Vector2(used_rect.position) * cell_size
	var world_size = Vector2(used_rect.size) * cell_size
	
	var final_px_w = int(world_size.x * scale_factor)
	var final_px_h = int(world_size.y * scale_factor)
	
	# Create the massive blank Master Image in System RAM
	var master_image = Image.create_empty(final_px_w, final_px_h, false, Image.FORMAT_RGBA8)
	
	# Create the "Drone" SubViewport
	var vp = SubViewport.new()
	vp.disable_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	vp.world_2d = layer.get_world_2d() 
	
	# Use a safe 2048x2048 chunk size (easily supported by all GPUs)
	var chunk_px_size = 2048
	vp.size = Vector2i(chunk_px_size, chunk_px_size)
	add_child(vp)
	
	var cam = Camera2D.new()
	cam.zoom = Vector2(scale_factor, scale_factor)
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	vp.add_child(cam)
	
	var world_chunk_step = float(chunk_px_size) / scale_factor
	var chunks_x = ceil(world_size.x / world_chunk_step)
	var chunks_y = ceil(world_size.y / world_chunk_step)
	
	# --- The Photo Loop ---
	for cy in range(chunks_y):
		for cx in range(chunks_x):
			var cam_pos = world_min + Vector2(cx * world_chunk_step, cy * world_chunk_step)
			cam.global_position = cam_pos
			
			# Wait 2 frames for the Camera to move and the GPU to draw the textures/fonts
			await get_tree().process_frame
			await get_tree().process_frame
			
			var chunk_img = vp.get_texture().get_image()
			
			var dest_x = cx * chunk_px_size
			var dest_y = cy * chunk_px_size
			master_image.blit_rect(chunk_img, Rect2i(0, 0, chunk_px_size, chunk_px_size), Vector2i(dest_x, dest_y))
			
	# Save to disk
	master_image.save_png(save_path)
	
	# --- CLEANUP AND RESTORE ---
	vp.queue_free()
	layer.global_transform = original_transform
	
	export_finished.emit(true)
