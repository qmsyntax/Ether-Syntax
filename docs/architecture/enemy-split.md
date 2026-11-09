# enemy.gd, split by concern

Phase 2, step 3 of `production/finish-plan.md` (2026-11-08). `game/scripts/enemy.gd` was one 2,099-line script with
116 functions and 76 variables: every enemy's statuses, how it takes hits, how it moves and routes, how it is drawn, and five
behaviours' thinking. It is now the `Enemy` node plus ten scripts in `scripts/enemy/` - four parts by concern, a
brain base class and one brain per behaviour - and no behaviour changed: the suite, the timeline and cast-every-skill
output, the self-test count and the duels table are the same before and after, step by step (one commit per
concern). It follows the player and main splits (`player-split.md`, `main-split.md`) and their pattern.

## The pattern: one node, parts that hold the logic

- **One node.** `scripts/enemy.gd` is `class_name Enemy` (the name was free: no other class, constant or autoload
  used it), still `extends CharacterBody3D`. It keeps the signals (`killed`, `crushed`, `reinforcements`, `hurt`),
  the lifecycle (`_init`, `setup`, `_ready`, `_physics_process`), the slot ring, the attack helpers every brain
  shares (`_no_attack`, `_windup_len`, `_blow`, `_strike`, `_attack_started`), the field block (`sleep_at`, `wake`,
  `go_home`, `_field_tick`, `_walk_home`, `_arrived_home`), the hooks Beast overrides, and every variable that is
  read from outside or shared between parts.
- **Parts and brains.** Each concern is a `RefCounted` in `scripts/enemy/` with a typed back-reference
  `var enemy: Enemy`, made in `Enemy._init` and held in a typed field (`status_part: EnemyStatuses`). A part reaches
  the node through `enemy` (`enemy.statuses`, `enemy.global_position`, `enemy.hurt.emit(enemy, source)`) and another
  part through it (`enemy.hits_part.stagger(...)`); `self` in the old code became `enemy`.
- **Virtual calls go through the node.** Beast overrides `setup`, `_ready`, `take_hit`, `guards_front`,
  `_field_tick`, `_think_behaviour` and `_arrived_home`. Wherever moved code calls one of those it calls the node
  (`enemy.take_hit(...)`, `enemy.guards_front(...)`), never the part, so a beast's override still runs - a burning
  tick on a buried lurker still does nothing, a stuck Burr-Hog's guard is still down.
- **Forwarders keep outside callers unchanged.** The end of `enemy.gd` has one-line forwarders, one block per part,
  for every moved function: the player's parts, projectiles, zones, the Netherecho, the HUD, Beast and the tests reach
  enemies by name (`call("add_status", ...)`, `has_method("is_lunging")`, `get("_windup")`, private helpers such as
  `_land_melee` and `_find_vantage`), and all of them still answer on the node.
- **Scene tree and timing are the same.** Parts are not nodes: the enemy has the same children in the same order
  (`EnemyLooks.build`, called from `setup` where the old lines were, adds the rig, the capsule, the aura ring and
  the label exactly as before), `_physics_process` does the same work in the same order, the same signals fire, and
  the one random draw (`_circle_sign` in `setup`) is where it was.
- **The moves were made by a script.** Each step was regenerated from the untouched `enemy.gd` by one script that
  moved the listed functions and variables, rewrote their names (`enemy.<name>`, `self` -> `enemy`, a sibling's
  function on its part, the virtual ones through the node) and wrote the forwarders, and warned about any name it
  could not place or any local that shadowed a member (there were none). So each commit is mechanical, and the only
  hand-written lines are the docs, the part headers, `_init`, `_brain_for` and the brain base class.

## Where things are (line counts at the split)

| File | Class (field on Enemy) | Holds |
|---|---|---|
| `scripts/enemy.gd` (543) | `Enemy` | signals; the stats and shared state (60 variables); `_init` (the parts); `setup`, `_ready`, `is_dead`, `is_elite`; the slot ring; `_physics_process` (statuses, a shove, recovery, poise, the field hook, the target, the route, then the brain, then the slide, the leash, the look); `_gone`; the attack helpers the brains share; the field block; `_brain_for` and the `_think_behaviour` hook; 93 forwarders |
| `enemy/enemy_statuses.gd` (551) | `EnemyStatuses` (`status_part`) | the status engine: `add_status` and its refusals, merges and caps, `has_status` (counts_as, derived), `clear_status`, the `_st_*` readers, front armour, metal, flesh, light, the ground zones it stands in, `_after_hurt`, `_expire`, `_death_effects`, `_tick_statuses` / `_tick_status` (damage over time, spread, drips, nudges, retching), `_kneeling`, `lure_reach`, `_charmed` |
| `enemy/enemy_hits.gd` (321) | `EnemyHits` (`hits_part`) | the back and front arcs, `take_hit` (statuses, the front guard, Spared's floor, Muffle, death, its burst and body), `take_poise` and `stagger`, the guard (`guards_front`, `blocks_shot`, `_answer_block`), `stun`, `interrupt` / `interrupt_attack`, shoves, pulls, nudges, `turn_away_from`, the shove's travel and the crush |
| `enemy/enemy_motion.gd` (303) | `EnemyMotion` (`motion_part`) | who it goes for (`_pick_target`: taunts, charms, lures, masks), the statuses that move it (`_flee`, `_walk_to_goal`, `_keep_leash`), routing (`_route_dir` on `NavPath`, `_level_nav`, `_round_stone` with `Stone.way_round`, the old steering `_fallback_dir` / `_door_dir`), `_turn_toward`, sight (`sees_point`, `_sees_target`, `_clear`, `_has_floor`) |
| `enemy/enemy_looks.gd` (103) | `EnemyLooks` (`looks_part`) | the body it is drawn with (`build`: model, capsule, aura ring, label), `_apply_facing`, `_look` (wind-up, slumped, highlight, the rig's animation), `_refresh_label`, the melee telegraph |
| `enemy/enemy_brain.gd` (18) | `EnemyBrain` | the brain interface: `think(delta, dir, dist)` |
| `enemy/enemy_melee_brain.gd` (61) | `EnemyMeleeBrain` (`melee_brain`) | `think` (was `_think_melee`), `_land_melee` |
| `enemy/enemy_ranged_brain.gd` (175) | `EnemyRangedBrain` (`ranged_brain`) | `think` (was `_think_ranged`), `_loose`, `_retreat_dir`, `_seek_line`, `_find_vantage` |
| `enemy/enemy_pouncer_brain.gd` (81) | `EnemyPouncerBrain` (`pouncer_brain`) | `think` (was `_think_pouncer`), `_pack_centre`, `_tick_leap` |
| `enemy/enemy_support_brain.gd` (89) | `EnemySupportBrain` (`support_brain`) | `think` (was `_think_support`), `_allies_within`, `_drum_roll` |
| `enemy/enemy_commander_brain.gd` (104) | `EnemyCommanderBrain` (`commander_brain`) | `think` (was `_think_commander`), `_land_sweep`, `_tick_charge` (also the charging beasts' charge) |

## The brains, and how one is chosen

An enemy's `behaviour` (enemies.json "behaviour", set in `setup`) names how it fights. Each frame, once statuses,
shoves, the field and the target are dealt with and nothing holds it (a stun, a stuck moment, fleeing, a commanded
walk), `_physics_process` asks `_brain_for(behaviour)` - or `_brain_for("melee")` while a `closes_in` status
(Taunted) is on it - and calls that brain's `think(delta, dir, dist)`:

| behaviour | brain |
|---|---|
| "ranged" | `ranged_brain` |
| "pouncer" | `pouncer_brain` |
| "support" | `support_brain` |
| "commander" | `commander_brain` |
| anything else ("melee", a beast's own) | none: the `_think_behaviour` hook, whose base is the melee brain |

Melee goes through the hook, as it always did, so a beast's override sees every fight that is not one of the four:
that is how a Kettle Beetle (melee) still swells and a Taunted Ditch Hound still flanks. Every enemy holds one brain
of each kind, made in `Enemy._init`; a brain is small and keeps only the state that it alone uses (the archer's
vantage and aim lock, the drummer's pulse clock). State a brain shares with another concern or that outside code
reads (`_windup`, `_leap_left`, `_retreat_t`, `phase`, `_charge_left` ...) stays on the node.

## Beast

`scripts/beast.gd` is still `class_name Beast`, `extends "res://scripts/enemy.gd"` (so it is an `Enemy`), and the
field camps still instantiate it (`FieldCamps._spawn`). It was not changed. Of the two options, the beasts' behaviours
**stay as virtual hooks on the node** (`_field_tick`, `_think_behaviour`, plus the `take_hit`, `guards_front`,
`_arrived_home` overrides), not brains chosen by data, because:

- `_field_tick` is not a fighting brain: it runs before the target is picked (a buried lurker, grazing, a Gleaner's
  run) and decides whether the frame is used at all, so it would stay a hook whatever the brains did;
- the beasts' fighting behaviours share Beast's own state with those field states and with its overrides (`calm`,
  `_angry_t`, `_base_speed`, `_swell`, `_charge_len`, `_kick`), so as brains they would need it moved onto the node
  or reached through the beast anyway;
- `beast.gd` is 544 lines, already a file of its own per concern (the beasts), and the hooks keep it unchanged, which
  is the safest way to keep the beasts byte-for-byte the same.

Making them brains later is straightforward: an `EnemyBrain` subclass per beast behaviour, an entry in a Beast
override of `_brain_for`, and the shared fields moved to Beast's node block.

## What stays on the node, and why

- **State read from outside or shared between parts.** 60 of the 76 variables: the stats (`kind`, `behaviour`, `radius`,
  `speed`, `damage`, `heavy`, `poise` ...), `body`, `target`, `statuses`, `facing`, `telegraph`, `phase`, the field
  state (`camp`, `home`, `asleep`, `_going_home`), and the private ones the tests, the bot report or Beast reach by
  name or that two parts share (`_windup`, `_attack_cd`, `_stuck_t`, `_leap_left`, `_leap_hit`, `_retreat_t`,
  `_aim`, `_shove_left`, `_special`, `_special_cd`, `_charge_*`, `_held_t`, `_turned_t`, `_poise_idle`, `_flash`,
  `_rig`, `_errand`, `_router`, `_walk_dir`, `_def`, `_cfg` ...). Only variables one part alone uses moved into it:
  `_burn_t`, `_spread_t`, `_retch_t` (statuses), `_shove_dir` (hits), `_nav`, `_chase`, `_lured` (motion),
  `_label`, `_shown_*` (looks), `_aim_locked`, `_vantage`, `_vantage_t`, `_retreat_side` (ranged), `_pulse_t`
  (support).
- **`_physics_process`**: the frame's order is the enemy's timing (statuses, then a shove, recovery and poise, the
  field hook, the target and route, the brain, the slide, the leash, the look) and it calls the hooks.
- **The attack helpers** (`_no_attack`, `_windup_len`, `_blow`, `_strike`, `_attack_started`) and **the slot ring**
  (`_has_slot`, `_release_slot`, `claim_slot`, `release_slot`): every brain and Beast use them, so they belong to
  no one brain.
- **The field block**: `_field_tick` and `_arrived_home` are hooks Beast overrides, and the rest (sleep, wake, walk
  home) is what FieldCamps calls; it is about 90 lines.
- **`_gone`** (static) is called through the class (`Enemy._gone`) from the motion part.

## How it was checked

- Before any change, and after each of the five code commits: `tools/test/run_all.sh --all` passed (23 tests);
  every `TIMELINE` line and the whole timeline and cast-every-skill logs were byte-identical to the baseline; the
  self-test printed `SELFTEST: 1681 passed, 0 failed`; the bots', zone, Stubble-bot and Netherecho result lines
  matched (`bot_full`'s money read $272 in the baseline run and $273 in every later one - the known $1 flip from the
  passage's rent being charged per frame delta, which main.gd's split saw too).
- **The duels, made exact.** `newbie_duels` runs without `--fixed-fps`, so two untouched runs already differ on
  about ten of its 110 rows (camp fights mostly). Run with `--fixed-fps 60` it is deterministic: two untouched runs
  gave the same table, and after every step the split's table was identical to the untouched build's, row for row
  (0 of 110 rows differ). Enemies are what duels measures, so this is the strongest check that no brain, status,
  hit or move changed.
- Screenshots (`--shot-ui=enemies4|combat|stubble-fight-ditch_hound|stubble-fight-burr_hog|stubble-fight-wirehorn|
  stubble-lineup`), two before and one after: the same views, telegraphs, rings and HUD; what differs also differs between the two before shots
  (poses, scattered props; shot runs are not seeded).
- The combat-review probe's fast config (`tools/combat-review/configs-fast.txt`, 35 runs), twice on the untouched
  build and twice after (the probe is not deterministic: enemy rolls and the bake order). Deaths 20 and 19 before,
  21 and 19 after; mean game time 101 / 88 s before, 96 / 89 s after; kills 25.0 / 24.6 before, 26.3 / 25.0 after;
  casts per fight-minute 162 / 163 before, 165 / 168 after; damage per fight-second 240.5 / 232.6 before, 238.5 /
  242.8 after; health lost per fight-minute 315 / 314 before, 346 / 322 after. Row by row `compare.py` moves as much
  between the two untouched runs as between before and after.
- Not checked: how it plays (needs Brent), the perf probe.

## Found while splitting (not fixed)

- **A lone War Drummer can hold an arena wave open forever** (the combat-review probe's arena runs that hit their
  8-minute cap, mid tier; seen for Life and Earth, on the untouched build too). With no melee or commander ally
  within 14 m, `EnemySupportBrain.think` returns before it moves: it stands where it is and never comes for you.
  The probe's scripted player walks straight at its target (a person steers round things by hand; only the bot
  follows a path), so when one of the arena's blocks lies between them it presses against the block forever, and
  its ranged skill spends itself on the block. The fix belongs in the probe (`tests/combat_review/driver.gd`: walk
  to an out-of-reach target by `NavPath`, as `_walk_to` already does, or apply `_unstick` in the arena too); whether
  a drummer left alone should also do something (close in as a Taunted one does, or seek a line like the archer) is
  a design question for Brent.

## Next (typed calls, not done in this step)

1. Type the holders. Enemies are held as `Node`, `Node3D` or `CharacterBody3D` almost everywhere (the player's parts'
   targets, `apply_hit`'s `target`, projectiles, zones, `FieldCamps`, `LevelFactory`, the HUD) and reached through
   strings: `call("has_status")` (~144 uses in scripts and tests), `call("add_status")` (~96), `call("is_dead")`
   (~90), `call("status_stacks")` (~67), `call("clear_status")` (~40), `call("shove")`, `take_poise`, `metal_class`,
   `is_behind`, `blocks_shot` ... (some of these also reach the player, a thrall or a lure). Typing them `Enemy`
   where only an enemy can arrive would make those calls static and let most forwarders go.
2. `main.gd` and `field_camps.gd` keep `const EnemyScript := preload("res://scripts/enemy.gd")`; with the class
   name they can say `Enemy` (and `Beast` can say `extends Enemy`), a one-line change each.
3. Give the private names that outside code reaches a public reader first: `_windup` (the HUD, the bot report, ~90
   test uses), `_attack_cd`, `_stuck_t`, `_leap_left`, `_retreat_t`, `_shove_left`, `_special`, `_special_cd`,
   `_charge_left`, `_poise_idle`, `_flash`, `_rig`, `_land_melee`, `_find_vantage`, `_tick_statuses`.
4. Beast's behaviours as brains (see Beast above), if a second creature source makes Beast grow.

## Adding to the enemy

- New logic goes in the part of its concern, not in `enemy.gd`. A new behaviour is a new `EnemyBrain` subclass in
  `scripts/enemy/`, a field and a `new(self)` in `Enemy._init`, and a line in `_brain_for`.
- State used by one part is declared in that part; state that is shared or read from outside is declared on the node.
- When outside code needs a part's function, add a forwarder in that part's block at the end of `enemy.gd`. Outside
  code calls the node, never a part.
- Call a function Beast overrides through the node (`enemy.take_hit`), never through the part.
- A source check that looks for the enemy's text must read `enemy.gd` and `scripts/enemy/*.gd`.
