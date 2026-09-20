# Systems Index: Passage (working title)

> **Status**: Draft — written autonomously at Brent's request ("get this as far as you can"); **awaiting Brent's review**
> **Created**: 2026-09-20
> **Last Updated**: 2026-09-20
> **Source Concept**: design/gdd/game-concept.md
> **Review mode**: lean — TD-SYSTEM-BOUNDARY, PR-SCOPE and CD-SYSTEMS director gates skipped (they are not phase gates). Run `/gate-check systems-design` for formal sign-off.

Provenance tags per CLAUDE.md Rule 2. This index is `[MODEL]` throughout — the *decomposition* is ours;
the rules inside each system carry their own tags in their GDDs and in `design/01-systems-bible-v0.md`.

---

## Overview

Passage is a solo, real-time isometric dungeon crawler built around a body that can be hurt in
layers and a town that charges for time. Mechanically it needs four things to work together: a
**damage pipeline that talents can hook into** (one odd permanent rule per character, many
talents), a **wound model** where natural healing is free but slow and never restores what is
lost (Pillar 3), a **time-and-money economy** that makes resting a real decision inside a 20–30
minute sitting, and **dungeons whose rules are fixed at creation** — sealed entrances, a halfway
gate, escalating stages, rewards scaled to contribution. Everything else (the Netherecho layer,
construct binding, auctions, standing, relics, break events) deepens the feeling of living in
that world (Pillar 1) and is layered on after the core is proven fun.

---

## Systems Enumeration

"Prototype" = what `game/` already does at tag `v0.2.0-natural-healing`: **Yes** (rules run and are
self-tested or smoke-tested), **Rough** (works, hard-coded or partial), **No**. Nothing marked Yes has
been played for feel.

| # | System Name | Category | Priority | Status | Design Doc | Prototype | Depends On |
|---|-------------|----------|----------|--------|------------|-----------|------------|
| 1 | Damage & Hook Pipeline (inferred) | Core | MVP | Not Started | — | Rough — talent effects are a `match` inside `player.gd` | — |
| 2 | Data Definitions Layer (inferred) | Core | MVP | Not Started | — | Rough — talents are JSON; enemies, abilities, prices are constants in code | — |
| 3 | Input & Player Controller (inferred) | Core | MVP | Not Started | — | Yes | — |
| 4 | Game Flow & Scene Management (inferred) | Core | MVP | Not Started | — | Rough — one scene, a string state machine | — |
| 5 | Isometric Camera (inferred) | Core | MVP | Not Started | — | Yes | 3 |
| 6 | Wound & Body Model | Gameplay | MVP | Not Started | — | Yes — three layers, natural healing, striking arm | 1, 2 |
| 7 | Essence, Satellite & Reflux | Gameplay | MVP | Not Started | — | Yes — one tank, satellite regen, thresholds, lockout, meditate | 2 |
| 8 | Currency, Debt & Credit (inferred) | Economy | MVP | Not Started | — | Yes — money, debt, credit limit | 2 |
| 9 | Town Clock (inferred) | Economy | MVP (minimal) | Not Started | — | Rough — rent per second of rest stands in for a clock | 4 |
| 10 | Combat | Gameplay | MVP | Not Started | — | Yes — melee arc, overcharge, water bolt | 1, 3, 6, 7 |
| 11 | Talent System | Gameplay | MVP | Not Started | — | Rough — 40 defined, 6 wired, flags not rolled or hidden yet | 1, 2, 6, 7 |
| 12 | Enemy AI & Monster Definitions (inferred) | Gameplay | MVP | Not Started | — | Rough — two enemy kinds, chase-telegraph-strike | 1, 2, 6 |
| 13 | Living Scenery (inferred) | Gameplay | MVP | Not Started | — | Yes — grass and bushes, alive, destructible | 1, 6 |
| 14 | Dungeon Structure & Rule Cards | Gameplay | MVP | Not Started | — | **No** — wave arena instead; the one MVP gap | 2, 4, 12 |
| 15 | Healer Service | Economy | MVP | Not Started | — | Yes — layered prices, arm regrowth, credit | 6, 8 |
| 16 | Notebook HUD & Discovery Log | UI | MVP | Not Started | — | Rough — text panel; "Proven" lines for 3 discoveries | 6, 7, 11 |
| 17 | Combat Feedback (inferred) | UI | MVP | Not Started | — | Rough — float text, hit flash, wind-up colour | 1, 10 |
| 18 | Save/Load & Character Profile (inferred) | Persistence | Vertical Slice | Not Started | — | No | 2 |
| 19 | Latent Aura & Ascension | Progression | Vertical Slice | Not Started | — | Rough — hidden pool, risk-scaled gain, 2★ ascension; only Lifesteal evolves | 1, 6, 7, 11 |
| 20 | Abilities & Tempering Techniques | Gameplay | Vertical Slice | Not Started | — | No — one hard-coded bolt | 2, 6, 7, 10 |
| 21 | Loot, Extraction & Contribution Ledger | Economy | Vertical Slice | Not Started | — | Rough — flat bounty per kill | 1, 2, 8, 14 |
| 22 | Death, Debt & Indenture (two modes) | Economy | Vertical Slice | Not Started | — | No — death ends the run | 4, 6, 8, 9, 18 |
| 23 | Hub & Town Services (rent, ticket seller, scroll vendor) | Economy | Vertical Slice | Not Started | — | No | 4, 8, 9, 14, 15 |
| 24 | Character Creation (a prime manifests; the broker's trade) | UI | Vertical Slice | Not Started | — | Rough — a six-option key menu | 2, 8, 11, 18 |
| 25 | Hub, Dungeon Select & Rule Card UI (inferred) | UI | Vertical Slice | Not Started | — | No | 14, 23 |
| 26 | Menus, Settings & Pause (inferred) | UI | Vertical Slice | Not Started | — | No | 4, 18 |
| 27 | Room Generator & Adaptation Director | Gameplay | Alpha | Not Started | — | No | 12, 14 |
| 28 | Netherecho Layer | Gameplay | Alpha | Not Started | — | No | 4, 6, 7, 12 |
| 29 | Construct Binding | Progression | Alpha | Not Started | — | No | 20, 28 |
| 30 | Spirit Abilities (aura compression) | Progression | Alpha | Not Started | — | No | 19, 20 |
| 31 | Affinity & Wisp Gathering | Progression | Alpha | Not Started | — | No | 7, 14, 28 |
| 32 | Gear, Sets & Unique Items | Economy | Alpha | Not Started | — | No | 1, 2, 21 |
| 33 | Ticket Auctions & Faction Standing | Economy | Alpha | Not Started | — | No | 8, 23 |
| 34 | Appraisal & Contracts | Economy | Alpha | Not Started | — | No | 8, 9, 23, 32 |
| 35 | Audio (inferred) | Audio | Alpha | Not Started | — | No | 4, 10 |
| 36 | Onboarding (inferred) | Meta | Alpha | Not Started | — | No | 10, 11, 16, 23 |
| 37 | Accessibility Options (inferred) | Meta | Alpha | Not Started | — | No | 16, 17, 26 |
| 38 | Soul Damage & Scars | Progression | Full Vision | Not Started | — | No | 6, 9, 18 |
| 39 | Badges & Reputation | Progression | Full Vision | Not Started | — | No | 14, 18, 23 |
| 40 | Break Events (district pressure) | Gameplay | Full Vision | Not Started | — | No | 9, 14, 23 |
| 41 | Hired Party (optional) | Gameplay | Full Vision | Not Started | — | No | 12, 19, 21 |

Why the inferred systems exist:
- **Damage & Hook Pipeline** — forty talents each change one rule about dealing or taking damage. Without a shared damage event that talents subscribe to, every talent is an edit to the player script (which is exactly what the prototype does today).
- **Data Definitions Layer** — the project's coding standard requires gameplay values in data, not code; enemies, abilities, prices and healing rates are all constants right now.
- **Town Clock** — Pillar 3 says free healing costs *time*. Rent, contract deadlines, natural healing in town and break pressure all need one clock to tick on.
- **Currency, Debt & Credit** — standard-mode death lands you in debt, so money must be able to go negative with rules, before any contract system exists.
- **Living Scenery** — a talent that pays on "anything alive" needs things that are alive and not enemies.
- **Save/Load** — hidden flags are rolled per save; debt, scars and standing persist; hardcore mode must be unforgeable.
- **Combat Feedback, the three UI systems, Audio, Onboarding, Accessibility** — every gameplay system needs a way to be seen, heard and learned.

---

## Categories

| Category | Description | Systems here |
|----------|-------------|--------------|
| **Core** | Foundation everything depends on | 1–5 |
| **Gameplay** | What you do moment to moment | 6, 7, 10–14, 20, 27, 28, 40, 41 |
| **Progression** | How the character grows | 19, 29–31, 38, 39 |
| **Economy** | Money, time, goods, consequences | 8, 9, 15, 21–23, 32–34 |
| **Persistence** | Save state and continuity | 18 |
| **UI** | What the player sees | 16, 17, 24–26 |
| **Audio** | Sound and music | 35 |
| **Meta** | Outside the core loop | 36, 37 |

**Narrative** is removed as a category: the concept specifies emergent narrative only — no authored plot, no canon cast (CLAUDE.md Rule 1). Contracts, debts and scars carry the story and live under Economy and Progression.

---

## Priority Tiers

| Tier | Definition | Target Milestone | Design Urgency |
|------|------------|------------------|----------------|
| **MVP** | Needed to answer "is this fun?" under the revised pillars: free-but-slow healing, time pressure, varied talents, one gated dungeon | First playable | Design FIRST |
| **Vertical Slice** | One complete gated dungeon with a rule card, a minimal town, persistence, death-into-debt, 2★ ascension | Vertical slice | Design SECOND |
| **Alpha** | Full mechanical scope in rough form: Netherecho, binding, generator, gear, auctions | Alpha | Design THIRD |
| **Full Vision** | Scars across runs, badges, break events, hired party | Beta / Release | As needed |

Priorities follow the **proposed** MVP in `game-concept.md` (Brent to confirm). Why each MVP system is there:

| System | Why MVP |
|--------|---------|
| Damage & Hook Pipeline | Every talent is a hook on this. Without it, "many varied talents" (Rule 5) means rewriting the player for each one. |
| Data Definitions Layer | Tuning is the whole job after the first playtest; numbers buried in scripts make every tweak a code change. |
| Input & Player Controller, Camera | The 30-second loop is moving and hitting. D2-style feel lives here. |
| Game Flow & Scene Management | The gated dungeon needs a real enter → seal → gate → exit flow, not a string in one script. |
| Wound & Body Model | Pillar 3 *is* this system: what mends, what never does, what a lost arm costs you. |
| Essence, Satellite & Reflux | The pacing system — heat instead of mana. Decides whether abilities feel like a resource or a trap. |
| Currency, Debt & Credit | Makes "free healing costs time" bite, and is the floor under standard-mode death. |
| Town Clock (minimal) | Without a time cost, free natural healing deletes all pressure and the core hypothesis is untestable. |
| Combat | The moment-to-moment. Overcharge is where "health as ammunition" becomes something your hands do. |
| Talent System | The unique hook. If six talents don't play differently, the premise fails regardless of everything else. |
| Enemy AI & Monster Definitions | Something has to be dangerous enough that wounds happen. |
| Living Scenery | Lets a lifesteal-type talent be used *between* fights — the beat the title talent is built around. |
| Dungeon Structure & Rule Cards | The no-retreat halfway gate is the core risk decision of a delve; the arena has no such decision. |
| Healer Service | The paid alternative to resting; the only non-talent route to regrowth. Sets the price of a mistake. |
| Notebook HUD & Discovery Log | Carries all feedback in a game that hides numbers on purpose. If it fails, the game reads as opaque, not mysterious. |
| Combat Feedback | Telegraphs and hit reactions are what make real-time combat fair. |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **Damage & Hook Pipeline** — the contract every hittable thing and every talent plugs into. **Bottleneck: 9 dependents.**
2. **Data Definitions Layer** — schemas and loaders for talents, monsters, abilities, prices, dungeons. **Bottleneck: 11 dependents.**
3. **Input & Player Controller** — movement, mouse aim.
4. **Game Flow & Scene Management** — hub ↔ dungeon ↔ Netherecho transitions, run state. **Bottleneck: 7 dependents.**

### Core Layer (depends only on foundation)

5. **Isometric Camera** — depends on: 3
6. **Wound & Body Model** — depends on: 1, 2. **Bottleneck: 11 dependents.**
7. **Essence, Satellite & Reflux** — depends on: 2
8. **Currency, Debt & Credit** — depends on: 2
9. **Town Clock** — depends on: 4
18. **Save/Load & Character Profile** — depends on: 2

### Feature Layer (depends on core)

10. Combat — 1, 3, 6, 7
11. Talent System — 1, 2, 6, 7
12. Enemy AI & Monster Definitions — 1, 2, 6
13. Living Scenery — 1, 6
14. Dungeon Structure & Rule Cards — 2, 4, 12
15. Healer Service — 6, 8
19. Latent Aura & Ascension — 1, 6, 7, 11
20. Abilities & Tempering Techniques — 2, 6, 7, 10
21. Loot, Extraction & Contribution Ledger — 1, 2, 8, 14
22. Death, Debt & Indenture — 4, 6, 8, 9, 18
23. Hub & Town Services — 4, 8, 9, 14, 15
27. Room Generator & Adaptation Director — 12, 14
28. Netherecho Layer — 4, 6, 7, 12
29. Construct Binding — 20, 28
30. Spirit Abilities — 19, 20
31. Affinity & Wisp Gathering — 7, 14, 28
32. Gear, Sets & Unique Items — 1, 2, 21
33. Ticket Auctions & Faction Standing — 8, 23
34. Appraisal & Contracts — 8, 9, 23, 32
38. Soul Damage & Scars — 6, 9, 18
39. Badges & Reputation — 14, 18, 23
40. Break Events — 9, 14, 23
41. Hired Party — 12, 19, 21

### Presentation Layer (wraps features)

16. Notebook HUD & Discovery Log — 6, 7, 11
17. Combat Feedback — 1, 10
24. Character Creation — 2, 8, 11, 18
25. Hub, Dungeon Select & Rule Card UI — 14, 23
26. Menus, Settings & Pause — 4, 18
35. Audio — 4, 10

### Polish Layer

36. Onboarding — 10, 11, 16, 23
37. Accessibility Options — 16, 17, 26

Leaf systems (nothing depends on them — safe to design late): 13, 17, 25, 26, 27, 30, 31, 33, 34, 35–41.

---

## Recommended Design Order

Effort: S = 1 session, M = 2–3, L = 4+. Systems the prototype already runs are mostly **reverse-documentation**
(`/reverse-document`) plus the decisions the code skipped — cheaper than designing from nothing.

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | Damage & Hook Pipeline | MVP | Foundation | systems-designer, lead-programmer | M |
| 2 | Data Definitions Layer | MVP | Foundation | systems-designer, godot-gdscript-specialist | S |
| 3 | Wound & Body Model | MVP | Core | systems-designer | M |
| 4 | Essence, Satellite & Reflux | MVP | Core | systems-designer | M |
| 5 | Currency, Debt & Credit | MVP | Core | economy-designer | S |
| 6 | Town Clock (minimal) | MVP | Core | economy-designer | S |
| 7 | Talent System | MVP | Feature | game-designer, systems-designer | L |
| 8 | Combat | MVP | Feature | game-designer, gameplay-programmer | M |
| 9 | Enemy AI & Monster Definitions | MVP | Feature | ai-programmer, game-designer | M |
| 10 | Dungeon Structure & Rule Cards | MVP | Feature | level-designer, game-designer | L |
| 11 | Healer Service | MVP | Feature | economy-designer | S |
| 12 | Living Scenery | MVP | Feature | game-designer | S |
| 13 | Input & Player Controller | MVP | Foundation | gameplay-programmer | S |
| 14 | Game Flow & Scene Management | MVP | Foundation | lead-programmer | S |
| 15 | Isometric Camera | MVP | Core | gameplay-programmer | S |
| 16 | Notebook HUD & Discovery Log | MVP | Presentation | ux-designer | M |
| 17 | Combat Feedback | MVP | Presentation | ux-designer, technical-artist | S |
| 18 | Save/Load & Character Profile | Vertical Slice | Core | lead-programmer | M |
| 19 | Latent Aura & Ascension | Vertical Slice | Feature | systems-designer | M |
| 20 | Death, Debt & Indenture | Vertical Slice | Feature | economy-designer, game-designer | M |
| 21 | Loot, Extraction & Contribution Ledger | Vertical Slice | Feature | economy-designer | M |
| 22 | Abilities & Tempering Techniques | Vertical Slice | Feature | game-designer | L |
| 23 | Hub & Town Services | Vertical Slice | Feature | economy-designer, world-builder | M |
| 24 | Character Creation | Vertical Slice | Presentation | ux-designer, game-designer | M |
| 25 | Hub, Dungeon Select & Rule Card UI | Vertical Slice | Presentation | ux-designer | M |
| 26 | Menus, Settings & Pause | Vertical Slice | Presentation | ui-programmer | S |
| 27+ | Alpha tier (27–37), then Full Vision (38–41) | — | — | — | — |

Items 13–15 are Foundation/Core but sit late in the order on purpose: they already work and hold few
open design questions, so documenting them can wait behind the systems where decisions are still owed.

---

## Circular Dependencies

None survive once a contract is defined. Three near-cycles to watch:

- **Talent System ↔ Latent Aura & Ascension** — talents evolve when a star forms, and the size of the evolution depends on compressed aura. *Resolution*: the Talent System exposes `evolve(star, jump)`; Ascension calls it. Aura depends on Talent, never the reverse.
- **Dungeon Structure ↔ Loot & Contribution** — rewards appear at the exit scaled to contribution, so each seems to need the other. *Resolution*: the dungeon emits an exit event carrying the contribution ledger; Loot subscribes. Loot depends on Dungeon only.
- **Death, Debt & Indenture (Vertical Slice) ↔ Appraisal & Contracts (Alpha)** — death creates a debt before any contract system exists. *Resolution*: a plain debt ledger lives in Currency, Debt & Credit (MVP); Contracts later extends it rather than replacing it. A sequencing risk, not a true cycle.

Also a **tier inversion**: Abilities (Vertical Slice) advance a stage only by binding a construct, and Construct Binding and the Netherecho are Alpha. In the Vertical Slice, abilities stay at Stage 0 or stage-ups are stubbed — the Abilities GDD must say which.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| Talent System | Scope / Design | 40 talents, each bespoke hooks and flags. With natural healing now free the title talent is less dominant, but trap picks remain likely. | Define a small vocabulary of hooks first; prove the six wired talents play *differently* before adding a seventh; run `/balance-check`. |
| Damage & Hook Pipeline | Technical | Today every talent is a branch inside `player.gd`. Each new talent makes that worse, and summons, DoTs and scenery all need the same hooks. | First GDD, first ADR, first refactor story. Blocks all talent growth. |
| Town Clock / "free costs time" | Design | Pillar 3 rests entirely on time pressure feeling fair inside a 20–30 minute sitting. If rent reads as a nag, free healing has no counterweight. | Already testable in the arena build (`v0.2.0`). Brent's playtest should target it directly. |
| Essence, Satellite & Reflux | Design | Brent calls reflux only partly understood; our thresholds are a working model `[MODEL]`. | Keep every number in data; revisit after a re-listen or a targeted read. |
| Latent Aura & Ascension | Design | Invisible progress can read as no progress. | The notebook must carry it; test the qualitative reads with someone who doesn't know the system. |
| Spirit Abilities | Design (blocked) | How they are acquired is an open canon question (Q29), as is Unholy Blessing (Q30). | Do not design until answered or until Brent rules that we invent it. |
| Netherecho Layer | Technical / Design | A second overlay world with its own entities, and a one-hit-kill rule that can feel unfair (Pillar 5). | Separate throwaway prototype (`/prototype`) before any GDD. Keep out of MVP and Vertical Slice. |
| Room Generator & Adaptation Director | Technical / Scope | Procedural rooms plus an AI that counters the player's habits is a classic solo-developer sink. | Hand-authored stages through the Vertical Slice; generator only in Alpha. |
| Whole project | Scope | 41 systems, one developer, no velocity data. Comparable solo isometric ARPGs took five to eight years. | Hold the line at MVP until the fun gate passes. Alpha and Full Vision are a map, not a commitment. |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 41 (25 explicit in the concept, 16 inferred) |
| MVP systems | 17 — 8 run in the prototype, 8 rough, **1 not built** (Dungeon Structure & Rule Cards) |
| Vertical Slice systems | 9 |
| Alpha systems | 11 |
| Full Vision systems | 4 |
| Design docs started | 0 |
| Design docs reviewed | 0 |
| Design docs approved | 0 |
| MVP systems designed | 0/17 |
| Vertical Slice systems designed | 0/9 |

---

## Next Steps

- [ ] **Brent reviews this enumeration** — missing systems? anything to merge, split or cut? are the priorities right?
- [ ] Brent confirms or overrules the proposed MVP in `game-concept.md`
- [ ] Design MVP systems in the order above (`/design-system [system-name]`, or `/map-systems next`)
- [ ] Run `/design-review` on each completed GDD, in a fresh session
- [ ] Run `/gate-check systems-design` for director sign-off on the system set
- [ ] Prototype the Netherecho separately before it gets a GDD
