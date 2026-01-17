class_name InspectorZone
extends InspectorStrategy

# --- STATE ---
var _tracked_zones: Array = []
var _zone_inputs: Dictionary = {}

# ==============================================================================
# 1. LIFECYCLE
# ==============================================================================

func can_handle(_nodes, _edges, _agents, zones: Array) -> bool:
	return not zones.is_empty()

func enter(_nodes, _edges, _agents, zones: Array) -> void:
	super.enter(_nodes, _edges, _agents, zones)
	_tracked_zones = zones
	_rebuild_zone_ui()

func update(_nodes, _edges, _agents, zones: Array) -> void:
	_tracked_zones = zones
	_rebuild_zone_ui()

func exit() -> void:
	super.exit()
	_tracked_zones.clear()
	_zone_inputs.clear()

# ==============================================================================
# 2. UI CONSTRUCTION
# ==============================================================================

func _rebuild_zone_ui() -> void:
	if _tracked_zones.is_empty(): return
	var zone = _tracked_zones[0] as GraphZone
	
	# --- SECTION 1: PROPERTIES ---
	var schema = [
		{ "name": "zone_name", "label": "Name", "type": TYPE_STRING, "default": zone.zone_name },
		{ "name": "zone_type", "label": "Type", "type": TYPE_INT, "default": zone.zone_type, "hint": "enum", "hint_string": "Geographical,Logical,RigidGroup" },
		{ "name": "zone_color", "label": "Color", "type": TYPE_COLOR, "default": zone.zone_color },
		
		{ "name": "sep_rules", "type": TYPE_NIL, "hint": "separator" },
		{ "name": "allow_new_nodes", "label": "Allow New Nodes", "type": TYPE_BOOL, "default": zone.allow_new_nodes },
		{ "name": "is_traversable", "label": "Agent Traversable", "type": TYPE_BOOL, "default": zone.is_traversable },
		{ "name": "traversal_cost", "label": "Traversal Cost", "type": TYPE_FLOAT, "default": zone.traversal_cost, "step": 0.1, "min": 0.1 },
		{ "name": "damage_per_tick", "label": "Damage / Tick", "type": TYPE_FLOAT, "default": zone.damage_per_tick, "step": 1.0 }
	]
	
	# Dynamic Properties
	var registered_props = GraphSettings.get_properties_for_target("ZONE")
	if not registered_props.is_empty():
		schema.append({ "name": "sep_custom", "type": TYPE_NIL, "hint": "separator" })
		
	for key in registered_props:
		var def = registered_props[key]
		var val = def.default
		if "custom_data" in zone: val = zone.custom_data.get(key, def.default)
		schema.append({ "name": key, "label": key.capitalize(), "type": def.type, "default": val })

	schema.append({ "name": "action_add_property", "label": "Add Custom Data...", "type": TYPE_NIL, "hint": "button" })
	
	# Render Main Section
	var prop_section = _create_section("Zone Properties")
	_zone_inputs = SettingsUIBuilder.render_dynamic_section(prop_section, schema, _on_input)
	
	# --- SECTION 2: ROSTER ---
	var roster_count = zone.registered_nodes.size()
	if roster_count > 0:
		var roster_section = SettingsUIBuilder.create_collapsible_section(container, "Node Roster (%d)" % roster_count, false)
		
		var content = TextEdit.new()
		var sorted_nodes = zone.registered_nodes.duplicate()
		sorted_nodes.sort()
		content.text = "\n".join(sorted_nodes)
		content.editable = false
		content.custom_minimum_size.y = 120
		content.add_theme_color_override("font_readonly_color", Color(0.8, 0.8, 0.8))
		
		# Add directly to the roster section container
		roster_section.add_child(content)

# ==============================================================================
# 3. INPUT HANDLER
# ==============================================================================

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
