class_name InspectorZone
extends InspectorStrategy

# State
var _tracked_zones: Array = []
var _zone_inputs: Dictionary = {}

func can_handle(_nodes, _edges, _agents, zones: Array) -> bool:
	return not zones.is_empty()

func enter(_nodes, _edges, _agents, zones: Array) -> void:
	super.enter(_nodes, _edges, _agents, zones)
	_tracked_zones = zones
	_build_ui()

func update(_nodes, _edges, _agents, zones: Array) -> void:
	_tracked_zones = zones
	_build_ui()

func exit() -> void:
	super.exit()
	_tracked_zones.clear()

# --- VIEW LOGIC ---

func _build_ui() -> void:
	if _tracked_zones.is_empty(): return
	var zone = _tracked_zones[0] as GraphZone
	
	# 1. PREPARE ROSTER DATA
	var roster_count = zone.registered_nodes.size()
	var roster_text = "(Empty)"
	if roster_count > 0:
		var sorted_nodes = zone.registered_nodes.duplicate()
		sorted_nodes.sort()
		roster_text = "\n".join(sorted_nodes)

	# 2. DEFINE SCHEMA
	var schema = [
		{ "name": "head", "label": "Zone Inspector", "type": TYPE_STRING, "default": "Properties", "hint": "read_only" },
		{ "name": "zone_name", "label": "Name", "type": TYPE_STRING, "default": zone.zone_name },
		{ "name": "zone_type", "label": "Type", "type": TYPE_INT, "default": zone.zone_type, "hint": "enum", "hint_string": "Geographical,Logical,RigidGroup" },
		{ "name": "zone_color", "label": "Color", "type": TYPE_COLOR, "default": zone.zone_color },
		{ "name": "stat_count", "label": "Node Count", "type": TYPE_STRING, "default": str(roster_count), "hint": "read_only" },
		{ "name": "sep_rules", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "allow_new_nodes", "label": "Allow New Nodes", "type": TYPE_BOOL, "default": zone.allow_new_nodes },
		{ "name": "is_traversable", "label": "Agent Traversable", "type": TYPE_BOOL, "default": zone.is_traversable },
		{ "name": "traversal_cost", "label": "Traversal Cost", "type": TYPE_FLOAT, "default": zone.traversal_cost, "step": 0.1, "min": 0.1 },
		{ "name": "damage_per_tick", "label": "Damage / Tick", "type": TYPE_FLOAT, "default": zone.damage_per_tick, "step": 1.0 }
	]
	
	# 3. DYNAMIC PROPERTIES
	var registered_props = GraphSettings.get_properties_for_target("ZONE")
	if not registered_props.is_empty():
		schema.append({ "name": "sep_custom", "type": TYPE_NIL, "hint": "separator" })
		
	for key in registered_props:
		var def = registered_props[key]
		var val = def.default
		if "custom_data" in zone: val = zone.custom_data.get(key, def.default)
		schema.append({ "name": key, "label": key.capitalize(), "type": def.type, "default": val })

	schema.append({ "name": "action_add_property", "label": "Add Custom Data...", "type": TYPE_NIL, "hint": "button" })
	
	# 4. RENDER MAIN SECTION
	# Note: InspectorZone needs manual appending, so we render to the container but allow appending
	SettingsUIBuilder.clear_ui(container) 
	_zone_inputs = SettingsUIBuilder.render_dynamic_section(container, schema, _on_input)
	
	# 5. APPEND MANUAL ROSTER TOGGLE
	_add_roster_ui(container, roster_count, roster_text)

func _add_roster_ui(parent: Control, count: int, text_content: String) -> void:
	if count == 0: return

	parent.add_child(HSeparator.new())

	var btn = Button.new()
	btn.text = "Show Roster (%d Nodes)" % count
	btn.toggle_mode = true
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	parent.add_child(btn)
	
	var content = TextEdit.new()
	content.text = text_content
	content.editable = false
	content.custom_minimum_size.y = 120
	content.visible = false
	content.add_theme_color_override("font_readonly_color", Color(0.8, 0.8, 0.8))
	parent.add_child(content)
	
	btn.toggled.connect(func(is_pressed):
		content.visible = is_pressed
		btn.text = ("Hide Roster" if is_pressed else "Show Roster (%d Nodes)" % count)
	)

# --- INPUT HANDLER ---

func _on_input(key: String, value: Variant) -> void:
	if _tracked_zones.is_empty(): return
	var zone = _tracked_zones[0] as GraphZone
	
	if key == "action_add_property":
		request_wizard.emit("ZONE")
		return

	# Core Properties
	if key in ["zone_name", "zone_color", "allow_new_nodes", "is_traversable", "traversal_cost", "damage_per_tick", "zone_type"]:
		zone.set(key, value)
		
		if key == "zone_color":
			graph_editor.renderer.queue_redraw()
			graph_editor.mark_modified()
		elif key == "zone_name":
			graph_editor.mark_modified()
			
	# Dynamic Properties
	else:
		zone.custom_data[key] = value
		graph_editor.mark_modified()
