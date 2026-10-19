# Passage — full build plan (2026-10-18)

Updated 2026-10-19 for Brent's ruling that the early levels are spent hunting non-starred monsters. Written after a three-part review of main at `v0.41.0-real-enemies` (+ design commits to `bdd6983`): the designs against the
build, the code's health, and the content against the full-game targets. It replaces `production/roadmap.md` (2026-09-23),
whose milestones 2-4 are done and whose fun gate never happened. Sizes are relative (S one build step, M two to four, L a sprint,
XL several sprints); there is no velocity data, so there are no dates. Nothing here has been hand-played: every "built" means the
code and data exist and the automated tests pass.

## Where the game is

| Area | Now | Full game |
|---|---|---|
| Zones | 4 of 34 designed (town square, practice arena, the Stubble with no enemies, Tenwall Cut) | 34 in regions 1-5, then regions for 4★ and up (not designed) |
| Enemies | 8 masked-human kinds, star 1; no unstarred monsters | the early unstarred bestiary (3 designed + 4-6 to design), 8 named rares, 55 drafted creatures for bands 2-12 (many non-human) |
| Items | 59 live | 1,984 drafted across 12 bands |
| Skills | 35 of 40 (5 held skills missing); skill tree and trainer built | 40 |
| Talents | 40 in data, 6 playable, evolutions only to 2★ | 108+ (design/04), evolutions per star to 10 |
| Tempering | 6 of 18 techniques | 18 + manuals |
| Crafting | step 1 in progress (3 of 20 skills, 20 of 1,392 recipes) | 20 skills, gathering, pattern books |
| Progression | tops out at 2★ | 10★ and beyond |
| Quests, dialogue, factions | none (story is emergent by design) | contracts, standing, named NPCs |
| Art | real bodies, hair, faces, enemies; scrubland ground and props | every biome, modern cities, realm kits, weapons, VFX |
| Audio | none | full |
| Tech | saves, keybinds, UI v2 | settings, controller, localisation, export, perf budget |

## The plan

**Phase 0 — Make it safe to build on** (M). Do first; these bite whatever comes next.
- Save safety: atomic writes (temp file, rename, backup), a real schema version with migrations, hardcore death clears every slot.
- The self-test deletes the player's own key bindings: back them up and restore them as the click probe does.
- Fix the flaky brute-slam checks at the cause: enemies move by the exact frame step, not move_and_slide's own clock.
- Pin the physics engine; version stamp in game and in saves; one command that runs every test; an export preset and one test export.
- Measure a full wall of real enemies and the town crowd; then pool enemies, strip hidden pieces per archetype, share materials,
  add visibility ranges and a shader warm-up. Target 60 fps on the dev machine with a full wall, with headroom to spare.
- Done when: all tests run from one command, a full-wall fps number is on record and meets budget, a save survives a kill mid-write.

**Phase 1 — The fun gate** (S for Brent, M to act on). The roadmap's first milestone, never held.
- Brent plays the current build for a session or two: town, a trainer, the Stubble, Tenwall Cut, the arena, dying and the corpse run.
- A playtest report records what is fun, what drags, what breaks; one tuning pass on numbers only.
- Done when: a PROCEED / PIVOT / KILL verdict is written. Everything below assumes PROCEED.

**Phase 2 — Untangle the code** (L). Before content multiplies the cost of every change.
- Split main.gd into a game state machine and one controller per level type (town, field, arena, passage), a level factory, the
  world look, and a test harness that loads only with test flags. Split player.gd (combat, casting, progression, economy,
  targeting, bot driver) and enemy.gd (one brain per behaviour). Give Player, Enemy and Game class names and typed calls.
- Validate data once on load and remove the ~290 silent numeric fallbacks; move the hard-coded gameplay numbers and talent
  constants into data; replace skill-id checks in the damage pipeline with effect hooks.
- Retire the procedural people (keep procedural weapons, grass and Netherecho until replaced).
- Done when: no file over ~1,200 lines, no stringly-typed cross-object calls, every gameplay number in data.

**Phase 3 — Finish the approved systems** (XL; runs in parallel with Phase 4 once Phase 2 is done).
- Combat and skills (design/05): the 5 held skills (channel, charge-release), cover and pillars in chambers, cross rules 2-10,
  per-skill concept rules, the five deviations from Part Y, step 6 tempering (12 techniques, manuals).
- Equipment (design/06 steps 2-6): worn weight, the rest of the armour, weapon families and two-handed rules, shields with a guard
  pool, the five ranged families with ammunition, consumables and quick slots, rarity tiers and colours, uniques, curses and tolls,
  the runesetter.
- Items (design/10): band, rarity and category in shops and the pack; band-aware drops; a stacking pack; use effects.
- Crafting (design/11): finish step 1, then the remaining 17 skills in the approved order, gathering nodes in zones, field kits,
  pattern books and guild halls.
- Talents: wire the 34 data-only talents in batches (12+ playable by the vertical slice), hidden flags rolled per save.
- Rule fixes the review found: the arena grants growth (it should not); satellite essence makes no reflux (it should).

**Phase 4 — Region 1, complete and modern** (XL). The vertical slice's world.
- World engine (design/07): the 90-minute clock with night, camps with sleep, aggro, leash and walk-home, respawn and zone memory,
  position in the save, the off-screen threat marker, the map screen, named spawns, carriage posts, perches, a zone bot.
- Tithebarrow rebuilt as a smaller modern town (Brent's rulings): brick, concrete, signage, screens, power lines, vehicles; folk with
  phones; the Ninth and Passage Row as walkable districts with every designed service (bank, registry, ticket hall, collection
  office, carriage post, runesetter, crafting stations).
- New Earth countryside: the Stubble made modern-rural (roads, wires, ruins) and populated; Longacre Drove, Carrion Flats,
  Sumpside, Hackle Foot.
- Realms stay fantasy: Old Counting-House, Drowned Lock, the Muster; a second dungeon template beside the assault.
- Enemies, unstarred first ([B] 2026-10-19: the early levels are spent hunting non-starred monsters): the Stubble and the
  west of Longacre Drove hold only unstarred monsters - the Gleaner, Sod-Lurker and Thornback plus 4-6 more kinds to design,
  at least two of them quadrupeds - whose remains feed Rendering and Leatherwork. Then the starred invaders (moved east and into
  the later ring zones and Tenwall Cut), the Sapper and the 8 named rares. An unstarred kill's aura falls off as the star grows.
- This makes the **creature source the first thing Phase 4 needs**: decide it during Phase 1 and prove one beast (rig, clips,
  look, remains) on the existing pipeline before the zone work starts.
- Done when (vertical slice): a new character can go from creation to 2★ in region 1 with the whole loop - town, crafting, field,
  dungeons, death, corpse run - and the playtest says it holds up.

**Phase 5 — Art and sound foundations** (XL; starts alongside Phase 4).
- Modern city kit: buildings at three scales (town, city, metropolis), streets, vehicles, street furniture, signage, screens and
  ethertech props; districts that stream so a massive city stays fast.
- Realm kits with real assets for each biome (dungeon, swamp, snow, mountain), real weapons and shields, enemy props, VFX for
  skills and statuses, cloth and hair motion where it pays.
- Audio from nothing: bus layout, sound manager, hits, telegraphs, footsteps, UI, ambience per zone, music.
- Graphics settings (resolution, quality, effects, fps cap), LOD and impostors for crowds and distance.

**Phase 6 — Stars 3 to 10** (XL; needs Brent's canon answers).
- Design the curve past 2★ (design/10 Q2), then ascension 3-10, the body curve per star, talent evolutions per star for every
  playable talent, construct tiers past remnant, band 2-12 items wired from the draft, band-scaled sinks, the Loud rule and caps.
- The 55 band 2-12 creatures designed and built (behaviours, looks, remains) on the creature pipeline Phase 4 proved; each
  later region keeps some unstarred wildlife for gathering and ambience, but its fights are starred.
- Spirit abilities and aura compression once canon Q29/Q30 are answered.

**Phase 7 — The wider world** (XL).
- Regions 2-5 (Sallow Fen, the Hackle with Winchgate, Rimeward, the Understeps): 22 zones, 8 more dungeons and raid-like realms.
- Design the regions for 4★ and up (none designed yet).
- The very big modern metropolis (Brent's ruling), built on the Phase 5 city kit with district streaming.

**Phase 8 — The long game** (XL; needs design first).
- Contracts and courier work, faction standing, ticket auctions, badges, the bank and trunk, owned / wild / public passages
  everywhere, breaks (realm spill-outs into cities), soul damage, parties or hired help for raid-like realms, dialogue beyond one
  line per person.

**Phase 9 — Ship-ready** (L).
- Localisation (string keys, extraction), controller support (an aim and soft-target design), accessibility, onboarding, the full
  settings menu, crash logging, a minimum-spec performance pass, a build pipeline. Rights and outreach stay parked until Brent says.

## Order at a glance

0 Safe to build on → 1 Fun gate → 2 Untangle → (3 Systems ∥ 4 Region 1 ∥ 5 Art and sound) → vertical slice gate → 6 Stars 3-10 →
7 Wider world → 8 Long game → 9 Ship-ready. Phases 3-5 overlap because they touch different code once Phase 2 has split it.

## Decisions needed from Brent, by what they unblock

1. Phase 1: play the build and give the verdict (the single most useful thing now).
2. Phase 3 items: the open questions in design/10 §16 were never ruled on (bands at +5%, money ×4 per star, the Loud rule,
   weight per band, armour cap per star, one band per star). They gate every item above band 1 and stars past 2.
3. Phase 3 skills: design/08 Q1-6 (skill point pace, drill, scroll prerequisites, trainers per affinity, respec, town actions).
4. Phase 4 world: design/07 Q3 (the passage meter), Q4 (does the clock run in dungeons), Q6 (a trunk in your room),
   Q8 (do herds belong), Q10 (bands per region).
5. Sources: a creature source for the unstarred beasts (now needed at the start of Phase 4, so decide it during Phase 1),
   audio (a CC0 library such as Freesound's CC0 subset, or generated) and the UI font from Google Fonts (design/09 Q1) for
   Phase 5. Downloads still need your yes each time.
6. Phase 6 canon: how long later stars take (design/10 Q2), spirit abilities (design/02 Q29/Q30), soul construct (Q17),
   whether ability progress carries across ascension (Q5 follow-up).
7. Repository: about 350 MB of history so far with every model re-export adding 10-13 MB; Git LFS for the large binaries
   (local only, no remote) is worth a yes before Phase 5.

## Risks

- Scope: the full design is several times what exists. The vertical slice (region 1, 1★-2★) is the honest first target.
- Performance: real bodies are heavy (114 meshes and a 65-bone rig each) and a full wall has not been measured.
- Canon gaps: stars past 6 and much of the later world are invented; the books cover less than the game needs.
- No hand-play yet: every system is tested by scripts only; feel, pace and fun are unknown until Phase 1.
- Asset sources: creatures, audio and modern architecture each need a source Brent approves. Creatures come first now: the
  opening hours are unstarred monsters, so region 1 cannot be populated without them.
