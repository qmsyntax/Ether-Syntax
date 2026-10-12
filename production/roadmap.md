# Roadmap — from concept prototype to vertical slice

> Written 2026-09-23 after Brent's first reaction to `v0.4.0` ("not half bad") and his list: satellites as
> items, inventory, loot, the Netherecho, an ethercosm screen, ability hotkeys. Order follows the dependency
> map in `design/gdd/systems-index.md`. Sprint contents are proposals; `/sprint-plan` turns each into stories.
> Durations are not estimated — no velocity data exists yet.

## Where we are
Concept prototype, `v0.4.0-hud-and-keybinds`. All 17 MVP systems exist in the build, rough. Brent has played it
enough to say it is not half bad; the fun gate is not formally passed (no `/playtest-report`, no PROCEED verdict).

## Milestone 1 — Fun gate (now)
- Brent plays `v0.4.0` properly; `/playtest-report` records what worked, what didn't, what broke.
- One tuning sprint from his notes (numbers only — no new systems). Tag `v0.5.0`.
- Verdict: PROCEED / PIVOT / KILL. Everything below assumes PROCEED.

## Milestone 2 — Foundations that everything Brent asked for hangs off
**Sprint 2a — Damage & Hook Pipeline + Data Definitions** (index #1, #2)
- Every hit is an event; talents, items, summons and DoTs subscribe to it instead of living in `player.gd`.
- Enemies, abilities, prices, healing rates move from constants into `game/data/*.json`.
- Why first: inventory effects, loot modifiers, more talents and the ethercosm screen all read from this.

**Sprint 2b — Abilities as data + hotbar** (index #20, #44)
- Abilities defined in data with cost, reflux, stage and progress; progress advances by essence spent through
  the ability plus use (Brent's 2026-09-23 ruling). Stage-ups stubbed until binding exists.
- Hotbar: N slots, each an InputMap action (`ability_1..N`) in the existing controls menu; assign abilities to
  slots from the ethercosm screen.

## Milestone 3 — Things you own
**Sprint 3a — Inventory, equipment slots, loot** (index #42, #21, #32 minimal)
- Inventory with weight or slot capacity (canon: carry capacity is an economic stat).
- Equipment slots incl. **one satellite slot**. Satellites become items; the free 1/s starter is removed.
  Open question to settle first: what refills essence without a satellite (proposal: meditation gathers).
- Loot: drops from monsters and per-person rewards at the passage exit scaled to contribution; sell in town.
- Save/load (index #18) lands here because inventory is the first thing worth saving.

**Sprint 3b — Ethercosm screen** (index #43)
- A screen you open from town or while meditating: your stars (tanks, fill, the aura's qualitative read),
  abilities arranged around them with stage/progress, the satellite, and **runes** — Brent to define what a rune
  is before this sprint (`design/02-open-questions-for-brent.md`).

## Milestone 4 — The other layer
**Sprint 4a — Netherecho throwaway prototype** (index #28, flagged high-risk)
- Isolated prototype (`prototypes/netherecho/`), not in the main build: project from meditation, wisps as
  gatherable paint, wild vestiges with one-hit-kill on the projection, flee-to-body. Verdict before any GDD.

**Sprint 4b — Netherecho in the build + construct binding** (index #28, #29)
- Subdue-and-bind duels that stage-up an ability; the construct's concept picks the named upgrade.

## Milestone 5 — Vertical slice
- Death into debt with contracts/indenture as content (#22), a fuller town (#23), character creation with the
  broker (#24), 2★ ascension with talent evolutions for all six wired talents (#19), menus (#26).
- `/vertical-slice` verdict gates Production.

## Parked until after the slice
Room generator and adaptation director, spirit abilities (blocked on canon Q29/Q30), ticket auctions and standing,
gear sets and uniques, soul damage, badges, break events, hired party, audio, onboarding, accessibility.

## Standing rules
- Rights and outreach stay parked (CLAUDE.md Rule 1, 4).
- Each sprint: stories via `/create-stories`, smoke + self-test + bots green before every commit, tag at the end.
- Brent plays every tagged build; his notes beat any number in the design docs.

## Build targets added 2026-10-11 (the playtest day)
Standing instruction from Brent: add these to the build target. Design docs first, then build in the staged order
each doc proposes; nothing here is started in code unless marked.

1. **Affinity skills, combat depth, tempering rethought** - `design/05-affinity-skills-and-combat-v0.md` (approved
   by Brent 2026-10-12 as recommended). One signature mechanic per affinity, 40 skills, cross-affinity rules,
   seven enemy archetypes, poise / stagger / interrupts. **Built (2026-10-12):** step 1 water and lightning, step 2
   the combat rules, step 3 fire, wind and earth - all five starter kits now play by their own rule (sprint-06
   Parts O-U). Step 4 (Pavise Bearer, Censer-Bearer, War Drummer, the phased Wall Commander) is built too (Part W). Steps 5a and 5b (scrolls, and twenty of the 25 further skills) are built (Parts X, Y). **Not built:** cover in the chambers, the five held skills of step 5c
   (the other 25 skills, learned from scrolls), step 6 (tempering rethought, the cross-affinity rules).
2. **Loot, equipment slots, armour, ranged weapons** - `design/06-loot-and-equipment-v0.md` and
   `design/data-drafts/items-v2.json` (design agent, in progress). More slots, armour, ranged weapon families that
   change the basic attack, a full loot list.
3. **Biomes** - dungeon, snow, swamp, mountain, city, scrubland kits (art agent, in progress on branch
   `art/environments`), then wiring into the level builder.
4. **Learning skills and techniques** - scrolls or a trainer; today a character only has its starter kits.
5. **Pacing pass** - measure the real time to the second star against the two-hour target; slow skill progress.
6. **Enemy art** - bring the three enemies up to the player model's fidelity.
