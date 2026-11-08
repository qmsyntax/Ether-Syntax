class_name PlayerBot
extends RefCounted
## The player's part for the bot driver (the scripted test player) and test characters.
## A part of the player (scripts/player.gd), split out by concern: it holds this concern's logic and its
## private state; everything shared or saved stays on the player, reached through `player`.
## Map and pattern: docs/architecture/player-split.md.

var player: Player

var _bot_path := NavPath.new()


func _init(of: Player) -> void:
	player = of


## A test character (title screen "Test characters"): this one affinity, and every skill of it
## learned in tree order (any not on the tree after), each at balance.skills.test_stage (0: Brent
## 2026-10-23 - a test character walks through every level lock in order, vestige to asura, on the
## seal screen like anyone else) with its bar full. TEST OVERRIDES: the stage cap is stars + 1, so it
## is given balance.skills.test_stars full stars (4: the asura lock is reachable) - a full tank; it
## carries test_constructs_each of every construct; and after each bind that takes, its bar is filled
## again (test_refill_after_bind, in _bind_seal). The first six skills are on the bar; the
## hotbar_page key shows the next six.
func make_test_character(aff: String) -> void:
	player.set_affinities([aff])
	player.test_character = true
	player.hotbar_page = 0
	var n: int = GameData.inum("skills", "test_stars")
	player.stars = n
	player.star_pct.clear()
	for i: int in n:
		player.star_pct.append(GameData.num("stars", "max_pct"))
	player._recompute_essence_max()
	player.essence = player.essence_max
	var ids: Array[String] = []
	for id: String in GameData.skill_tree_of(aff):
		ids.append(id)
	for id: String in GameData.abilities:
		if str(GameData.ability(id).get("affinity", "")) == aff and not ids.has(id):
			ids.append(id)
	player.abilities.clear()
	for i: int in player.hotbar.size():
		player.hotbar[i] = -1
	var stage: int = mini(GameData.inum("skills", "test_stage"), player.stars + 1)
	for id: String in ids:
		player.abilities.append({"id": id, "stage": stage, "progress": 100.0})       # full bars: ready for the first lock
	for i: int in mini(player.hotbar.size(), player.abilities.size()):
		player.hotbar[i] = i
	# every construct tier, test_constructs_each of every word that fits it, to bind with (Brent 2026-10-23;
	# words since 2026-11-04: a vestige of every rune, the authored words above - only those this
	# character's skills can take, its affinities' and the universal ones)
	player.constructs.clear()
	for tier: Variant in GameData.construct_tiers:
		for concept: Variant in GameData.construct_word_ids(str(tier)):
			if not bool(player.construct_fits(str(tier), str(concept))["ok"]):
				continue
			for k: int in GameData.inum("skills", "test_constructs_each"):
				player.constructs.append({"tier": str(tier), "concept": str(concept)})
	player.note("TEST CHARACTER: every %s skill, stage %d, each ready for its level lock (the ethercosm). %s turns the skill bar to the next six." % [
		str(GameData.affinity(aff).get("label", aff)).to_lower(), stage, Keybinds.binding_text("hotbar_page")])


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for node: Node in player.get_tree().get_nodes_in_group("enemies"):
		var e := node as Node3D
		if e == null or bool(e.call("is_dead")):
			continue
		var d: float = e.global_position.distance_to(player.global_position)
		if d < best_d:
			best_d = d
			best = e
	return best


## Test bot: returns true when it wants to swing.
func _bot_think(delta: float = 0.0) -> bool:
	var near: Node3D = _nearest_enemy()
	var goal: Vector3 = near.global_position if near != null else player.bot_goal
	var to: Vector3 = goal - player.global_position
	to.y = 0.0
	var dist: float = to.length()
	player._bot_dir = _bot_way(goal, delta) if dist > 0.6 else Vector3.ZERO
	if dist > 0.2:
		player._facing = to / dist
	if near == null:
		return false
	return dist <= player.reach_now() + float(near.get("radius"))


## Test bot: the way to walk to `goal` - along the level's navigation mesh, or where there is
## none yet through the passage's doorway (Route, via the `router` group), else straight.
func _bot_way(goal: Vector3, delta: float) -> Vector3:
	var nav: LevelNav = LevelNav.find(player.get_tree(), player.global_position)
	if nav != null:
		var way: Vector3 = _bot_path.steer(nav, player.global_position, goal, 0.4, delta)
		if way != Vector3.ZERO or _bot_path.blocked:
			return way
	var next: Vector3 = goal
	var router: Node = player.get_tree().get_first_node_in_group("router")
	if router != null:
		next = router.call("route", player.global_position, goal, 0.4)
	var flat := Vector3(next.x - player.global_position.x, 0.0, next.z - player.global_position.z)
	return flat.normalized() if flat.length() > 0.05 else Vector3.ZERO
