class_name ExperimentBuilder
extends RefCounted

# ==============================================================================
# 1. THE MATH: CARTESIAN PRODUCT GENERATOR
# ==============================================================================
# Takes a Sweep Definition and calculates every possible combination of parameters.
# sweep_def example: 
# {
#    "width": { "mode": "sweep", "type": TYPE_INT, "min": 10, "max": 20, "step": 5 },
#    "iterations": { "mode": "fixed", "value": 4 },
#    "use_zones": { "mode": "fixed", "value": true }
# }
static func generate_combinations(sweep_def: Dictionary) -> Array[Dictionary]:
	var keys = sweep_def.keys()
	var values_per_key = []
	
	for key in keys:
		var config = sweep_def[key]
		var possible_values = []
		
		if config.get("mode", "fixed") == "fixed":
			possible_values.append(config.get("value"))
			
		# Handle Enum Checklists
			if config.get("is_enum", false):
				var selections = config.get("enum_selection", [])
				if selections.is_empty():
					possible_values.append(config.get("value")) # Fallback
				else:
					possible_values.append_array(selections)
			else:
				var cur = float(config.get("min", 0.0))
				var end = float(config.get("max", 1.0))
				var step = float(config.get("step", 1.0))
			
				# Safety check to prevent infinite while-loops
				if step <= 0.0001: step = 1.0
			
				var is_int = config.get("type") == TYPE_INT
			
				while cur <= end + 0.00001: # Tiny epsilon for float precision
					possible_values.append(int(cur) if is_int else cur)
					cur += step
				
		values_per_key.append(possible_values)
		
	var results: Array[Dictionary] = []
	_cartesian_recurse(keys, values_per_key, 0, {}, results)
	
	# --- DIAGNOSTIC PRINT ---
	print("ExperimentBuilder: Generated %d unique configurations." % results.size())
	# ------------------------
	return results

static func _cartesian_recurse(keys: Array, values_per_key: Array, depth: int, current_dict: Dictionary, results: Array) -> void:
	# Base Case: We've picked a value for every parameter
	if depth == keys.size():
		results.append(current_dict.duplicate(true))
		return
		
	# Recursive Step: Iterate through all possibilities for the current parameter
	for val in values_per_key[depth]:
		current_dict[keys[depth]] = val
		_cartesian_recurse(keys, values_per_key, depth + 1, current_dict, results)

# ==============================================================================
# 2. SCHEMA EXTRACTION
# ==============================================================================
# Extracts the baseline settings from any strategy and pre-formats them for a Sweep UI
static func get_sweep_schema(strategy_script: Script) -> Dictionary:
	var sweep_schema = {}
	var dummy: GraphStrategy = strategy_script.new()
	var raw_settings = dummy.get_settings()
	
	for s in raw_settings:
		var s_name = s.get("name", "")
		if s_name == "" or s_name.begins_with("sep_"): continue
		
		var s_type = s.get("type")
		var is_enum = (s.get("hint", "") == "enum") # [NEW] Detect dropdowns
		
		if is_enum:
			# [NEW] Pre-format the Enum for the checklist UI
			sweep_schema[s_name] = {
				"label": s.get("label", s_name.capitalize()),
				"type": s_type,
				"is_enum": true,
				"options": s.get("hint_string", "").split(","),
				"mode": "fixed",
				"value": s.get("default", 0)
			}
		elif s_type == TYPE_INT or s_type == TYPE_FLOAT:
			# (Keep your existing int/float dictionary logic here)
			sweep_schema[s_name] = {
				"label": s.get("label", s_name.capitalize()),
				"type": s_type,
				"is_enum": false,
				"mode": "fixed",
				"value": s.get("default", 0),
				"min": s.get("min", 0),
				"max": s.get("max", 100),
				"step": 1 if s_type == TYPE_INT else 0.1
			}
		else:
			sweep_schema[s_name] = {
				"label": s.get("label", s_name.capitalize()),
				"type": s_type,
				"is_enum": false,
				"mode": "fixed",
				"value": s.get("default", null)
			}
			
	return sweep_schema
