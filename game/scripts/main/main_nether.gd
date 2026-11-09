class_name MainNether
extends RefCounted
## main.gd's side of the Netherecho. The spirit layer has its own controller, the `Netherecho` node
## (scripts/nether/netherecho.gd) that main.gd owns, ticks and gives each level's sites; it is not a state of its
## own but an overlay on the field, the passage and the arena's rest (nether.active). This part leaves the body
## and returns to it (toggle_projection), answers the Netherecho's and the body's signals (connected to the
## node's forwarders), and sets the look of the waking world or of its echo. Moved out of main.gd as it was
## (docs/architecture/main-split.md).

var main: Main


func _init(of: Main) -> void:
	main = of


## Leave the body, or return to it. Only possible out of combat, in the field.
func toggle_projection() -> void:
	if main.nether.active:
		main.nether.exit("You return to your body.")
		return
	if main.state != "dungeon" and main.state != "arena_rest" and main.state != "field":
		main.player.note("There is nothing to find in the echo of this place." if main.state == "town" else "Not now.")
		return
	var why: String = main.nether.cannot_enter_reason()
	if why != "":
		main.player.note(why)
		return
	main.nether.enter()


func _on_nether_entered() -> void:
	_set_nether_look(true)
	main.hud.announce("THE NETHERECHO")
	main.player.note("You step out of yourself.")


func _on_nether_exited(reason: String) -> void:
	_set_nether_look(false)
	main._prompt = ""
	if reason != "":
		main.player.note(reason)


## Something hit the body while the soul was away.
func _on_body_disturbed() -> void:
	if main.nether.active:
		main.nether.exit("Pain drags you back into your body.")


## Canon: a destroyed projection is death. Standard mode turns that into debt like any other death.
func _on_projection_destroyed() -> void:
	main.player.note("Your soul is torn apart in the echo.")
	(main.player.body as Body).apply_damage(99999.0)
	main.player.check_death()


## The echo of a place: dark, violet, lit from nowhere. Living enemies and loose loot do not show.
func _set_nether_look(on: bool) -> void:
	# the waking world looks like its biome; the echo of any place is the same dark violet
	main._env.background_color = Color(0.03, 0.015, 0.07) if on else main._biome.get("sky", Color(0.045, 0.05, 0.065))
	main._env.ambient_light_color = Color(0.5, 0.42, 0.95) if on else main._biome.get("ambient", Color(0.5, 0.56, 0.7))
	var boost: float = float((GameData.balance["biomes"]["ambient_boost"] as Dictionary).get(main.biome, 1.0))
	main._env.ambient_light_energy = 0.75 if on else float(main._biome.get("ambient_energy", 0.6)) * boost
	main._env.fog_light_color = Color(0.1, 0.05, 0.2) if on else main._biome.get("fog_color", Color(0.1, 0.11, 0.14))
	main._env.fog_density = 0.006 if on else float(main._biome.get("fog_density", 0.006))
	main._sun.light_energy = 0.18 if on else float(main._biome.get("sun_energy", 1.35))
	main._sun.light_color = Color(0.7, 0.6, 1.0) if on else main._biome.get("sun_color", Color(1.0, 0.87, 0.72))
	main._sun.rotation_degrees = main._biome.get("sun_rotation", Vector3(-44.0, 38.0, 0.0))
	for group: String in ["enemies", "pickups"]:
		for n: Node in main.get_tree().get_nodes_in_group(group):
			if n is Node3D:
				(n as Node3D).visible = not on
