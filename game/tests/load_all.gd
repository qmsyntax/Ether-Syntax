extends Node
## Loads every script and checks the data (Phase 2 step 4b, docs/architecture/data-schema.md).
##   --headless --path game res://tests/load_all.tscn          prints LOADALL: PASS, or what failed; exit 0 / 1
##
## - load() of every .gd under res://scripts and res://tests: the headless import does not compile a script nothing
##   loads (step 4a: a broken line in crafting.gd passed the import and the smoke run), and load() runs the whole
##   analyzer (parse and type errors).
## - GameData's load-time check of every data file against data/schema.json (unknown keys, missing required keys,
##   wrong types, ids that point nowhere) found nothing.
## - every GameData.opt(<entry>, "<kind>", "<key>"[, "<variant>"]) in the scripts names a kind, key and variant the
##   schema has: Godot cannot check a string, and a read the schema does not know has no default.

const ROOTS: Array[String] = ["res://scripts", "res://tests"]


func _ready() -> void:
	var failed: Array[String] = []
	var n := 0
	var sources: Dictionary = {}          # res:// path -> text, for the opt() check
	for root: String in ROOTS:
		for path: String in _walk(root):
			n += 1
			var s: Variant = ResourceLoader.load(path)
			if s == null or not (s is GDScript):
				failed.append("%s: does not load" % path)
				continue
			var gs: GDScript = s
			if not gs.can_instantiate() and not gs.is_abstract():
				failed.append("%s: does not compile" % path)
			if path.begins_with("res://scripts"):
				sources[path] = FileAccess.get_file_as_string(path)
	for e: String in GameData.data_errors:
		failed.append("data: " + e)
	var reads: int = 0
	var re := RegEx.new()
	re.compile("(?:GameData\\.|[^.\\w])opt\\((.*?), \"([a-z_.]+)\", \"([a-z_0-9]+)\"(?:, \"([a-z_0-9]+)\")?\\)")
	for path2: String in sources:
		var lines: PackedStringArray = (sources[path2] as String).split("\n")
		for i: int in lines.size():
			for m: RegExMatch in re.search_all(lines[i]):
				reads += 1
				var why: String = _unknown_read(m.get_string(2), m.get_string(3), m.get_string(4))
				if why != "":
					failed.append("%s:%d: GameData.opt(..., \"%s\", \"%s\"%s): %s" % [path2, i + 1, m.get_string(2),
						m.get_string(3), ", \"%s\"" % m.get_string(4) if m.get_string(4) != "" else "", why])
	print("LOADALL: %d scripts loaded, data checked in %.1f ms, %d schema reads named" % [n, GameData.check_ms, reads])
	if failed.is_empty():
		print("LOADALL: PASS")
	else:
		for f: String in failed:
			print("  FAIL ", f)
		print("LOADALL: FAIL (%d)" % failed.size())
	get_tree().quit(0 if failed.is_empty() else 1)


func _unknown_read(kind: String, key: String, variant: String) -> String:
	var sc: DataSchema = GameData.schema
	if not sc.kinds.has(kind):
		return "no kind '%s' in data/schema.json" % kind
	if not (sc.defaults.get(kind, {}) as Dictionary).has(key):
		return "%s has no default for '%s'" % [kind, key]
	if variant != "" and not ((sc.variants.get(kind, {}) as Dictionary).get(key, {}) as Dictionary).has(variant):
		return "%s.%s has no variant '%s'" % [kind, key, variant]
	return ""


func _walk(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub: String in d.get_directories():
		out.append_array(_walk(dir.path_join(sub)))
	return out
