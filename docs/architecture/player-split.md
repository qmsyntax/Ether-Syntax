# The player, split by concern

Phase 2, step 1 of `production/finish-plan.md` (2026-11-08). `game/scripts/player.gd` was one 7,953-line script
with 389 functions. It is now the `Player` node plus eleven parts, one per concern, and no behaviour changed: the
suite, the timeline and cast-every-skill output and the self-test count are the same before and after, step by step
(one commit per concern).

## The pattern: one node, parts that hold the logic

- **One node.** The player is still one `CharacterBody3D`, `scripts/player.gd`, now `class_name Player`. It keeps
  the signals, the lifecycle (`_init`, `_ready`, `_physics_process`, the model), the log helpers (`note`, `_float`),
  identity (`set_affinities`, `set_look`, `set_talent`) and every variable that is saved, shared between concerns,
  or read from outside the player (main.gd, the HUD, the screens, the tests).
- **Parts.** Each concern is a `RefCounted` in `scripts/player/`, made at the top of `Player._init` and held in a
  typed field (`combat_part: PlayerCombat`). A part holds its concern's functions and its *private* state (a
  variable only that part touches), and reaches the character through its typed back-reference
  `var player: Player` - `player.essence`, `player.global_position`, `player.died.emit()` - and the other parts
  through it: `player.hits_part.apply_hit(...)`. Calls stay static and are checked when the script loads.
- **`self` is the part.** Anything that wants the character gets `player`: `take_hit(..., player)`,
  `add_status(id, n, player)`, `ctx.source = player`, `ExactSlide.slide(player, delta)`, `zone.caster = player`.
- **Forwarders keep outside callers unchanged.** The end of `player.gd` has one-line forwarders, one block per
  part (`func deal_damage(target: Node, ...) -> HitContext: return combat_part.deal_damage(target, ...)`), for every
  function any other script, scene, data file or test names. So `player.call("x")`, `player.x()`,
  `has_method("x")` and the tests' calls to private helpers all work as before. State stayed on the node, so
  `player.get("x")` / `set("x")` and the save's keys are unchanged.
- **Why not an `extends` chain** (`player_base -> player_combat -> ... -> player`). GDScript checks a bare call
  against the script and its ancestors, and the concerns call each other both ways (combat calls casting and
  casting calls combat), so a chain would need `call("x")` or stubs for every upward call. Parts keep every call
  typed. No part needed the chain, so it is not used anywhere.

## Where things are (line counts at the split)

| File | Class (field on Player) | Holds |
|---|---|---|
| `scripts/player.gd` (808) | `Player` | signals, lifecycle, `_physics_process` (timers, ticks, meditation, reflux shed, natural healing, overcharge; then `motion_part._tick_move`), the model, identity, log helpers, 153 shared or outside-read variables, 219 forwarders |
| `player/player_motion.gd` (827) | `PlayerMotion` (`motion_part`) | `_tick_move` (click and stance input, walking to a target or a point, the run, shoves, sidestep and dash travel, facing), `walk_speed`, click targeting and hover, the cursor and aim, the feel block (`press_slot`, input buffer, strike credit, cast facing, hit-stop, `camera_kick`), the sidestep, endurance, walking in to cast, Slipstream, `_rig_action` |
| `player/player_combat.gd` (985) | `PlayerCombat` (`combat_part`) | `deal_damage` / `take_hit` (HitContext through every TalentEffect), `_apply_damage`, bare strikes and overcharge, conjured weapons, the ranged weapon, Edge Heat, the ward pool, healing over time and drain, the weapon coat, counters and deflection, shoves taken, the slot ring, armour, wounds, death, start / end fight |
| `player/player_hits.gd` (1,017) | `PlayerHits` (`hits_part`) | `apply_hit` and the hit payload helpers (statuses, consumes, drains, arcs, shatter, bursts), the affinity rules as data (`_affinity_rules`, `_affinity_reaches`, Heat, Dark's light, Life, Death, Dream, unseen), blood, clouds, growth, stores, Crush, Live marks and Overload, the v2 role ticks |
| `player/player_casting.gd` (942) | `PlayerCasting` (`casting_part`) | the hotbar and its pages, `cast_slot` / `cast_ability` / `_perform_cast` / `_repeat_cast`, recovery and the level cap, wind-ups and Braced, buffs and auras, reflux per affinity and the loadout, refusals, `lead_aim`, targeting helpers (`_skill_target`, `_aim_point`, `_ray`, `_muzzle`, `_line_visual`) |
| `player/player_skill_moves.gd` (945) | `PlayerSkillMoves` (`moves_part`) | skill kinds done with the body: burst, dash, beam, blink, projectile (and where it lands), displace, throw, chain, spur, smite, grapple, streak, the held kinds (channel, charge_release) |
| `player/player_skill_world.gd` (819) | `PlayerSkillWorld` (`world_part`) | skill kinds that leave something in the world: zones and rods, standing stone and props, delayed blasts and detonations, corpses (exhume, status deaths), lures, summons, seeds, field pulses, ground lay-downs |
| `player/player_runes.gd` (992) | `PlayerRunes` (`runes_part`) | a skill's numbers through its word (`ability_stats`, `apply_rune_patch`, `rune_preview`, `skill_details`), the level lock and its draft (`can_open_seal`, `open_seal`, keystones, `word_*`, undo / redo, `can_bind_seal`, `bind_seal`, `_bind_construct`), constructs (`construct_fits`, `construct_groups`, `preview_bind`, drops), rune discovery |
| `player/player_progression.gd` (511) | `PlayerProgression` (`progress_part`) | stars and the essence ceiling, meditation's gather, the latent aura and kill rewards, tempering, learning from scrolls, the skill tree and skill points, ascension |
| `player/player_economy.gd` (314) | `PlayerEconomy` (`economy_part`) | gear (`weapon_stat`, `reach_now`, `refresh_gear`), loot and pickups, money, the healer, corpses, the night's rest, remains, field consumables |
| `player/player_save.gd` (140) | `PlayerSave` (`save_part`) | `to_save` / `from_save` |
| `player/player_bot.gd` (106) | `PlayerBot` (`bot_part`) | the bot driver (`_bot_think`, `_bot_way`, `_nearest_enemy`) and `make_test_character` |

## What was not split, and why

- **Most state stays on the node.** 153 of 181 variables stayed: 109 are read or written from outside the player
  (by name: `player.get("_melee_cd")`, `p.set("_windup_t", ...)`, the HUD, the screens), and the rest are shared by
  two or more parts (the dash's `_dash_*` state is set by the dash skill in `PlayerSkillMoves` and moved each frame
  by `PlayerMotion._tick_move`; `_p` and the other tuning dictionaries are read everywhere). Moving them would have
  needed property forwarders or changed outside callers. 28 variables and one constant (`DRAFT_HISTORY_MAX`) that
  only one part uses moved into it.
- **`_physics_process` stays on the node**, split once: the feet half became `PlayerMotion._tick_move(delta)`,
  called at the same point.
- **The forwarders stay** until callers are typed: about 200 distinct names are called on the player through
  `call` / `get` / `set` strings from the game's scripts (main.gd ~370 uses, hud.gd and ethercosm_screen.gd ~94
  each, inventory_screen.gd 46, talk_screen.gd 23, netherecho.gd 18, then the tempering, skill tree and ascension
  screens), and the tests do the same in 27 files.

## Next (typed calls, not done in this step)

1. Type the holders: `main.gd`'s `var player: CharacterBody3D`, `hud.gd` / `ui_screen.gd`'s `var player: Node`,
   `netherecho.gd` / `field_camps.gd`'s `Node3D` become `Player`, then turn their `player.call("x")` /
   `get("x")` / `set("x")` into `player.x(...)` / `player.x` (main.gd first: it is most of them, and main.gd's own
   split is next).
2. Give the private names that outside code reaches a public reader first: `_facing` (9 uses), `_refresh_highlights`
   (7), `_recover_t` (5), `_melee_cd`, `_know` (3), `_ranged_cd`, `_latent_aura`, `_held`, `_check_death` (2),
   `_windup`, `_windup_t`, `_windup_total`, `_stagger_t`, `_focus_max` (1).
3. The dash's `_dash_*` state is split between `PlayerSkillMoves` (set by the dash) and `PlayerMotion` (moved each
   frame); one owner for the dash's travel would let it leave the node.

## Adding to the player

- New logic goes in the part of its concern, not in `player.gd`. A new concern gets a new part: `class_name`,
  `extends RefCounted`, `var player: Player`, `func _init(of: Player)`, a field on `Player` and a `new(self)` at the
  top of `Player._init`.
- State used by one part is declared in that part. State that is saved, shared between parts or read from outside
  is declared on the player.
- When outside code needs a part's function, add a forwarder at the end of `player.gd` in that part's block. Outside
  code calls the player, never a part.
- A source check in a test that looks for a function's text must read `player.gd` and `scripts/player/*.gd` (as the
  self-test's bind-callers check and `combat_fix_checks`' refill check do).
