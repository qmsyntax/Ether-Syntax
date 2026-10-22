# Build brief: every affinity, every skill, test characters (2026-10-22)

Brent: "Put it all into the game, we can always roll back. Give me a custom character selection for each affinity so
I can play with all skills." The rollback point is tag `v0.43.0-runes-1`.

## Sources (read all first)

- **`CLAUDE.md`**: rules, architecture, test commands. Follow it exactly:
  - data-driven numbers;
  - everything a skill does to an enemy goes through `Player.apply_hit`;
  - no branching on ids in gameplay code;
  - verify UI with screenshots;
  - the windowed click tests need a window.
- **`design/data-drafts/skills/*.json` (16 files, 176 skills)**: each skill's base rune, kind, numbers (abilities.json
  field names), signature, new mechanics, good and bad modifiers; each affinity's rule and reflux tier; effects.
  `*.md` beside them are readable summaries.
- **`design/runes-data/modifier-check-planned.md`**: the rune-rule changes to build (below). Twelve "good modifier
  with nothing to act on" lines at the end of the affinity sections are skill-data gaps to fill.
- **`design/runes-workbook.xlsx`**: the runes. **Read only**: never open in Excel, never write. Re-run
  `tools/runes/export_runes_json.py` to refresh `game/data/runes.json`. All 166 base runes now have an Effect (game).
  A new op `through` exists: the hit ignores front block and shields. Extend the exporter's syntax check.
- **What exists**: `game/data/abilities.json`, `statuses.json`, `affinities.json`, `skill_tree.json`,
  `game/scripts/player.gd`, `enemy.gd`, `game/scripts/runes/` (effects_v1 is the rune effect engine).

## Build

1. **A generator, not hand edits.** `tools/skills/emit_abilities.py` reads the 16 drafts and writes the game's
   abilities, statuses, affinities and skill trees. Rules:
   - Existing ability ids keep their ids.
   - Each ability carries `base_rune` and `signature`.
   - The exporter derives `skill_anchor` from `base_rune`, not from workbook names.
   - Mark generated files with a `_note` ("edit the drafts and re-run").
   - Fill the twelve data gaps: every skill has a cost, and every skill that hits has a hit payload.
2. **All 16 affinities in `affinities.json`:**
   - a colour each, distinct and readable;
   - the three starters as the kit;
   - its reflux tier;
   - its rule as text.
   - Its rule as mechanics: implement each affinity's rule where it is a few lines in the data-driven style:
     - Ice: Chill stacks to Frozen to Brittle;
     - Poison: a dose clock;
     - Disease: flesh multiplier and clouds;
     - Death: corpses lie longer for it, and the "dying" bonus;
     - Life: inside, and the "hale" bonus;
     - Blood: Bleeding, pools and held blood, never health;
     - Dark: Lit / Dim / Dark, at least as circles around light sources and dark zones;
     - Metal: metal class per enemy;
     - Nature: growth patches with ages;
     - Light: Lit;
     - Dream: line of sight, front arc and sleep.
   - Where a rule is a big system, build the simplest honest version and list what is simplified.
3. **One general status engine.** Statuses are data in `statuses.json` with generic keys the enemy reads in one
   place, for example:
   - move_mult, attack_speed_mult, cannot_act, cannot_cast;
   - dps_per_stack (any status, not just alight), damage_taken_mult, armour_mult, front_block_off;
   - spreads (radius, time), on_expire (burst), on_death (cloud, corpse effect);
   - wakes_on_hit, flees, blinded (melee reach and sight), max stacks, lasts.
   - **Merge duplicate definitions across drafts into one each:** `blinded` (fire, light, dark), `unseen` (light,
     dark), `rooted` / `pinned`.
   - **Merge duplicate new kinds into one each:** `hex` / `smite` / `seize`, the instant effect on a targeted enemy.
     `field_pulse` is shared by Death and Nature.
4. **Skill kinds.** Use the existing behaviours wherever a draft's kind maps to one. Build the shared new ones
   generically:
   - smite, an instant targeted effect;
   - cloud, a drifting ground zone;
   - channel and charge_release, the held skills design/05 step 5c never built;
   - summon, a corpse thrall, as a simple allied fighter;
   - seed, hidden and triggered;
   - grapple, which moves you to a point;
   - streak;
   - decoy.

   Anything you cannot build properly in this pass still has to be castable: give it the nearest existing behaviour,
   set `"simplified": "what is missing"` on the ability, and show "(simplified)" in its description.
5. **Rune engine changes (effects_v1 plus the exporter):**
   - a status op on a skill that already applies that status adds stacks;
   - `jumps +n` on any hit arcs it on to n more enemies within 4 m (reduced damage, data);
   - `braced` works on any skill (Braced for the cast and recovery);
   - `through` makes a hit ignore front block and shields;
   - every skill's recovery (its own or the default) counts in the windup group;
   - a self buff's or channel's main magnitude counts as power. Each skill may declare `magnitude` paths, with
     direction, for this;
   - poise on any damaging hit adds stagger damage;
   - duration also lengthens the statuses a skill applies;
   - add `on_rise.poise` and `on_arrive.poise` to the poise group;
   - **ticking payloads** (zones, trails, channels, clouds) apply control statuses (stunned, aloft, interrupts,
     asleep, pinned...) at most once per target per cast.
6. **Test characters** (Brent's request), on the title screen, under "Test characters":
   - **One button per affinity (16).** Each creates a character with that one affinity and **every skill of that
     affinity learned**.
   - **Skills at a stage high enough to try big rune words.** The stage cap allows it, so give the character enough
     stars, or a test override clearly marked as one.
   - **The rest of the loadout:**
     - a full essence tank;
     - the rune palette (test loadout);
     - the first skills on the hotbar.
   - **It starts in town,** with a way to reach the practice arena.
   - Mark these characters as test characters in the save, and keep them out of normal play's rules where that
     matters.
   - Add a hotbar way to reach all of an affinity's skills: the existing hotbar has 6 slots, and the ethercosm can
     assign them. Make sure that is easy, or add a test-only "next page" of skills.
7. **Skill trees.** Give every affinity a skill tree in `skill_tree.json`, with tier 1 as the three starters, built
   from the drafts. Normal character creation can roll any of the 16 affinities.

## Tests (all must pass before you commit)

- **Everything already in the suite:**
  - smoke;
  - self-test `0 failed`;
  - `--bot-dungeon`, `--bot-full`, `--bot-die`;
  - zone_probe;
  - nether_death_probe (and `--hardcore`);
  - windowed: ui_click_probe (and `--field`), creation_probe.
- **New: cast every skill.** A headless test that, for each of the 176 abilities:
  1. creates a test character of its affinity in a test world with dummy enemies;
  2. casts the skill (aimed, pointed or targeted as needed);
  3. ticks a few seconds of game time.

  It fails on any script error (ErrorCatcher), and prints a line per skill: hit something / applied its status /
  simplified. Also cast each skill with a locked word of three good modifiers from its own draft, so the rune
  engine runs on every skill.
- **New self-test checks:**
  - status stacking;
  - jumps on a non-chain hit;
  - `through`;
  - the ticking-payload rule;
  - a status from each new affinity rule;
  - a test character has every skill of its affinity.
- **Screenshots** (look at each one and iterate until it looks right):
  - the title screen with Test characters;
  - one test character of each of three new affinities fighting in the arena;
  - the ethercosm of a test character with many skills;
  - the rune view with a new affinity's skill;
  - the HUD with new statuses on enemies.

## Commit and report

- **Commits:** several, one per coherent step, on your branch, Conventional Commits, each ending
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. Do not merge, push, tag or delete anything.
- **Report:**
  - files by area;
  - exact test lines;
  - the cast-every-skill summary: how many hit, applied their status, or are simplified, with the simplified list;
  - every merged duplicate;
  - every decision Brent has not made;
  - screenshot paths;
  - what is not built.
