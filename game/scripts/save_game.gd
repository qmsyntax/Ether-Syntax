class_name SaveGame
extends RefCounted
## One character save in user://save.json. Written whenever you are back in town; deleted when a
## hardcore character dies. Plain JSON on purpose - this is a prototype, not tamper-proofing.

const PATH := "user://save.json"
const VERSION := 1


static func exists(path: String = PATH) -> bool:
	return FileAccess.file_exists(path)


static func write(data: Dictionary, path: String = PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	data["version"] = VERSION
	file.store_string(JSON.stringify(data, "  "))
	return true


## Returns {} if there is no save, it cannot be parsed, or it is from another version.
static func read(path: String = PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or int((parsed as Dictionary).get("version", 0)) != VERSION:
		return {}
	return parsed


static func delete(path: String = PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
