extends RefCounted
## The self-test's checks on the data schema (Phase 2 step 4b, docs/architecture/data-schema.md): the load-time check
## found nothing in the real data, and it does report each kind of fault - planted in a copy of the data, never in
## the files. `-- --only=data` runs it alone.

var check: Callable         # the self-test's _check(label, ok, detail)


func _init(check_fn: Callable) -> void:
	check = check_fn


func run() -> void:
	print("the data schema (data/schema.json, 2026-11-09):")
	check.call("GameData's load-time check of every data file against data/schema.json found nothing (%.1f ms)" % GameData.check_ms,
		GameData.data_errors.is_empty(), "\n    ".join(GameData.data_errors.slice(0, 10)))
	var abilities: Dictionary = _file("abilities")
	var ab: Dictionary = abilities["abilities"]["tsunami_strike"]
	ab["recovry"] = 0.4                                         # a typo
	_planted("a misspelt key in an ability", abilities, "abilities", "unknown key 'recovry'")
	abilities = _file("abilities")
	(abilities["abilities"]["tsunami_strike"] as Dictionary).erase("cost")
	_planted("a required key missing from an ability", abilities, "abilities", "missing required key 'cost'")
	abilities = _file("abilities")
	abilities["abilities"]["tsunami_strike"]["cost"] = "five"
	_planted("a number given as text", abilities, "abilities", "a string where ability wants number")
	abilities = _file("abilities")
	abilities["abilities"]["tsunami_strike"]["on_hit"]["status"] = "soggy"
	_planted("an ability's status that does not exist", abilities, "abilities", "'soggy' is not a known status")
	var enemies: Dictionary = _file("enemies")
	enemies["enemies"]["grunt"]["remains"] = "no_such_item"
	_planted("an enemy's remains that name no item", enemies, "enemies", "'no_such_item' is not a known item")
	var zones: Dictionary = _file("zones")
	var camp: Dictionary = (zones["zones"]["the_stubble"]["camps"] as Array)[0]
	(camp["members"] as Array)[0]["kind"] = "gremlin"
	_planted("a camp member of an enemy kind that does not exist", zones, "zones", "'gremlin' is not a known enemy")
	var tree: Dictionary = _file("skill_tree")
	var water: Dictionary = tree["trees"]["water"]
	water["no_such_skill"] = {"tier": 1, "col": 0}
	_planted("a skill-tree node for an ability that does not exist", tree, "skill_tree", "'no_such_skill' is not a known ability")


## A deep copy of one data file as the game parses it.
func _file(name: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/%s.json" % name))


## Check one planted fault: the schema check over that one changed file reports it.
func _planted(what: String, parsed: Dictionary, file: String, expect: String) -> void:
	var one := DataSchema.new()
	one.load_file(JSON.parse_string(FileAccess.get_file_as_string(DataSchema.SCHEMA_PATH)))
	one.files = {file: one.files[file]}
	var data: Dictionary = {}
	data[file] = parsed
	var found: Array[String] = one.check(data, GameData._id_sets())
	var hit := false
	for e: String in found:
		if e.contains(expect):
			hit = true
	check.call("the schema check reports %s" % what, hit, "got %s" % str(found))

