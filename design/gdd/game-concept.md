# Game Concept: Passage (working title)

*Created: 2026-09-18*
*Status: Draft*

**Source universe**: the *1% Lifesteal* novels by Robert Blaise (publisher: Aethon Books).
This is an unlicensed, exploratory fan concept for internal evaluation only. The setting is
Blaise's; player characters, talent wording, names and art are original. No book text is
stored or reproduced — see CLAUDE.md Rule 1.

Ported from `design/00-game-concept-draft.md` v0. Full canon citations live in that file,
`design/01-systems-bible-v0.md` and `research/`. Provenance tags per CLAUDE.md Rule 2:
`[C]` read directly, `[F]` fan source, `[B]` Brent's ruling, `[MODEL]` our invention, `[?]` unknown.

---

## Elevator Pitch

> It's a dungeon crawler where you're a nobody who just became an archhuman, and you learn
> what your one permanent, secretly-ruled talent actually does by bleeding for it — while
> rent, healer bills and the city's factions all take their cut.

Premise `[C/F]`; phrasing `[MODEL]`.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Action RPG dungeon crawler, real-time isometric combat `[B]` |
| **Platform** | PC (Windows first) `[B]` — see `.claude/docs/technical-preferences.md` |
| **Target Audience** | Mid-core to hardcore PC players who like opaque systems and punishing economies; progression-fantasy readers second (proposed — see Target Player Profile) |
| **Player Count** | Single-player, solo-first; optional hired party that raises income and lowers growth `[B]` |
| **Session Length** | `[?]` not decided |
| **Monetization** | None. Unlicensed prototype; nothing ships or is sold without a written licence (CLAUDE.md Rule 1) |
| **Estimated Scope** | Small — prototype / first playable `[B]` |
| **Comparable Titles** | Diablo 2 (isometric combat feel) and Baldur's Gate 3 (hub depth) `[B]`; Darkest Dungeon and Stoneshard (attrition economy), Noita (rules learned by experiment) — proposed |

---

## Core Fantasy

You are a nobody who became something impossible — an archhuman — with exactly one permanent
power whose real rules are secret even from you. You spend blood, coin and your own body
finding them out, one bruise at a time. `[MODEL]` synthesis of `[C/F]` premises.

---

## Unique Hook

It's like Diablo 2, **and also** your build is a single permanent talent with hidden
"technicality" flags — does bleed count? does overkill count? does it cure poison? — that
can only be learned by experiment, inside a healing economy so punishing that lifesteal-type
sustain is the *correct* survival answer rather than a numbers pick.

Talent permanence and unknown fine print `[C]`; flags-as-discoverable-mechanic `[MODEL]`.
1% Lifesteal is one talent among many (`game/data/talents.json`), not the premise — CLAUDE.md Rule 5.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

**Top priority CONFIRMED by Brent 2026-09-19: living in that world comes first** `[B]`. When goals
conflict, the fantasy of being an archhuman in that city wins over system opacity and over
economic harshness. The order of ranks 2–4 below is proposed, not yet confirmed.
Evidence base: `research/audience-and-comparables.md` §1, `[F]`.

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Fantasy** | 1 `[B]` | A nobody-turned-archhuman in a might-makes-right city. Readers rate the world highly and the books' protagonist lowest — an original player character keeps the first and drops the second. Every system is judged first on whether it makes the player feel they live there. |
| **Discovery** | 2 | A talent whose core rule is visible and whose fine print still holds a few surprises; invisible latent aura, item histories, dungeon rule cards. Readers' top praise is the power system, and their recurring complaint is that the protagonist never systematically *tests* his talent — the game hands the player that experiment. |
| **Challenge** | 3 | Attrition with a floor: three-layer wounds, free-but-slow natural healing that never regrows what is lost, costly fast healing, reflux heat, the halfway gate. Pressure, not punishment. |
| **Expression** | 4 | One talent out of many, scroll loadouts, which constructs you bind, whether you take spirit abilities and stall your own ascension. |
| **Sensation** | 5 | Body-horror feedback: limb-cost overcharge, self-damage past reflux 80, tempering sessions. Low-poly keeps it readable rather than gory. |
| **Narrative** | 6 | Emergent only — debts, contracts, scars. No authored plot and no canon cast. |
| **Submission** | 7 | Grazing scenery between rooms is the one low-stress beat, and it is deliberate. |
| **Fellowship** | N/A | Solo-first. |

### Key Dynamics (Emergent player behaviors)

Behaviours the mechanics in `design/03-core-mechanics-spec-v0.1.md` are built to produce. All
`[MODEL]` predictions — none observed yet; the prototype has not been played for feel.

- **Running experiments on yourself.** Players deliberately hit constructs, undead, thrown
  scenery, etc. to see whether the talent pays, and keep the results in the notebook (spec §2).
- **Aggression as the safe play.** Limb-cost overcharge plus reflux heat should make ending a
  fight fast cheaper than playing it carefully (spec §8.2).
- **Grazing between fights.** Trampling the meadow and felling trees after a room to top up —
  the heal is useless in a fight and essential between them (spec §8.1).
- **Courting risk without a bar to watch.** Latent aura is never shown as a number and safe
  farming trends to zero, so players should drift toward harder tickets, solo play and
  no-consumable clears (spec §4).
- **Choosing where to be helpless.** Meditation purges reflux and is the door to the
  Netherecho, and both leave the body defenceless inside a sealed dungeon (spec §3).
- **The long bet.** Taking a spirit ability knocks visible progress back on the spot for a
  bigger jump later; a few players will sit at three and refuse to ascend (spec §4).

### Core Mechanics (Systems we build)

1. **Discoverable single-talent system** — hidden flags revealed through play `[C]` premise, `[MODEL]` implementation
2. **Attrition economy** — persistent injury, ruinous healer costs, lifesteal-type sustain as the budget answer `[C/F]`
3. **Per-affinity reflux heat** — replaces mana/cooldowns; kills purge it with the right construct `[C]`
4. **Netherecho** — second-layer projection overlay: wisps, item histories, wild vestiges; high reward, one-hit-kill risk `[C]`
5. **Passage / dungeon structure** — halfway-gate no-retreat rule, escalating stages, contribution-scaled loot `[C]`

---

## Player Motivation Profile

**PROPOSED — Brent to confirm.** `[MODEL]`

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** | Which ticket to bid on, when to cash out after the gate, whether to sell blind or pay for appraisal, whether to take a spirit ability and stall. The world constrains you hard; the choices inside the constraint are yours. | Core |
| **Competence** | Knowledge is the real loot — a proven talent flag is permanent skill, not a stat. Surviving on thin margins; the Supreme→Dynamic evolution at 2★ as a felt spike. | Core |
| **Relatedness** | Factions, healers and brokers who remember what you owe. Relationships are transactional by design. | Minimal |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Explorers** — primary. Understanding systems and finding secrets is the main reward: talent flags, construct concepts, rule cards.
- [x] **Achievers** — secondary. Filling the star, ascending, closing a dungeon for good, clearing debt.
- [ ] **Socializers** — not served. Solo-first.
- [ ] **Killers/Competitors** — not served. The canon arena gives no growth `[C]`; a side mode at most.

### Flow State Design

- **Onboarding curve**: start as a broke 1★ with one talent and no explanation of its fine print. The first room teaches combat; the first heal bill teaches the economy; the first meadow teaches the talent. `[MODEL]` — untested.
- **Difficulty scaling**: by ticket choice, not a slider. Difficulty is shown only as a recommendation ("high 2★ solo") `[C]`. Stages spike past the midpoint and the adaptation director counters habits `[C]`.
- **Feedback clarity**: the weak point, on purpose. Latent aura is never a number `[C]`; the notebook gives qualitative reads and records each proven flag. The notebook has to carry the whole job of telling the player they are improving.
- **Recovery from failure**: DECIDED by Brent 2026-09-19 `[B]` — **two modes**. *Standard*: dying in a dungeon means you are dragged out and patched up, and you wake up owing someone — a healer bill, a bad contract, or indentured work until it is paid (canon has indentured mining for debtors `[F]`). The character survives; failure becomes content, and experiments stay cheap. *Hardcore* (opt-in): permadeath.

---

## Core Loop

### Moment-to-Moment (30 seconds)
Room-by-room real-time combat: melee, overcharge, ranged bolt; managing reflux heat; reading
scenery. `[MODEL]` — implemented in the current prototype, feel **untested** (needs Brent's hands).

### Short-Term (5-15 minutes)
One delve: room to room, deciding whether to push past the halfway gate or extract, and when
to risk projecting into the Netherecho. `[C]` structure, `[MODEL]` pacing.

### Session-Level (30-120 minutes)
Hub (rent, tax, healer, contracts, scrolls, choose a passage by realm code / step count /
affinity match) → delve → extract or die → convert (sell blind, pay for appraisal or gamble at
auction; temper body; fill the star; test a talent hypothesis) → pressure ticks toward a break
in your district. `[C]`, from draft §3.

### Long-Term Progression
Filling the star by gathering affinity wisps; ascension; discovering every flag of your talent;
faction standing; scars and soul damage carried across runs. `[C/F/MODEL]`

### Retention Hooks
- **Curiosity**: untested talent flags, unopened realm codes
- **Investment**: persistent injuries, relics, standing
- **Social**: none — solo-first
- **Mastery**: reflux and overcharge timing; reading the adaptation director

---

## Game Pillars

**Direction CONFIRMED by Brent 2026-09-19** `[B]`; the exact wording below is Claude's and can
still be edited. Pillars are tie-breakers, listed in priority order.

### Pillar 1: You live in that world
The fantasy of being a nobody-turned-archhuman in a might-makes-right city comes first.

*Design test*: when a system's opacity or harshness fights the feeling of living there, the feeling wins.

### Pillar 2: A talent with fine print worth finding
The talent's core rule and most of its behaviour are visible up front. A few surprises remain
to be proven by play — enough for discovery, not enough to feel arbitrary. (Softened from
"never looked up" at Brent's direction.)

*Design test*: if a player cannot tell roughly what their talent does at creation, show more; if nothing is left to find, hide one thing.

### Pillar 3: The body mends itself; miracles cost
Natural healing is free and happens over time, as a healthy body's would — and like a body, it
never regrows a limb or a ruined organ. Fast healing, and anything catastrophic, costs money, a
talent, or both. Time is the hidden price of "free": rent, contracts and break pressure keep
ticking while you rest.

*Design test*: if an option makes in-combat or catastrophic healing free or instant, reject it. If it makes ordinary recovery cost money, reject that too.

### Pillar 4: A hard town, not a crooked one
The hub bargains hard and the newcomer pays for ignorance, but the game itself never cheats:
prices are honest once known, and every bad deal could have been seen coming. (Softened from
"everyone scams the newcomer" at Brent's direction.)

*Design test*: if the player loses money to something they had no way to anticipate, fix it.

### Pillar 5: One hit from disaster, one room from profit
Netherecho risk-reward sits alongside grounded tactical combat.

*Design test*: if a Netherecho reward feels safe, it doesn't belong there.

### Anti-Pillars (What This Game Is NOT)

- **NOT a wiki-optimised theorycrafting game**: exact public numbers would break Pillar 1.
- **NOT an open-world sandbox**: passages are discrete, step-counted delves `[C]`.
- **NOT party-based or an MMO**: solo-first `[B]`.
- **NOT a port of the books' cast**: no canon characters (CLAUDE.md Rule 1).

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| *1% Lifesteal* (Robert Blaise) — the source universe | The setting's laws: permanent talents with unknown fine print, ruinous healing, stars and affinity wisps, the Netherecho, passages and the late-series dungeon rules (halfway gate, escalating stages, contribution-scaled rewards, ticket auctions) — paraphrased mechanics only | Original player characters, talents, names and art; the books' cast does not appear | The dungeon layer is already a crawler spec — we adopt it as written instead of inventing one |
| Diablo 2 | Isometric real-time combat feel, itemisation tension | Far harsher healing economy; build identity comes from one hidden-rules talent, not gear | Shows isometric ARPG combat can carry a whole game |
| Baldur's Gate 3 | Hub depth, contract and faction texture | No party tactics or turn-based combat — depth applies to city systems | Shows a small hub can feel alive without an open world |
| Darkest Dungeon | A town that drains your gold; persistent afflictions; recovery cost as the engine of the loop | One character and one body, not a roster to burn through | 6M units from a ~6-person team: bleak attrition sells when presentation is strong |
| Noita | Rules left unexplained, learned by experiment | Our hidden rules are about *your own build*, rolled per save | Hidden rules work when experiments are cheap, fast and spectacular |
| Stoneshard | Body-part injuries, pain, scarce and costly healing | Real-time, and a talent that makes the cost payable | Closest mechanical neighbour — and a scope warning: Early Access since 2020 |
| Battle Brothers | Economy-first campaign with permanent injuries | Single character | Three people shipped deep systems on cheap art |
| Halls of Torment | Diablo-look isometric action **built in Godot** | Systems depth over horde spectacle | Proof the engine carries the genre; scoped small on purpose |

Comparable-game figures and sources: `research/audience-and-comparables.md` §3.

**Non-game inspirations**: the *1% Lifesteal* novels themselves. Others `[?]`.

---

## Target Player Profile

**PROPOSED — Brent to confirm.** Built from genre-audience evidence in
`research/audience-and-comparables.md` §2, most of it MED confidence or lower (modelled web
traffic and author commentary, not surveys). Reddit sentiment could not be reached at all.

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 18–40. Royal Road traffic peaks at 18–24; genre commentary describes millennial and Gen X readers with gaming backgrounds. |
| **Gaming experience** | Mid-core to hardcore. Comfortable with opaque systems and punishing economies. |
| **Time availability** | DECIDED by Brent 2026-09-19 `[B]`: **a sitting is 20–30 minutes** — one delve plus a quick stop in town. Comparable small-team isometric games run 15–45 minutes and players ask for shorter. |
| **Platform preference** | PC |
| **Current games they play** | Darkest Dungeon, Stoneshard, Battle Brothers, Path of Exile / Diablo 2, Noita |
| **What they're looking for** | A power system worth working out; a weak start exploited cleverly; consequences that stick |
| **What would turn them away** | Bleakness with no payoff (the books' most divisive trait); an unlikable fixed protagonist (the books' lowest-rated element — moot here, characters are original); attrition that reads as save-file friction (Stoneshard's review drag) |

The books' own audience, for scale (2026-09-18): ~12,000 Royal Road followers; ~5,900 Goodreads
ratings on book 1 falling to ~2,400 by volume 4; 2,500–3,800 Audible ratings per book.

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | Godot 4.7.2, GDScript — chosen and running (`/setup-engine`, 2026-09-18) |
| **Key Technical Challenges** | Reflux/heat balancing; Netherecho as a distinct overlay layer; hidden talent flags in a plain-JSON data file; persistent cross-run injury and scar state |
| **Art Style** | Low-poly 3D; nodes built in code `[B]` |
| **Art Pipeline Complexity** | Medium — custom low-poly 3D |
| **Audio Needs** | `[?]` |
| **Networking** | None |
| **Content Volume** | `[?]` — six dungeon templates named in draft §4; hours and counts unscoped |
| **Procedural Systems** | Room generator with an adaptation director that counters what the player has been using `[C]` |

---

## Risks and Open Questions

### Design Risks
- **The central joke may not be fun.** A heal that is useless in combat has to *feel* essential
  between fights, not like a chore. If grazing scenery is tedious, the premise fails (spec §8.1).
- **Hidden information can read as unfair.** Hidden talent flags, invisible latent aura and
  recommendation-only difficulty stack three kinds of opacity. The notebook has to make
  discovery feel earned rather than arbitrary.
- **Attrition spirals.** Persistent injury plus ruinous healing can lock a save into a death
  spiral with no interesting way out. Needs a floor (debt, indenture, a bad contract) that is
  itself content — canon offers indentured mining `[F]`.
- **Flags are discoverable once.** After the first character, a player knows what to test for.
  Flags are rolled per save (spec §2), but the *list* of possible flags becomes known.
- **The title talent may dominate.** If lifesteal is the correct answer to the economy, the
  other 39 talents need their own answer or they are trap picks (CLAUDE.md Rule 5).

### Technical Risks
- **Hidden flags live in plain JSON** (`game/data/talents.json`). Fine for a private
  prototype; trivially readable by anyone with the files.
- **Netherecho as a second map layer** — a rules and rendering overlay on every room — is the
  largest unbuilt system and is unprototyped.
- **Adaptation director** (enemies counter what you have been using) is unprototyped.
- **3D physics engine is not pinned** in `game/project.godot`; and the engine version (4.7) is
  newer than most agents' training data — see `docs/engine-reference/godot/`.
- **No automated tests yet.** GUT is chosen but not installed; wound-layer and reflux formulas
  are exactly the kind of logic that should be under test.

### Market Risks
Moot while nothing ships (CLAUDE.md Rule 1); recorded so the picture is complete if that ever
changes. Source: `research/audience-and-comparables.md`.
- **Small, loyal niche.** The series' measurable audience is in the low thousands to low tens of
  thousands, with roughly 40% retention from volume 1 to 4. Tone narrows it further — the
  bleakness is the books' most divisive trait.
- **Unproven space.** No licensed Western LitRPG or progression-fantasy PC game was found
  shipped or announced (MED — absence of evidence). No competition, and no precedent.
- **Attrition games carry review risk.** Stoneshard sits at Mostly Positive with save and
  attrition friction cited, after six-plus years in Early Access.
- **Solo isometric ARPGs take years.** Chronicon: solo, five years in Early Access.
  The Slormancer: two people, about eight years in all.
- **No public fan-works policy** from the author or publisher was found. A tolerated parody fan
  fiction exists; prose is not a precedent for a game.

### Scope Risks
- **One developer, canon-sized ambition.** Draft §2 lists nine pillars' worth of systems; draft
  §4 adds six dungeon templates, item fusion and a ticket-auction economy.
- **Already drifting.** The prototype grew a healer, ascension and six talents before the v0
  MVP's gated dungeon exists (see MVP Definition).
- **40 talents, six wired.** Each talent with real hidden flags is bespoke design and code.

### Rights Risk
No licence exists. The setting belongs to Robert Blaise; Aethon Books publishes the series and
bought a majority stake in a tabletop studio in 2026, so interactive rights may sit with or be
wanted by either party — unknown `[?]` (`research/secondary-sources.md` §3). Nothing ships, is
shown, or is pitched, and nobody is contacted, unless Brent explicitly decides to
(CLAUDE.md Rule 1). Rights work is parked until the fun gate is passed (Rule 4).

### Open Questions
- **Is the core loop fun?** The four questions in spec §8 — answered only by Brent playing
  the build. Status: **untested**.
- **Canon gaps still open** (`design/02-open-questions-for-brent.md`): Q14 self-authored
  spells, Q15 scrolls and teaching, Q17 soul-construct upgrade path, Q21 why passages break,
  Q26 early-game prices, Q29 how spirit abilities are acquired (**A** priority), Q30 Unholy
  Blessing (**A**), Q31–36. Q13 and Q28 parked. Reflux is a working model, only partly understood.
- **Permadeath or persistence?** The draft says "each run/character" and also "long-term scar
  system across runs". Whether death ends a save is not stated anywhere `[?]`.
- **Session length and content volume** — both `[?]`.

---

## MVP Definition

**Core hypothesis**: a heal too slow to save you makes every other cost affordable.

**Required for MVP** (draft v0 §4):
1. One affinity (water)
2. The title talent with 4–5 hidden technicality flags
3. One assault-type dungeon with the halfway-gate rule
4. Reflux heat
5. Limb-cost overcharge
6. Lifesteal-off-scenery recovery between rooms

**Explicitly NOT in MVP**: Netherecho, relics, hub economy depth, the other five dungeon
templates, multiple affinities.

**UNRESOLVED — scope drift**: the prototype already contains a paid healer, a hidden aura with
ascension to 2-star, and six wired talents, and it is a wave arena rather than a gated
assault dungeon. Whether the MVP definition moves to match the build, or the build is
treated as having drifted, is Brent's call. The v0 text above is left unchanged until then.

### Scope Tiers

Timelines are `[?]` — no velocity data exists yet for this project. Content per tier is a
`[MODEL]` proposal for Brent to correct.

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | One arena or one assault dungeon, water affinity, one talent | Three-layer wounds, lifesteal off scenery, reflux, overcharge, notebook | `[?]` |
| **Vertical Slice** | One complete gated dungeon with a rule card, a minimal hub (healer, rent, one ticket seller), 2★ ascension | Core + hidden aura + talent evolution + 5–6 talents with real flags | `[?]` |
| **Alpha** | All six dungeon templates (placeholder art), 2–3 affinities, Netherecho layer, construct binding | Hub economy (appraisal, contracts, standing), gear and set fusion, adaptation director | `[?]` |
| **Full Vision** | Full talent roster, relics, break events hitting the home district, soul-damage scars across runs | Everything in draft §2 and §4 | `[?]` |

---

## Next Steps

- [x] Engine configured (`/setup-engine`, 2026-09-18 — Godot 4.7.2, GDScript)
- [x] Concept prototype built (`game/`) — runs headless without script errors; **feel untested**
- [ ] **Brent plays the build** and answers the four questions in `design/03-core-mechanics-spec-v0.1.md` §8
- [ ] Write the prototype report with a PROCEED / PIVOT / KILL verdict (`/playtest-report`)
- [ ] Brent confirms or rewrites the four draft pillars above
- [ ] Resolve the MVP scope drift (see MVP Definition)
- [ ] If PROCEED: decompose into systems (`/map-systems`) → `design/gdd/systems-index.md`
- [ ] Author system GDDs (`/design-system [system]`), carrying provenance tags and open questions across
- [ ] Remaining adoption steps: `docs/adoption-plan-2026-09-18.md`
- [ ] Rights and outreach stay parked until the fun gate is passed (CLAUDE.md Rule 4)
