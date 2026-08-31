class_name GenerationValidator
extends RefCounted

var grid: GridData
var full_explore: bool
var delay_doors: bool

var start_pos: Vector2i = Vector2i(-1, -1)
var end_pos: Vector2i = Vector2i(-1, -1)
var keys_in_world: Dictionary = {}
var doors_in_world: Dictionary = {}
var triggers_in_world: Dictionary = {} 
var hit_trigger_id: String = "" # Tracks if we hit one this frame
var last_trigger_pos: Vector2i = Vector2i(-1, -1)
var blocked_cells: Dictionary = {} 
var valid_floors: Dictionary = {}
var total_walkable: int = 0

# --- THE PERSISTENT STATE ---
var queue: Array = []
var visited: Dictionary = {}
var inventory: Dictionary = {}
var consumed_triggers: Dictionary = {} # The player's memory of pulled levers
var stuck_doors: Dictionary = {} 
var pending_unlocks: Array = []
var pending_triggers: Array = [] # Queue for delayed triggers

var is_finished: bool = false
var found_end: bool = false
var ortho = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

# Event tracking for the controller to draw/log
var newly_visited: Array = []
var log_messages: Array = []

func _init(initial_grid: GridData, p_full_explore: bool, p_delay_doors: bool) -> void:
	full_explore = p_full_explore
	delay_doors = p_delay_doors
	_parse_entities_and_floors(initial_grid)
	
	if start_pos != Vector2i(-1, -1):
		queue.append(start_pos)
		visited[start_pos] = true
		log_messages.append("[color=gray]Starting validation from Start Point...[/color]")
	else:
		is_finished = true
		log_messages.append("[color=red]Missing Start Point![/color]")

# ==============================================================================
# THE DIMENSIONAL SHIFT (Phase 2 Survival)
# ==============================================================================
func update_world(new_grid: GridData, dirty_rect: Rect2i = Rect2i(), re_explore: bool = false) -> void:
	_parse_entities_and_floors(new_grid)
	
	# 1. Calculate what survived the blast (Standard Evaporation)
	var surviving_visited = {}
	for pt in visited:
		var evaporated = false
		if not valid_floors.has(pt): evaporated = true
		if dirty_rect.size != Vector2i.ZERO and dirty_rect.has_point(pt): evaporated = true
		if not evaporated: surviving_visited[pt] = true
			
	var surviving_queue_map = {}
	for pt in queue:
		var evaporated = false
		if not valid_floors.has(pt): evaporated = true
		if dirty_rect.size != Vector2i.ZERO and dirty_rect.has_point(pt): evaporated = true
		if surviving_visited.has(pt): evaporated = true 
		if not evaporated: surviving_queue_map[pt] = true
			
	# --- FEATURE 3: AMNESIA PROTOCOL ---
	if re_explore:
		var anchor = Vector2i(-1, -1)

		# --- TRIGGER PREFERENCE ---
		if last_trigger_pos != Vector2i(-1, -1):
			if valid_floors.has(last_trigger_pos):
				anchor = last_trigger_pos
			else:
				# Try a small radial search (10 tiles) instead of entire map
				var best_dist = 999999.0
				for pt in valid_floors:
					var d = pt.distance_squared_to(last_trigger_pos)
					if d < best_dist:
						best_dist = d
						anchor = pt
			# Clear the memory after use
			last_trigger_pos = Vector2i(-1, -1)

		# --- ORIGINAL FALLBACK (unchanged) ---
		if anchor == Vector2i(-1, -1):
			# Grab the MOST RECENT step the fluid took that survived the blast
			var visited_keys = visited.keys()
			for i in range(visited_keys.size() - 1, -1, -1):
				if surviving_visited.has(visited_keys[i]):
					anchor = visited_keys[i]
					break
			# Fallbacks just in case the player was completely annihilated
			if anchor == Vector2i(-1, -1) and surviving_queue_map.size() > 0:
				anchor = surviving_queue_map.keys()[0]
			if anchor == Vector2i(-1, -1):
				anchor = start_pos

		# --- TOTAL AMNESIA (keep inventory) ---
		visited.clear()
		queue.clear()
		stuck_doors.clear()
		pending_unlocks.clear()

		# --- DROP THE PIN ---
		if valid_floors.has(anchor):
			queue.append(anchor)
			visited[anchor] = true
			log_messages.append("[color=orange]Re-exploration triggered! Dropped pin at current position: " + str(anchor) + "[/color]")
	else:
		# --- STANDARD RE-IGNITION PROTOCOL ---
		visited = surviving_visited
		for pt in visited.keys():
			for d in ortho:
				var n = pt + d
				if valid_floors.has(n) and not visited.has(n):
					surviving_queue_map[pt] = true 
					break
		queue = surviving_queue_map.keys()
		
		var surviving_pending = []
		for pt in pending_unlocks:
			if valid_floors.has(pt) and doors_in_world.has(pt) and not (dirty_rect.size != Vector2i.ZERO and dirty_rect.has_point(pt)):
				surviving_pending.append(pt)
		pending_unlocks = surviving_pending
		
		# --- Protect Pending Triggers ---
		var surviving_triggers = []
		for pt in pending_triggers:
			if valid_floors.has(pt) and triggers_in_world.has(pt) and not (dirty_rect.size != Vector2i.ZERO and dirty_rect.has_point(pt)):
				surviving_triggers.append(pt)
		pending_triggers = surviving_triggers
		
		for k in stuck_doors.keys():
			var surviving_stuck = []
			for pt in stuck_doors[k]:
				if valid_floors.has(pt) and doors_in_world.has(pt) and not (dirty_rect.size != Vector2i.ZERO and dirty_rect.has_point(pt)):
					surviving_stuck.append(pt)
			stuck_doors[k] = surviving_stuck

# ==============================================================================
# THE VCR ENGINE
# ==============================================================================
func step(batch_size: int = 1, constant_speed: bool = false) -> Dictionary:
	newly_visited.clear()
	log_messages.clear()
	hit_trigger_id = "" 
	
	if is_finished: return get_payload()
	
	var target_steps = batch_size
	if constant_speed and queue.size() > 0:
		target_steps = queue.size()
	
	var steps_taken = 0
	while steps_taken < target_steps:
		# --- EXHAUSTIVE EXPLORATION TRIGGER ---
		if queue.is_empty():
			if pending_unlocks.size() > 0:
				queue.append_array(pending_unlocks)
				log_messages.append("[color=magenta]Area exhausted. Progressing through " + str(pending_unlocks.size()) + " delayed door(s)...[/color]")
				pending_unlocks.clear()
				break 
			elif pending_triggers.size() > 0:
				# --- DELAYED TRIGGER ACTIVATION ---
				var t_pos = pending_triggers.pop_front()
				hit_trigger_id = triggers_in_world[t_pos]
				triggers_in_world.erase(t_pos)
				consumed_triggers[hit_trigger_id] = true
				
				
				# --- THE ANCHOR FIX ---
				# Collapse the fluid's leading edge perfectly onto the trigger tile!
				queue.clear()
				queue.append(t_pos)
				visited[t_pos] = true
				newly_visited.append(t_pos)
				#print("[DEBUG] Trigger activated at tile: ", t_pos)
				last_trigger_pos = t_pos
				log_messages.append("[color=fuchsia]All paths exhausted. Activating Trigger: " + hit_trigger_id + "[/color]")
				break
			else:
				_finish_validation()
				break
				
		var curr = queue.pop_front()
		newly_visited.append(curr)
		steps_taken += 1
		
		if curr == end_pos and not found_end:
			found_end = true
			if not full_explore:
				log_messages.append("[color=green]Validation Passed! Exit is reachable.[/color]")
				_finish_validation()
				break 
			else:
				log_messages.append("[color=lime]Exit found! Continuing exploration...[/color]")
				
		for d in ortho:
			var n = curr + d
			if visited.has(n) or not grid.in_bounds_vec(n): continue
			if not valid_floors.has(n): continue
			
			if doors_in_world.has(n):
				var req = doors_in_world[n]
				if req != "" and req != "Unlocked":
					if not inventory.has(req):
						if not stuck_doors.has(req): stuck_doors[req] = []
						stuck_doors[req].append(n)
						visited[n] = true 
						continue
					elif delay_doors:
						pending_unlocks.append(n)
						visited[n] = true
						continue
						
			visited[n] = true
			queue.append(n)
			
						
			if keys_in_world.has(n):
				# --- USE HELPER ---
				_acquire_key(keys_in_world[n])
						
			# --- TRIGGER DETECTION ---
			if triggers_in_world.has(n):
				# If "Exhaustive Mode" is on, push it to the back of the line!
				if delay_doors and not pending_triggers.has(n):
					pending_triggers.append(n)
					visited[n] = true # Mark as seen so we don't infinitely re-queue it
					continue 
				elif not delay_doors:
					# Instant Mode
					hit_trigger_id = triggers_in_world[n]
					triggers_in_world.erase(n)
					consumed_triggers[hit_trigger_id] = true 
					
					
					# --- THE ANCHOR FIX ---
					last_trigger_pos = n
					
					log_messages.append("[color=fuchsia]Trigger Activated! Shifting Dimensions...[/color]")
					break
					
		# --- HALT THE BATCH ---
		if hit_trigger_id != "":
			break
			
	return get_payload()

func fast_forward() -> Dictionary:
	while not is_finished:
		step(999999) # Process until finished
	return get_payload()

# ==============================================================================
# HELPERS
# ==============================================================================
func get_payload() -> Dictionary:
	return {
		"is_finished": is_finished,
		"newly_visited": newly_visited.duplicate(),
		"frontier": queue.duplicate(), # For drawing the glowing outline
		"logs": log_messages.duplicate(),
		"is_playable": found_end,
		"inventory": inventory.keys(),
		"hit_trigger": hit_trigger_id # Tell the thread we hit a trigger
	}

func get_redraw_payload() -> Dictionary:
	return {
		"is_finished": is_finished,
		"newly_visited": visited.keys(), # Dumps ALL surviving history
		"frontier": queue.duplicate(),
		"logs": ["[color=cyan]Validator adapted to new topology.[/color]"],
		"is_playable": found_end,
		"inventory": inventory.keys(),
		"is_redraw": true # <--- Tells the Controller to do a full repaint
	}

func get_temporal_snapshot() -> Dictionary:
	var anchor = Vector2i(-1, -1)
	# The frontier (queue) is the leading edge. If empty, fallback to the last visited puddle tile.
	if queue.size() > 0: anchor = queue[0]
	elif visited.size() > 0: anchor = visited.keys()[-1]
	
	return {
		"inventory": inventory.keys().duplicate(),
		"consumed_triggers": consumed_triggers.keys().duplicate(), # Export the memory
		"anchor": anchor
	}

func _finish_validation() -> void:
	is_finished = true
	if found_end:
		var msg = "[color=green]Validation Complete. Exit Reached.[/color]"
		if stuck_doors.size() > 0: msg += "\n[color=orange](Note: " + str(stuck_doors.size()) + " door types were left permanently locked!)[/color]"
		log_messages.append(msg)
	else:
		log_messages.append("[color=red]Validation Failed! Softlock detected (Exit unreachable).[/color]")

func _parse_entities_and_floors(new_grid: GridData) -> void:
	grid = new_grid
	keys_in_world.clear()
	doors_in_world.clear()
	triggers_in_world.clear()
	blocked_cells.clear()
	valid_floors.clear()
	total_walkable = 0
	start_pos = Vector2i(-1, -1)
	end_pos = Vector2i(-1, -1)
	
	for pos in grid.entities:
		var e = grid.entities[pos]
		var e_type = e.get("type", "")
		
		if e_type == "start_point": start_pos = pos
		elif e_type == "end_point": end_pos = pos
		elif e_type == "key": keys_in_world[pos] = e.get("key_type")
		elif e_type == "door": doors_in_world[pos] = e.get("lock_type", "Unlocked")
		elif e_type == "trigger": triggers_in_world[pos] = e.get("trigger_id", "")
		elif e_type == "structure":
			var footprint = e.get("footprint_world", [])
			if e.get("is_solid", true):
				for pt in footprint: blocked_cells[pt] = true
				
	for y in range(grid.height):
		for x in range(grid.width):
			var id = grid.get_cell(x, y)
			if grid.palette.get_data(id).get("walkable", false) and not blocked_cells.has(Vector2i(x, y)):
				valid_floors[Vector2i(x, y)] = true
				total_walkable += 1


func get_final_analytics() -> Dictionary:
	var missed_keys = []
	for k in keys_in_world.values():
		if not inventory.has(k) and not missed_keys.has(k): missed_keys.append(k)
		
	var unreachable = {}
	for pos in grid.entities:
		var e = grid.entities[pos]
		if e.get("type") == "structure" and e.get("is_solid", true):
			var reached = false
			for pt in e.get("footprint_world", []):
				for d in ortho:
					if visited.has(pt + d): reached = true; break
				if reached: break
			if not reached: unreachable[e.get("name", "Structure")] = unreachable.get(e.get("name", "Structure"), 0) + 1
		else:
			if not visited.has(pos): unreachable[e.get("name", "Entity")] = unreachable.get(e.get("name", "Entity"), 0) + 1
			
	return {
		"is_playable": found_end,
		"total_walkable": total_walkable,
		"reachable_walkable": visited.size(),
		"coverage_percent": (float(visited.size()) / float(max(1, total_walkable))) * 100.0,
		"keys_collected": inventory.keys(),
		"keys_missed": missed_keys,
		"permanently_locked": stuck_doors.keys(),
		"unreachable_entities": unreachable
	}

func _acquire_key(k_type: String) -> void:
	if not inventory.has(k_type):
		inventory[k_type] = true
		
		# Give Temporal keys a distinct log color!
		if k_type.begins_with("TemporalLock_"):
			log_messages.append("[color=fuchsia]Acquired Temporal Key: " + k_type + "[/color]")
		else:
			log_messages.append("[color=yellow]Found Key: " + k_type + "[/color]")
		
		if stuck_doors.has(k_type):
			var unlocked_count = stuck_doors[k_type].size()
			if delay_doors:
				pending_unlocks.append_array(stuck_doors[k_type])
				log_messages.append("[color=cyan]Unlocked " + str(unlocked_count) + " " + k_type + " door(s)! (Queued)[/color]")
			else:
				queue.append_array(stuck_doors[k_type])
				log_messages.append("[color=cyan]Unlocked " + str(unlocked_count) + " " + k_type + " door(s)![/color]")
			stuck_doors.erase(k_type)
