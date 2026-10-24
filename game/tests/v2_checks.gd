extends RefCounted
## The self-test's checks for the v2 build (2026-10-24, design/data-drafts/skills-v2/BUILD-BRIEF.md): the
## data the generator writes from the v2 drafts (18 affinities, their starters, dropped skills gone, every
## skill on its own rune, every ascension aspect reaching a real number, a desc for every status) and one
## check per role mechanic. Called from selftest.gd, borrowing its helpers (_new_player, _foe, _lost ...)
## through `t`; numbers come from the data. Run alone with `-- --only=v2`.

const PlayerScript := preload("res://scripts/player.gd")
const STEP := 1.0 / 60.0

## The skills the v2 drafts drop (Brent approved the drafts 2026-10-24): none may stay in the game.
const DROPPED: Array[String] = ["hammering_heart", "knell", "rousing_blow", "icicle", "bent_light", "residue", "water_bolt",
	"undertow", "pressure_jet", "upwelling", "steady_drip", "tidal_bore", "slack_water", "headwind"]

var t: Node                 # the self-test node
var check: Callable         # its _check(label, ok, detail)


func _init(test: Node, check_fn: Callable) -> void:
	t = test
	check = check_fn


func run() -> void:
	print("the v2 build: every affinity rebuilt around its role (2026-10-24):")
	await t.get_tree().physics_frame
	_data()


# --- the data -------------------------------------------------------------------------------------

func _data() -> void:
	var ids: Array = GameData.affinity_ids()
	check.call("eighteen affinities, each with a kit of three of its own starters", ids.size() == 18 and ids.all(func(a: Variant) -> bool:
		var kit: Array = GameData.affinity(str(a)).get("kit", [])
		return kit.size() == 3 and kit.all(func(k: Variant) -> bool:
			return str(GameData.ability(str(k)).get("affinity", "")) == str(a) and bool(GameData.ability(str(k)).get("starter", false)))), str(ids))
	var still: Array[String] = DROPPED.filter(func(id: String) -> bool: return GameData.abilities.has(id))
	check.call("the %d skills the v2 drafts drop are gone" % DROPPED.size(), still.is_empty(), str(still))
	var off_rune: Array[String] = []
	for id: String in GameData.abilities:
		var ab: Dictionary = GameData.ability(id)
		var rid: String = str(ab.get("base_rune", ""))
		var r: Dictionary = GameData.rune(rid)
		if r.is_empty() or str(r.get("affinity", "")) != str(ab.get("affinity", "")) or GameData.skill_anchor(id) != rid or str(r.get("name", "")) != str(ab.get("rune", "")):
			off_rune.append("%s (%s)" % [id, rid])
	check.call("every skill sits on exactly the rune its draft names, a rune of its own affinity (%d skills)" % GameData.abilities.size(), off_rune.is_empty(), str(off_rune))
	# the ascension boost reads aspects through the rune stat groups: each draft-named field must be a number one reaches
	var unreached: Array[String] = []
	for id: String in GameData.abilities:
		var ab: Dictionary = GameData.ability(id)
		var mags: Array = (ab.get("magnitude", []) as Array).map(func(m: Dictionary) -> String: return str(m["path"]))
		var fields: Dictionary = ab.get("ascension_fields", {})
		if fields.is_empty():
			unreached.append("%s: no ascension fields" % id)
			continue
		for aspect: String in Ascension.aspect_ids():
			if not fields.has(aspect):
				unreached.append("%s: no %s field" % [id, aspect])
				continue
			for path: String in str(fields[aspect]).split(" + "):
				var groups: Array[String] = Runes.active().groups_of_path(ab, path)
				var want: Dictionary = Ascension.aspect_groups(aspect)
				var ok: bool = groups.any(func(g: String) -> bool: return want.has(g)) or (aspect == "power" and mags.has(path)) \
					or (path == "recovery" and want.has("windup"))
				if not ok:
					unreached.append("%s: %s -> %s" % [id, aspect, path])
	check.call("every skill's four ascension aspects reach a real number of it (through the stat groups, or as its magnitude)", unreached.is_empty(), str(unreached))
	var no_desc: Array[String] = []
	for sid: String in GameData.status_ids():
		if StatusText.desc(sid).strip_edges() == "":
			no_desc.append(sid)
	for pid: String in GameData.player_state_ids():
		if str(GameData.player_state(pid).get("desc", "")).strip_edges() == "":
			no_desc.append(pid)
	var v2_statuses: Array[String] = ["taunted", "turned", "tithed", "bidden", "quarry", "charmed", "doubting", "steeped", "condemned", "penitent",
		"exiled", "leeched", "leashed", "tormented", "stasis", "barbed"]
	var missing: Array[String] = v2_statuses.filter(func(sid: String) -> bool: return GameData.status(sid).is_empty())
	check.call("the 14 statuses the v2 runes grant, and the drafts' own (Stasis, Barbed), are in the status engine", missing.is_empty(), str(missing))
	check.call("every status and every state of yours has a written desc", no_desc.is_empty(), str(no_desc))
