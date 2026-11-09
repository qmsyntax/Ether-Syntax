# Typed calls

Phase 2, step 4a of `production/finish-plan.md` (2026-11-09). Steps 1-3 split `player.gd`, `main.gd` and `enemy.gd`
into class-named nodes (`Player`, `Main`, `Enemy`) with RefCounted parts and one-line forwarders, but most outside
code still reached them by name: `main.player.call("x")`, `player.get("x")`, `game.call("x")`,
`target.call("has_status", ...)`. This step types the holders of those three objects and turns the string calls on
them into direct calls and property access wherever the receiver's type is certain. No behaviour changed (see "How
it was checked").

## The rule for new code

**Typed by default.** Hold the player as `Player`, the game as `Main`, an enemy as `Enemy` (a beast as `Beast`), and
call them directly: `main.player.deal_damage(...)`, `game.open_shop()`, `e.add_status("soaked")`. Use
`call("x")` / `get("x")` / `set("x", v)` only where the receiver's type varies (a target that may be an enemy, the
player, a thrall, a lure, a stone or scenery), behind a `has_method` check as now. Outside code reaches a private
name through its public reader, never by string.

**Godot does not check member names for you here.** In Godot 4.7.2 a call or property access on a typed receiver
that names a member the class does not have is NOT a compile error (`p.no_such()` on `p: Player` loads cleanly; it
fails only when it runs), and the headless import does not even compile a script nothing loads, so neither is a safety net for a misspelt name. Every conversion in this step was
checked against the class's declared members by a script (below), and by the suite at run time. Type errors (a value
of the wrong type assigned or passed) are still caught when the script loads.

## What was typed

| Holder | Was | Now | Where |
|---|---|---|---|
| `Main.player` | `CharacterBody3D` | `Player` | `main.gd`; every `main.player.call/get/set` in `scripts/main/*.gd` is direct |
| the HUD's `player`, `refresh(p)` | `Node` | `Player` | `hud.gd` |
| `UiScreen.player` | `Node` | `Player` | `ui/ui_screen.gd`, so every screen; the ethercosm's and skill tree's inner classes too |
| `Netherecho.player`, `FieldCamps.player` | `Node3D` | `Player` | `nether/netherecho.gd`, `field_camps.gd` |
| `TalentEffect.owner` | `Node` | `Player` | `talent_effect.gd` and the talents |
| `Crafting`'s `p` | `Node` | `Player` | `crafting.gd` (all static functions) |
| `ZoneBuilder`'s local `player` | `Node` | `Player` | `zone_builder.gd` |
| `UiScreen.game`, every screen's `_init(game_node)` | `Node` | `Main` | `ui/*.gd` |
| `TownBuilder.main` | `Node` | `Main` | `town_builder.gd` |
| the player's and the enemy's `_router`, the bot's router, the townsfolk's game | `Node` | `Main` | `player.gd`, `enemy.gd`, `player/player_bot.gd`, `townsperson.gd` (the "router" group holds only main.gd) |
| `Main.hud` | `Control` | `Hud` (`hud.gd` is now `class_name Hud`) | `main.gd`, `scripts/main/*.gd` |
| the restart's fresh node | `Node` | `Main` | `Main._swap_for_fresh` |
| `Beast`'s base | `extends "res://scripts/enemy.gd"` | `extends Enemy` | `beast.gd` |
| `EnemyScript` preloads | `main.gd`, `field_camps.gd` | gone: `Enemy.new()` / `Beast.new()` | `level_factory.gd`, `field_camps.gd` |
| every loop over the "enemies" group (37) | `for node: Node`, `var e := node as Node3D` | `for node: Enemy`, `var e: Enemy = node` | the player's parts, the enemy's parts, zones, stones, lamps, light, lures, seeds, projectiles, thralls, the censer burst, the harness (only `enemy.gd` and `beast.gd` join the group) |
| FieldCamps' members, edge, lurkers and `_spawn` | `Node3D` | `Enemy` | `field_camps.gd` |
| the target in `apply_hit` after the `add_status` guard | `Node` | `var foe: Enemy` | `player/player_hits.gd` (only an enemy takes statuses) |
| the lists from `_enemies_near` and `inside()` | `for e: Node3D in` | `for e: Enemy in` | the player's skill parts (both helpers collect from the "enemies" group only) |
| the harness's shot enemies and beasts | `Node`, `CharacterBody3D` | `Enemy`, `Beast` | `main/main_shots.gd`, `main/main_seal_shots.gd`, `main/main_harness.gd` |

## Public readers added

Each is a plain alias of a private field or a one-line forwarder to a private function. The private name stays, so
the parts, the saves (their keys are written by hand in `to_save`, not from field names) and the tests that name the
private field by string read and write exactly the same thing.

- **Player** (`player.gd`, block "public readers"): `facing_dir` (`_facing`), `recover_left` (`_recover_t`),
  `melee_cd_left` (`_melee_cd`), `ranged_cd_left` (`_ranged_cd`), `latent_aura` (`_latent_aura`), `held_cast`
  (`_held`), `windup_cast` / `windup_left` / `windup_total` (`_windup` / `_windup_t` / `_windup_total`),
  `stagger_left` (`_stagger_t`); functions `edge_focus_max()` (`_focus_max`), `know_rune(id)` (`_know`),
  `refresh_highlights()`, `check_death()`, `float_note(txt, color)` (`_float`), `float_note_at(target, txt, color)`
  (`_text`), `apply_blow(amount, heavy)` (`_apply_damage`), `spend_heal_points(points)`.
- **Enemy** (`enemy.gd`): `windup_left` (`_windup`), `stuck_left` (`_stuck_t`), `leap_left` (`_leap_left`),
  `retreat_time` (`_retreat_t`), `special_move` (`_special`), `model_rig` (`_rig`); functions `apply_facing()`,
  `update_melee_telegraph()`.
- **Beast** (`beast.gd`): `rise_left` (`_rise_t`), `kick_ready` (`_kick`).
- **Main** (`main.gd`): `last_payout` (`_last_payout`); functions `biome_floor`, `biome_wall`, `static_box` (the
  level helpers `TownBuilder` draws with).

The names were chosen so that no string anywhere in the game, the tests or the tools already probes them on another
object (`facing`, for example, is read by name off attackers in `PlayerCombat`; giving the player a `facing` would
have changed what that read returns).

## What stays duck-typed, and why

Counted with a script over `game/scripts` (2026-11-09; a "site" is one `.call("x"`, `.set("x",` or one-argument
`.get("x")`; a two-argument `.get("x", default)` is a Dictionary read and is counted apart - 2,718 before and after):

| | before | after |
|---|---:|---:|
| all string sites in `scripts/` (with Dictionary reads) | 4,485 | 3,462 |
| object-shaped sites (`call` + `set` + one-argument `get`) | 1,767 | 744 |
| of which `call` / `set` / one-argument `get` | 1,008 / 164 / 595 | 428 / 54 / 262 |

The 744 left, by why they remain (sorted by receiver and file; the split is approximate at the edges):

- **Duck-typed targets, ~278.** The receiver can be an enemy, the player, a thrall, a lure, a standing stone or
  scenery: the target of a hit (`apply_hit` before its `add_status` guard, `deal_damage`, `take_hit`'s source),
  what a projectile, zone or burst strikes, an enemy's `target` and `_player` (`Enemy.wake(who)` and `Beast.provoke` can put whoever woke it there, not
  only the player), `hovered` / `attack_target`. They stay `has_method` / `call` on purpose: a typed call there
  would crash on the other kinds. Most of the `has_status` / `add_status` / `is_dead` / `status_stacks` /
  `clear_status` strings left are these. Calls only `Beast` answers (`is_calm`, `provoke`, `run_for`, `run_to`,
  `buried`) on FieldCamps' members (an `Enemy` or a `Beast`) stay strings for the same reason.
- **Other classes, ~290.** Receivers outside this step's three types: zones (`GroundZone`), stones, lures, thralls,
  projectiles and enemy shots, rigs (`ModelRig` / `RealCharacter`), pickups and corpses, the Netherecho's constructs
  and projection, rune words and rule sets. Many of these classes have a `class_name` and could be typed the same way
  in a later pass.
- **The harness, ~94** (`main_shots.gd`, `main_seal_shots.gd`): test code - `main.screen` driven by name, and
  indexed calls on untyped arrays (`foes[0].call(...)`).
- **The open screen, ~55.** `main.screen` holds whichever screen is open (`Control`), and `RuneBoard` / the inner
  classes hold their owner screen as `Control`; the ethercosm and inventory screens have no `class_name` yet.
- **Dictionary reads without a default, ~27** (`d.get("k")`): not dispatch at all.

The tests (`game/tests`, 4,385 object-shaped sites in 27 files) were not typed (optional in this step); they keep
calling by string and keep passing, which also proves the private names behind the readers still answer.

## Forwarders removed

22 one-line forwarders at the end of `enemy.gd` that nothing named anywhere - no direct call, no string, no
`has_method`, no `Callable`, no connection - in `game/` (scripts, tests, scenes, data) or `tools/`: the part's own
helpers `_canon`, `_end_with`, `_shove_class`, `_zone_dps_mult`, `_zone_bill_bonus`, `_in_zone_flag`, `_in_zone_list`,
`_after_hurt`, `_expire`, `_death_effects`, `_in_zone_banking`, `_tick_status`, `_tick_alight`,
`_nearest_enemy_within`, `_answer_block`, `_knock_down`, `_leave_fallen`, `_shove_ended`, `_round_stone`,
`_fallback_dir`, `_door_dir`, `_has_floor`. Each is still a function of its part; only the node's copy went. `Beast`
overrides none of them. (The check: every forwarder's name as a word anywhere in `game/` and `tools/`, leaving out
its definitions, the part calling its own function, and calls made straight to a part.)

No player or main forwarder went: every one of the 215 on `player.gd` and the 80 on `main.gd` is still named
somewhere, mostly by the tests' string calls, and the typed callers go through them too (`main.player.deal_damage()`
is the forwarder). They are the node's public face; removing them would mean the callers reaching into the parts.

## How it was checked

**Before anything changed**, on an untouched copy of `4d42834`: the full suite (`tools/test/run_all.sh --all`, 23
tests), the timeline and cast-every-skill logs, the self-test count (`SELFTEST: 1681 passed, 0 failed`) and the duels
at a fixed 60 fps (`tools/test/godot.sh --headless --fixed-fps 60 --path <copy>/game res://tests/newbie_duels.tscn`,
deterministic, unlike the suite's own duels run). **After each commit**, the same on a copy of that commit:

| Commit | Suite | TIMELINE lines / whole log | cast-every-skill log | Self-test | Fixed-60 duels |
|---|---|---|---|---|---|
| `9da775c` player holders | 22 of 23 (self-test, below) | identical | identical | 1680 passed, 1 failed | 0 of 110 rows differ |
| `5e71055` main holders | 22 of 23 (self-test, below) | identical | identical | 1680 passed, 1 failed | 0 of 110 rows differ |
| `e336f2a` the source check | import, smoke, self-test only | - | - | 1681 passed, 0 failed | - |
| `ddc4a69` enemy holders | 23 of 23 | identical | identical | 1681 passed, 0 failed | 0 of 110 rows differ |
| `2293b2c` readers | 23 of 23 | identical | identical | 1681 passed, 0 failed | 0 of 110 rows differ |
| `20bb8e0` enemy lists | 23 of 23 | identical | identical | 1681 passed, 0 failed | 0 of 110 rows differ |
| `2c20928` forwarders | 23 of 23 | identical | identical | 1681 passed, 0 failed | 0 of 110 rows differ |

- **The one failed check** on the first two commits was a source-text check, not behaviour:
  `tests/combat_fix_checks.gd` read main.gd's text for `player.call("refill_endurance")`, which is now
  `main.player.refill_endurance()`. `e336f2a` accepts either form. Every other check passed on both.
- Every other test's result line matched the baseline on every commit, except `bot_full`'s money once ($272 against
  $273 on `5e71055`): the known $1 flip from the passage's rent being charged per real frame delta, which the
  main.gd and enemy.gd splits saw too.
- **The names were checked before the runs**, since Godot does not: every rewrite was made by a script that
  converts `x.call("m"...)` / `x.get("p")` / `x.set("p", v)` only where `x` is declared with the class (a field, a
  local, a loop variable or a parameter, within that declaration's scope) and `m` / `p` is declared on that class's
  script or its `extends` chain (a `func` for a call, a `var` for a get or set), and skips and lists anything else (a
  private name, a name only `Beast` has, a constant). After each batch, every script under `scripts/` and `tests/`
  was compiled (a `SceneTree` script that `load()`s all 190 of them: 0 failed), then the import and the smoke run.
- Shots were not compared: no screen's drawing code changed, only how it reaches the player and the game, and the
  windowed click tests (`ui_click`, `ui_click_field`, `test_character`, `creation`, `game_menu`, `ascension`, `move`)
  drive those screens through real input and passed on every commit.
- **Performance** (`tests/perf_probe.tscn`, windowed, the untouched copy and the final commit run alternately, one at
  a time): no slower. fps average (1% low), base -> final:
  wall 348.7 (217.9), 345.8 (211.9) -> 351.6 (220.9), 346.4 (218.9); Stubble 282.5 (143.9) -> 299.0 (159.3); town
  428.7 (300.0) -> 428.1 (296.5); Netherecho 304.3 (197.6), 304.0 (192.7), 293.9 (171.2) -> 291.9 (174.5), 307.5
  (194.5), 306.2 (191.7); skill storm 141.6 (80.2), 139.4 (74.2) -> 141.4 (77.5), 135.9 (73.7). The script time per
  frame (`process_ms`) is the same or lower in every pair (wall 0.40 -> 0.39, Stubble 0.29 -> 0.26, skills 0.51 ->
  0.50). The spread is the probe's own: the number of actors on screen at measuring time varies from run to run on
  both sides (the Netherecho's 42-49), and fps follows it - the slowest Netherecho run on each side is the one with
  49 actors.
- Not checked: how it plays (needs Brent); the combat-review probe (not deterministic; the duels table at a fixed 60
  fps is the stronger check on enemies and was identical).

## Found while typing (not fixed)

None in the game. Two things about the tools, which matter for step 4b:

- **A typed receiver does not make Godot check the member's name.** In 4.7.2 `p.no_such()` and `p.no_such_prop` on
  `p: Player` (or on a `Node3D`) compile; they fail only when that line runs. "Godot's checks are the safety net"
  safety net" holds for types (a String passed where an int is wanted fails at load), not for names.
- **The headless import does not compile scripts nothing loads.** A deliberate bad line in `crafting.gd` passed
  `run_all.sh --only=import,smoke` cleanly; only loading the script found it. A one-line test that loads every
  script (as the compile check above did) would catch parse and type errors in scripts no test touches - worth adding
  to `run_all.sh`; not done here (no new tests in this step).
- The tests still reach the player and enemies by string about 4,400 times, and a string `get` of a name that no
  longer exists returns null instead of failing. Renaming or removing a field in step 4b must grep the tests (and
  `tools/`) for the name as a string first.
