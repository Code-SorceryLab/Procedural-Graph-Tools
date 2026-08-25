@tool
class_name DocumentationTools
extends Node



static func get_all_gd_files(base_path: String = "res://", skip_addons: bool = true) -> Array[String]:
	var result: Array[String] = []
	_scan_directory(base_path, skip_addons, result)
	result.sort()
	return result

static func _scan_directory(dir_path: String, skip_addons: bool, output: Array[String]) -> void:
	var dir = DirAccess.open(dir_path)
	if dir == null:
		push_warning("GraphSettings: Cannot open directory: " + dir_path)
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue

		var full_path = dir_path.path_join(file_name)

		if dir.current_is_dir():
			# Skip .godot and optionally addons
			if file_name == ".godot":
				file_name = dir.get_next()
				continue
			if skip_addons and file_name == "addons":
				file_name = dir.get_next()
				continue
			_scan_directory(full_path, skip_addons, output)
		else:
			if file_name.get_extension() == "gd":
				output.append(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()
