extends Node
## Autoload: tuning numbers, enemy kinds and ability definitions from game/data/*.json.
## Gameplay scripts read from here instead of holding constants (coding standard: values are data).

var balance: Dictionary = {}
var enemies: Dictionary = {}
var abilities: Dictionary = {}
var construct_tiers: Array = []
var concepts: Dictionary = {}
var _wild: Dictionary = {}
var items_file: Dictionary = {}
var items: Dictionary = {}
var creation: Dictionary = {}
var _statuses: Dictionary = {}
var _tempering: Dictionary = {}
var _affinities: Dictionary = {}
var _prime_default: Array = []
var _zones: Dictionary = {}
## What the real character bodies wear: data/wardrobe.json (see scripts/art/real_character.gd).
var wardrobe: Dictionary = {}
## How each enemy kind looks as a real body: data/enemy_looks.json.
var enemy_looks: Dictionary = {}


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
	var con: Dictionary = _load("res://data/constructs.json")
	construct_tiers = con.get("tiers", [])
	concepts = con.get("concepts", {})
	_wild = con.get("wild", {})
	items_file = _load("res://data/items.json")
	items = items_file.get("items", {})
	creation = _load("res://data/creation.json")
	_statuses = _load("res://data/statuses.json").get("statuses", {})
	_tempering = _load("res://data/tempering.json")
	var aff: Dictionary = _load("res://data/affinities.json")
	_affinities = aff.get("affinities", {})
	_prime_default = aff.get("prime_default", [])
	_zones = _load("res://data/zones.json").get("zones", {})
	wardrobe = _load("res://data/wardrobe.json")
	enemy_looks = _load("res://data/enemy_looks.json")


## A tempering technique definition, or {} if the id is unknown.
func technique(id: String) -> Dictionary:
	_ensure()
	return (_tempering.get("techniques", {}) as Dictionary).get(id, {})


func technique_ids() -> Array:
	_ensure()
	return (_tempering.get("techniques", {}) as Dictionary).keys()


## The numbers for one training session.
func tempering_session() -> Dictionary:
	_ensure()
	return _tempering.get("session", {})


## An affinity definition (label, color, desc), or {} if the id is unknown.
func affinity(id: String) -> Dictionary:
	_ensure()
	return _affinities.get(id, {})


## The affinities a character has when none were rolled for it (tests, bots, old saves).
func default_affinities() -> Array[String]:
	_ensure()
	var out: Array[String] = []
	for a: Variant in _prime_default:
		out.append(str(a))
	return out


## An overland zone definition (data/zones.json), or {} if the id is unknown.
func zone(id: String) -> Dictionary:
	_ensure()
	return _zones.get(id, {})


## An item definition, or {} if the id is unknown.
func item(id: String) -> Dictionary:
	_ensure()
	return items.get(id, {})


## The construct tier an ability at `stage` needs to advance (stage 0 -> "vestige").
func tier_for_stage(stage: int) -> String:
	_ensure()
	return str(construct_tiers[stage]) if stage >= 0 and stage < construct_tiers.size() else ""


## How a construct of `tier` behaves when met wild in the Netherecho.
func wild_construct(tier: String) -> Dictionary:
	_ensure()
	return _wild.get(tier, _wild.get("vestige", {}))


func concept(id: String) -> Dictionary:
	_ensure()
	return concepts.get(id, {})


func concept_ids() -> Array:
	_ensure()
	return concepts.keys()


## Ability ids a new character with these affinities starts with, in hotbar order: each
## affinity's kit in turn.
func ability_loadout(for_affinities: Array) -> Array:
	_ensure()
	var out: Array = []
	for a: Variant in for_affinities:
		for id: Variant in affinity(str(a)).get("kit", []):
			out.append(str(id))
	return out


func affinity_ids() -> Array:
	_ensure()
	return _affinities.keys()


func affinity_color(id: String) -> Color:
	return Color(str(affinity(id).get("color", "9c917b")))


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


## A status definition (stacks, lasts and the numbers its rule reads), or {} if unknown.
func status(id: String) -> Dictionary:
	_ensure()
	return _statuses.get(id, {})


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
