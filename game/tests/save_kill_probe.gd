extends Node
## A save survives a kill mid-write (Phase 0, 2026-11-08). Two runs, in a folder of their own
## (user://kill_probe/, never the player's files):
##   -- --write [--fresh]   writes a large character save, the key bindings and the settings over
##                          and over; a watcher thread kills the process (OS.kill on itself: no
##                          clean-up, no flush) at a random moment, printing where the write was.
##   -- --verify            the next start: the save, the key bindings and the settings must load
##                          whole (from the file or a backup copy), and the character must be the
##                          one written. Prints "SAVEKILL: PASS" / "SAVEKILL: FAIL", exit 0 / 1.
## tools/test/save_kill.sh runs several rounds. Headless.

const DIR := "user://kill_probe/"
const PAD_ITEMS := 20000           # ~1.5 MB of save, so a kill usually lands inside a write
const MAX_WRITE_S := 30.0

var _thread: Thread


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--verify"):
		_verify()
	elif args.has("--write"):
		_write(args.has("--fresh"))
	else:
		print("SAVEKILL: FAIL (pass --write or --verify)")
		get_tree().quit(1)


func _character() -> Dictionary:
	var p: Node = load("res://scripts/player.gd").new()
	add_child(p)
	p.call("set_talent", str(TalentDB.talents.keys()[0]))
	p.set("char_name", "Kill Probe")
	p.set("char_id", "kill-probe-id")
	var d: Dictionary = p.call("to_save")
	p.queue_free()
	var pad: Array = []
	for i: int in PAD_ITEMS:
		pad.append("pad-%06d" % i)
	d["padding"] = pad
	return d


func _write(fresh: bool) -> void:
	UserFiles.sandbox(DIR, fresh)
	var data: Dictionary = _character()
	var k := InputEventKey.new()
	k.physical_keycode = KEY_J
	Keybinds.rebind("ability_1", k)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var wait_ms: int = rng.randi_range(300, 2500)
	print("SAVEKILL: writing; the watcher kills this process after %d ms" % wait_ms)
	_thread = Thread.new()
	_thread.start(_killer.bind(wait_ms))
	var started: int = Time.get_ticks_msec()
	var i := 0
	while Time.get_ticks_msec() - started < int(MAX_WRITE_S * 1000.0):
		i += 1
		data["counter"] = i
		SaveGame.write(data, SaveGame.slot_path(1))
		if i % 3 == 0:
			Keybinds.rebind("ability_1", k)
			GameSettings.set_zoom_start(0.2 + 0.01 * float(i % 50))
	print("SAVEKILL: FAIL (no kill came in %d s)" % int(MAX_WRITE_S))
	get_tree().quit(1)


func _killer(wait_ms: int) -> void:
	OS.delay_msec(wait_ms)
	printerr("SAVEKILL: killed during stage '%s'" % UserFiles.stage)
	OS.kill(OS.get_process_id())


func _verify() -> void:
	UserFiles.sandbox(DIR, false)
	var lines: Array[String] = []
	var ok := true
	var path: String = SaveGame.slot_path(1)
	var got: Dictionary = SaveGame.inspect(path)
	var data: Dictionary = got["data"]
	var whole: bool = (str(got["state"]) == "ok" or str(got["state"]) == "recovered") and str(data.get("char_id", "")) == "kill-probe-id" \
		and (data.get("padding", []) as Array).size() == PAD_ITEMS and int(data.get("counter", 0)) >= 1
	ok = ok and whole
	lines.append("save: %s from %s, counter %d%s" % [got["state"], str(got["from"]).get_file(), int(data.get("counter", 0)),
		("  (" + str(got["note"]) + ")") if str(got["note"]) != "" else ""])
	var p: Node = load("res://scripts/player.gd").new()
	add_child(p)
	p.call("from_save", data)
	var loads: bool = str(p.get("char_name")) == "Kill Probe"
	ok = ok and loads
	lines.append("loads into a character: %s" % loads)
	var bind_ok: bool = Keybinds.binding_text("ability_1") == "J"
	ok = ok and bind_ok
	lines.append("key bindings: ability_1 = %s" % Keybinds.binding_text("ability_1"))
	var zoom: float = GameSettings.zoom_start()
	var zoom_ok: bool = zoom >= 0.2 - 0.001 and zoom <= 0.7
	ok = ok and zoom_ok
	lines.append("settings: zoom_start %.2f" % zoom)
	var copies: Array[String] = []
	for c: String in UserFiles.copies(path):
		if FileAccess.file_exists(c):
			copies.append(c.get_file())
	lines.append("on disk: %s" % ", ".join(copies))
	for line: String in lines:
		print("SAVEKILL:   " + line)
	print("SAVEKILL: %s" % ("PASS" if ok else "FAIL"))
	get_tree().quit(0 if ok else 1)
