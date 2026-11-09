class_name MainStates
extends RefCounted
## main.state - the one string that says which part of the game is running - and the level controller that
## runs each value (docs/architecture/main-split.md). The string itself stays on the node, unchanged: the HUD,
## the screens, Light, FieldCamps and the tests read it (and the tests and shots set it) by name.
##
##   "select"                      the title: character creation and the test characters (MainSession._show_select).
##                                 No level controller; the town is built behind it.
##   "town"                        MainTown      (MainTown._enter_town)
##   "field"                       MainField     (MainField.enter_zone)
##   "dungeon"                     MainPassage   (MainPassage._enter_dungeon)
##   "arena_rest", "arena_fight"   MainArena     (MainArena._enter_arena; the arena moves itself between the two)
##   "dead"                        the hardcore death notice (MainSession._on_player_died). No level controller.
##
## Each controller's enter function is the only way into its state; the level that was standing is thrown
## away by LevelFactory._new_level. The Netherecho is not a state: it lies over "field", "dungeon" and
## "arena_rest" while nether.active (MainNether and the Netherecho node), and the level's own controller
## keeps ticking under it.
##
## Each frame Main._process calls the running controller's `tick`, Main._unhandled_input its `handle_input`
## (after the keys every state shares), and Main._where its `where`.


## The level controller that runs `state`, or null (the title, the hardcore death notice).
static func controller(main: Main, state: String) -> MainLevel:
	match state:
		"town":
			return main.town_part
		"field":
			return main.field_part
		"dungeon":
			return main.passage_part
		"arena_rest", "arena_fight":
			return main.arena_part
	return null
