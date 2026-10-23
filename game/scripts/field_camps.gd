class_name FieldCamps
extends Node
## The living things of an overland zone (design/07 3.5 and 6.3): camps, herds, roamers and the
## Sod-Lurker patches, built from the zone's data (zones.json "camps", "lurker_patches") and run
## here. Rules (numbers in balance.json "camps", a camp may override them):
##   - a camp sleeps until you come within its aggro radius (or one of it is hurt); then all of it
##     comes. Neighbouring camps do not - unless a Gleaner at its edge runs and fetches one.
##   - past the leash (measured from the camp, or from the camp that called it) they turn round,
##     walk home and mend there, and sleep again.
##   - a herd is neutral: it grazes until one of it is hurt, then all of it fights.
##   - a camp whose last member falls refills after respawn_s, at the first moment you are more than
##     respawn_clear_m away. Never in your face. (No world clock yet: real seconds.)
## It also starts and ends the player's fight (in_combat) while anything awake is close.

signal camp_woke(camp_id: String)
signal camp_cleared(camp_id: String)

const EnemyScript := preload("res://scripts/enemy.gd")

var main: Node
var zone: ZoneBuilder
var player: Node3D
## id -> {def, state: asleep|awake|returning|cleared|calm, members: Array[Node3D], edge: Array[Node3D],
##        centre (level-local), anchor (level-local), leash, aggro, strength, timer}
var camps: Dictionary = {}
## Each patch: {def, at (level-local), lurker, timer, mark}
var patches: Array = []
var rng := RandomNumberGenerator.new()

var _cfg: Dictionary = {}
var _fighting := false


## Set up for `zone_builder`'s zone in `main`'s current level; call build() once it is in the tree.
func setup(owner_main: Node, zone_builder: ZoneBuilder) -> void:
	main = owner_main
	zone = zone_builder
	player = main.get("player")
	_cfg = GameData.balance.get("camps", {})
	name = "FieldCamps"
	rng.randomize()


func _level() -> Node3D:
	return main.get("level")


## Spawn every live camp and every lurker patch. `force_all` puts the spare sites up too (tests).
func build(force_all: bool = false) -> void:
	var def: Dictionary = zone.def
	for c: Dictionary in def.get("camps", []):
		var chance: float = float(c.get("live_chance", 1.0))
		if not force_all and chance < 1.0 and rng.randf() >= chance:
			continue
		_add_camp(c)
	for p: Dictionary in def.get("lurker_patches", []):
		var at: Array = p["at"]
		var patch: Dictionary = {"def": p, "at": zone.to_local(float(at[0]), float(at[1])), "lurker": null, "timer": 0.0, "mark": null}
		patch["mark"] = _patch_mark(patch["at"], float(p.get("radius", 2.2)))
		patches.append(patch)
		_spawn_lurker(patch)


func _add_camp(c: Dictionary) -> void:
	var at: Array = c["at"]
	var centre: Vector3 = zone.to_local(float(at[0]), float(at[1]))
	var state: Dictionary = {"def": c, "state": "calm" if bool(c.get("herd", false)) else "asleep", "members": [], "edge": [],
		"centre": centre, "anchor": centre, "leash": float(c.get("leash", _cfg.get("leash", 24.0))),
		"aggro": float(c.get("aggro", _cfg.get("aggro_radius", 12.0))), "strength": float(c.get("strength", 1.0)), "timer": 0.0,
		"path_i": 0}
	camps[str(c["id"])] = state
	_populate(str(c["id"]))


## (Re)fill a camp with its members and its edge (Gleaners).
func _populate(id: String) -> void:
	var c: Dictionary = camps[id]
	var def: Dictionary = c["def"]
	c["members"] = []
	c["edge"] = []
	var kinds: Array[String] = []
	for m: Dictionary in def.get("members", []):
		for i: int in int(m.get("n", 1)):
			kinds.append(str(m["kind"]))
	var spread: float = float(def.get("spread", _cfg.get("spread", 3.0)))
	for i: int in kinds.size():
		var a: float = TAU * float(i) / float(maxi(1, kinds.size())) + 0.4
		var r: float = spread * (0.45 + 0.55 * float(i % 2))
		var spot: Vector3 = (c["centre"] as Vector3) + Vector3(cos(a) * r, 0.0, sin(a) * r)
		var e: Node3D = _spawn(kinds[i], spot, float(c["strength"]), id)
		(c["members"] as Array).append(e)
	for edge: Dictionary in def.get("edge", []):
		var off: Array = edge.get("offset", [6.0, 0.0])
		var spot2: Vector3 = (c["centre"] as Vector3) + Vector3(float(off[0]), 0.0, float(off[1]))
		var g: Node3D = _spawn(str(edge["kind"]), spot2, float(c["strength"]), id)
		g.set_meta("runs_to", str(edge.get("runs_to", "")))
		(c["edge"] as Array).append(g)
	c["state"] = "calm" if bool(def.get("herd", false)) else "asleep"
	c["anchor"] = c["centre"]


## A member of camp `camp_id` at `local` (level frame), asleep (or grazing, for a herd).
func _spawn(kind: String, local: Vector3, strength: float, camp_id: String) -> Node3D:
	var d: Dictionary = GameData.enemy(kind)
	var e: CharacterBody3D = Beast.new() if (str(d.get("creature", "")) != "" or d.has("stars")) else EnemyScript.new()
	e.call("setup", kind, player, strength)
	e.position = local
	e.set("camp", camp_id)
	var lvl: Node3D = _level()
	e.set("home", lvl.to_global(local))
	lvl.add_child(e)
	var herd: bool = camp_id != "" and camps.has(camp_id) and bool((camps[camp_id]["def"] as Dictionary).get("herd", false))
	if not herd and str(d.get("behaviour", "")) != "lurker":
		e.call("sleep_at", lvl.to_global(local))
	e.connect("hurt", _on_hurt)
	e.connect("killed", _on_killed)
	if e.has_signal("fetched"):
		e.connect("fetched", _on_fetched)
	if main.has_method("_on_reinforcements"):
		e.connect("reinforcements", Callable(main, "_on_reinforcements"))
	return e


# --- Sod-Lurker patches -----------------------------------------------------------------------

func _spawn_lurker(patch: Dictionary) -> void:
	var p: Dictionary = patch["def"]
	var e: Node3D = _spawn(str(p.get("kind", "sod_lurker")), patch["at"], float(p.get("strength", _cfg.get("lurker_strength", 0.7))), "")
	patch["lurker"] = e
	e.set_meta("patch", true)


## The turned earth over a lurker: dark, raked soil a few metres across. You can read it - that is
## the point - but only if you are looking at the ground.
func _patch_mark(local: Vector3, radius: float) -> Node3D:
	var mark: Node3D = FieldProps.prop("turned_earth", radius)
	mark.position = local
	mark.rotation.y = rng.randf() * TAU
	_level().add_child(mark)
	return mark


# --- each frame ---------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	tick(delta)


## One step of every camp. Public so tests can drive it.
func tick(delta: float) -> void:
	if player == null or not is_instance_valid(player) or _level() == null:
		return
	var lvl: Node3D = _level()
	var me: Vector3 = lvl.to_local(player.global_position)
	var alive: bool = not bool(player.get("dead"))
	var close_fight := false
	for id: String in camps:
		var c: Dictionary = camps[id]
		_prune(c)
		var everyone: Array = (c["members"] as Array) + (c["edge"] as Array)
		var st: String = str(c["state"])
		if (c["members"] as Array).is_empty() and st != "cleared":
			c["state"] = "cleared"
			c["timer"] = float((c["def"] as Dictionary).get("respawn_s", _cfg.get("respawn_s", 480.0)))
			for g: Node3D in c["edge"]:
				g.call("go_home")
			camp_cleared.emit(id)
			continue
		match st:
			"asleep":
				if alive and _flat(me, c["centre"]) <= float(c["aggro"]):
					wake_camp(id)
			"awake":
				if not alive or _flat(me, c["anchor"]) > float(c["leash"]):
					_send_home(id)
				else:
					for e: Node3D in everyone:
						if _flat(lvl.to_local(e.global_position), me) <= float(_cfg.get("fight_radius", 30.0)) and not bool(e.get("asleep")):
							close_fight = true
			"returning":
				var all_home := true
				for e: Node3D in everyone:
					if bool(e.call("is_going_home")):
						all_home = false
				if all_home:
					c["state"] = "calm" if bool((c["def"] as Dictionary).get("herd", false)) else "asleep"
					c["anchor"] = c["centre"]
			"calm":
				_roam(c, delta)
			"cleared":
				c["timer"] = float(c["timer"]) - delta
				if float(c["timer"]) <= 0.0 and _flat(me, c["centre"]) > float(_cfg.get("respawn_clear_m", 60.0)):
					for g: Node3D in c["edge"]:
						g.queue_free()
					_populate(id)
	for patch: Dictionary in patches:
		var l: Node3D = patch["lurker"]
		if l == null or not is_instance_valid(l):
			patch["timer"] = float(patch["timer"]) - delta
			if float(patch["timer"]) <= 0.0 and _flat(me, patch["at"]) > float(_cfg.get("respawn_clear_m", 60.0)):
				_spawn_lurker(patch)
			continue
		if not bool(l.get("buried")) and not bool(l.call("is_going_home")) and _flat(lvl.to_local(l.global_position), me) <= float(_cfg.get("fight_radius", 30.0)):
			close_fight = true
	if close_fight and alive and not _fighting:
		_fighting = true
		player.call("start_fight")
	elif not close_fight and _fighting:
		_fighting = false
		player.call("end_fight")


func _prune(c: Dictionary) -> void:
	c["members"] = (c["members"] as Array).filter(func(e: Variant) -> bool: return e != null and is_instance_valid(e) and not bool((e as Node).call("is_dead")))
	c["edge"] = (c["edge"] as Array).filter(func(e: Variant) -> bool: return e != null and is_instance_valid(e) and not bool((e as Node).call("is_dead")))


func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Wake camp `id`: every member goes for the player; a Gleaner at its edge runs for its camp.
func wake_camp(id: String, anchor_local: Variant = null) -> void:
	if not camps.has(id):
		return
	var c: Dictionary = camps[id]
	if str(c["state"]) == "cleared":
		return
	var was: String = str(c["state"])
	c["state"] = "awake"
	if anchor_local is Vector3:
		c["anchor"] = anchor_local
	for e: Node3D in c["members"]:
		if e.has_method("provoke") and bool(e.call("is_calm")):
			e.call("provoke", player)
		else:
			e.call("wake", player)
	if was == "awake":
		return
	for g: Node3D in c["edge"]:
		var to_id: String = str(g.get_meta("runs_to", ""))
		if to_id != "" and camps.has(to_id) and str(camps[to_id]["state"]) == "asleep" and g.has_method("run_for"):
			g.call("wake", player)
			g.call("run_for", _level().to_global(camps[to_id]["centre"]), to_id)
		else:
			g.call("wake", player)
	camp_woke.emit(id)


## Past the leash: they all turn round and walk home.
func _send_home(id: String) -> void:
	var c: Dictionary = camps[id]
	c["state"] = "returning"
	for e: Node3D in (c["members"] as Array) + (c["edge"] as Array):
		if e.has_method("run_for"):
			e.set("run_to", null)
		e.call("go_home")


## A herd or roamer group grazes; one with a path drifts its grazing ground along it.
func _roam(c: Dictionary, delta: float) -> void:
	var path: Array = (c["def"] as Dictionary).get("path", [])
	if path.size() < 2:
		return
	var i: int = int(c["path_i"]) % path.size()
	var goal: Vector3 = zone.to_local(float(path[i][0]), float(path[i][1]))
	var centre: Vector3 = c["centre"]
	var to: Vector3 = goal - centre
	to.y = 0.0
	var step: float = float((c["def"] as Dictionary).get("roam_speed", _cfg.get("roam_speed", 0.6))) * delta
	if to.length() <= step:
		c["path_i"] = i + 1
		c["centre"] = goal
	else:
		c["centre"] = centre + to.normalized() * step
	c["anchor"] = c["centre"]
	var lvl: Node3D = _level()
	for e: Node3D in c["members"]:
		e.set("home", lvl.to_global(c["centre"]))


# --- signals ------------------------------------------------------------------------------------

## Hurt while asleep, the camp wakes; hurt in a herd, the herd answers.
func _on_hurt(e: Node, _source: Node) -> void:
	var id: String = str(e.get("camp"))
	if id == "" or not camps.has(id):
		return
	var st: String = str(camps[id]["state"])
	if st == "asleep" or st == "calm" or st == "returning":
		wake_camp(id)


func _on_killed(_e: Node) -> void:
	for patch: Dictionary in patches:
		if patch["lurker"] == _e:
			patch["lurker"] = null
			patch["timer"] = float((patch["def"] as Dictionary).get("respawn_s", _cfg.get("lurker_respawn_s", 300.0)))


## A Gleaner got there: that camp comes, its leash measured from the fight it was called to.
func _on_fetched(g: Node, camp_id: String) -> void:
	if not camps.has(camp_id):
		return
	var from: String = str(g.get("camp"))
	var anchor: Variant = camps[from]["anchor"] if camps.has(from) else null
	var c: Dictionary = camps[camp_id]
	c["leash"] = maxf(float(c["leash"]), float((c["def"] as Dictionary).get("leash", _cfg.get("leash", 24.0))))
	if anchor is Vector3:
		c["leash"] = float(c["leash"]) + _flat(anchor, c["centre"])
	wake_camp(camp_id, c["centre"])
	if player != null and is_instance_valid(player) and player.has_method("note"):
		player.call("note", "The Gleaner got there: %s is coming." % str((c["def"] as Dictionary).get("name", camp_id)).to_lower())


# --- for the HUD and tests ----------------------------------------------------------------------

## The camps as the minimap draws them: [{at (map frame), state, name, herd}].
func minimap_marks() -> Array:
	var out: Array = []
	for id: String in camps:
		var c: Dictionary = camps[id]
		var at: Vector3 = c["centre"]
		out.append({"at": Vector2(at.x + zone.size.x * 0.5, at.z + zone.size.y * 0.5), "state": str(c["state"]),
			"name": str((c["def"] as Dictionary).get("name", id)), "herd": bool((c["def"] as Dictionary).get("herd", false))})
	return out


func state_of(id: String) -> String:
	return str(camps[id]["state"]) if camps.has(id) else ""


func members_of(id: String) -> Array:
	if not camps.has(id):
		return []
	_prune(camps[id])
	return (camps[id]["members"] as Array) + (camps[id]["edge"] as Array)


## Every living beast and enemy this zone holds (asleep or not), patches included.
func all_living() -> Array:
	var out: Array = []
	for id: String in camps:
		out.append_array(members_of(id))
	for patch: Dictionary in patches:
		if patch["lurker"] != null and is_instance_valid(patch["lurker"]):
			out.append(patch["lurker"])
	return out


## Seconds until camp `id` refills (tests); set it with the same key.
func set_respawn_timer(id: String, seconds: float) -> void:
	if camps.has(id):
		camps[id]["timer"] = seconds
