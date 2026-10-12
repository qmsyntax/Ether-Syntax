class_name CharacterLook
extends RefCounted
## What a character looks like: a Dictionary of option ids ("body", "skin", "hair", ...) that the
## model library turns into a model. This is the one place gameplay and UI ask the library about
## looks, so neither depends on which options the art currently offers.

const MODELS_PATH := "res://scripts/art/models.gd"

static var _models: GDScript
static var _methods: Dictionary = {}


static func _arg_count(method: String) -> int:
	if _models == null:
		_models = load(MODELS_PATH)
		for m: Dictionary in _models.get_script_method_list():
			_methods[str(m["name"])] = (m["args"] as Array).size()
	return int(_methods.get(method, -1))


## key -> Array of {"id", "label", optional "color"} in display order; first is the default.
## Empty if the model library offers no choices.
static func options() -> Dictionary:
	if _arg_count("look_options") < 0:
		return {}
	return _models.call("look_options")


static func default_look() -> Dictionary:
	var look := {}
	var opts: Dictionary = options()
	for key: String in opts:
		var list: Array = opts[key]
		if not list.is_empty():
			look[key] = str((list[0] as Dictionary)["id"])
	return look


## Fill gaps and replace ids the library no longer knows (saves outlive art passes).
static func normalize(look: Dictionary) -> Dictionary:
	var out: Dictionary = default_look()
	var opts: Dictionary = options()
	for key: String in out:
		if not look.has(key):
			continue
		for o: Dictionary in opts[key]:
			if str(o["id"]) == str(look[key]):
				out[key] = str(look[key])
				break
	return out


static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	var look := {}
	var opts: Dictionary = options()
	for key: String in opts:
		var list: Array = opts[key]
		if not list.is_empty():
			look[key] = str((list[rng.randi() % list.size()] as Dictionary)["id"])
	return look


## The next (step = 1) or previous (-1) option id for `key`, wrapping round.
static func cycle(look: Dictionary, key: String, step: int) -> String:
	var list: Array = options().get(key, [])
	if list.is_empty():
		return str(look.get(key, ""))
	var at := 0
	for i: int in list.size():
		if str((list[i] as Dictionary)["id"]) == str(look.get(key, "")):
			at = i
	return str((list[posmod(at + step, list.size())] as Dictionary)["id"])


static func label(key: String, id: String) -> String:
	for o: Dictionary in options().get(key, []):
		if str(o["id"]) == id:
			return str(o.get("label", id))
	return id


## A player model wearing `look`.
static func build(look: Dictionary) -> ModelRig:
	if _arg_count("player") >= 1:
		return _models.call("player", normalize(look))
	return _models.call("player")
