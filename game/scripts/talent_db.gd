extends Node
## Loads the talent roster from data/talents.json. Talents are data, not code:
## each entry names a set of effect hooks that gameplay systems query.

const ROSTER_PATH := "res://data/talents.json"

var talents: Dictionary = {}


func _ready() -> void:
	_load_roster()


func _load_roster() -> void:
	var file := FileAccess.open(ROSTER_PATH, FileAccess.READ)
	if file == null:
		push_error("TalentDB: cannot open %s" % ROSTER_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("talents"):
		push_error("TalentDB: malformed roster")
		return
	for entry: Dictionary in parsed["talents"]:
		talents[entry["id"]] = entry
	print("TalentDB: loaded %d talents" % talents.size())


func get_talent(id: String) -> Dictionary:
	return talents.get(id, {})


func ids_by_category(category: String) -> Array:
	var out: Array = []
	for id: String in talents:
		if talents[id].get("category", "") == category:
			out.append(id)
	return out
