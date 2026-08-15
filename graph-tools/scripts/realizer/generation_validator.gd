class_name GenerationValidator
extends RefCounted

# Returns true if beatable, false if softlocked
static func run(grid: GridData, visualize: bool, emit: Callable, check_cancel: Callable) -> bool:
	var start_pos = Vector2i(-1, -1)
	var end_pos = Vector2i(-1, -1)
	var keys_in_world = {}
	var doors_in_world = {}

	# 1. Parse the board state
	for pos in grid.entities:
		var e = grid.entities[pos]
		if e.get("type") == "start_point": start_pos = pos
		elif e.get("type") == "end_point": end_pos = pos
		elif e.get("type") == "key": keys_in_world[pos] = e.get("key_type")
		# [FIXED] Add "Unlocked" as the default fallback so it doesn't return null!
		elif e.get("type") == "door": doors_in_world[pos] = e.get("lock_type", "Unlocked")

	if start_pos == Vector2i(-1, -1) or end_pos == Vector2i(-1, -1):
		if emit.is_valid(): emit.call_deferred("log", "[color=red]Missing Start or End point![/color]")
		return false

	var valid_floors = {}
	for id in grid.palette._definitions:
		if grid.palette.get_data(id).get("walkable", false):
			valid_floors[id] = true

	# 2. Setup the "Player" State
	var queue = [start_pos]
	var visited = { start_pos: true }
	var inventory = {}
	var stuck_doors = {} # lock_type -> array of Vector2i
	var ortho = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]

	var steps_since_emit = 0
	var visited_batch = []

	if emit.is_valid(): emit.call_deferred("log", "Starting validation from Start Point...")

	# 3. The Exploration Loop
	while queue.size() > 0:
		if check_cancel.is_valid() and check_cancel.call():
			if emit.is_valid(): emit.call_deferred("log", "[color=orange]Validation Cancelled.[/color]")
			return false

		var curr = queue.pop_front()
		visited_batch.append(curr)

		if curr == end_pos:
			if emit.is_valid():
				# [FIXED] Pass a .duplicate() so the array isn't erased before the UI renders it!
				emit.call_deferred("flood", visited_batch.duplicate()) 
				emit.call_deferred("log", "[color=green]Validation Passed! Exit is reachable.[/color]")
			return true

		for d in ortho:
			var n = curr + d
			if visited.has(n) or not grid.in_bounds_vec(n): continue
			if not valid_floors.has(grid.get_cell(n.x, n.y)): continue

			# Check if our path is blocked by a Door
			if doors_in_world.has(n):
				var req = doors_in_world[n]
				
				# An empty string AND the word "Unlocked" both mean free passage
				if req != "" and req != "Unlocked" and not inventory.has(req):
					if not stuck_doors.has(req): stuck_doors[req] = []
					stuck_doors[req].append(n)
					visited[n] = true # Mark visited so we don't spam it, but DO NOT queue it yet!
					continue

			visited[n] = true
			queue.append(n)

			# Check if we stepped on a Key
			if keys_in_world.has(n):
				var k_type = keys_in_world[n]
				if not inventory.has(k_type):
					inventory[k_type] = true
					if emit.is_valid():
						emit.call_deferred("flood", visited_batch.duplicate()) # [FIXED]
						visited_batch.clear()
						emit.call_deferred("log", "[color=yellow]Found Key: " + k_type + "[/color]")
						if visualize: OS.delay_msec(250) # Pause so the user sees the discovery!

					# Did we find a key for a door we were previously stuck at?
					if stuck_doors.has(k_type):
						var unlocked_count = stuck_doors[k_type].size()
						for door_pos in stuck_doors[k_type]:
							queue.append(door_pos) # Add the door back to the active frontier!
						stuck_doors.erase(k_type)
						if emit.is_valid():
							emit.call_deferred("log", "[color=cyan]Unlocked " + str(unlocked_count) + " " + k_type + " door(s)![/color]")
							if visualize: OS.delay_msec(250)

		steps_since_emit += 1
		
		# Batch visual updates to prevent UI thread lag
		if visualize and steps_since_emit >= 20: 
			if emit.is_valid(): emit.call_deferred("flood", visited_batch.duplicate()) # [FIXED]
			visited_batch.clear()
			steps_since_emit = 0
			OS.delay_msec(10) # Gives a cool "creeping water" visual effect

	# 4. Out of valid moves
	if emit.is_valid():
		emit.call_deferred("flood", visited_batch.duplicate()) # [FIXED]
		emit.call_deferred("log", "[color=red]Validation Failed! Softlock detected.[/color]")
	return false
	
	
