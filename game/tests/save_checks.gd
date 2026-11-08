extends RefCounted
## The self-test's checks that a character survives (Phase 0, 2026-11-08): atomic writes and the
## fallback to a backup copy (a kill after the new copy is written, after the old one became the
## backup; a truncated, garbage or empty file; a file held open), the save schema and its
## migrations (an old save loads, a newer one is refused and left alone), the character id, the
## displaced autosave, hardcore death removing every copy of that character (by hand and through
## main.gd), and the key bindings and settings files recovering the same way. Everything runs in
## the self-test's sandbox (UserFiles.sandbox); selftest.gd checks the player's own files are
## byte-identical afterwards. Called from selftest.gd (`-- --only=saves` runs just this).

var t: Node                 # the self-test node
var check: Callable         # its _check(label, ok, detail)
var _base: Dictionary = {}  # a real character's save, the template for the fixtures


func _init(test: Node, check_fn: Callable) -> void:
	t = test
	check = check_fn


func run() -> void:
	print("saves are safe (atomic writes, backups, schema, hardcore; 2026-11-08):")
	var p: Node = t.call("_new_player", str(TalentDB.talents.keys()[0]))
	p.set("char_name", "Fixture")
	_base = p.call("to_save")
	p.queue_free()
	check.call("the self-test is sandboxed: saves, key bindings and settings point at its own folder",
		UserFiles.sandbox_dir != "" and SaveGame.slot_path(0).begins_with(UserFiles.sandbox_dir)
		and Keybinds.path.begins_with(UserFiles.sandbox_dir) and GameSettings.path.begins_with(UserFiles.sandbox_dir),
		"%s %s %s" % [SaveGame.slot_path(0), Keybinds.path, GameSettings.path])
	_clear_all()
	_atomic_writes()
	_clear_all()
	_kills_and_damage()
	_clear_all()
	_schema()
	_clear_all()
	_displaced()
	_clear_all()
	_hardcore_by_hand()
	_clear_all()
	await _hardcore_through_main()
	_clear_all()
	_config_files()
	_clear_all()


# --- fixtures ------------------------------------------------------------------------------------

func _char(char_name: String, id: String, extra: Dictionary = {}) -> Dictionary:
	var d: Dictionary = _base.duplicate(true)
	d["name"] = char_name
	d["char_id"] = id
	d["day"] = 3
	d.merge(extra, true)
	return d


func _raw(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _text(path: String) -> String:
	return FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""


func _name_in(path: String) -> String:
	return str(UserFiles.parse_json(_text(path)).get("name", ""))


func _clear_all() -> void:
	UserFiles.test_stop_at = ""
	for slot: int in SaveGame.SLOTS + 1:
		SaveGame.delete(SaveGame.slot_path(slot))
	for name: String in UserFiles._files_in(SaveGame.displaced_dir()):
		UserFiles.remove_one(SaveGame.displaced_dir() + name)


## Every file of the sandbox's save folder that holds this character id.
func _files_with(id: String) -> Array[String]:
	var out: Array[String] = []
	var dirs: Array[String] = [SaveGame.test_dir, SaveGame.displaced_dir()]
	for d: String in dirs:
		for name: String in UserFiles._files_in(d):
			if _text(d + name).contains(id):
				out.append(d + name)
	return out


# --- the write path ------------------------------------------------------------------------------

func _atomic_writes() -> void:
	var path: String = SaveGame.slot_path(1)
	check.call("a first write leaves the file and nothing else", SaveGame.write(_char("First", "id-a"), path)
		and FileAccess.file_exists(path) and not FileAccess.file_exists(path + UserFiles.NEW) and not FileAccess.file_exists(path + UserFiles.BAK))
	check.call("a second write keeps the first as the backup", SaveGame.write(_char("Second", "id-a"), path)
		and _name_in(path) == "Second" and _name_in(path + UserFiles.BAK) == "First" and not FileAccess.file_exists(path + UserFiles.NEW),
		"%s / %s" % [_name_in(path), _name_in(path + UserFiles.BAK)])
	var d: Dictionary = UserFiles.parse_json(_text(path))
	check.call("a save carries its schema, the legacy version, its build and its character id",
		int(d.get("schema", 0)) == SaveGame.SCHEMA and int(d.get("version", 0)) == SaveGame.LEGACY_VERSION
		and str(d.get("build", "?")) == str(ProjectSettings.get_setting("application/config/version", "")) and str(d.get("char_id", "")) == "id-a", str(d.keys()))
	# the first write of a run to a file that was already there keeps it as it was (.prev)
	var other: String = SaveGame.test_dir + "prev_check.json"
	_raw(other, JSON.stringify(_char("Before this run", "id-p")))
	UserFiles.write_text(other, JSON.stringify(_char("Write 1", "id-p")), UserFiles.json_ok)
	UserFiles.write_text(other, JSON.stringify(_char("Write 2", "id-p")), UserFiles.json_ok)
	check.call("the file as this run found it is kept as .prev, the last write as .bak",
		_name_in(other + UserFiles.PREV) == "Before this run" and _name_in(other + UserFiles.BAK) == "Write 1" and _name_in(other) == "Write 2")
	UserFiles.remove(other)
	# a write over a damaged file does not make the damage the backup
	_raw(path, "{\"name\": \"Trunc")
	SaveGame.write(_char("Third", "id-a"), path)
	# (the damage replaced "Second", so the last good copy left is "First", already the backup)
	check.call("writing over a damaged file keeps the last good copy as the backup, not the damage", _name_in(path) == "Third" and _name_in(path + UserFiles.BAK) == "First",
		_name_in(path + UserFiles.BAK))
	# Windows: a rename onto a file someone holds open fails; the write says so and nothing is lost
	var held := FileAccess.open(path, FileAccess.READ)
	var ok_held: bool = SaveGame.write(_char("Fourth", "id-a"), path)
	held.close()
	var after: Dictionary = SaveGame.read(path)
	check.call("a write while the file is held open either lands or fails cleanly (%s); either way a whole save loads" % OS.get_name(),
		(ok_held and str(after.get("name", "")) == "Fourth") or (not ok_held and (str(after.get("name", "")) == "Third" or str(after.get("name", "")) == "Fourth")),
		"%s %s" % [ok_held, after.get("name", "")])
	check.call("once it is let go, the next write lands and leaves no stray copy", SaveGame.write(_char("Fifth", "id-a"), path)
		and _name_in(path) == "Fifth" and not FileAccess.file_exists(path + UserFiles.NEW))


# --- a save survives a kill mid-write, and damage ---------------------------------------------------

func _kills_and_damage() -> void:
	var path: String = SaveGame.slot_path(2)
	SaveGame.write(_char("Good", "id-k"), path)
	SaveGame.write(_char("Better", "id-k"), path)        # .bak = Good

	UserFiles.test_stop_at = "after_new"                  # killed after the new copy was written, before any rename
	SaveGame.write(_char("Newest", "id-k"), path)
	UserFiles.test_stop_at = ""
	var got: Dictionary = SaveGame.inspect(path)
	check.call("killed with the new copy written but not renamed: the save in place loads whole",
		str(got["state"]) == "ok" and str((got["data"] as Dictionary).get("name", "")) == "Better", "%s %s" % [got["state"], got["note"]])
	check.call("and the next write tidies the stray new copy away", SaveGame.write(_char("Better", "id-k"), path) and not FileAccess.file_exists(path + UserFiles.NEW))

	UserFiles.test_stop_at = "after_backup"               # killed after the old one became the backup
	SaveGame.write(_char("Newest", "id-k"), path)
	UserFiles.test_stop_at = ""
	got = SaveGame.inspect(path)
	check.call("killed between the backup and the rename: the complete new copy loads, and says so",
		not FileAccess.file_exists(path) and str(got["state"]) == "recovered" and str((got["data"] as Dictionary).get("name", "")) == "Newest"
		and str(got["note"]).contains(".new"), "%s %s" % [got["state"], got["note"]])
	check.call("the next write puts it back in place", SaveGame.write(_char("Newest", "id-k"), path) and _name_in(path) == "Newest"
		and not FileAccess.file_exists(path + UserFiles.NEW))

	var whole: String = _text(path)
	_raw(path, whole.left(whole.length() / 2))            # truncated mid-write (an old non-atomic write, a full disk)
	got = SaveGame.inspect(path)
	check.call("a truncated save falls back to its backup and says so", str(got["state"]) == "recovered"
		and str((got["data"] as Dictionary).get("char_id", "")) == "id-k" and str(got["note"]).contains("damaged"), "%s %s" % [got["state"], got["note"]])
	SaveGame.last_note = ""
	var data: Dictionary = SaveGame.read(path)
	check.call("read() gives the backup's character and leaves a note for the HUD", not data.is_empty() and SaveGame.take_note() != "" and SaveGame.last_note == "")

	var noise := PackedByteArray()                        # ASCII junk: invalid UTF-8 would log an engine error
	for i: int in 900:
		noise.append(1 + (i * 37 + 11) % 126)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_buffer(noise)
	f.close()
	got = SaveGame.inspect(path)
	check.call("a garbage save with a good backup loads the backup", str(got["state"]) == "recovered" and not (got["data"] as Dictionary).is_empty(), str(got["note"]))
	_raw(path, "")
	got = SaveGame.inspect(path)
	check.call("an empty save with a good backup loads the backup", str(got["state"]) == "recovered" and str(got["note"]).contains("empty"), str(got["note"]))

	UserFiles.remove_one(path + UserFiles.BAK)
	UserFiles.remove_one(path + UserFiles.PREV)
	_raw(path, "{ not json")
	got = SaveGame.inspect(path)
	check.call("a damaged save with no good copy is 'broken', not a character and not 'empty'", str(got["state"]) == "broken"
		and SaveGame.read(path).is_empty() and SaveGame.describe_slot(path).begins_with("damaged"), SaveGame.describe_slot(path))
	SaveGame.take_note()


# --- the schema and its migrations --------------------------------------------------------------------

func _schema() -> void:
	# a save exactly as the game wrote it before 2026-11-08: "version": 1, no schema, no id, no build
	var old: Dictionary = _char("Maren", "")
	old.erase("char_id")
	old["version"] = 1
	var p1: String = SaveGame.slot_path(1)
	var p2: String = SaveGame.slot_path(2)
	_raw(p1, JSON.stringify(old, "  "))
	_raw(p2, JSON.stringify(old, "  "))
	var a: Dictionary = SaveGame.read(p1)
	var b: Dictionary = SaveGame.read(p2)
	check.call("an old (version 1) save loads, migrated to the current schema", int(a.get("schema", 0)) == SaveGame.SCHEMA
		and str(a.get("name", "")) == "Maren" and not a.has("version") and str(a.get("build", "?")) == "", str(a.keys()))
	check.call("it gets a character id, the same for every copy of that character", str(a.get("char_id", "")).begins_with("legacy-")
		and str(a["char_id"]) == str(b.get("char_id", "")))
	var someone: Dictionary = old.duplicate(true)
	someone["name"] = "Ilse"
	check.call("another character gets another id", SaveGame.migrate(someone)["char_id"] != a["char_id"])
	var q: Node = t.call("_new_player")
	q.call("from_save", a)
	check.call("the migrated save loads into a character with that id", str(q.get("char_name")) == "Maren" and str(q.get("char_id")) == str(a["char_id"]))
	q.queue_free()
	var zero: Dictionary = old.duplicate(true)
	zero.erase("version")
	_raw(p1, JSON.stringify(zero))
	var z: Dictionary = SaveGame.read(p1)
	check.call("a save from before any version number (schema 0) loads through every step", int(z.get("schema", 0)) == SaveGame.SCHEMA
		and str(z.get("char_id", "")) == str(a["char_id"]))
	var now: Dictionary = UserFiles.parse_json(JSON.stringify(_char("Now", "id-n", {"schema": SaveGame.SCHEMA})))
	check.call("a save at the current schema comes through migrate() unchanged", JSON.stringify(SaveGame.migrate(now), "", true) == JSON.stringify(now, "", true))

	# a save from a newer build: refused, shown as such, never written over or cleared
	var newer: Dictionary = _char("Future", "id-f", {"schema": SaveGame.SCHEMA + 1, "version": 9})
	_raw(p2, JSON.stringify(newer, "  "))
	var md5: String = FileAccess.get_md5(p2)
	var got: Dictionary = SaveGame.inspect(p2)
	check.call("a save from a newer schema is refused with a clear message", str(got["state"]) == "newer" and SaveGame.read(p2).is_empty()
		and str(got["note"]).contains("newer build") and SaveGame.describe_slot(p2).contains("newer build"), str(got["note"]))
	SaveGame.take_note()
	check.call("writing over it is refused and the file is byte-identical", not SaveGame.write(_char("Now", "id-n"), p2)
		and FileAccess.get_md5(p2) == md5 and not FileAccess.file_exists(p2 + UserFiles.BAK) and SaveGame.take_note().contains("newer build"))
	SaveGame.clear_character("id-f")
	check.call("a hardcore clear never touches it either", FileAccess.get_md5(p2) == md5)


# --- the autosave keeps the character it held ------------------------------------------------------

func _displaced() -> void:
	var auto: String = SaveGame.slot_path(0)
	SaveGame.write(_char("Maren", "id-m"), auto)
	SaveGame.write(_char("Maren", "id-m", {"day": 4}), auto)
	check.call("the same character written over the autosave moves nothing", not SaveGame.exists(SaveGame.slot_path(1)) and SaveGame.take_note() == "")
	SaveGame.write(_char("Ilse", "id-i"), SaveGame.slot_path(1))
	SaveGame.write(_char("Brann", "id-b"), auto)              # a new character, or a load from another slot
	var kept: Dictionary = SaveGame.read(SaveGame.slot_path(2))
	check.call("another character written over the autosave keeps the old one in the first empty slot (2)",
		str(kept.get("char_id", "")) == "id-m" and int(kept.get("day", 0)) == 4 and str(SaveGame.read(auto).get("name", "")) == "Brann"
		and SaveGame.take_note().contains("slot 2"), str(kept.get("name", "")))
	for slot: int in range(1, SaveGame.SLOTS + 1):
		if not SaveGame.exists(SaveGame.slot_path(slot)):
			SaveGame.write(_char("Filler %d" % slot, "id-x%d" % slot), SaveGame.slot_path(slot))
	SaveGame.write(_char("Cora", "id-c"), auto)
	var archived: String = SaveGame.displaced_dir() + "id-b.json"
	check.call("with every slot full it is kept in the displaced folder", str(UserFiles.parse_json(_text(archived)).get("name", "")) == "Brann"
		and SaveGame.take_note().contains("displaced"), _text(archived).left(40))
	SaveGame.write(_char("Test: Fire", "id-t", {"test_character": true}), auto)
	SaveGame.write(_char("Dana", "id-d"), auto)
	check.call("a test character is never kept that way", not FileAccess.file_exists(SaveGame.displaced_dir() + "id-t.json"))
	SaveGame.take_note()


# --- hardcore death clears every copy of that character ---------------------------------------------

func _hardcore_by_hand() -> void:
	var a := "id-hc-a"
	var b := "id-hc-b"
	SaveGame.write(_char("Doomed", a, {"hardcore": true}), SaveGame.slot_path(0))
	SaveGame.write(_char("Doomed", a, {"hardcore": true, "day": 5}), SaveGame.slot_path(0))   # .bak is Doomed too
	SaveGame.write(_char("Doomed", a, {"hardcore": true}), SaveGame.slot_path(2))
	SaveGame.write(_char("Doomed", a, {"hardcore": true}), SaveGame.slot_path(4))
	SaveGame.write(_char("Other", b), SaveGame.slot_path(4))                 # slot 4: Other, its .bak Doomed
	SaveGame.write(_char("Other", b), SaveGame.slot_path(3))
	_raw(SaveGame.displaced_dir() + a + ".json", JSON.stringify(_char("Doomed", a)))
	_raw(SaveGame.slot_path(5) + UserFiles.PREV, JSON.stringify(_char("Doomed", a)))   # a stray old copy
	check.call("(the fixture: the doomed character is in 6 or more files)", _files_with(a).size() >= 6, str(_files_with(a)))
	var removed: int = SaveGame.clear_character(a)
	check.call("a hardcore clear removes every file holding that character - autosave, slots, backups, displaced",
		_files_with(a).is_empty() and removed >= 6, "%d left: %s" % [_files_with(a).size(), _files_with(a)])
	var none_back := true
	for slot: int in [0, 2, 5]:
		none_back = none_back and SaveGame.read(SaveGame.slot_path(slot)).is_empty()
	check.call("no fallback can bring it back: its slots load as empty", none_back)
	check.call("the other character's saves are untouched", str(SaveGame.read(SaveGame.slot_path(4)).get("char_id", "")) == b
		and str(SaveGame.read(SaveGame.slot_path(3)).get("char_id", "")) == b)
	check.call("an empty id clears nothing", SaveGame.clear_character("") == 0 and SaveGame.exists(SaveGame.slot_path(3)))
	SaveGame.take_note()


## The real path: a hardcore character made in main.gd, autosaved and parked in slot 3, dies.
func _hardcore_through_main() -> void:
	SaveGame.write(_char("Someone else", "id-else"), SaveGame.slot_path(5))
	var main: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.add_child(main)
	main.set("hardcore", true)
	main.call("start_new_character", 0)                   # town: autosaved (sandboxed)
	main.call("save_to_slot", 3)
	var id: String = str(main.get("player").get("char_id"))
	var saved: bool = SaveGame.exists(SaveGame.slot_path(0)) and str(SaveGame.read(SaveGame.slot_path(3)).get("char_id", "")) == id
	main.call("town_rest_night")                          # another autosave: the backup is this character too
	check.call("(main.gd: a new hardcore character has an id, its autosave and slot 3)", id != "" and saved and _files_with(id).size() >= 3,
		"%s %s" % [id, _files_with(id)])
	main.call("_on_player_died")
	check.call("main.gd: a hardcore death removes every save of that character", _files_with(id).is_empty()
		and str(main.get("state")) == "dead", str(_files_with(id)))
	check.call("main.gd: another character's slot is untouched", str(SaveGame.read(SaveGame.slot_path(5)).get("char_id", "")) == "id-else")
	main.queue_free()
	await t.get_tree().process_frame

	# a softcore death clears nothing
	var soft: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	t.add_child(soft)
	soft.call("start_new_character", 0)
	var sid: String = str(soft.get("player").get("char_id"))
	soft.call("_on_player_died")
	check.call("main.gd: a softcore death keeps the character's save", sid != "" and str(SaveGame.read(SaveGame.slot_path(0)).get("char_id", "")) == sid)
	soft.queue_free()
	await t.get_tree().process_frame
	SaveGame.take_note()


# --- key bindings and settings recover the same way --------------------------------------------------

func _config_files() -> void:
	Keybinds.reset_defaults()
	var g := InputEventKey.new()
	g.physical_keycode = KEY_J
	Keybinds.rebind("ability_1", g)                       # written: keybinds.cfg says J
	var h := InputEventKey.new()
	h.physical_keycode = KEY_U
	Keybinds.rebind("ascend", h)                          # written again: the J file is the backup
	check.call("key bindings are written to the sandbox, with a backup", FileAccess.file_exists(Keybinds.path)
		and FileAccess.file_exists(Keybinds.path + UserFiles.BAK) and Keybinds.path != Keybinds.SAVE_PATH)
	_raw(Keybinds.path, "[binds]\nability_1=\"key:7")      # truncated mid-write
	Keybinds.use_path(Keybinds.path)
	check.call("a damaged keybinds.cfg falls back to its backup", Keybinds.binding_text("ability_1") == "J", Keybinds.binding_text("ability_1"))
	_raw(Keybinds.path, "")
	UserFiles.remove_one(Keybinds.path + UserFiles.BAK)
	UserFiles.remove_one(Keybinds.path + UserFiles.PREV)
	Keybinds.use_path(Keybinds.path)
	check.call("with no good copy at all the defaults stand", Keybinds.binding_text("ability_1") == "1")
	Keybinds.reset_defaults()
	UserFiles.remove(Keybinds.path)

	GameSettings.set_zoom_start(0.25)
	GameSettings.set_zoom_start(0.75)
	_raw(GameSettings.path, "[camera]\nzoom_start=0.")
	_raw(GameSettings.path, "\u0001\u0002garbage")
	GameSettings.use_path(GameSettings.path)
	check.call("a damaged settings.cfg falls back to its backup", is_equal_approx(GameSettings.zoom_start(), 0.25), str(GameSettings.zoom_start()))
	UserFiles.remove(GameSettings.path)
	GameSettings.use_path(GameSettings.path)
