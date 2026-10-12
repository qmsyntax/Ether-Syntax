extends Node
## Autoload: tuning numbers, enemy kinds and ability definitions from game/data/*.json.
## Gameplay scripts read from here instead of holding constants (coding standard: values are data).

var balance: Dictionary = {}
var enemies: Dictionary = {}
var abilities: Dictionary = {}
var _starting_loadout: Array = []
var construct_tiers: Array = []
var concepts: Dictionary = {}
var items_file: Dictionary = {}
var items: Dictionary = {}


## Loaded in the constructor: the singleton name resolves before the node enters the tree,
## and the main scene's member initialisers may read from it that early.
func _init() -> void:
	_ensure()


func _ensure() -> void:
	if not balance.is_empty():
		return
	balance = _load("res://data/balance.json")
	enemies = _load("res://data/enemies.json").get("enemies", {})
	var ab_file: Dictionary = _load("res://data/abilities.json")
	abilities = ab_file.get("abilities", {})
	_starting_loadout = ab_file.get("starting_loadout", [])
	var con: Dictionary = _load("res://data/constructs.json")
	construct_tiers = con.get("tiers", [])
	concepts = con.get("concepts", {})
	items_file = _load("res://data/items.json")
	items = items_file.get("items", {})


## An item definition, or {} if the id is unknown.
func item(id: String) -> Dictionary:
	_ensure()
	return items.get(id, {})


## The construct tier an ability at `stage` needs to advance (stage 0 -> "vestige").
func tier_for_stage(stage: int) -> String:
	_ensure()
	return str(construct_tiers[stage]) if stage >= 0 and stage < construct_tiers.size() else ""


func concept(id: String) -> Dictionary:
	_ensure()
	return concepts.get(id, {})


func concept_ids() -> Array:
	_ensure()
	return concepts.keys()


## Ability ids a new character starts with, in hotbar order.
func ability_loadout() -> Array:
	_ensure()
	return _starting_loadout


## A number from balance.json. Missing keys are a loud error, not a silent zero.
func num(section: String, key: String) -> float:
	_ensure()
	var sec: Variant = balance.get(section)
	if typeof(sec) != TYPE_DICTIONARY or not (sec as Dictionary).has(key):
		push_error("GameData: balance.%s.%s is not defined" % [section, key])
		return 0.0
	return float((sec as Dictionary)[key])


func inum(section: String, key: String) -> int:
	return int(num(section, key))


func enemy(kind: String) -> Dictionary:
	_ensure()
	if not enemies.has(kind):
		push_error("GameData: unknown enemy kind '%s'" % kind)
		return {}
	return enemies[kind]


func ability(id: String) -> Dictionary:
	_ensure()
	if not abilities.has(id):
		push_error("GameData: unknown ability '%s'" % id)
		return {}
	return abilities[id]


static func _load(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("GameData: cannot open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("GameData: %s is not a JSON object" % path)
		return {}
	return parsed
