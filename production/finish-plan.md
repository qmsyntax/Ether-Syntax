# Ether Syntax - the plan to finish (2026-11-08)

Written at `v0.55.0-construct-words` (4959094). It replaces `production/build-plan.md` (2026-10-18), whose phases it
re-orders with what has landed since. Brent's open questions and play tests are kept in `production/brent-todo.md`.
Sizes are relative (S one build, M two to four, L a sprint, XL several sprints). There is still no velocity data and no
hand-play data, so there are no dates.

## Where we are

Seventeen builds since the last plan (v0.41 -> v0.55), almost all of them depth in skills and runes:

| Area | 2026-10-18 | Now | Region 1 needs (the slice) | Full design |
|---|---|---|---|---|
| Skills | 35 of 40, 5 affinities | **216 skills, 18 affinities**, roles, status engine, held skills | done (13 simplified) | done |
| Runes and seals | none | **rune sets, seals, level locks, keystones, 262 vestiges + 112 words**, discovery | done, rulings open | done |
| Ascension | to 2 stars | **every star** (offer + per-skill boosts) | done | curve past 2 stars undesigned |
| Combat feel | first pass | input buffer, hit-stop, sidestep + endurance, review fixes R1-R4 | backlog R2, R5-R8, Q3-Q5 | - |
| Zones | town, arena, Tenwall Cut, empty Stubble | **+ the Stubble populated** (8 unstarred kinds, camps, its Netherecho) | 12 (4 built) | 34 + regions past 3 stars |
| Enemies | 8 starred humans | **16 kinds** (8 starred, 8 unstarred stand-ins) | + 4-6 beasts, Sapper, 8 named rares, real creature art | 55 more for bands 2-12 |
| Items | 59 | 80 | band 1 complete (~250 of the draft) | 1,984 drafted |
| Talents | 6 playable of 40 | **6 playable** of 40 | 12+ playable | 108+, evolutions to 10 stars |
| Tempering | 6 of 18 | 6 of 18 | 18 + manuals | same |
| Crafting | step 1 started | 3 skills, 35 recipes | finish step 1 + gathering | 20 skills, 1,392 recipes |
| World engine | none | camps, leash, respawn, fog, minimap, zone save | clock + night, map screen, carriage, named spawns | same |
| Audio | none | **none** | the basics | full |
| Shipping | none | **never exported**; S:\Passage gets the project folder | a Windows .exe | installer, settings, controller |

**What has not moved since the last plan**, and is now the biggest risk:
1. **No hand-play.** 55 tagged builds; the fun gate has never been held. Every "works" is a script's word.
2. **Phase 0 and Phase 2 were skipped.** `player.gd` has grown to 7,949 lines (the target was under 1,200), `main.gd`
   3,649, `enemy.gd` 2,099. Saves are not written atomically. There is no export preset, no fps number for a full
   wall, the physics engine is not pinned, and the test suite runs from two scripts in a temp folder, not the repo.
3. **Breadth.** Region 1 has 4 of its 12 zones; 6 of 40 talents play; no sound at all.

The depth work was what you asked for and it was right to do. But each new system now costs more to add, because it
touches the 8,000-line player script, and none of it has met a player. So the next stretch flips the balance: make it
safe, play it, untangle it, then fill the world.

## What "finished" means (your call - in the to-do)

| Target | What it is | Rough size from here |
|---|---|---|
| **A. Vertical slice** | Region 1 (12 zones), a new character from creation to 2 stars, the whole loop, sound, a Windows .exe. The thing to show the author. | ~6-8 XL-sized stretches |
| **B. First act** (recommended as "the game") | Regions 1-3 (25 zones), stars 1-4, Winchgate as the second city, 30+ talents, items to band ~20, crafting through step 3 | A + about as much again |
| **C. The full design** | All 34 zones and the regions past 3 stars, 10 stars, 108 talents, 1,984 items, 20 crafts, the long game (contracts, factions, auctions, breaks, parties) | many times B; partly undesigned and past what canon covers |

Recommendation: aim at **B** as "finished". Treat A as its checkpoint and C as what comes after, if B is fun. The
phases below run to A, then B.

## The plan

### Phase 0 - Safe to build on (M) - starts now, needs nothing from you except the export yes
- Save safety: write to a temp file, then rename, keeping a backup; a real schema version with migrations; hardcore
  death clears every slot.
- [x] Move the test suite into the repo (`tools/test/run_all.sh`: headless + windowed, one Godot at a time) - done
  2026-11-08, with the lock wrapper `tools/test/godot.sh`; see CLAUDE.md "Tests - one command".
- [x] Fix the move probe's flake at its cause - done 2026-11-08, in the probe: state leaked between cases (a camp
  woken by one case was still awake in the next "asleep" one; the body kept the last case's facing), a click's
  target was read before the click was handled, and the facing check averaged a short run's samples, so a brief
  pose pop (below) swung it past the limit or not with frame timing. The brute-slam flake too (bodies stepped by
  hand now move the exact step, `ExactSlide`), and every test's random rolls are seeded (`RngSeed`). Found, not
  fixed (game, art pipeline): when the sprint and the run cross-fade on a dip in speed, the body's shoulders and
  hips swing ~80 degrees for a few frames.
- [ ] The self-test must back up and restore the player's key bindings.
- Pin the physics engine; a version stamp in the game and in saves.
- **A Windows export**: a preset, the export templates (a download - your yes), and an .exe on S:\Passage from then on.
- Performance: measure a full wall of real enemies, the Stubble and the town crowd. Then pool enemies, strip hidden
  pieces, share materials, add visibility ranges and a shader warm-up. Target: 60 fps on your machine with headroom.
- Done when: one command runs every test, a full-wall fps number is on record and meets budget, a save survives a kill
  mid-write, and S:\Passage has a working .exe.

### Phase 1 - The fun gate (you; runs alongside Phase 0)
- You play a session or two using the checklist in the to-do. Claude writes up a playtest report from your notes (or
  a screen recording if you make one).
- One tuning pass on numbers only, then a verdict: keep going / change direction / stop.
- After that, every build that changes how something feels comes with a short "what to try" list.

### Phase 2 - Untangle (L) - before content multiplies the cost of every change
- Split `player.gd` by concern: movement and feel, combat and hits, casting and kinds, runes and seals, progression
  (stars, ascension, skill points), economy and inventory, the bot driver. Split `main.gd` into a game state machine
  plus one controller per level type (town, field, passage, arena, Netherecho) and a test harness loaded only by test
  flags. Split `enemy.gd` into one brain per behaviour.
- Give the big objects class names and typed calls. Validate data once on load and remove the silent numeric fallbacks.
- No behaviour change: the full suite and the combat-review probe must give the same numbers before and after.
- Done when no gameplay file is over ~1,500 lines and the suite is green.

### Phase 3 - Systems to slice depth (XL; three streams in parallel once Phase 2 lands)
- **Combat**: your rulings on R2 / R5 / Q4, then R6 (juice: hit sounds, death bursts, kill knockback, bigger skill
  numbers - lands with the audio in Phase 5), R7 (swarm camps, champions), R8 (visible growth), Q3, Q5; enemy statuses
  on the player; the 13 simplified skills; cover and pillars in chambers.
- **Gear** (design/06 steps 2-6, design/10): worn weight, the rest of the armour, weapon families, shields and guard,
  the five ranged families with ammunition, quick slots, rarity tiers, uniques; band 1 items complete. Needs your
  design/10 section 16 answers.
- **Character**: talents 6 -> 12+ playable in batches (hidden flags rolled per save); tempering 6 -> 18 with manuals;
  crafting step 1 finished plus gathering nodes and field kits.
- **World engine** (design/07): the 90-minute clock with night, sleeping at camps, the map screen, carriage posts,
  named spawns, the off-screen threat marker. Needs your design/07 answers.

### Phase 4 - Region 1 built (XL; starts once a creature source is chosen)
- First, prove one real beast end to end (rig, clips, look, remains) on the existing pipeline. Then replace the 8
  stand-ins and add 4-6 more kinds, at least two of them four-legged.
- The rest of Region 1: Longacre Drove, Carrion Flats, Sumpside, Hackle Foot (overland); the Old Counting-House and
  Drowned Lock (dungeons, plus a second dungeon template beside the assault); the Muster (raid-like).
- Tithebarrow rebuilt modern: the Ninth and Passage Row as walkable districts with every designed service.
- The starred invaders moved east, the Sapper, and the 8 named rares.

### Phase 5 - Sound and look (XL; alongside Phase 4)
- Audio from nothing (needs a source): buses, a sound manager, hits, telegraphs, footsteps, UI, ambience per zone, then
  music.
- VFX for skills and statuses (216 skills share a small set of effect families, so this is a library, not 216 jobs).
- Kits: the modern town, swamp, mountain and dungeon realms; real weapons and shields.
- Graphics settings, LOD and impostors.

### Gate - Vertical slice (target A)
A new character goes from creation to 2 stars in Region 1 with the whole loop; you play it start to finish; tag
`gate/vertical-slice`. That is the build to show the author, when you say.

### Phase 6 - Toward the first act (target B)
- Design the curve past 2 stars (design/10 Q2, and the canon questions), then stars 3-4: ascension, body curve,
  talent evolutions, construct tiers in the wild, bands 2-4 of the item draft, band-scaled costs.
- Regions 2 and 3: the Sallow Fen (6 zones) and the Hackle (7 zones, with Winchgate as the second city and its ticket
  auctions and standing).
- Talents to 30+, crafting steps 2-3, the band 2-4 creatures.

### Phase 7 - Ship-ready (L)
- The full settings menu, controller support (aim and soft-target design first), accessibility, onboarding, crash
  logging, a minimum-spec performance pass, a build pipeline, localisation keys.
- Naming and anything public stay your call (CLAUDE.md rule 1).

### After B (target C, only if B is fun)
Regions 4-5 and the regions past 3 stars (undesigned), stars 5-10, the long game (contracts and courier work, faction
standing, auctions, the bank, breaks, soul damage, parties), the metropolis.

## Order at a glance

```
now:     Phase 0 (safe + .exe) ‖ Phase 1 (you play)
then:    Phase 2 (untangle)
then:    Phase 3 (systems) ‖ Phase 4 (Region 1) ‖ Phase 5 (sound + look)
gate:    vertical slice (A)
then:    Phase 6 (stars 3-4, regions 2-3) -> Phase 7 (ship-ready) = first act (B)
```

## How the work runs

- Claude runs agents in parallel worktrees, one stream per phase. Each release follows the routine: check the
  screenshots, merge, the full suite, tag, push, copy to S:\Passage, relaunch.
- Your time goes to playing and ruling. Everything that needs you is in `production/brent-todo.md`, ordered by what it
  unblocks. Work never stalls waiting on one answer; it goes on with the stream that doesn't need it.
- Once Phase 2 lands, the session state file (`production/session-state/active.md`, last written 2026-09-18) is
  rewritten and kept current.

## Risks

- **Fun is unproven.** If the first play says the loop doesn't hold, Phases 3-6 change. That is why Phase 1 is now.
- **Depth before breadth again.** New rune or skill rulings are welcome, but each one is weighed against the slice.
- **Asset sources**: creatures, audio and the modern town each need a source you approve. Creatures come first.
- **Canon runs out** near 6 stars. Target B stays inside what the books cover; C does not.
- **Performance** of real bodies at crowd sizes is unmeasured.
- **Repo size** (484 MB) grows with every art pass; Git LFS is worth deciding before Phase 4.
