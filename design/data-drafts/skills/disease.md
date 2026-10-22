# Disease: skills draft (2026-10-22)

Draft for Brent. Nothing is built. Data: `disease.json`. All names are original. Disease is the books' miasma, renamed
[B 2026-10-21].

**What the books say** (paraphrased notes only) [C: book5-mechanics-notes, ch218]:
- crystallized miasma rots flesh on skin contact;
- it is useless against full armour;
- armour counters flesh-only affinities.

Everything else here is **[MODEL]**.

**Rule.** Disease lives in **clouds** that linger and drift, and flesh inside them catches **Infected**:
- every Disease hit and tick is multiplied by the target's **flesh**, so worn armour cuts it and constructs and stone
  ignore it;
- a cloud goes round a shield and does not care which way anyone faces.

**Why.** The first pass is kept and made measurable. Armour needs a number, and that number, **flesh**, is kept
separate from the front armour a shield gives. That split is the design:
- shields, facing and the rear-hit rule mean nothing to a cloud;
- worn armour does.

So Disease is good into a Pavise line, which wears mail behind the shield (0.6 flesh), and poor against the plated
Wall Commander (0.3). Poison is a bill inside one body; Disease is air that moves from body to body.

**Reflux: high (1.4).** Each cloud keeps working long after you stop paying for it. High reflux stops a disease
fighter covering the whole room, so each cloud is a choice of where the fight will be.

**Against the new enemies.**
- **Pavise Bearer:** Fever Flask is lobbed over the shield, and its cloud does not care about the shield.
- **Wall Commander:** plate, so Disease is weak against it. Corroded (Poison) raises its flesh, if someone holds both.
- **Constructs:** flesh 0, untouched.
- **Censer-Bearer:** a dead Infected body leaves a corpse cloud. Mind where the censer dies.

| Skill | Rune | Kind | What it does | Starter |
|---|---|---|---|---|
| Fever Flask | Infect | delayed_blast (lobbed) | 12 m lob: 45, 2 Infected, a 2.5 m cloud for 6 s drifting away | ranged |
| Fever Break | Disinfect | detonate | Every Infected enemy in 10 m: 30 a stack now, stacks gone | |
| Contagion | Spread | chain (fan) | 2 Infected on one; then everyone within 3 m of it, then of those: up to 8, 20 and 1 stack each | |
| Sealing Clot | Contain | projectile | 45, 3 Infected, Contained 10 s (cap 10, ticks x1.5, never spreads) | |
| Festering Hands | Fester | self_buff | 8 s: every hit on an Infected enemy adds a stack and stops its poise refilling | |
| Lancing Cut | Lance | targeted_strike | 2.0x, +25 a stack (stacks drained); the drained sickness becomes a 2.5 m cloud | |
| Plaguebloom | Billow | melee_burst | 360°, 3.5 m: 1.6x, 1 Infected; a 3 m cloud drifts the way you face for 6 s | close burst |
| Dispersal | Clear | dash | 5.5 m through enemies as fog: 1 Infected each; a small cloud where you stood | movement |
| Teeming Fog | Overrun | ground_zone (cloud) | 5 m fog, 8 s, drifting: a stack a second; at 5 stacks inside, its poise breaks once | |
| Inured Blood | Immunise | self_buff | 8 s: 5% less damage taken per Infected enemy within 8 m (max 30%) | |

**The starter loop.**
1. Lob a Fever Flask behind the front line.
2. Plaguebloom when they close.
3. Dispersal out through them, leaving a cloud.

The clouds keep working while you are somewhere else.

## New mechanics

| Name | Kind | Rule |
|---|---|---|
| flesh | field (enemy) | 0-1, the share not under worn armour; multiplies all Disease damage. Proposed: Skirmisher, Archer, Harrier, Censer-Bearer, Drummer 1.0; Brute 0.8; Pavise 0.6; Commander 0.3; constructs 0 |
| infected | status | Up to 5, 6 s refreshed: 6 a second per stack x flesh. A dead Infected body leaves a 2 m corpse cloud for 4 s |
| cloud | behaviour | Zone: 1 Infected a second to flesh inside (at most 1 a second from all clouds). Drifts at drift_speed and stops at walls and stone. Shields and facing do nothing |
| lobbed | field | A delayed_blast that flies over bodies and shields; only tall walls and stone stop it |
| fan | field | A chain that jumps from every body hit to every new enemy within jump_radius, for depth generations |
| contained | status | 10 s: Infected cap 10, ticks x1.5, nothing spreads, no corpse cloud. Stacks above 5 fall away at the end |
| festering | status | 3 s: poise does not refill |
| overrun_at | field | A cloud staggers each enemy that reaches this many stacks inside it, once per cast |
| dr_per_infected | field | Damage taken cut per Infected enemy within radius, up to dr_max |

## Rune effects

| Rune | Effect |
|---|---|
| Infect | status infected 2 |
| Disinfect | bonus infected +0.4 |
| Spread | jumps +1; status infected |
| Contain | reach x0.75; power x1.3 |
| Fester | status infected; duration x1.3 |
| Lance | pierce +1; power x1.1 |
| Billow | reach x1.35; power x0.9 |
| Clear | shove +1; reach x1.15 |
| Overrun | poise x1.4 |
| Immunise | braced; cost x1.1 |

## Open
- **flesh is a new enemy key**, and the values are first guesses. The Pavise's flesh assumes mail under the shield;
  if Brent sees it as unarmoured behind the shield, it is 1.0, and Disease becomes the Pavise's hard counter.
- **Wind and clouds.** Wind skills, Gale Lane above all, should carry clouds. That is a cross rule for the wind and
  disease pair, not written here.
- **Disease and Alight both damage over time.** They differ in that Alight is stronger per stack (8 against 6), jumps
  by touch, and ignores armour. Infected comes from air, is cut by armour, and leaves clouds when a body dies.
