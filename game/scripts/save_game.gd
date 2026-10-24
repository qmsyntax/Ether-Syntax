class_name SaveGame
extends RefCounted
## Character saves. Slot 0 is the autosave (user://save.json): written whenever something changes
## in town, deleted when a hardcore character dies. Slots 1..SLOTS are written only on request.
## Plain JSON on purpose - this is a prototype, not tamper-proofing.

const PATH := "user://save.json"
const VERSION := 1
const SLOTS := 5

## Set by a click test so its saves go to a folder of their own, never over the real ones
## ("" = the real files). Ends with a slash, e.g. "user://probe_saves/".
static var test_dir := ""


static func slot_path(slot: int) -> String:
	if test_dir != "":
		DirAccess.make_dir_recursive_absolute(test_dir)
		return test_dir + ("save.json" if slot <= 0 else "save_slot_%d.json" % slot)
	return PATH if slot <= 0 else "user://save_slot_%d.json" % slot


## "Name, Talent" for a save (older saves have no name).
static func who(data: Dictionary) -> String:
	var talent: String = str(TalentDB.get_talent(str(data.get("talent_id", ""))).get("name", "?"))
	var char_name: String = str(data.get("name", ""))
	return talent if char_name == "" else "%s, %s" % [char_name, talent]


## One line for a save list: who, how far along, how rich. "empty" for {}.
static func describe(data: Dictionary) -> String:
	if data.is_empty() or str(data.get("talent_id", "")) == "":
		return "empty"
	var pcts: Array = data.get("star_pct", [])
	var newest: int = int(float(pcts[pcts.size() - 1])) if not pcts.is_empty() else 0
	return "%s   -   day %d   -   star %d at %d%%   -   %s%s" % [
		who(data), int(data.get("day", 1)),
		int(data.get("stars", 1)), newest, UiTheme.money_text(int(data.get("money", 0))),
		"   -   hardcore" if bool(data.get("hardcore", false)) else ""]


static func exists(path: String = "") -> bool:
	return FileAccess.file_exists(slot_path(0) if path == "" else path)


static func write(data: Dictionary, path: String = "") -> bool:
	if path == "":
		path = slot_path(0)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	data["version"] = VERSION
	file.store_string(JSON.stringify(data, "  "))
	return true


## Returns {} if there is no save, it cannot be parsed, or it is from another version.
static func read(path: String = "") -> Dictionary:
	if path == "":
		path = slot_path(0)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or int((parsed as Dictionary).get("version", 0)) != VERSION:
		return {}
	return parsed


static func delete(path: String = "") -> void:
	if path == "":
		path = slot_path(0)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
