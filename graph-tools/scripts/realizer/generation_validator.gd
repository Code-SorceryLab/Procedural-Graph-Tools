class_name GenerationValidator
extends RefCounted

static func run(grid: GridData, visualize: bool, full_explore: bool, emit: Callable, check_cancel: Callable) -> Dictionary:
	var start_pos = Vector2i(-1, -1)
	var end_pos = Vector2i(-1, -1)
	var keys_in_world = {}
	var doors_in_world = {}
	var blocked_cells = {} 

	for pos in grid.entities:
		var e = grid.entities[pos]
		var e_type = e.get("type", "")
		
		if e_type == "start_point": start_pos = pos
		elif e_type == "end_point": end_pos = pos
		elif e_type == "key": keys_in_world[pos] = e.get("key_type")
		elif e_type == "door": doors_in_world[pos] = e.get("lock_type", "Unlocked")
		elif e_type == "structure":
			var footprint = e.get("footprint_world", [])
			# Only add it to the collision mask if it is completely solid
			if e.get("is_solid", true):
				for pt in footprint: blocked_cells[pt] = true

	if start_pos == Vector2i(-1, -1) or end_pos == Vector2i(-1, -1):
		if emit.is_valid(): emit.call_deferred("log", "[color=red]Missing Start or End point![/color]")
		return {"is_playable": false, "error": "Missing Start/End"}

	var valid_floors = {}
	var total_walkable = 0
	for y in range(grid.height):
		for x in range(grid.width):
			var id = grid.get_cell(x, y)
			if grid.palette.get_data(id).get("walkable", false) and not blocked_cells.has(Vector2i(x, y)):
				valid_floors[Vector2i(x, y)] = true
				total_walkable += 1

	var queue = [start_pos]
	var visited = { start_pos: true }
	var inventory = {}
	var stuck_doors = {} 
	var ortho = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

	var steps_since_emit = 0
	var visited_batch = []
	var found_end = false

	if emit.is_valid(): emit.call_deferred("log", "Starting validation from Start Point...")

	while queue.size() > 0:
		if check_cancel.is_valid() and check_cancel.call():
			if emit.is_valid(): emit.call_deferred("log", "[color=orange]Validation Cancelled.[/color]")
			return {"is_playable": false, "error": "Cancelled"}

		var curr = queue.pop_front()
		visited_batch.append(curr)

		if curr == end_pos and not found_end:
			found_end = true
			if not full_explore:
				if emit.is_valid():
					emit.call_deferred("flood", visited_batch.duplicate()) 
					emit.call_deferred("log", "[color=green]Validation Passed! Exit is reachable.[/color]")
				break # Stop early if we just want to prove it's beatable
			else:
				if emit.is_valid():
					emit.call_deferred("flood", visited_batch.duplicate())
					visited_batch.clear()
					emit.call_deferred("log", "[color=lime]Exit found! Continuing exploration...[/color]")

		for d in ortho:
			var n = curr + d
			if visited.has(n) or not grid.in_bounds_vec(n): continue
			if not valid_floors.has(n): continue

			if doors_in_world.has(n):
				var req = doors_in_world[n]
				if req != "" and req != "Unlocked" and not inventory.has(req):
					if not stuck_doors.has(req): stuck_doors[req] = []
					stuck_doors[req].append(n)
					visited[n] = true 
					continue

			visited[n] = true
			queue.append(n)

			if keys_in_world.has(n):
				var k_type = keys_in_world[n]
				if not inventory.has(k_type):
					inventory[k_type] = true
					if emit.is_valid():
						emit.call_deferred("flood", visited_batch.duplicate())
						visited_batch.clear()
						emit.call_deferred("log", "[color=yellow]Found Key: " + k_type + "[/color]")
						if visualize: OS.delay_msec(250)

					if stuck_doors.has(k_type):
						var unlocked_count = stuck_doors[k_type].size()
						for door_pos in stuck_doors[k_type]:
							queue.append(door_pos) 
						stuck_doors.erase(k_type)
						if emit.is_valid():
							emit.call_deferred("log", "[color=cyan]Unlocked " + str(unlocked_count) + " " + k_type + " door(s)![/color]")
							if visualize: OS.delay_msec(250)

		steps_since_emit += 1
		if visualize and steps_since_emit >= 20: 
			if emit.is_valid(): emit.call_deferred("flood", visited_batch.duplicate())
			visited_batch.clear()
			steps_since_emit = 0
			OS.delay_msec(10) 

	# Out of valid moves
	if emit.is_valid():
		emit.call_deferred("flood", visited_batch.duplicate())
		if found_end:
			var msg = "[color=green]Validation Passed! Full grid explored.[/color]"
			if stuck_doors.size() > 0: msg += "\n[color=orange](Note: " + str(stuck_doors.size()) + " door types were left permanently locked!)[/color]"
			emit.call_deferred("log", msg)
		else:
			emit.call_deferred("log", "[color=red]Validation Failed! Softlock detected (Exit unreachable).[/color]")

	# --- COMPILE ANALYTICS ---
	var missed_keys = []
	for k in keys_in_world.values():
		if not inventory.has(k) and not missed_keys.has(k): missed_keys.append(k)

	# Advanced Reachability Check
	var unreachable_entities = {}
	for pos in grid.entities:
		var e = grid.entities[pos]
		var e_type = e.get("type", "Unknown Entity")
		var e_name = e.get("name", e_type)
		var reached = false

		if e_type == "structure":
			var footprint = e.get("footprint_world", [])
			var is_solid = e.get("is_solid", true)
			
			for pt in footprint:
				if visited.has(pt):
					reached = true
					break
				# If it's a solid structure, you can't stand on it, 
				# but if you can stand NEXT to it, it is "reached"!
				if is_solid:
					for d in ortho:
						if visited.has(pt + d):
							reached = true
							break
				if reached: break
		else:
			# Normal entities (Keys, Scatter) just need their anchor point touched
			reached = visited.has(pos)

		if not reached:
			unreachable_entities[e_name] = unreachable_entities.get(e_name, 0) + 1

	return {
		"is_playable": found_end,
		"total_walkable": total_walkable,
		"reachable_walkable": visited.size(),
		"coverage_percent": (float(visited.size()) / float(max(1, total_walkable))) * 100.0,
		"keys_collected": inventory.keys(),
		"keys_missed": missed_keys,
		"permanently_locked": stuck_doors.keys(),
		"unreachable_entities": unreachable_entities,
		"full_explore": full_explore
	}
