class_name GenerationValidator
extends RefCounted

var grid: GridData
var full_explore: bool
var delay_doors: bool

var start_pos: Vector2i = Vector2i(-1, -1)
var end_pos: Vector2i = Vector2i(-1, -1)
var keys_in_world: Dictionary = {}
var doors_in_world: Dictionary = {}
var blocked_cells: Dictionary = {} 
var valid_floors: Dictionary = {}
var total_walkable: int = 0

# --- THE PERSISTENT STATE ---
var queue: Array = []
var visited: Dictionary = {}
var inventory: Dictionary = {}
var stuck_doors: Dictionary = {} 
var pending_unlocks: Array = []

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
func update_world(new_grid: GridData, dirty_rect: Rect2i = Rect2i()) -> void:
	_parse_entities_and_floors(new_grid)
	
	# 1. Prune the Puddle (Visited Cells)
	# Evaporate tiles that are no longer valid floors, OR were caught in the blast radius!
	var surviving_visited = {}
	for pt in visited:
		var evaporated = false
		if not valid_floors.has(pt): evaporated = true
		if dirty_rect.size != Vector2i.ZERO and dirty_rect.has_point(pt): evaporated = true
		
		if not evaporated:
			surviving_visited[pt] = true
	visited = surviving_visited
	
	# 2. Prune the Frontier (Queue)
	var surviving_queue_map = {}
	for pt in queue:
		var evaporated = false
		if not valid_floors.has(pt): evaporated = true
		if dirty_rect.size != Vector2i.ZERO and dirty_rect.has_point(pt): evaporated = true
		if surviving_visited.has(pt): evaporated = true # Don't queue tiles that are already safely visited
		
		if not evaporated:
			surviving_queue_map[pt] = true
			
	# 3. RE-IGNITE THE FRONTIER
	# If the puddle was sheared cleanly by the dirty rect, the surviving tiles on the border 
	# must be woken up so they pour back into the newly generated room!
	for pt in visited.keys():
		for d in ortho:
			var n = pt + d
			if valid_floors.has(n) and not visited.has(n):
				surviving_queue_map[pt] = true # Wake up the border tile!
				break
				
	queue = surviving_queue_map.keys()
	
	# 4. Prune Pending Unlocks
	var surviving_pending = []
	for pt in pending_unlocks:
		if valid_floors.has(pt) and doors_in_world.has(pt) and not (dirty_rect.size != Vector2i.ZERO and dirty_rect.has_point(pt)):
			surviving_pending.append(pt)
	pending_unlocks = surviving_pending
	
	# 5. Prune Stuck Doors
	for k in stuck_doors.keys():
		var surviving_stuck = []
		for pt in stuck_doors[k]:
			if valid_floors.has(pt) and doors_in_world.has(pt) and not (dirty_rect.size != Vector2i.ZERO and dirty_rect.has_point(pt)):
				surviving_stuck.append(pt)
		stuck_doors[k] = surviving_stuck

# ==============================================================================
# THE VCR ENGINE
# ==============================================================================
func step(batch_size: int = 1) -> Dictionary:
	newly_visited.clear()
	log_messages.clear()
	
	if is_finished: return get_payload()
	
	var steps_taken = 0
	while steps_taken < batch_size:
		# --- Exhaustive Exploration Trigger ---
		if queue.is_empty():
			if pending_unlocks.size() > 0:
				queue.append_array(pending_unlocks)
				log_messages.append("[color=magenta]Area exhausted. Progressing through " + str(pending_unlocks.size()) + " delayed door(s)...[/color]")
				pending_unlocks.clear()
				break # Pause visually after opening delayed doors
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
				var k_type = keys_in_world[n]
				if not inventory.has(k_type):
					inventory[k_type] = true
					log_messages.append("[color=yellow]Found Key: " + k_type + "[/color]")
					
					if stuck_doors.has(k_type):
						var unlocked_count = stuck_doors[k_type].size()
						if delay_doors:
							pending_unlocks.append_array(stuck_doors[k_type])
							log_messages.append("[color=cyan]Unlocked " + str(unlocked_count) + " " + k_type + " door(s)! (Queued for later)[/color]")
						else:
							queue.append_array(stuck_doors[k_type])
							log_messages.append("[color=cyan]Unlocked " + str(unlocked_count) + " " + k_type + " door(s)![/color]")
						stuck_doors.erase(k_type)
						
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
		"inventory": inventory.keys()
	}

func get_redraw_payload() -> Dictionary:
	return {
		"is_finished": is_finished,
		"newly_visited": visited.keys(), # <--- Dumps ALL surviving history
		"frontier": queue.duplicate(),
		"logs": ["[color=cyan]Validator adapted to new topology.[/color]"],
		"is_playable": found_end,
		"inventory": inventory.keys(),
		"is_redraw": true # <--- Tells the Controller to do a full repaint
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
