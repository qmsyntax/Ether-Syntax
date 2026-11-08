class_name SaveGame
extends RefCounted
## Character saves. Slot 0 is the autosave (user://save.json): written whenever something changes
## in town (and every so often in the field); slots 1..SLOTS are written only on request.
## Plain JSON on purpose - this is a prototype, not tamper-proofing.
##
## Safety (Phase 0, 2026-11-08):
## - every write goes through `UserFiles.write_text` (a new copy, then the old one kept as
##   `.bak`, then a rename), and every read takes the newest good copy (`UserFiles.read_text`);
## - each save carries `schema` (SCHEMA) and is brought up to date on load by the migrations
##   below, one step at a time; a save from a NEWER schema is refused, shown as such and never
##   written over;
## - each save carries `char_id` (one per character) and `build` (the game version that wrote it);
## - a hardcore death removes every copy of that character (`clear_character`);
## - when the autosave is about to be written over by a different character, the one it held is
##   kept first (`_keep_displaced`): in the first empty numbered slot, else in user://displaced/.

const PATH := "user://save.json"
const SLOTS := 5
## The save format. Raise it by one, and add the step to `_migrate_step`, whenever a change would
## make an older save load wrongly. 1: the format as it stood on 2026-11-08 (it was "version": 1).
## 2: `char_id` and `build` added, `schema` replaces `version` as the format number.
const SCHEMA := 2
## Still written, for builds from before `schema`: they load a save only if "version" is 1, and
## schema 2 is a schema-1 save plus two keys they ignore. Raise it with any change they would misread.
const LEGACY_VERSION := 1
const DISPLACED_DIR_REAL := "user://displaced/"

## Set by a test so its saves go to a folder of their own, never over the real ones
## ("" = the real files). Ends with a slash, e.g. "user://probe_saves/". UserFiles.sandbox sets it.
static var test_dir := ""
## One line about the last read that had to recover, refuse or move something ("" = nothing to say),
## for the title and the HUD. Cleared by `take_note`.
static var last_note := ""


static func slot_path(slot: int) -> String:
	if test_dir != "":
		DirAccess.make_dir_recursive_absolute(test_dir)
		return test_dir + ("save.json" if slot <= 0 else "save_slot_%d.json" % slot)
	return PATH if slot <= 0 else "user://save_slot_%d.json" % slot


static func displaced_dir() -> String:
	return (test_dir + "displaced/") if test_dir != "" else DISPLACED_DIR_REAL


## The build (application/config/version) this game is; "" when it is not set.
static func build() -> String:
	return str(ProjectSettings.get_setting("application/config/version", ""))


## A new character's id: unique enough to tell two characters' saves apart.
static func new_char_id() -> String:
	return "%d-%08x%08x" % [int(Time.get_unix_time_from_system()), randi(), randi()]


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


## What is in a slot, for lists: describe() for a usable save, the reason for one that is not.
static func describe_slot(path: String) -> String:
	var got: Dictionary = inspect(path)
	match str(got["state"]):
		"newer":
			return "made by a newer build (save format %d, this build reads up to %d) - not loaded, never written over" % [int(got["schema"]), SCHEMA]
		"broken":
			return "damaged and no good copy left - %s" % str(got["note"])
	return describe(got["data"])


static func exists(path: String = "") -> bool:
	return UserFiles.any_exists(slot_path(0) if path == "" else path)


## The format number of a save's data (0 for one from before "version").
static func schema_of(data: Dictionary) -> int:
	if data.has("schema"):
		return int(data["schema"])
	return int(data.get("version", 0))


## Everything known about a slot file. {"state": "ok" | "recovered" (read from a backup copy) |
## "newer" (a later schema: refused) | "empty" (nothing there) | "broken" (there, but no copy
## is readable), "data" (migrated to SCHEMA; {} unless ok / recovered), "schema" (as found),
## "from" (the copy read), "note" (one line, "" when all was well)}.
static func inspect(path: String = "") -> Dictionary:
	if path == "":
		path = slot_path(0)
	var got: Dictionary = UserFiles.read_text(path, UserFiles.json_ok)
	var out: Dictionary = {"state": "empty", "data": {}, "schema": 0, "from": str(got["from"]), "note": str(got["note"])}
	if str(got["from"]) == "":
		if str(got["note"]) != "":
			out["state"] = "broken"
		return out
	var data: Dictionary = UserFiles.parse_json(str(got["text"]))
	var schema: int = schema_of(data)
	out["schema"] = schema
	if schema > SCHEMA:
		out["state"] = "newer"
		out["note"] = "%s was saved by a newer build (format %d; this build reads up to %d). It was not loaded and will not be written over." % [
			path.get_file(), schema, SCHEMA]
		push_warning("SaveGame: " + str(out["note"]))
		return out
	out["data"] = migrate(data)
	out["state"] = "ok" if str(got["from"]) == path else "recovered"
	return out


## The save's data brought up to SCHEMA, or {} if there is no usable save (missing, damaged with no
## good copy, or from a newer schema). Says in the log and in `last_note` when it had to recover.
static func read(path: String = "") -> Dictionary:
	var got: Dictionary = inspect(path)
	if str(got["note"]) != "":
		last_note = str(got["note"])
	if str(got["state"]) == "ok" or str(got["state"]) == "recovered":
		return got["data"]
	return {}


## The note left by the last read or write, once (the HUD / title show it).
static func take_note() -> String:
	var n: String = last_note
	last_note = ""
	return n


## Write a character. Refuses (false) to write over a save from a newer schema. The autosave keeps
## the character it held when another is written over it (`_keep_displaced`).
static func write(data: Dictionary, path: String = "") -> bool:
	if path == "":
		path = slot_path(0)
	var there: Dictionary = inspect(path)
	if str(there["state"]) == "newer":
		last_note = str(there["note"])
		return false
	if path == slot_path(0) and (str(there["state"]) == "ok" or str(there["state"]) == "recovered"):
		_keep_displaced(there["data"], str(data.get("char_id", "")))
	var out: Dictionary = data.duplicate()
	out.erase("version")
	out["schema"] = SCHEMA
	out["version"] = LEGACY_VERSION
	out["build"] = build()
	out["saved_at"] = Time.get_datetime_string_from_system(true)
	return UserFiles.write_text(path, JSON.stringify(out, "  "), UserFiles.json_ok)


## Remove a save and every copy of it.
static func delete(path: String = "") -> void:
	if path == "":
		path = slot_path(0)
	UserFiles.remove(path)


## Hardcore is permadeath: remove every save of this character - the autosave, every numbered
## slot, every backup copy and any displaced copy - so no fallback can bring it back. A slot whose
## main file is this character goes whole (its older copies were the slot's past, overwritten by
## choice); elsewhere only the copies that are this character go. Never touches a save from a
## newer schema. Returns how many files were removed.
static func clear_character(char_id: String) -> int:
	if char_id == "":
		return 0
	var removed := 0
	var files: Array[String] = []
	for slot: int in SLOTS + 1:
		var path: String = slot_path(slot)
		var main_data: Dictionary = _file_data(path)
		if _id_of(main_data) == char_id:
			for cand: String in UserFiles.copies(path):
				if FileAccess.file_exists(cand):
					removed += 1
			UserFiles.remove(path)
			continue
		for cand: String in UserFiles.copies(path):
			files.append(cand)
	for name: String in UserFiles._files_in(displaced_dir()):
		files.append(displaced_dir() + name)
	for cand: String in files:
		if FileAccess.file_exists(cand) and _id_of(_file_data(cand)) == char_id:
			UserFiles.remove_one(cand)
			removed += 1
	return removed


# --- migrations: one function per step, schema n -> n + 1 -----------------------------------------

## Bring `data` up to SCHEMA one step at a time. A save already at SCHEMA comes back as it was.
static func migrate(data: Dictionary) -> Dictionary:
	var d: Dictionary = data.duplicate(true)
	var at: int = schema_of(d)
	while at < SCHEMA:
		d = _migrate_step(at, d)
		at += 1
		d["schema"] = at
	return d


static func _migrate_step(from: int, d: Dictionary) -> Dictionary:
	match from:
		0:
			return _to_1(d)
		1:
			return _to_2(d)
	push_error("SaveGame: no migration from schema %d" % from)
	return d


## 0 -> 1: a save from before "version" was written. Its keys are the same; nothing to change.
static func _to_1(d: Dictionary) -> Dictionary:
	return d


## 1 -> 2: `char_id` and `build`. A character saved before ids is given one made from who it is
## (name, prime, identity, affinities), so every copy of it - the autosave and any slot - gets the
## same id and a hardcore death still finds them all.
static func _to_2(d: Dictionary) -> Dictionary:
	d.erase("version")
	if str(d.get("char_id", "")) == "":
		d["char_id"] = legacy_id(d)
	if not d.has("build"):
		d["build"] = ""
	return d


static func legacy_id(d: Dictionary) -> String:
	var who_key: String = "|".join([str(d.get("name", "")), str(d.get("talent_id", "")), str(d.get("identity", "")),
		",".join((d.get("affinities", []) as Array).map(func(a: Variant) -> String: return str(a))),
		str(d.get("test_character", false))])
	return "legacy-" + who_key.md5_text().left(16)


# --- helpers -------------------------------------------------------------------------------------

## One copy's data as written, migrated far enough to carry an id ({} if unreadable).
static func _file_data(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var d: Dictionary = UserFiles.parse_json(FileAccess.get_file_as_string(path))
	if d.is_empty() or schema_of(d) > SCHEMA:
		return {}                       # a newer build's save is never matched, so never removed
	return migrate(d)


static func _id_of(d: Dictionary) -> String:
	return str(d.get("char_id", ""))


## The autosave holds `old`, and a character with id `new_id` is about to be written over it. If
## that is another character, keep it: in the first empty numbered slot, else in displaced/<id>.json
## (written over by that character's next displacement only). Says where in `last_note`.
static func _keep_displaced(old: Dictionary, new_id: String) -> void:
	var old_id: String = _id_of(old)
	if old.is_empty() or str(old.get("talent_id", "")) == "" or old_id == "" or old_id == new_id or bool(old.get("test_character", false)):
		return
	var text: String = JSON.stringify(old, "  ")
	for slot: int in range(1, SLOTS + 1):
		var p: String = slot_path(slot)
		if not UserFiles.any_exists(p):
			if UserFiles.write_text(p, text, UserFiles.json_ok):
				last_note = "The autosave held %s; it was kept in slot %d." % [who(old), slot]
				print("SaveGame: " + last_note)
				return
	var keep: String = displaced_dir() + old_id.validate_filename() + ".json"
	if UserFiles.write_text(keep, text, UserFiles.json_ok):
		last_note = "The autosave held %s; every slot was full, so it was kept in %s." % [who(old), ProjectSettings.globalize_path(keep)]
		print("SaveGame: " + last_note)
