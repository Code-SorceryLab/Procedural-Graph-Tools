class_name GenerationValidator
extends RefCounted

# [FIXED] Added full_explore to signature
static func run(grid: GridData, visualize: bool, full_explore: bool, emit: Callable, check_cancel: Callable) -> bool:
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
			for pt in footprint: blocked_cells[pt] = true

	if start_pos == Vector2i(-1, -1) or end_pos == Vector2i(-1, -1):
		if emit.is_valid(): emit.call_deferred("log", "[color=red]Missing Start or End point![/color]")
		return false

	var valid_floors = {}
	for id in grid.palette._definitions:
		if grid.palette.get_data(id).get("walkable", false):
			valid_floors[id] = true

	var queue = [start_pos]
	var visited = { start_pos: true }
	var inventory = {}
	var stuck_doors = {} 
	var ortho = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

	var steps_since_emit = 0
	var visited_batch = []
	var found_end = false # [NEW] Track if we've touched the exit

	if emit.is_valid(): emit.call_deferred("log", "Starting validation from Start Point...")

	while queue.size() > 0:
		if check_cancel.is_valid() and check_cancel.call():
			if emit.is_valid(): emit.call_deferred("log", "[color=orange]Validation Cancelled.[/color]")
			return false

		var curr = queue.pop_front()
		visited_batch.append(curr)

		if curr == end_pos and not found_end:
			found_end = true
			if not full_explore:
				if emit.is_valid():
					emit.call_deferred("flood", visited_batch.duplicate()) 
					emit.call_deferred("log", "[color=green]Validation Passed! Exit is reachable.[/color]")
				return true
			else:
				if emit.is_valid():
					emit.call_deferred("flood", visited_batch.duplicate())
					visited_batch.clear()
					emit.call_deferred("log", "[color=lime]Exit found! Continuing exploration of side branches...[/color]")

		for d in ortho:
			var n = curr + d
			if visited.has(n) or not grid.in_bounds_vec(n): continue
			if not valid_floors.has(grid.get_cell(n.x, n.y)): continue
			if blocked_cells.has(n): continue

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

	# 4. Out of valid moves
	if emit.is_valid():
		emit.call_deferred("flood", visited_batch.duplicate())
		
		# Evaluate the final state after FULL exploration
		if found_end:
			var msg = "[color=green]Validation Passed! Full grid explored.[/color]"
			if stuck_doors.size() > 0:
				msg += "\n[color=orange](Note: " + str(stuck_doors.size()) + " door types were left permanently locked!)[/color]"
			emit.call_deferred("log", msg)
		else:
			emit.call_deferred("log", "[color=red]Validation Failed! Softlock detected (Exit unreachable).[/color]")
			
	return found_end
