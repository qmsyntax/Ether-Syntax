# The data schema

Phase 2, step 4b of `production/finish-plan.md` (2026-11-09). Before this step about a thousand reads in
`game/scripts` looked like `def.get("radius", 2.0)`: a misspelt or missing key in `game/data/*.json` silently took
the script's default, and the same key was read with different defaults in different places. Now the data is checked
once when it loads, and optional keys are read through one helper whose defaults live in one file. No behaviour
changed (see "How it was checked").

## The rule for new code

**Read data through the schema.** On a data entry (or a copy of one: an ability's patched stats, a buff, a held
cast), never write `.get("key", <number>)`. Write `GameData.opt(entry, "<kind>", "<key>")` and give the key its
default in `game/data/schema.json`. A key every entry has is listed as required there; read it with `entry["key"]`
or through `opt` (its default then never fires). Saves (`SaveGame`, `PlayerSave`) and dictionaries built in code
(hit contexts, a status's runtime state, describe results) keep their own tolerant `.get` defaults: they are not
data.

## Where it lives

| What | Where |
|---|---|
| The schema | `game/data/schema.json` (hand-maintained) |
| Loading, checking, defaults | `scripts/data_schema.gd` (`DataSchema`: `load_file`, `check`, `fallback`) |
| The check at load, the reader | `scripts/game_data.gd`: `_check` (in `_ensure`, every run), `data_errors`, `check_ms`, `opt()` |
| Checks | `tests/data_checks.gd` (the self-test's "data schema" block, `-- --only=data`), `tests/load_all.tscn` |

`schema.json` has two parts:

- **`files.<file>`**: which dictionary in that file is which kind. `paths` maps a pattern to a kind: `*` is any key of
  an id map (`abilities.*`), `[]` each element of a list (`zones.*.camps[].members[]`). `idmaps` lists the
  dictionaries whose keys are ids; `maps` the dictionaries whose keys name ids (or free names) and whose values share
  one type (`recipes.*.inputs`: item ids -> numbers); `skip` what is not looked into (big generated tables checked by
  hand in `GameData._check_by_hand`).
- **`kinds.<kind>`**: `keys` (each `[type]`, `[type, default]` or `[type, default, {variant: default}]`; types
  `number`, `int` (read as a whole number), `string`, `bool`, `array`, `object`, `null`, `any`, joined with `|`),
  `required` (keys every entry must have), `refs` (keys naming ids: `"status": "status"`, `"kit[]": "ability"` for a
  list; a target `affinity+own+plain` also takes those words) and `code_only` (read in code, never in the data).

One kind can sit at many places: every hit block of an ability (`on_hit`, `on_pass`, `zone.payload`, a coat's
`strike_payload`, an affinity's `ward_break_payload`, a status's shatter `shard`, ...) is kind `payload`, because
one function (`Player.apply_hit`) reads them all; an ability's `zone`, `trail`, `aura`, `leave_zone` and a status's
death `cloud` are kind `zone`. 246 kinds, 2,022 keys.

### Variants: one key, two defaults

Where two call sites read the same key with different defaults, both are kept: the commonest is the key's default,
the other is a named variant, read as `GameData.opt(ab, "ability", "range", "fire_beam")`. A variant is named after
the function that first read it (with its value when one function has two). These are the 42 keys with variants:

| Key | Default | Variants (site default) |
|---|---|---|
| ability.arc_deg | 0 | channel_pulse 60 |
| ability.range | 10 | cast_ability 6, cast_ability_8 8, perform_cast 99, fire_beam 9, streak 7, channel_pulse 5, release_charge 12 |
| ability.pull | 10 | displace 4, burst 0 |
| ability.radius | 6 | take_buff 2.5, take_hit 0, tick_roles 12, inured_mult 8, displace 3, channel_pulse 5, start_blast 2 |
| ability.delay | 0 | start_blast 0.5, sow 6 |
| ability.per_stack_damage | 0 | field_pulse 30, beats 8 |
| ability.duration | 2 | take_buff -1, put_coat 6, summon 15, sow 20 |
| ability.pass_radius | 1 | streak 1.1 |
| ability.damage | 0 | detonate 70, raise_prop 40 |
| ability.life | 12 | lead_aim 1, plant_rod 10, raise_prop 3, raise_prop_5 5, raise_prop_30 30 |
| ability.burst_radius | 2 | detonate 2.5, sow 1.2 |
| ability.spread_radius | 0 | smite 4 |
| ability.width | 3 | fire_projectile 0, channel_pulse 1 |
| ability.pip_seconds | 0.2 | lay_zone 0 |
| ability.jumps | 7 | chain 3, fire_beam 0 |
| ability.jump_radius | 3 | chain 5, fire_beam 4 |
| ability.max_count | 2 | raise_prop 0 |
| ability.pool_radius | 0 | field_pulse 4 |
| ability.heal_over_s | 2 | burst 3 |
| ability.hp | 150 | raise_prop 300 |
| ability.spread_every | 0 | raise_prop 5 |
| ability.max_sites | 0 | exhume 4 |
| ability.beats | 0 | beats 3 |
| enemy.height | 1.7 | setup 1.6, make 1 (every entry has it: never used) |
| enemy.speed | 3 | setup 3.4 (every entry has it: never used) |
| enemy.stuck_after_miss | 0 | tick_leap 1 |
| enemy.angry_s | 10 | provoke 12 |
| enemy.death_burst.delay | 1.1 | take_hit 0.8 |
| enemy.death_burst.radius | 2.6 | take_hit 4 |
| payload.damage | 0 | detonate 40 |
| payload.radius | 2.5 | buff_ended 3, burst_at 2, throw 1.5 |
| shape_trait.min_runes | 3 | shape_traits 5 |
| status.stacks | 1 | draw_statuses 3 |
| status.lasts | 1.5 | add_status 1, rules_of 0 |
| status.overload_damage | 150 | rules_of 0 |
| status.arc_damage | 60 | rules_of 0 |
| status.arc_radius | 12 | rules_of 0 |
| town.exit_reach | 2.1 | town_door_in_reach 1.5 (every entry has it: never used) |
| zone.radius | 3 | lay_cloud 2, projectile_landed 2.5, rules_of 1 |
| zone.life | 4 | end_dash 3, projectile_landed 6, lay_ground 5 |
| zone.tick_s | 1 | tick_aura 0.5 |
| zone.width | 1 | lay_zone 2 |

Most are one key meaning different things to different skill kinds (a beam's `range` and a charge's), which is why
they were kept and not merged. A few are the same thing read two ways, which only matters where an entry lacks the
key: the status text's `rules_of` describes a missing `lasts`, `overload_damage` or `arc_*` as 0 where the game uses
1.5 / 150 / 60 / 12, and `add_status` lasts 1.0 where other callers stagger for 1.5. Left as they are (no behaviour
change in this step); worth a look when the status text is next touched.

## How to add a key

1. Add it to the entry in the data (or to the generator's tables, for a generated file - see CLAUDE.md).
2. Add it to its kind in `schema.json`: `"my_key": ["number", 0.0]` (optional, with the default code reads when an
   entry lacks it), or `["number"]` and the key in `required` when every entry must have it. A key that names an id
   goes in `refs` too.
3. Read it with `GameData.opt(entry, "<kind>", "my_key")`.

A new kind of dictionary (a new block on an ability, a new list in a zone): add its pattern under `files.<file>.paths`
with a kind (a new one, or an existing one with the same keys). A dictionary whose pattern the schema does not list
is not checked; a key its parent kind does not list is reported, so a new block is caught until it is added.

## What the check reports

`GameData._check` runs in `_ensure` (the autoload's `_init`), on every start, play included. Each problem is pushed
with `push_error` as `GameData: <file>.json <where>: <what>` and kept in `GameData.data_errors`:

- **an unknown key** - a key its kind does not list (a typo: `recovry`); keys starting with `_` (`_note`) are free;
- **a missing required key**;
- **a wrong type** (text where a number is wanted), and a fraction where a key is read as a whole number;
- **an id that points nowhere**: an ability's statuses (`on_hit.status`, `statuses[].id`, `consume_status`, ...),
  affinity, base rune and self state; an enemy's `remains` and `loot`; a skill-tree node's ability (and its tree's
  affinity, its `requires`); a scroll's ability (`teaches`); an affinity's kit and parents; a construct word's runes
  and affinity, the legacy table's words; a zone's camp member and edge kinds, nether wisps' affinities and
  constructs' words; a recipe's items, station and skill; a town station; a status's `counts_as`; rune ops' statuses;
  a balance wall recipe's enemies; and by hand, the tables the walk skips: runes' `skill_anchor`, rune discovery's
  starting runes, construct words and kill kinds, and `enemy_looks`.

The self-test (`data schema` block) and `tests/load_all.tscn` fail on any of them. A read through `GameData.opt` of a
kind, key or variant the schema does not name is a script error when it runs (never a quiet default), and
`load_all` checks every such call in `scripts/` against the schema before anything runs.

**Cost**: about 28 ms per start on this machine (schema parse 3 ms, compile 3 ms, the walk 18 ms, the by-hand tables
4 ms), beside the 21 ms the game already spends parsing the data. Measured with `GameData.check_ms`, which
`load_all` and the self-test print.

## What is not read through the schema

134 `.get("key", <number>)` reads remain in `game/scripts`, none on a data entry:

| Why | Reads |
|---|---:|
| a status's, buff's, word's or wound's runtime state (`enemy.statuses[id]`, a buff's `t` / `softened` / `upkeep_*`, `player.stores`, the rune engine's `rune_repeat`, keystones) | 67 |
| describe and preview results (`describe_rune`, `describe_node`, the ethercosm's and rune board's rows) | 23 |
| code tables (`Biomes.prop_meta`, `GroundMaterial.SETS`, creature legs, model shapes) | 21 |
| saves (`PlayerSave.from_save`, `SaveGame`, the title and session screens) | 18 |
| contexts built in code (crafting's `ctx`, `deal_damage`'s and `add_status`'s `opts`) | 4 |
| `StatusText._walk_applied`, which walks every block of an ability looking for statuses | 1 |

Non-numeric fallbacks (`.get("status", "")`, `.get("zone", {})`) were not part of this step.

## How it was checked

Same method as steps 1-4a. **Before anything changed**, on an untouched copy of `5e8cd34`: the full suite
(`run_all.sh --all`, 23 tests: all pass), the timeline and cast-every-skill logs, the self-test count
(`SELFTEST: 1681 passed, 0 failed`) and the duels at a fixed 60 fps (`godot.sh --headless --fixed-fps 60 --path <copy>
res://tests/newbie_duels.tscn`, 110 `DUELS` lines). **After each commit**, the same on a copy of that commit:

| Commit | Suite | TIMELINE / whole log | cast-every-skill log | Self-test | Fixed-60 duels |
|---|---|---|---|---|---|
| `595579b` schema.json | (nothing loads it; covered by the next row) | | | | |
| `4b1c4ff` validation | 23 of 23 | identical | identical | 1681 + 8 passed, 0 failed | 0 of 110 rows differ |
| `930d680` player reads | 23 of 23 | identical | identical | 1681 + 8, 0 failed | 0 of 110 differ |
| `92706d3` enemy and world reads | 23 of 23 | identical | identical | 1681 + 8, 0 failed | 0 of 110 differ |
| `f30dc72` the other reads | 23 of 23 | identical | identical | 1681 + 8, 0 failed | 0 of 110 differ |
| `4742c11` loadall | import, smoke, loadall, self-test | - | - | 1681 + 8, 0 failed | - |
| `d431fd7` duels at 60 fps, the probe driver | 24 of 24 | identical | identical | 1681 + 8, 0 failed | 0 of 110 differ; the suite's own duels run gives the same 110 rows |
| `2b1fe84` opt in one lookup | 24 of 24 | identical | identical | 1681 + 8, 0 failed | 0 of 110 differ |

- The 8 new self-test checks are the "data schema" block: the real data is clean, and seven planted faults in a copy
  of the data are each reported.
- Every other result line matched the baseline on every commit except `bot_full`'s money once ($272 against $273 on
  `f30dc72`): the known $1 flip from the passage's rent being charged per real frame delta (steps 2, 3 and 4a saw it).
- **The check bites.** A scratch copy of the game (not the repo) with one fault of each kind planted - `recovry` for
  `recovery` on Tsunami Strike, `hp` taken off the brute, the soaked status's `lasts` given as `"long"`, a Stubble
  camp member of kind `"gremlin"` - started with four `GameData:` errors naming the file, entry and key, and
  `load_all` printed `LOADALL: FAIL (4)` (exit 1).
- **Before the reads were rewritten** a script listed every `.get("k", <number>)` in `scripts/` with what its receiver
  is (1,004), classified each as a data kind or out of scope, derived the schema's defaults from them and rewrote the
  870 in scope mechanically, checking each site's text first; `load_all` then confirmed every `GameData.opt` call
  names a kind, key and variant the schema has.
- **Cost of the reader**: `GameData.opt` costs about 0.23 us a read against 0.06 us for a bare `.get` (a 200,000-read
  loop). The perf probe's skill storm makes about 1,200 schema reads a frame; the first version of `opt` (0.19 us a
  hit, 0.43 us a miss) cost it about 0.4 ms of physics a frame (fps 129 against 138, four runs a side), which the
  last commit took back (one lookup, and Masked's lure loop, about 570 reads a frame, off it): four runs a side
  after it, base 130 / 148 / 149 / 144 fps, final 139 / 146 / 135 / 143 (the probe's own spread is about 10%;
  physics 1.21 ms against 1.28 ms on average).
  The other scenes, once a side on the final code (fps average / 1% low, base -> final): wall 350.4 / 217.7 ->
  352.4 / 224.2, Stubble 300.8 / 165.8 -> 301.0 / 165.9, town 424.6 / 276.0 -> 433.8 / 302.2, Netherecho 308.9 /
  192.7 -> 302.5 / 190.0; script time per frame the same in each (`process_ms` 0.39, 0.26, 0.58, 0.38 -> 0.39).
- Not checked: how it plays (needs Brent). Shots were not compared (no drawing code changed; the windowed click
  tests passed on every commit).
