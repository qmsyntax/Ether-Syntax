class_name GameSettings
extends RefCounted
## The player's own settings that are not key bindings (those are Keybinds'): the window mode and
## the camera zoom a game starts at. Saved to user://settings.cfg. There is no sound in the game
## yet, so there is no volume. Read through the static functions; main.gd applies them only when
## the game is started for play (no test, shot or bot arguments), so tests and screenshots stay
## the same on every machine.

const DEFAULT_PATH := "user://settings.cfg"

## Set by a click test so it never writes over the real settings.
static var path := DEFAULT_PATH
static var _cfg: ConfigFile


static func _file() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(path)                 # a missing file is simply empty
	return _cfg


## Point at another file (tests) and forget what was read from the old one.
static func use_path(p: String) -> void:
	path = p
	_cfg = null


static func fullscreen() -> bool:
	return bool(_file().get_value("display", "fullscreen", false))


static func set_fullscreen(on: bool) -> void:
	_file().set_value("display", "fullscreen", on)
	_file().save(path)
	apply_window()


## The zoom a new game's camera starts at (0 far .. 1 near); the data's default until one is set.
static func zoom_start() -> float:
	return clampf(float(_file().get_value("camera", "zoom_start", GameData.num("camera", "zoom_default"))), 0.0, 1.0)


static func set_zoom_start(z: float) -> void:
	_file().set_value("camera", "zoom_start", clampf(z, 0.0, 1.0))
	_file().save(path)


static func reset_zoom_start() -> void:
	if _file().has_section_key("camera", "zoom_start"):
		_file().erase_section_key("camera", "zoom_start")
		_file().save(path)


## Put the window in the saved mode. Nothing to do without a window (headless runs).
static func apply_window() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var now: int = DisplayServer.window_get_mode()
	var is_full: bool = now == DisplayServer.WINDOW_MODE_FULLSCREEN or now == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if fullscreen() and not is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not fullscreen() and is_full:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)   # a maximised window is left alone
