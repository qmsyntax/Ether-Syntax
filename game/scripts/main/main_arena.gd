class_name MainArena
extends MainLevel
## The practice arena (main.state "arena_rest" / "arena_fight"): its level, the rest between waves and the
## waves themselves. Moved out of main.gd as it was (docs/architecture/main-split.md).

## Each frame in the arena: the rest's countdown to the next wave, or the wave being fought.
func tick(delta: float) -> void:
	match main.state:
		"arena_rest":
			main.rest_timer -= delta
			main._prompt = "Wave %d in %d   -   pick up what the last one left before it starts\n%s go now     %s rest longer     %s healer     hold %s to meditate     %s back to town" % [
				main.wave + 1, int(ceil(main.rest_timer)),
				main._k("go_now"), main._k("rest"), main._k("healer"), main._k("meditate"), main._k("interact")]
			if main.rest_timer <= 0.0:
				_start_wave()
		"arena_fight":
			main._prompt = ""
			if main.get_tree().get_nodes_in_group("enemies").is_empty():
				main.player.end_fight()
				main.state = "arena_rest"
				main.rest_timer = GameData.num("arena", "rest_between_waves")
				main._prebuild_bodies(_wave_kinds(main.wave + 1))     # built during the rest
				main.player.note("Wave %d cleared." % main.wave)


## The keys in the arena: skills, ascend, the seal, and (resting) go now, rest longer, the healer, back to town.
func handle_input(event: InputEvent) -> void:
	if main._cast_from_hotbar(event):
		pass
	elif event.is_action_pressed("ascend"):
		main.player.try_ascend()
	elif event.is_action_pressed("bind"):
		main.open_seal_first_ready()
	elif event.is_action_pressed("go_now"):
		if main.state == "arena_rest":
			main.rest_timer = 0.0
	elif event.is_action_pressed("rest"):
		if main.state == "arena_rest":
			main.rest_timer += GameData.num("arena", "rest_extend")
			main.player.note("You rest a while longer. The landlord notices.")
	elif event.is_action_pressed("healer"):
		if main.state == "arena_rest":
			main.player.buy_healing()
		else:
			main.player.note("The healer won't come in here mid-fight.")
	elif event.is_action_pressed("interact"):
		if main.state == "arena_rest":
			main._enter_town("arena")


func where() -> String:
	return "Practice arena  -  wave %d" % main.wave


func enter_arena() -> void:
	main._show_screen(null, false)
	_enter_arena()


func _enter_arena() -> void:
	main.factory_part._new_level(0.0)
	var bcfg: Dictionary = GameData.balance["biomes"]
	main.factory_part._use_biome(bcfg["arena"])
	var span: float = main.arena_half * 2.0 + 2.0
	main._biome_floor(Vector3.ZERO, Vector2(span, span))
	# tall on the far sides, low on the camera's side so the floor is not hidden
	main._biome_wall(Vector3(0, 0, -main.arena_half - 0.5), span, 0.0, float(bcfg["wall_height_far"]))
	main._biome_wall(Vector3(-main.arena_half - 0.5, 0, 0), span, 90.0, float(bcfg["wall_height_far"]))
	main._biome_wall(Vector3(0, 0, main.arena_half + 0.5), span, 180.0, float(bcfg["wall_height_near"]))
	main._biome_wall(Vector3(main.arena_half + 0.5, 0, 0), span, -90.0, float(bcfg["wall_height_near"]))
	main.factory_part._scatter_props(Vector3.ZERO, Vector2(main.arena_half - 0.5, main.arena_half - 1.5), int(bcfg["arena_props"]))
	# standing blocks: something for a shove to end against, and for a beam to stop on (design/05 6.2)
	var block: Array = GameData.balance["arena"]["block_size"]
	for at: Array in GameData.balance["arena"]["blocks"]:
		main._static_box(Vector3(float(at[0]), float(block[1]) * 0.5, float(at[1])), Vector3(float(block[0]), float(block[1]), float(block[2])),
			(main._biome.get("wall_color", Color(0.3, 0.3, 0.33)) as Color).lightened(0.12))
	for i: int in GameData.inum("arena", "scenery_count"):
		var pos := Vector3.ZERO
		for attempt: int in 8:
			pos = Vector3(main.rng.randf_range(-main.arena_half + 1.5, main.arena_half - 1.5), 0.0, main.rng.randf_range(-main.arena_half + 1.5, main.arena_half - 1.5))
			if pos.length() > 3.0:
				break
		main._spawn_cuttable(0 if i % GameData.inum("arena", "bush_every_n") == 0 else i * 2 + 2, pos)
	for q: Vector3 in [Vector3(-8, 0, -8), Vector3(8, 0, -8), Vector3(-8, 0, 8), Vector3(8, 0, 8)]:
		main.nether.populate_site(q, Vector2(6.0, 6.0))
	main.player.global_position = Vector3.ZERO
	main.player.active = true
	main.factory_part._place_corpses("arena")
	# every kind the waves bring, loaded with the level: by the wave after the last threshold all have come
	var last: int = 1
	for key: String in GameData.balance["arena"]:
		if key.ends_with("_every_n_waves") or key.ends_with("_from_wave"):
			last = maxi(last, GameData.inum("arena", key) + 1)
	var roster: Array[String] = []
	for w: int in range(1, last + 1):
		roster.append_array(_wave_kinds(w))
	main.factory_part._warm_bodies(roster + main.factory_part._calls_of(roster))
	main._prebuild_bodies(_wave_kinds(1))
	main.wave = 0
	main.rest_timer = GameData.num("arena", "first_rest")
	main.state = "arena_rest"


func _start_wave() -> void:
	main.wave += 1
	main.state = "arena_fight"
	main.hud.announce("WAVE %d" % main.wave)
	main.player.start_fight()
	var kinds: Array[String] = _wave_kinds(main.wave)
	for kind: String in kinds:
		_spawn_arena_enemy(kind)
	main._prebuild_bodies(main.factory_part._calls_of(kinds))


## Who comes in arena wave `w`, in the order they are placed.
func _wave_kinds(w: int) -> Array[String]:
	var kinds: Array[String] = []
	for i: int in GameData.inum("arena", "grunts_base") + w:
		kinds.append("grunt")
	for i: int in w / GameData.inum("arena", "brute_every_n_waves"):
		kinds.append("brute")
	for i: int in w / GameData.inum("arena", "archer_every_n_waves"):
		kinds.append("archer")
	for i: int in w / GameData.inum("arena", "harrier_every_n_waves"):
		kinds.append("harrier")
	for i: int in w / GameData.inum("arena", "pavise_every_n_waves"):
		kinds.append("pavise")
	# one problem per pack: never more than one of each
	if w >= GameData.inum("arena", "censer_from_wave") and w % 2 == 1:
		kinds.append("censer")
	if w >= GameData.inum("arena", "drummer_from_wave"):
		kinds.append("drummer")
	return kinds


func _spawn_arena_enemy(kind: String) -> void:
	var angle: float = main.rng.randf() * TAU
	main.factory_part._spawn_enemy(kind, Vector3(cos(angle), 0.0, sin(angle)) * (main.arena_half - 3.0), 1.0)
