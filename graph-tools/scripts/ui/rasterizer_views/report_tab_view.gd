class_name ReportTabView
extends MarginContainer

var _report_text: RichTextLabel

func _init() -> void:
	name = "Report"
	add_theme_constant_override("margin_top", 10)
	add_theme_constant_override("margin_left", 10)
	add_theme_constant_override("margin_right", 10)
	add_theme_constant_override("margin_bottom", 10)

	var scroll = ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

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

func set_loading() -> void:
	_report_text.text = "[color=gray]Generating...[/color]"

func update_report(data: Dictionary) -> void:
	if data.is_empty():
		_report_text.text = "[color=gray]Progression solver was disabled or failed to find regions.[/color]"
		return
	_report_text.text = _format_report(data)

# ==============================================================================
# FORMATTING ENGINE
# ==============================================================================
func _format_report(data: Dictionary) -> String:
	var s = "[b]Critical Path[/b]\n"
	var spine_path = data.get("spine_path", [])
	var regions = data.get("regions", [])

	var region_by_id = {}
	for r in regions: region_by_id[r["id"]] = r

	if spine_path.is_empty():
		s += "  No path from start to end found.\n"
	else:
		for i in range(spine_path.size()):
			var r_id = spine_path[i]
			var r = region_by_id.get(r_id, {})
			var depth = r.get("depth", -1)
			s += "  [color=#4CAF50]%s[/color] Depth %d" % [_format_region(r_id, region_by_id), depth]
			if i < spine_path.size() - 1: s += "\n    ↓\n"

	s += "\n\n[b]Locks[/b]\n"
	var locks = data.get("locks", [])
	if locks.is_empty():
		s += "  No locked doors.\n"
	else:
		for l in locks:
			var lock_str = l.get("lock_str", "")
			var src = l.get("source_region", -1)
			var dst = l.get("dest_region", -1)
			var key_regions = _find_key_regions_for_lock(data, lock_str)
			s += "  [color=#F44336]%s[/color]: %s → %s" % [lock_str, _format_region(src, region_by_id), _format_region(dst, region_by_id)]
			if not key_regions.is_empty():
				var key_strs = []
				for x in key_regions: key_strs.append(_format_region(x, region_by_id))
				s += " (Key in: " + ", ".join(key_strs) + ")"
			s += "\n"

	s += "\n[b]Keys[/b]\n"
	var keys = data.get("keys", [])
	if keys.is_empty():
		s += "  No keys.\n"
	else:
		for k in keys:
			s += "  [color=#FFC107]%s[/color]: %s (%s)\n" % [k.get("lock_str", ""), _format_region(k.get("region", -1), region_by_id), k.get("placement_method", "unknown")]

	s += "\n[b]Stats[/b]\n"
	var stats = data.get("stats", {})
	s += "  Regions: %d\n" % stats.get("region_count", 0)
	s += "  Locks: %d\n" % stats.get("lock_count", 0)
	s += "  Keys: %d\n" % stats.get("key_count", 0)
	s += "  Max Depth: %d\n" % stats.get("max_depth", 0)
	s += "  Areas: %d\n" % stats.get("area_count", 0)
	s += "  Spine Length: %d\n" % stats.get("spine_length", 0)

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
