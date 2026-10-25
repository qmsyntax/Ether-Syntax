class_name GroundZone
extends Node3D
## A patch of ground that does something to enemies standing in it: a line of flame, a pool, a
## lane of wind, a cloud, a pall of dark. A "strip" runs from `from` to `to`, `width` across; a
## "circle" is `radius` round `from`. It lasts `life` seconds. Every `tick_s` it applies `payload`
## (a hit payload, see Player.apply_hit) and `extra_status` to each enemy inside, through `caster`,
## so that talents and affinity rules see it as the caster's doing; `on_enter` lands once on each
## enemy, when it is first inside. A ticking payload applies a hold (a status marked control, or an
## interrupt) at most once per target for the zone's life (`_once`). Every frame it pushes them
## `push_per_s` along the strip and drags them `pull_per_s` toward a circle's middle; a circle may
## drift `drift_speed` along `drift_dir`. The rest is read by others: `shove_mult` by an enemy being
## shoved from inside it; `caster_speed_mult` / `pip_gain_mult` / `freeze_pips` / `shed_standing` by
## the caster standing in it; `dark` by Light.level_at; `blocks_sight` / `hides` by an enemy's line
## of sight; `banks` (a status that does not run down inside), `no_heal` and `blocks_status` by the
## enemies inside; `kind` ("cloud", "dark_ground") by skills that look for zones of a kind.

var shape := "strip"
var from := Vector3.ZERO
var to := Vector3.ZERO
var width := 1.0
var radius := 0.0
var life := 3.0
var tick_s := 1.0
var payload: Dictionary = {}
var on_enter: Dictionary = {}
var extra_status := ""
var shove_mult := 1.0
var push_per_s := 0.0
var pull_per_s := 0.0
var drift_vel := Vector3.ZERO
var caster_speed_mult := 1.0
var pip_gain_mult := 1.0
var tags: Array = []
var caster: Node
var color := Color(1.0, 0.5, 0.2)
## Drawn hot (fire) or as a faint wash (water, wind).
var bright := true
## A bright zone lights this far round its middle (0: it lights nothing).
var light_radius := 0.0
var kind := ""
var dark := false
var dark_extra_ticks := 0
var blocks_sight := false
var hides := false
var banks := ""
var no_heal := false
var blocks_status: Array = []
var ends_status: Array = []
var kill_projectiles := false
var freeze_pips := false
var shed_standing := false
var ends_if_left := false
var overrun_at := 0
## v2 (2026-10-24): a status's damage over time ticks this much harder on enemies inside ({status: x}, Smokepall);
## a bill (an on_expire damage) paid on an enemy inside is x(1 + bill_bonus) (Clean Air's dose_bonus); the caster's
## hits on an enemy inside carrying a status do this much more ({status: fraction}, Dusk Well's lit_bonus).
var dps_mult: Dictionary = {}
var bill_bonus := 0.0
var bonus_vs: Dictionary = {}
## v2: what it does each tick to you and your summons inside it (Hallowed Ground's ally_payload: ward_per_s up to
## ward_max from this zone, damage_taken_mult while inside)
var ally_payload: Dictionary = {}
## v2: a zone that goes where this body goes (an aura of dark, Gloom Mantle)
var follow: Node3D = null

var _tick := 0.0
var _mesh: MeshInstance3D
var _entered: Dictionary = {}       # enemy instance id -> true, for on_enter
var _once: Dictionary = {}          # holds already applied by a tick, per target (Player.apply_hit)
var _overrun: Dictionary = {}
var _extra_left := -1


func _ready() -> void:
	add_to_group("ground_zones")
	_mesh = MeshInstance3D.new()
	var mat := StandardMaterial3D.new()
	var c: Color = Color(0.08, 0.05, 0.14) if dark else color
	mat.albedo_color = Color(c, 0.55 if bright else (0.62 if dark else 0.3))
	mat.emission_enabled = not dark
	mat.emission = color
	mat.emission_energy_multiplier = 1.6 if bright else 0.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mesh.material_override = mat
	if shape == "circle":
		var disc := CylinderMesh.new()
		disc.top_radius = radius
		disc.bottom_radius = radius
		disc.height = 0.06
		disc.radial_segments = 40
		_mesh.mesh = disc
		add_child(_mesh)
		global_position = from + Vector3.UP * 0.04
		return
	var length: float = from.distance_to(to)
	if length < 0.05:
		return
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.06, length)
	_mesh.mesh = box
	add_child(_mesh)
	global_position = (from + to) * 0.5 + Vector3.UP * 0.04
	look_at(Vector3(to.x, global_position.y, to.z), Vector3.UP)


func _physics_process(delta: float) -> void:
	tick(delta)


## One step of the zone's life. Public so a test can run it by hand.
func tick(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		# a dark echo: in the Dark the zone runs a few more ticks
		if dark_extra_ticks > 0 and _extra_left < 0 and Light.is_dark(get_tree() if is_inside_tree() else null, from):
			_extra_left = dark_extra_ticks
		if _extra_left <= 0:
			queue_free()
			return
	if ends_if_left and is_instance_valid(caster) and not has_point((caster as Node3D).global_position):
		queue_free()
		return
	if follow != null and is_instance_valid(follow):
		var at: Vector3 = Vector3(follow.global_position.x, from.y, follow.global_position.z)
		global_position += at - from
		to += at - from
		from = at
	if drift_vel != Vector3.ZERO and shape == "circle":
		var step: Vector3 = drift_vel * delta
		if not is_inside_tree() or get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.6, from + Vector3.UP * 0.6 + step.normalized() * (step.length() + radius * 0.5), 1)).is_empty():
			from += step
			to += step
			global_position += step
	var now: Array[Node3D] = inside()
	if push_per_s != 0.0 and shape == "strip":
		var along: Vector3 = to - from
		along.y = 0.0
		if along.length() > 0.05:
			for e: Node3D in now:
				e.call("nudge", along.normalized() * push_per_s * delta)
	if pull_per_s != 0.0 and shape == "circle":
		for e: Node3D in now:
			var inward: Vector3 = from - e.global_position
			inward.y = 0.0
			if inward.length() > 0.3:
				e.call("nudge", inward.normalized() * minf(pull_per_s * delta, inward.length()))
	for e: Node3D in now:
		for st: Variant in ends_status:
			e.call("clear_status", str(st))
	if kill_projectiles and is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group("enemy_shots"):
			var shot := node as Node3D
			if shot != null and has_point(shot.global_position):
				shot.queue_free()
	if not on_enter.is_empty() and is_instance_valid(caster):
		for e: Node3D in now:
			if not _entered.has(e.get_instance_id()):
				_entered[e.get_instance_id()] = true
				caster.call("apply_hit", e, on_enter, tags + ["enter"])
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = tick_s
	if _extra_left > 0:
		_extra_left -= 1
	if not ally_payload.is_empty() and is_instance_valid(caster) and caster.has_method("zone_ally_tick"):
		caster.call("zone_ally_tick", self)
	for e: Node3D in inside():
		if extra_status != "":
			e.call("add_status", extra_status)
		if not payload.is_empty() and is_instance_valid(caster) and caster.has_method("apply_hit"):
			caster.call("apply_hit", e, payload, tags, 1.0, Vector3.ZERO, _once)
		if overrun_at > 0 and is_instance_valid(e) and not bool(e.call("is_dead")) and not _overrun.has(e.get_instance_id()) \
				and int(e.call("status_stacks", "infected")) >= overrun_at:
			_overrun[e.get_instance_id()] = true
			e.call("stagger", float(GameData.status("staggered").get("lasts", 1.5)))


## True if a body of radius `margin` at `point` touches the zone.
func has_point(point: Vector3, margin: float = 0.0) -> bool:
	var p := Vector2(point.x, point.z)
	var a := Vector2(from.x, from.z)
	if shape == "circle":
		return p.distance_to(a) <= radius + margin
	return Geometry2D.get_closest_point_to_segment(p, a, Vector2(to.x, to.z)).distance_to(p) <= width * 0.5 + margin


## True if the straight line a-b passes through it (for sight that it blocks).
func crosses(a: Vector3, b: Vector3) -> bool:
	var pa := Vector2(a.x, a.z)
	var pb := Vector2(b.x, b.z)
	var c := Vector2(from.x, from.z)
	if shape == "circle":
		return Geometry2D.get_closest_point_to_segment(c, pa, pb).distance_to(c) <= radius
	return Geometry2D.segment_intersects_segment(pa, pb, c, Vector2(to.x, to.z)) != null or has_point(a) or has_point(b)


## The enemies standing in it right now.
func inside() -> Array[Node3D]:
	var out: Array[Node3D] = []
	if not is_inside_tree():
		return out
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null or bool(e.call("is_dead")):
			continue
		if has_point(e.global_position, float(e.get("radius"))):
			out.append(e)
	return out


## Lift it now (Daybreak, Blowout).
func end() -> void:
	remove_from_group("ground_zones")
	queue_free()
