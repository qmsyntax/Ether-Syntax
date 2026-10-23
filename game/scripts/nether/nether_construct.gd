extends Node3D
## A wild ether construct: a concept given form. It wants nothing (Brent 2026-09-18); it simply is,
## and some of them simply attack. Beat it down and it is subdued, not killed - it can then be
## carried out and bound into an ability.

signal subdued(construct: Node)

var tier := "vestige"
var concept := "tension"
var display_name := "Vestige"
var body: Body
var height := 0.9
var radius := 0.45
var highlight := 0
var is_scenery := false
## Docile constructs ignore you... until, without warning, one does not.
var docile := false
var hostile := false
var target: Node3D                 # the projection, while there is one

var _model: Node3D
var _home := Vector3.ZERO
var _wander := Vector3.ZERO
var _wander_t := 0.0
var _attack_cd := 0.8
var _windup := -1.0
var _strike_t := 0.0
var _shown_highlight := 0
var _shown_windup := false
var _speed := 3.0
var _damage := 4.0
var _cooldown := 1.4
var _windup_time := 0.5
var _reach := 1.6
var _cfg: Dictionary
var rng := RandomNumberGenerator.new()


func setup(construct_tier: String, construct_concept: String, is_docile: bool) -> void:
	tier = construct_tier
	concept = construct_concept
	docile = is_docile
	rng.randomize()
	_cfg = GameData.balance["nether"]
	var wild: Dictionary = GameData.wild_construct(tier)
	body = Body.new(float(wild.get("hp", 90.0)))
	height = float(wild.get("height", 0.9))
	radius = float(wild.get("radius", 0.45))
	_speed = float(wild.get("speed", 3.0))
	_damage = float(wild.get("damage", 4.0))
	_cooldown = float(wild.get("cooldown", 1.4))
	_windup_time = float(wild.get("windup", 0.5))
	_reach = float(wild.get("reach", 1.6))
	display_name = "%s of %s" % [tier.capitalize(), str(GameData.concept(concept).get("label", concept.capitalize()))]
	_model = NetherArt.construct(tier, concept, height, radius)
	add_child(_model)
	add_to_group("nether_hittable")
	add_to_group("nether_enemies")


## Made weaker (or stronger) than its tier's wild numbers: a zone for new characters scales its
## constructs to a new character's projection (zones.json "nether").
func scale_for(hp_mult: float, damage_mult: float) -> void:
	body = Body.new(body.total_max() * hp_mult)
	_damage *= damage_mult


func _ready() -> void:
	_home = position
	_wander = _home


func is_dead() -> bool:
	return body.is_dead()


func set_highlight(level: int) -> void:
	highlight = level


func take_hit(amount: float, _heavy: bool, _source: Node, _tags: Array = []) -> float:
	var applied: float = body.apply_damage(amount)
	hostile = true                      # nothing stays docile once struck
	NetherArt.look(_model, "flash", 0.12)
	if body.is_dead():
		remove_from_group("nether_hittable")
		remove_from_group("nether_enemies")
		subdued.emit(self)
		queue_free()
	return applied


## Driven by the Netherecho controller while a projection is out.
func tick(delta: float) -> void:
	if body.is_dead():
		return
	_attack_cd -= delta
	_strike_t -= delta
	var move := Vector3.ZERO
	var has_target: bool = target != null and is_instance_valid(target)
	var to := Vector3.ZERO
	var dist := INF
	if has_target:
		to = target.global_position - global_position
		to.y = 0.0
		dist = to.length()
		if not hostile and dist <= float(_cfg["aggro_radius"]):
			if not docile:
				hostile = true
			elif rng.randf() < float(_cfg["docile_snap_chance_per_s"]) * delta:
				hostile = true           # the quiet ones turn without warning

	if hostile and has_target:
		if _windup >= 0.0:
			_windup -= delta
			if _windup < 0.0:
				if dist <= _reach + radius:
					target.call("take_hit", _damage, false, self)
				_attack_cd = _cooldown
				_strike_t = 0.22
		elif dist > _reach * 0.75 + radius:
			move = to / maxf(dist, 0.001) * _speed
		elif _attack_cd <= 0.0:
			_windup = _windup_time
	else:
		# idle: drift between points near home
		_wander_t -= delta
		if _wander_t <= 0.0:
			_wander_t = rng.randf_range(2.0, 5.0)
			var a: float = rng.randf() * TAU
			_wander = _home + Vector3(cos(a), 0.0, sin(a)) * rng.randf() * float(_cfg["wander_radius"])
		var tw: Vector3 = _wander - global_position
		tw.y = 0.0
		if tw.length() > 0.3:
			move = tw.normalized() * _speed * 0.35

	global_position += move * delta
	if move.length() > 0.05:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-move.x, -move.z), minf(1.0, delta * 10.0))
	elif hostile and has_target and dist > 0.1:
		_model.rotation.y = lerp_angle(_model.rotation.y, atan2(-to.x, -to.z), minf(1.0, delta * 10.0))

	var winding: bool = _windup >= 0.0
	if winding != _shown_windup:
		_shown_windup = winding
		NetherArt.look(_model, "set_windup", winding)
	if highlight != _shown_highlight:
		_shown_highlight = highlight
		NetherArt.look(_model, "set_highlight", highlight)
	if _model.has_method("animate"):
		_model.call("animate", delta, move.length(), _strike_t > 0.0)
