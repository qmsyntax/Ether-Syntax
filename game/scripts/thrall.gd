class_name Thrall
extends CharacterBody3D
## A summon of its caster's - one body for every summon kind (v2 build 2026-10-24: Death's thralls, Nature's
## beasts, Life's heartseed; death.json's summon widened by life.json). It walks to the nearest enemy and strikes
## it every `attack_s` for `damage` ("fight"), or keeps beside its caster and does not attack ("follow"); a hit
## goes through the caster's apply_hit, so its kills are the caster's, with every on-kill rule. Enemies close to
## it may turn on it (a lure with a short reach, see enemy._pick_target); a follower can be struck only from within
## `strikable_within`. It has `hp`, a `ward` (Holy's wards cover summons), and falls when that or its `life` runs
## out. `living` decides whether Life can touch it (a corpse thrall is not living).
##
## What its caster's skills put on it: `buffs` {id: {t, ...}} - a shared buff (Knit, Benediction, Overgrowth, Kind
## Light, Lucid, Embalm's thrall_ keys) or a summon's own (Unleashed): damage_mult / thrall_damage_mult /
## summon_deals_mult, attack_rate_mult / thrall_rate_mult, incoming_mult / thrall_incoming_mult, thrall_time_paused
## (its life does not run down), heal_per_s, heal_per_hit, poise_loss_mult. Statuses on its foe in its caster's
## name may draw it and sharpen it (Bidden, Quarry: summons_target, summon_damage_mult, summon_rate_mult).

var caster: Node
var skill := ""                       # the ability that raised it (a cap counts per skill)
var life := 15.0
var hp := 120.0
var hp_max := 120.0
var damage := 15.0
var attack_s := 1.2
var speed := 5.0
var reach := 1.6
var lure_radius := 2.5
var tags: Array = []
var dead := false
var radius := 0.45
var is_scenery := false
var is_living := false
var behaviour := "fight"
var on_hit: Dictionary = {}
var heal_per_s := 0.0                 # to its caster and the caster's living summons within heal_radius
var heal_per_hit := 0.0               # to its caster each time the caster lands a hit
var heal_radius := 6.0
var strikable_within := -1.0          # a follower: enemies this close may choose it (it holds no slot)
var model := "grunt"
var buffs: Dictionary = {}
var ward := 0.0
var ward_t := 0.0

var _cd := 0.0
var _heal_acc := 0.0
var _rig: Node3D


func _ready() -> void:
	add_to_group("lures")
	add_to_group("thralls")
	collision_layer = 0
	collision_mask = 1
	hp_max = maxf(hp_max, hp)
	if strikable_within >= 0.0:
		lure_radius = strikable_within
	var col := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.7
	col.shape = shape
	col.position.y = 0.85
	add_child(col)
	_rig = _build_model()
	if _rig != null:
		add_child(_rig)
		if _wash != null and is_inside_tree():
			get_tree().create_timer(0.25).timeout.connect(func() -> void: _apply_wash(_rig))


## Its look, from `model`: "grunt" (a corpse risen, the dead look), "mote:<affinity>" (a seed of light), or
## "beast:<kind>" (a procedural creature stand-in, as the Stubble's beasts are).
func _build_model() -> Node3D:
	if model.begins_with("mote:"):
		var m: Node3D = Models.wisp(model.get_slice(":", 1))
		m.position.y = 1.0
		m.scale = Vector3.ONE * 2.2
		return m
	if model.begins_with("beast:"):
		var kind: String = model.get_slice(":", 1)
		var pick: String = kind if CreatureModels.builders().has(kind) else "ditch_hound"
		return CreatureModels.make(pick)
	var r: ModelRig = Models.enemy(model)
	if r.has_method("set_dead_look"):
		r.set_dead_look()
	# a risen body is the enemy's own model, so it is washed in its caster's affinity colour to tell it from the
	# living foes it fights (a stand-in look, as the beasts are)
	var aff: String = "death"
	for tg: Variant in tags:
		if GameData.affinity_ids().has(str(tg)):
			aff = str(tg)
			break
	_wash = StandardMaterial3D.new()
	_wash.albedo_color = Color(GameData.affinity_color(aff).lightened(0.25), 0.55)
	_wash.emission_enabled = true
	_wash.emission = GameData.affinity_color(aff)
	_wash.emission_energy_multiplier = 0.6
	_wash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_apply_wash(r)
	return r


var _wash: StandardMaterial3D = null


## The risen look over every mesh of the model (again once its clothes have loaded).
func _apply_wash(r: Node) -> void:
	if _wash == null or r == null or not is_instance_valid(r):
		return
	for mi: Node in r.find_children("*", "MeshInstance3D", true, false):
		(mi as GeometryInstance3D).material_overlay = _wash


func _physics_process(delta: float) -> void:
	tick(delta)


## The product of number `key` (or `alt`) over what is on it now.
func buff_num(key: String, alt: String = "") -> float:
	var out := 1.0
	for id: String in buffs:
		var b: Dictionary = buffs[id]
		out *= float(b.get(key, b.get(alt, 1.0) if alt != "" else 1.0))
	return out


func _buff_flag(key: String) -> bool:
	for id: String in buffs:
		if bool((buffs[id] as Dictionary).get(key, false)):
			return true
	return false


## One step. Public so a test can run it by hand.
func tick(delta: float) -> void:
	if dead:
		return
	if not is_instance_valid(caster):
		_fall()                     # its caster is gone (a new game, a freed test body): it goes with them
		return
	for id: String in buffs.keys():
		var b: Dictionary = buffs[id]
		b["t"] = float(b.get("t", 0.0)) - delta
		if float(b.get("heal_per_s", 0.0)) > 0.0 and is_living:
			hp = minf(hp_max, hp + float(b["heal_per_s"]) * delta)
		if float(b["t"]) <= 0.0:
			buffs.erase(id)
	ward_t -= delta
	if ward_t <= 0.0:
		ward = 0.0
	if not _buff_flag("thrall_time_paused"):
		life -= delta
	_cd -= delta
	if life <= 0.0 or hp <= 0.0:
		_fall()
		return
	if heal_per_s > 0.0 and is_instance_valid(caster):
		_heal_acc += delta
		if _heal_acc >= 0.5:
			caster.call("summon_heals", self, heal_per_s * _heal_acc, heal_radius)
			_heal_acc = 0.0
	velocity = Vector3.ZERO
	var moving := false
	if behaviour == "follow":
		moving = _follow(delta)
	else:
		var foe: Node3D = _pick_foe()
		if foe != null:
			var to: Vector3 = foe.global_position - global_position
			to.y = 0.0
			if to.length() > 0.05:
				rotation.y = atan2(-to.x, -to.z)
			if to.length() > reach + float(foe.get("radius")):
				move_and_collide(to.normalized() * minf(speed * delta, to.length()))
				moving = true
			elif _cd <= 0.0 and is_instance_valid(caster):
				_strike(foe)
	if _rig != null and _rig.has_method("animate"):
		_rig.call("animate", delta, speed if moving else 0.0, _cd > attack_s - 0.25)


## Whom it goes for: an enemy its caster has marked for summons (Bidden, Quarry) if one stands, else the nearest.
func _pick_foe() -> Node3D:
	var best: Node3D = null
	var marked := false
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null or bool(e.call("is_dead")):
			continue
		var is_marked: bool = e.has_method("status_from") and not (e.call("status_from", "summons_target", caster) as Array).is_empty()
		if best == null or (is_marked and not marked) or (is_marked == marked and e.global_position.distance_to(global_position) < best.global_position.distance_to(global_position)):
			best = e
			marked = is_marked
	return best


## One blow: its damage, sharpened by what is on it and what its caster marked the foe with, through the caster.
func _strike(foe: Node3D) -> void:
	var rate: float = buff_num("attack_rate_mult", "thrall_rate_mult") * buff_num("thrall_rate_mult")
	var dmg: float = damage * buff_num("damage_mult") * buff_num("thrall_damage_mult") * buff_num("summon_deals_mult")
	if foe.has_method("status_from"):
		var m: Array = foe.call("status_from", "summons_target", caster)
		if not m.is_empty():
			var def: Dictionary = GameData.status(str(m[0]))
			var data: Dictionary = (m[1] as Dictionary).get("data", {})
			dmg *= float(data.get("summon_damage_mult", def.get("summon_damage_mult", 1.0)))
			rate *= float(data.get("summon_rate_mult", def.get("summon_rate_mult", 1.0)))
	_cd = attack_s / maxf(0.1, rate)
	var hit: Dictionary = on_hit.duplicate()
	hit["damage"] = dmg
	caster.call("apply_hit", foe, hit, tags + ["thrall"])
	var regrow: float = heal_per_hit
	for id: String in buffs:
		regrow += float((buffs[id] as Dictionary).get("heal_per_hit", 0.0))
	if regrow > 0.0 and is_living:
		hp = minf(hp_max, hp + regrow)            # Overgrowth on a beast: its own bite regrows it


## A follower keeps beside its caster (Heartseed): it walks back when it strays.
func _follow(delta: float) -> bool:
	if not is_instance_valid(caster):
		return false
	var to: Vector3 = (caster as Node3D).global_position - global_position
	to.y = 0.0
	if to.length() <= 2.0:
		return false
	rotation.y = atan2(-to.x, -to.z)
	move_and_collide(to.normalized() * minf(speed * delta, to.length() - 1.5))
	return true


func is_dead() -> bool:
	return dead


## Regrow `points` (a living summon only), up to its health when raised.
func heal(points: float) -> void:
	if is_living and not dead:
		hp = minf(hp_max, hp + points)


## A ward over it (Dawnward's summon_ward; Holy's wards cover summons), up to the one cap, for `lasts` s.
func add_ward(amount: float, lasts: float) -> void:
	ward = minf(GameData.num("ward", "cap"), ward + amount)
	ward_t = maxf(ward_t, lasts)


func take_hit(amount: float, _heavy: bool, _source: Node, _tags: Array = []) -> float:
	if dead:
		return 0.0
	var a: float = amount * buff_num("incoming_mult") * buff_num("thrall_incoming_mult")
	if is_instance_valid(caster) and caster.has_method("ally_zone_mult"):
		a *= float(caster.call("ally_zone_mult", self))        # standing on its caster's Hallowed Ground
	if ward > 0.0:
		var took: float = minf(ward, a)
		ward -= took
		a -= took
	hp -= a
	if _rig != null and _rig.has_method("flash"):
		_rig.call("flash", 0.1)
	if hp <= 0.0:
		_fall()
	return a


func claim_slot(_enemy: Node) -> bool:
	return true


func release_slot(_enemy: Node) -> void:
	pass


func shove(_dir: Vector3, _metres: float) -> void:
	pass


func _fall() -> void:
	dead = true
	remove_from_group("lures")
	remove_from_group("thralls")
	queue_free()
