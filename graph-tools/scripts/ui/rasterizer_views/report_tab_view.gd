class_name ReportTabView
extends MarginContainer

var _report_text: RichTextLabel
var _current_report_raw: String = ""

func _init() -> void:
	name = "Report"
	add_theme_constant_override("margin_top", 10)
	add_theme_constant_override("margin_left", 10)
	add_theme_constant_override("margin_right", 10)
	add_theme_constant_override("margin_bottom", 10)

	var main_vbox = VBoxContainer.new()
	add_child(main_vbox)
	
	# --- EXPORT TOOLBAR ---
	var toolbar = HBoxContainer.new()
	main_vbox.add_child(toolbar)
	
	var lbl_title = Label.new()
	lbl_title.text = "Map Analytics"
	lbl_title.add_theme_font_size_override("font_size", 14)
	toolbar.add_child(lbl_title)
	
	var spacer = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	
	var btn_copy = Button.new()
	btn_copy.text = "Copy to Clipboard"
	btn_copy.pressed.connect(_on_copy_pressed)
	toolbar.add_child(btn_copy)
	
	var btn_export = Button.new()
	btn_export.text = "Export .txt"
	btn_export.pressed.connect(_on_export_pressed)
	toolbar.add_child(btn_export)
	
	main_vbox.add_child(HSeparator.new())

	# --- REPORT TEXT ---
	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_vbox.add_child(scroll)

	_report_text = RichTextLabel.new()
	_report_text.bbcode_enabled = true
	_report_text.fit_content = true
	_report_text.selection_enabled = true
	_report_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_report_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_report_text)
	clear()

func clear() -> void:
	_report_text.text = "[color=gray]No progression data available. Rasterize the graph to view the report.[/color]"
	_current_report_raw = ""

func set_loading() -> void:
	_report_text.text = "[color=gray]Generating and Validating Map...[/color]"
	_current_report_raw = ""

func update_report(data: Dictionary) -> void:
	if data.is_empty():
		_report_text.text = "[color=gray]Progression solver was disabled or failed to find regions.[/color]"
		return
	_report_text.text = _format_report(data)
	_current_report_raw = _report_text.get_parsed_text() # Saves the raw text without BBCode tags for exporting

# ==============================================================================
# BUTTON HANDLERS
# ==============================================================================
func _on_copy_pressed() -> void:
	if _current_report_raw != "":
		DisplayServer.clipboard_set(_current_report_raw)

func _on_export_pressed() -> void:
	if _current_report_raw == "": return
	
	var fd = FileDialog.new()
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	fd.add_filter("*.txt", "Text Files")
	fd.current_file = "map_analytics_" + str(Time.get_unix_time_from_system()) + ".txt"
	fd.size = Vector2(600, 400)
	
	fd.file_selected.connect(func(path: String):
		var file = FileAccess.open(path, FileAccess.WRITE)
		if file:
			file.store_string(_current_report_raw)
			file.close()
		fd.queue_free()
	)
	fd.canceled.connect(func(): fd.queue_free())
	add_child(fd)
	fd.popup_centered()

# ==============================================================================
# FORMATTING ENGINE
# ==============================================================================
func _format_report(data: Dictionary) -> String:
	var s = ""
	
	# --- METADATA & DIAGNOSTICS (The Headless Validator Output) ---
	var meta = data.get("meta", {})
	if not meta.is_empty():
		s += "[b]Generation Metadata[/b]\n"
		s += "  Seed: %s\n" % meta.get("seed", "Unknown")
		s += "  Rasterization Time: %d ms\n" % meta.get("time_ms", 0)
		
		# --- BUILDER DIAGNOSTICS ---
		var c_rooms = meta.get("custom_rooms_placed", 0)
		var rej_rooms = meta.get("rejected_custom_rooms", 0)
		var sealed = meta.get("sealed_doorways", 0)
		var failed_routes = meta.get("failed_routes", 0)
		var wfc_contras = meta.get("wfc_contradictions", 0)
		
		# [CHANGED] Add wfc_contras to the display condition
		if c_rooms > 0 or rej_rooms > 0 or sealed > 0 or failed_routes > 0 or wfc_contras > 0: 
			s += "\n[b]Builder Diagnostics[/b]\n"
			s += "  Custom Rooms Placed: %d\n" % c_rooms
			
			if rej_rooms > 0:
				s += "  [color=orange]Rejected Custom Rooms (Overlap): %d[/color]\n" % rej_rooms
				s += "    [color=gray][i]* Note: This causes Distribution Engine minimum caps to be missed. Try reducing room sizes or enabling a sparser graph layout.[/i][/color]\n"
			
			if sealed > 0:
				s += "  Unused Custom Doors Sealed: %d\n" % sealed
				
			if failed_routes > 0:
				s += "  [color=red]Failed Corridors (A* Blocked): %d[/color]\n" % failed_routes
				
			# --- RENDER THE CONTRADICTIONS ---
			if wfc_contras > 0:
				s += "  [color=orange]WFC Contradictions (Fallbacks Triggered): %d[/color]\n" % wfc_contras
				s += "    [color=gray][i]* Note: The pattern extractor encountered boundaries or gaps it didn't know how to resolve based on the sample image.[/i][/color]\n"
				
		s += "\n"
		
	var analytics = data.get("analytics", {})
	if not analytics.is_empty():
		s += "[b]Validation Analytics[/b]\n"
		var is_playable = analytics.get("is_playable", false)
		s += "  Playable (Exit Reached): %s\n" % ("[color=green]YES[/color]" if is_playable else "[color=red]NO[/color]")
		s += "  Walkable Area Reached: %.1f%% (%d / %d tiles)\n" % [analytics.get("coverage_percent", 0.0), analytics.get("reachable_walkable", 0), analytics.get("total_walkable", 0)]
		
		var missed_keys = analytics.get("keys_missed", [])
		if not missed_keys.is_empty(): s += "  [color=orange]Unreachable Keys:[/color] %s\n" % ", ".join(missed_keys)
		
		var stuck_doors = analytics.get("permanently_locked", [])
		if not stuck_doors.is_empty(): s += "  [color=orange]Permanently Locked Doors:[/color] %s\n" % ", ".join(stuck_doors)
		
		# Render the unreachable entity tallies
		var unreachable_ents = analytics.get("unreachable_entities", {})
		if not unreachable_ents.is_empty():
			var ent_strs = []
			for e_name in unreachable_ents:
				ent_strs.append("%dx %s" % [unreachable_ents[e_name], e_name])
			s += "  [color=orange]Unreachable Entities:[/color] %s\n" % ", ".join(ent_strs)
		else:
			s += "  [color=green]All entities are reachable.[/color]\n"
			
		s += "\n"

	# --- PROGRESSION LOGIC ---
	var prog = data.get("progression", data)
	var stats = prog.get("stats", {})
	var locks = prog.get("locks", [])
	var keys = prog.get("keys", [])
	
	var critical_locks = prog.get("critical_locks", [])
	var vault_locks = prog.get("vault_locks", [])
	
	# Render the Progression Settings Block
	var p_set = prog.get("settings", {})
	if not p_set.is_empty():
		s += "[b]Progression Settings[/b]\n"
		s += "  Lock Chance: %.2f\n" % p_set.get("lock_chance", 0.0)
		s += "  Max Critical Locks: %s\n" % (str(p_set.get("max_locks")) if p_set.get("max_locks", 0) > 0 else "Unlimited")
		s += "  Max Optional Vaults: %d\n" % p_set.get("max_vaults", 0)
		s += "  Key Style Ratio: %.2f [color=gray][i](0.0 = All Tiers, 1.0 = All Colors)[/i][/color]\n" % p_set.get("style_ratio", 0.0)
		s += "  Extra Shortcuts: %d - %d\n" % [p_set.get("shortcut_min", 0), p_set.get("shortcut_max", 0)]
		s += "  Sequence Break Limit: %d [color=gray][i](Maximum depth an optional shortcut can bypass)[/i][/color]\n" % p_set.get("seq_break_limit", 0)
		s += "  Force Main Detours: %s [color=gray][i](Forces critical keys to spawn in side-branches if available)[/i][/color]\n" % ("On" if p_set.get("main_path_stash", false) else "Off")
		s += "  Non-Terminal Vaults: %s [color=gray][i](Allows optional vaults to be placed on branching paths or loops)[/i][/color]\n\n" % ("Allowed" if p_set.get("non_terminal_vaults", false) else "Strict Leaves")
	
	# --- CACHE REGION MAPPINGS EARLY ---
	var regions = prog.get("regions", [])
	var region_by_id = {}
	for r in regions: region_by_id[r["id"]] = r
		
	# Helper lambdas to format arrays of region IDs
	var format_r_list = func(arr: Array) -> String:
		if arr.is_empty(): return "None"
		var str_arr = []
		for r in arr: str_arr.append(_format_region(r, region_by_id))
		return ", ".join(str_arr)

	# Detailed formatter that lists exactly what a region connects to
	var format_detailed_list = func(arr: Array) -> String:
		if arr.is_empty(): return "None"
		var str_arr = []
		for r in arr:
			var n_strs = []
			for neighbor in prog.get("region_adj", {}).get(r, []):
				n_strs.append(_format_region(neighbor, region_by_id))
			str_arr.append("%s (to: %s)" % [_format_region(r, region_by_id), ", ".join(n_strs)])
		return "\n      " + "\n      ".join(str_arr)
	
	# Calculate Placements manually from the keys array metadata
	var fallback_keys = []
	var shortcut_count = 0
	
	for k in keys:
		var pm = k.get("placement_method", "").to_lower()
		if pm.contains("shortcut"): 
			shortcut_count += 1
		elif pm.contains("emergency") or pm.contains("fallback"): 
			fallback_keys.append(k.get("lock_str", "Unknown"))
	
	var fallback_vaults = 0
	for l in locks:
		if l.get("vault_tag", "") == "Fallback (Non-Terminal)": fallback_vaults += 1
	
	# Dedicated Metrics Block
	s += "[b]Progression Metrics[/b]\n"
	s += "  Spawn Placement: %s\n" % stats.get("start_method", "Unknown")
	s += "  Exit Placement: %s\n" % stats.get("end_method", "Unknown")
	
	# Topography Breakdown
	var hubs = stats.get("hubs", [])
	var corridors = stats.get("corridors", [])
	var leaves = stats.get("leaves", [])
	
	s += "  Topography: %d Hubs | %d Corridors | %d Leaves\n" % [hubs.size(), corridors.size(), leaves.size()]
	s += "    [color=gray][i]Calculated from the main network. Hubs (3+ doors), Corridors (2 doors), Leaves (1 door).[/i][/color]\n"
	if not hubs.is_empty(): s += "    [color=#B2EBF2]Hubs:[/color] %s\n" % format_detailed_list.call(hubs)
	if not corridors.is_empty(): s += "    [color=#B2EBF2]Corridors:[/color] %s\n" % format_detailed_list.call(corridors)
	if not leaves.is_empty(): s += "    [color=#B2EBF2]Leaves:[/color] %s\n" % format_r_list.call(leaves)
	
	# --- MULTI-WAY DOORS (MEGA-PORTALS) ---
	var multi_doors = stats.get("multi_way_doors", [])
	if not multi_doors.is_empty():
		s += "  Multi-Way Doors (3+ Regions): %d\n" % multi_doors.size()
		s += "    [color=gray][i]Single physical doors that touch and connect three or more regions together.[/i][/color]\n"
		for md in multi_doors:
			var r_strs = []
			for r in md["regions"]: r_strs.append(_format_region(r, region_by_id))
			s += "    [color=#B2EBF2]Portal %d:[/color] connects %s\n" % [md.get("portal_id", -1), ", ".join(r_strs)]
	
	s += "  Door-Bounded Regions (Physical Rooms): %d\n" % stats.get("valid_region_count", 0)
	s += "    [color=gray][i]Physical spaces separated by doors. (Note: standard graph nodes of the same biome merge into a single physical Region if no doors separate them!).[/i][/color]\n"
	
	s += "  Progression Zones (Gated Areas): %d\n" % stats.get("area_count", 0)
	s += "    [color=gray][i]Clusters of regions grouped by lock requirements (e.g., Zone 0 is unlocked at start).[/i][/color]\n"
	
	s += "  Max Depth: %d\n" % stats.get("max_depth", 0)
	s += "    [color=gray][i]The maximum topological distance (measured in door transitions) from the spawn point.[/i][/color]\n"
	
	s += "  Critical Locks: %d\n" % critical_locks.size()
	s += "    [color=gray][i]Mandatory locks blocking the critical path to the exit.[/i][/color]\n"
	
	s += "  Optional Vaults: %d\n" % vault_locks.size()
	s += "    [color=gray][i]Locks leading to optional bonus areas.[/i][/color]\n"
	
	if fallback_vaults > 0:
		s += "  [color=orange]Fallback Vaults: %d[/color]\n" % fallback_vaults
		s += "    [color=gray][i]Forced non-terminal vaults due to a lack of available dead-ends.[/i][/color]\n"
		
	s += "  Shortcuts Placed: %d\n" % shortcut_count
	s += "    [color=gray][i]Optional keys that allow sequence breaking and skipping map areas.[/i][/color]\n"
	
	if fallback_keys.is_empty():
		s += "  Fallback Placements: None\n"
	else:
		s += "  [color=orange]Fallback Placements: %s[/color]\n" % ", ".join(fallback_keys)
		s += "    [color=gray][i]Keys placed using emergency logic due to severe space constraints.[/i][/color]\n"
		
	# Pacing Metrics
	var avg_backtrack = stats.get("avg_backtrack", 0.0)
	if avg_backtrack >= 0.0 and critical_locks.size() > 0:
		s += "  Avg Key-to-Door Distance: %.1f regions\n" % avg_backtrack
		s += "    [color=gray][i]The average amount of backtracking (in door transitions) required to bring a key to its door.[/i][/color]\n"
		
	# [UPGRADED] Empty Areas update
	var empty_regs = stats.get("empty_regions", [])
	s += "  Empty Areas (No Objectives): %d\n" % empty_regs.size()
	s += "    [color=gray][i]Physical areas that contain no keys, locks, vaults, start points, or exit points.[/i][/color]\n"
	if not empty_regs.is_empty():
		s += "    [color=#B2EBF2]Empty:[/color] %s\n" % format_r_list.call(empty_regs)
	
	var avg_detour = stats.get("avg_detour_length", 0.0)
	if avg_detour > 0.0:
		s += "  Avg Detour Length: %.1f regions\n" % avg_detour
	s += "\n"

	s += "[b]Critical Path[/b]\n"
	var spine_path = prog.get("spine_path", [])

	if spine_path.is_empty():
		s += "  No path from start to end found.\n"
	else:
		for i in range(spine_path.size()):
			var r_id = spine_path[i]
			var r = region_by_id.get(r_id, {})
			var depth = r.get("depth", -1)
			s += "  [color=#4CAF50]%s[/color] Depth %d" % [_format_region(r_id, region_by_id), depth]
			if i < spine_path.size() - 1: s += "\n    ↓\n"

	s += "\n\n[b]Locks & Keys Map[/b]\n"
	if locks.is_empty():
		s += "  No locked doors.\n"
	else:
		for l in locks:
			var lock_str = l.get("lock_str", "")
			var src = l.get("source_region", -1)
			var dst = l.get("dest_region", -1)
			
			# --- [FIXED] INSTANCE CHECK ---
			# We now check the specific door's metadata, completely ignoring the lock's name
			var v_tag = l.get("vault_tag", "")
			var is_vault = (v_tag != "") 
			
			var style_tag = "[color=cyan][Crit][/color]"
			
			if is_vault:
				if v_tag == "Fallback (Non-Terminal)":
					style_tag = "[color=yellow][Vault (Fallback)][/color]"
				elif v_tag == "Non-Terminal Branch":
					style_tag = "[color=magenta][Vault (Branch)][/color]"
				else:
					style_tag = "[color=magenta][Vault][/color]"
			
			var key_regions = _find_key_regions_for_lock(prog, lock_str)
			s += "  %s [color=#F44336]%s[/color]: %s → %s" % [style_tag, lock_str, _format_region(src, region_by_id), _format_region(dst, region_by_id)]
			
			if not key_regions.is_empty():
				var key_strs = []
				for x in key_regions: key_strs.append(_format_region(x, region_by_id))
				s += " (Key in: " + ", ".join(key_strs) + ")"
			s += "\n"

	return s

func _format_region(region_id, region_by_id: Dictionary) -> String:
	if not region_by_id.has(region_id): return "Region %d" % region_id
	var r = region_by_id[region_id]
	var biomes = r.get("biome_keys", [])
	if biomes.is_empty(): return "Region %d" % region_id
	if biomes.size() == 1: return "%s:%d" % [biomes[0], region_id]
	var parts = []
	for b in biomes: parts.append(str(b))
	return "%s:%d" % ["/".join(parts), region_id]

func _find_key_regions_for_lock(data: Dictionary, lock_str: String) -> Array:
	var result: Array = []
	for k in data.get("keys", []):
		if k.get("lock_str", "") == lock_str: result.append(k.get("region", -1))
	return result
