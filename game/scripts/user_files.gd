class_name UserFiles
extends RefCounted
## Every file the game keeps in user:// (the saves, keybinds.cfg, settings.cfg) is written and read
## through here, so a kill, a crash or a full disk mid-write never costs the player what they had.
##
## A write (`write_text`):
##   1. the new text goes to `<file>.new`, is flushed and closed, and is read back to check it landed;
##   2. if the file in place is good (it passes the caller's check), it becomes `<file>.bak`; the
##      first write to a file in a run also copies it to `<file>.prev` (as it was when this run began);
##   3. `<file>.new` is renamed over `<file>`.
## Godot 4.7.2 on Windows (checked 2026-11-08): FileAccess WRITE truncates and writes the file in
## place (no temp file of its own); DirAccess.rename onto an existing file replaces it, but fails
## (ERR_FAILED) while anything holds the target open, so a rename is retried for a moment and a
## write that still cannot land returns false and leaves the old file where it was.
##
## A read (`read_text`) takes the first copy that is there, not empty and passes the check, in the
## order file, .new (a complete write that was not renamed), .bak, .prev - and says in the log, and
## in `note`, when it had to fall back.
##
## Tests never write the player's own files: `sandbox(dir)` points the saves, the key bindings and
## the settings at a folder of their own (main.gd does it for every run that is not play).

const NEW := ".new"
const BAK := ".bak"
const PREV := ".prev"
const RENAME_TRIES := 12
const RENAME_WAIT_MS := 25

## Where the current write is (read by the kill test's watcher thread): "", "new", "written",
## "backup", "rename", "done".
static var stage := ""
## Tests only: stop a write early, as a kill would. "after_new" (the new copy is written, nothing
## renamed) or "after_backup" (the file in place has become the backup; the new copy is not in place).
static var test_stop_at := ""
## The folder tests write to ("" = the player's own files are in use).
static var sandbox_dir := ""
## Files already written once in this run (the .prev copy is taken before the first write only).
static var _written_this_run: Dictionary = {}


## Every copy a file may have on disk, the file itself first.
static func copies(path: String) -> PackedStringArray:
	return PackedStringArray([path, path + NEW, path + BAK, path + PREV])


## Write `text` to `path` atomically, keeping the last good copy. `valid` (text -> bool) says whether
## a file's text is good; the file in place becomes the backup only if it is. False if the write
## could not be completed - the file in place is then untouched (or, if the very last rename
## failed, the new text waits in <path>.new and is what the next read takes).
static func write_text(path: String, text: String, valid: Callable = Callable()) -> bool:
	stage = "new"
	var dir: String = path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var tmp: String = path + NEW
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return _fail(path, "cannot open %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
	var ok: bool = f.store_string(text)
	f.flush()
	ok = ok and f.get_error() == OK
	f.close()
	if not ok or FileAccess.get_file_as_string(tmp) != text:
		DirAccess.remove_absolute(tmp)
		return _fail(path, "the new copy did not land intact (disk full?)")
	stage = "written"
	if test_stop_at == "after_new":
		return true
	stage = "backup"
	if FileAccess.file_exists(path) and _good(path, valid):
		if not _written_this_run.has(path):
			DirAccess.copy_absolute(path, path + PREV)        # as it was when this run began
		if not _rename(path, path + BAK):
			push_warning("UserFiles: could not keep %s as the backup; the older backup stays" % path)
	_written_this_run[path] = true
	if test_stop_at == "after_backup":
		return true
	stage = "rename"
	if not _rename(tmp, path):
		return _fail(path, "could not move the new copy into place (is the file open elsewhere?); it waits in %s" % tmp)
	stage = "done"
	return true


## The text of `path`, or of the newest good copy of it. {"text", "from" (the copy used, "" if
## none), "note" ("" when the file itself was fine; otherwise one line saying what was done)}.
static func read_text(path: String, valid: Callable = Callable()) -> Dictionary:
	var trouble: Array[String] = []
	for cand: String in copies(path):
		if not FileAccess.file_exists(cand):
			if cand == path:
				trouble.append("missing")
			continue
		var text: String = FileAccess.get_file_as_string(cand)
		if text.strip_edges() == "":
			trouble.append("%s is empty" % cand.get_file())
			continue
		if valid.is_valid() and not bool(valid.call(text)):
			trouble.append("%s is damaged" % cand.get_file())
			continue
		var note := ""
		if cand != path:
			note = "%s could not be read (%s); recovered it from %s." % [path.get_file(), ", ".join(trouble), cand.get_file()]
			push_warning("UserFiles: " + note)
			print("UserFiles: " + note)
		return {"text": text, "from": cand, "note": note}
	var none := ""
	if trouble.size() > 1 or (trouble.size() == 1 and trouble[0] != "missing"):
		none = "%s could not be read (%s) and no good copy was left." % [path.get_file(), ", ".join(trouble)]
		push_warning("UserFiles: " + none)
		print("UserFiles: " + none)
	return {"text": "", "from": "", "note": none}


## Whether the file or any copy of it is on disk.
static func any_exists(path: String) -> bool:
	for cand: String in copies(path):
		if FileAccess.file_exists(cand):
			return true
	return false


## Remove the file and every copy of it.
static func remove(path: String) -> void:
	for cand: String in copies(path):
		remove_one(cand)


static func remove_one(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## A JSON text whose top level is an object (silent on bad input: JSON.parse_string logs an error).
static func json_ok(text: String) -> bool:
	var j := JSON.new()
	return j.parse(text) == OK and typeof(j.data) == TYPE_DICTIONARY


static func parse_json(text: String) -> Dictionary:
	var j := JSON.new()
	if j.parse(text) != OK or typeof(j.data) != TYPE_DICTIONARY:
		return {}
	return j.data


## A ConfigFile text that parses. Lines are checked first, so damaged text is refused without
## ConfigFile logging a parse error.
static func cfg_ok(text: String) -> bool:
	for raw: String in text.split("\n"):
		var line: String = raw.strip_edges()
		if line == "" or line.begins_with(";"):
			continue
		if line.begins_with("["):
			if not line.ends_with("]") or line.length() < 3:
				return false
			continue
		var eq: int = line.find("=")
		if eq <= 0:
			return false
		var value: String = line.substr(eq + 1).strip_edges()
		if value == "" or value.count("\"") % 2 != 0:
			return false
		if not (value.begins_with("\"") or value.is_valid_float() or value in ["true", "false", "null"]
				or value.begins_with("Vector") or value.begins_with("Color(") or value.begins_with("[") or value.begins_with("{")):
			return false
	return ConfigFile.new().parse(text) == OK


## Save a ConfigFile through write_text.
static func write_cfg(path: String, cfg: ConfigFile) -> bool:
	return write_text(path, cfg.encode_to_text(), cfg_ok)


## Load a ConfigFile from the newest good copy; an empty one if there is none. {"cfg", "note"}.
static func read_cfg(path: String) -> Dictionary:
	var got: Dictionary = read_text(path, cfg_ok)
	var cfg := ConfigFile.new()
	if str(got["text"]) != "":
		cfg.parse(str(got["text"]))
	return {"cfg": cfg, "note": got["note"]}


## Point the saves, the key bindings and the settings at `dir` (ends with "/"), empty it the first
## time in this run, and put the key bindings back to their defaults in memory, so a test sees the
## same game on every machine and never writes a file of the player's.
static func sandbox(dir: String, wipe: bool = true) -> void:
	if sandbox_dir == dir:
		return
	sandbox_dir = dir
	DirAccess.make_dir_recursive_absolute(dir)
	if wipe:                                # `wipe` false: a test that reads what an earlier run left (the kill test)
		for name: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(name)))
		for sub: String in DirAccess.get_directories_at(dir):
			for name: String in DirAccess.get_files_at(dir.path_join(sub)):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join(sub).path_join(name)))
	SaveGame.test_dir = dir
	GameSettings.use_path(dir + "settings.cfg")
	Keybinds.use_path(dir + "keybinds.cfg")


## The player's own files (and their copies) as they are now: path -> md5, "" when absent. Every
## file at the top of user:// and in the displaced-autosave folder, so a stray write anywhere shows.
static func real_snapshot() -> Dictionary:
	var out: Dictionary = {}
	var named: PackedStringArray = PackedStringArray()
	for p: String in [SaveGame.PATH, Keybinds.SAVE_PATH, GameSettings.DEFAULT_PATH]:
		named.append_array(copies(p))
	for slot: int in range(1, SaveGame.SLOTS + 1):
		named.append_array(copies("user://save_slot_%d.json" % slot))
	for p: String in named:
		out[p] = FileAccess.get_md5(p) if FileAccess.file_exists(p) else ""
	for name: String in DirAccess.get_files_at("user://"):
		out["user://" + name] = FileAccess.get_md5("user://" + name)
	for name: String in _files_in(SaveGame.DISPLACED_DIR_REAL):
		out[SaveGame.DISPLACED_DIR_REAL + name] = FileAccess.get_md5(SaveGame.DISPLACED_DIR_REAL + name)
	return out


## What changed between two snapshots, one line each ("" = nothing).
static func snapshot_diff(before: Dictionary, after: Dictionary) -> String:
	var lines: Array[String] = []
	for k: String in before:
		if str(after.get(k, "")) != str(before[k]):
			lines.append("%s %s" % [k, "removed" if str(after.get(k, "")) == "" else ("added" if str(before[k]) == "" else "changed")])
	for k: String in after:
		if not before.has(k) and str(after[k]) != "":
			lines.append("%s added" % k)
	return "; ".join(lines)


## The files in a folder; none (and no error) if it does not exist.
static func _files_in(dir: String) -> PackedStringArray:
	return DirAccess.get_files_at(dir) if DirAccess.dir_exists_absolute(dir) else PackedStringArray()


static func _good(path: String, valid: Callable) -> bool:
	var text: String = FileAccess.get_file_as_string(path)
	if text.strip_edges() == "":
		return false
	return not valid.is_valid() or bool(valid.call(text))


static func _rename(from: String, to: String) -> bool:
	var a: String = ProjectSettings.globalize_path(from)
	var b: String = ProjectSettings.globalize_path(to)
	for i: int in RENAME_TRIES:
		if DirAccess.rename_absolute(a, b) == OK:
			return true
		OS.delay_msec(RENAME_WAIT_MS)       # a virus scanner or an open reader lets go in a moment
	return false


static func _fail(path: String, why: String) -> bool:
	stage = ""
	push_warning("UserFiles: could not write %s: %s" % [path, why])
	print("UserFiles: could not write %s: %s" % [path, why])
	return false
