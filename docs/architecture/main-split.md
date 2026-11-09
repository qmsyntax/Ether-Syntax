# main.gd, split by concern

Phase 2, step 2 of `production/finish-plan.md` (2026-11-08). `game/scripts/main.gd` was one 3,814-line script with
165 functions: the game's state, every level type, the screens, saving, and the test and screenshot harness. It is
now the `Main` node plus thirteen scripts in `scripts/main/` - the state machine (`MainStates`), the level
controller's interface (`MainLevel`) and eleven parts - and no behaviour changed: the suite, the timeline and
cast-every-skill output, the self-test count and the duels table are the same before and after, step by step (one
commit per concern). It follows the player split (`docs/architecture/player-split.md`) and its pattern.

## The pattern: one node, parts that hold the logic

- **One node.** `scripts/main.gd` is `class_name Main`, still the root of `main.tscn`. It keeps the signal
  (`replaced`), the lifecycle (`_init`, `_ready`, `_process`, `_unhandled_input`, `_exit_tree`), the camera, the
  keys every state shares, building the player and the HUD, the restart, the run mode (`_plays`, `_under_test`), the
  helpers the level controllers share (`_cast_from_hotbar`, `_flat_dist`, the rune stones, `_k`), and every
  variable that is read from outside or shared between parts.
- **Parts.** Each concern is a `RefCounted` in `scripts/main/` with a typed back-reference `var main: Main`, made in
  `Main._init` and held in a typed field (`town_part: MainTown`). A part reaches the node and its state through
  `main` (`main.player`, `main.level`, `main.get_tree()`, `main.add_child(...)`), and another part through it
  (`main.factory_part._new_level(...)`). `self` in the old code became `main` (`TalkScreen.new(main, role)`), so the
  screens and builders still hold the node. Calls stay typed and are checked when the script loads.
- **Forwarders keep outside callers unchanged.** The end of `main.gd` has one-line forwarders, one block per part,
  for every moved function that anything outside `main.gd` and its parts names: the UI screens, the HUD, `Light`,
  `TownBuilder` / `ZoneBuilder`, `FieldCamps`, `Netherecho`, the enemies' `router` lookup (`route`), town.json's gate
  actions (`walk_out`, `enter_arena`, `enter_passage`, called by name) and the tests (including `call("_x")` strings
  and private helpers). State stayed on the node, so every `main.get("x")` / `set("x")` works as before.
- **Signal connections are the same.** Every signal is still connected to a method of the node: the handlers
  (`_on_player_died`, `_on_body_disturbed`, `_on_rune_discovered`, `_on_ascended`, `_on_nether_entered`,
  `_on_nether_exited`, `_on_projection_destroyed`, `_on_reinforcements`, `_on_settings_closed`) are forwarders, and
  the parts that connect them (`LevelFactory._build_world`, `_spawn_enemy`, `MainScreens._open_settings`) connect the
  node's, as the old code did.
- **Scene tree and timing are the same.** Parts are not nodes: the tree has the same nodes, names and order, every
  `add_child` happens on the same node at the same moment, `_process` and `_unhandled_input` do the same work in
  the same order, and the RNG (`main.rng`, still on the node) is drawn in the same order.

## Where things are (line counts at the split)

| File | Class (field on Main) | Holds |
|---|---|---|
| `scripts/main.gd` (564) | `Main` | the `replaced` signal; the passage / arena / town tuning numbers; the shared state (74 variables); `_init` (the parts), `_ready`, `_process`, `_unhandled_input` (Esc, the screen keys, then the running level's), the camera, `_cast_from_hotbar`, `_k`, `_plays` / `_under_test`, `restart_game`, `_flat_dist`, `light_base`, the rune stones, `_build_player` / `_build_hud`, `_where`; 81 forwarders |
| `main/main_states.gd` (35) | `MainStates` (static) | the state machine: what each value of `main.state` means and which controller runs it (`controller(main, state)`) |
| `main/main_level.gd` (28) | `MainLevel` | the controller interface: `tick(delta)`, `handle_input(event)`, `where()` |
| `main/main_town.gd` (284) | `MainTown` (`town_part`) | state "town": building the town, arriving, who is in reach, clicks that walk you to someone, gateways and the passage door, the trainer, crafting (stations and field kits), the town services |
| `main/main_field.gd` (205) | `MainField` (`field_part`) | state "field": walking out, building a zone and its camps, the lines, fog and minimap, the Cut House door, entrances, the field autosave, your place in the save |
| `main/main_passage.gd` (341) | `MainPassage` (`passage_part`) | state "dungeon": the corridor, the seal, walls, exits, rent, spoils and exit rewards, `route` |
| `main/main_arena.gd` (138) | `MainArena` (`arena_part`) | states "arena_rest" / "arena_fight": the arena level, the rest, the waves |
| `main/main_nether.gd` (73) | `MainNether` (`nether_part`) | the node's side of the Netherecho: leaving the body and coming back, the Netherecho's and the body's signals, the waking world's or the echo's look |
| `main/level_factory.gd` (385) | `LevelFactory` (`factory_part`) | the world at boot (environment, sun, the Netherecho node, camera), the effects' shaders held from boot, a fresh level and its navigation, biomes (floor, walls, props, cuttables), colliders, enemies and reinforcements, bodies built ahead, corpses laid back |
| `main/main_screens.gd` (305) | `MainScreens` (`screens_part`) | showing and closing screens, the panels (inventory, ethercosm, skill tree, shop, tempering, register), the seal screen, the ascension, the controls menu, the game menu and its questions (save rule, leave warning, settings) |
| `main/main_session.gd` (166) | `MainSession` (`session_part`) | the title, starting a character (creation, quick start, test characters), the autosave and slots, loading, dropping an item, dying |
| `main/main_harness.gd` (172) | `MainHarness` (`_harness_part`) | the test harness: the run's test, shot and bot arguments, the shot countdown, the passage bot's steering and report, saving the shot |
| `main/main_shots.gd` (858) | `MainShots` (`_harness().shots`) | the `--shot-ui=` setups (title, town, hud, combat, skills, biomes, menus, the Stubble shots with `ShotWatch` / `ShotLabels`, the ascension shots ...) |
| `main/main_seal_shots.gd` (617) | `MainSealShots` (`_harness().seal_shots`) | the test-character, role, seal-board and level-lock shots, `_shot_seal` and its helpers |

## The state machine

`main.state` is still one string on the node (the HUD, `Light`, `FieldCamps`, the screens and the tests read it by
name, and tests and shots set it). `MainStates.controller(main, state)` says which `MainLevel` runs it:

| `main.state` | Controller | Entered by |
|---|---|---|
| "select" | none (the title; the town is built behind it) | `MainSession._show_select` |
| "town" | `MainTown` | `MainTown._enter_town` |
| "field" | `MainField` | `MainField.enter_zone` |
| "dungeon" | `MainPassage` | `MainPassage._enter_dungeon` |
| "arena_rest", "arena_fight" | `MainArena` | `MainArena._enter_arena`; the arena moves itself between the two |
| "dead" | none (the hardcore death notice) | `MainSession._on_player_died` |

Each frame `Main._process` moves the camera, ticks the Netherecho, then calls the running controller's `tick`, then
feeds the HUD, then the harness (if any), then the bodies built ahead - the order the old `match state` had.
`Main._unhandled_input` handles Esc, the screen keys and the projection key for every state, then hands the event to
the running controller's `handle_input`. `Main._where` asks its `where`. A level's state is entered only through its
controller's enter function, which throws the old level away (`LevelFactory._new_level`) and builds its own.

**The Netherecho is not a state**, which is where the code differs from the finish plan's "one controller per level
type: ... Netherecho". It already has its own controller, the `Netherecho` node (`scripts/nether/netherecho.gd`),
which main.gd owns and ticks. It lies over "field", "dungeon" and "arena_rest" while `nether.active`, and the level's
own controller keeps ticking under it (the camps, the passage's rent, the rest's countdown). So it got a small part
for the node's side of it (`MainNether`: leaving and returning, its signals, the look) and no `MainLevel`.

**The screens and the character are concerns the plan did not name**: about 300 lines of screens and game menu and
170 of starting, saving, loading and dying. They are not levels, so they are parts of their own (`MainScreens`,
`MainSession`) rather than pieces of a controller.

## What stays on the node, and why

- **State read from outside or shared between parts.** 74 variables: the tuning numbers (`ch_len`, `ticket_price`
  ... read by `Route`, `TalkScreen`, the tests), the nodes (`player`, `camera`, `hud`, `level`, `nether`, `screen`,
  `settings_menu`), `state`, the passage's progress (`sealed`, `current`, `cleared`, `bank`, `barriers`, `gates`,
  `pads`, read by the HUD and set by `_new_level` and the shots), the zone and town state (`_zone`, `fog`,
  `field_camps`, `_town`, `_talking_to`, `_walk_to`, read by the tests), the camera's zoom, the run flags
  (`_test_mode` set by tests, `_shot_mode` and `_bot_mode` read by `save_now`, `_bot_finished` / `_bot_died` /
  `_last_*` written where a run ends and read by the bot report and the inn's ledger) and the part fields. Only
  state one part alone uses moved into it: `_field_save_t` (field), `_held_materials` and `_prebuild_queue`
  (factory), `_screen_paused` and `_menu_return` (screens), the shot and bot bookkeeping (`_frames`,
  `_shot_countdown`, `_shot_late`, `_shot_dungeon`, `_bot_scenario`, `_bot_money_before`, `_bot_started_ms`) into the
  harness, and `cam_shot` into the shots.
- **The shared level helpers** - `_cast_from_hotbar` (arena, field and passage keys, and the timeline probe),
  `_flat_dist` (town, field, rune stones), the rune stones (`_rune_stone_in_reach`, `_read_stone`, `_stone_prompt`:
  the field, the passage and a seal shot) and `_k` (prompts everywhere, and the ethercosm screen) - are used by
  several controllers, so they stay on the node rather than in one controller.
- **The camera** (`_place_camera`, `_zoom_input`, the zoom variables) and **building the player and the HUD**: the
  node's own lifecycle, read every frame.
- **`restart_game` / `_swap_for_fresh` / `_go_on`**: they replace the node itself (`get_parent`, `queue_free`,
  `replaced`), so they belong to it.

## The test harness

Everything that exists only for tests, shots and bots is in `MainHarness` and its two shot parts, and a game being
played never builds them: `Main._harness()` makes the harness the first time a run needs it (a test, shot or bot
argument in `_ready`), and `_process` ticks it only if it exists. The script is still compiled with `main.gd` (the
field is typed), which costs nothing at run time. What is left of test code in the gameplay parts is small and
marked: the passage asks the harness for the bot's next move (`MainPassage.tick`) and for the `--shot-dungeon`
picture when wall 2 wakes (`_activate`), the run's end writes the bot's record (`_extract`, `_on_player_died`),
`save_now` skips while a shot or bot runs, `_build_world` reads `--zoom=`, and `_build_field_life` reads
`--all-camps`. `_plays`, `_under_test` and `TEST_SANDBOX` stay on the node: they decide, in every run, whether the
player's own files are touched.

## How it was checked

- Before any change, and after each of the ten commits: `tools/test/run_all.sh --all` passed (23 tests); every
  `TIMELINE` line and the whole timeline and cast-every-skill logs were byte-identical to the baseline; the self-test
  printed `SELFTEST: 1681 passed, 0 failed`; the bots', zone, Stubble-bot and Netherecho result lines matched.
- The duels table (`newbie_duels`, no `--fixed-fps`) moved by a few tenths of a second and a few hp on two or three
  camp rows from run to run, the same rows flipping back and forth between steps. It never loads `main.gd` (it builds
  its own world and players), so it is frame-timing noise, not this split. `bot_full`'s money once read $272 instead
  of $273: the passage's rent is charged per real frame delta; four reruns of that step gave $273.
- Screenshots (`--shot-ui=town|stubble|menu-field|nether|enemies4` and `--shot-dungeon`), two before, one after: the
  same views, HUD, messages and positions. What differs also differs between the two before shots (scattered props,
  enemy poses, and the nether shot's passage biome, rolled from the clock in an unseeded shot run).
- Not checked: how it plays (needs Brent), the combat-review probe and the perf probe (both call the node by name
  and are untouched, but were not run).

## Next (typed calls, not done in this step)

1. Step 4's typing: `var player: CharacterBody3D` on the node becomes `Player`, and the ~370 `player.call("x")` /
   `get` / `set` strings - now spread over main.gd's parts, the same count - become `main.player.x(...)`. The parts
   are already typed against `Main`, so that change is local to each line.
2. The screens hold `var game: Node` (`ui_screen.gd`), the builders `var main: Node`; typing them `Main` would make
   their calls static and let most forwarders go.
3. The level controllers reach shared state through `main.` (passage progress, zone, town); moving each level's own
   state into its controller needs the HUD, the tests and the shots to read it there first.

## Adding to main

- New logic goes in the part of its concern, not in `main.gd`. A new level type is a new `MainLevel` subclass, a
  field and a `new(self)` in `Main._init`, and a line in `MainStates.controller`.
- State used by one part is declared in that part; state that is shared or read from outside is declared on the node.
- When outside code needs a part's function, add a forwarder in that part's block at the end of `main.gd`. Outside
  code calls the node, never a part. A signal handler stays a forwarder on the node, and the connection names the
  node's method.
- Test-only code goes in the harness parts. A source check that looks for main.gd's text must read `main.gd` and
  `scripts/main/*.gd` (as `combat_fix_checks` does for the town's endurance refill).
