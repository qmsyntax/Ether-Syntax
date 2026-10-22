# Poison: skills draft (2026-10-22)

Draft for Brent. Nothing is built. Data: `poison.json`. All names are original; everything here is **[MODEL]**.

**Rule.** Poison puts doses in one body:
- the first dose starts a **6 s clock**;
- later doses add to the bill but never reset the clock;
- when the clock runs out, every dose is paid at once, **20 each**, up to 10 doses.

It never spreads on its own.

**Why.** The first pass ("doses stack inside a body and come due later") is kept and made exact. One clock per body,
shown over its head, makes "later" a number, and stacking fast before it runs out is the skill. The damage comes as
one lump, not a tick, which sets Poison apart from:
- Alight, which ticks and spreads by touch;
- Disease, which lives in clouds and spreads by air.

Poison moves between bodies only when you move it (Funnel).

**Reflux: low (0.7).** Most of the damage comes after the cast, so casts are cheap and leave little heat. You pay by
waiting.

**Against the new enemies.**
- **Pavise Bearer:** Corroded eats armour and shields, a third per stack, and goes on even through the shield, so
  Caustic Spew and Residue strip a Pavise's guard.
- **Censer-Bearer:** inside Clean Air its death heals nobody.
- **Brute:** Counterdose turns a big bill into a long seizure that stops its slam.
- **Constructs:** they take doses like anything else (see Open).

| Skill | Rune | Kind | What it does | Starter |
|---|---|---|---|---|
| Sting Dart | Poison | projectile | Fast dart: 50 and 2 doses | ranged |
| Black Purge | Purge | targeted_strike | 2.0x; the whole bill now at 30 a dose; interrupts | |
| Fouling Slide | Contaminate | dash | 5 m through enemies, 2 doses each | movement |
| Clean Air | Cleanse | ground_zone | 4 m, 8 s: enemies in it cannot be healed or Frenzied | |
| Caustic Spew | Corrode | melee_burst | 120°, 3.1 m: 1.6x, 1 dose, Corroded | close burst |
| Counterdose | Neutralise | projectile | 45; doses cancelled; Stunned 0.3 s a dose (2.5 s max), interrupts | |
| Residue | Linger | ground_zone | 3 m slick for 10 s that never moves; a dose a second | |
| Funnel | Flush | detonate (gather) | Every dosed enemy within 6 m of the target pours its doses into it (cap 20) | |
| Sapping Tether | Sap | channel (tether) | Hold on one enemy: a dose every 0.5 s; it deals 30% less and moves 30% slower | |
| Bitter Tonic | Stimulate | self_buff | 8 s: +15% speed, recovery -25%, your doses come due in 4 s | |

**The starter loop.**
1. Sting Dart (2 doses) starts the clock.
2. Caustic Spew adds a dose and strips armour.
3. Fouling Slide doses everything you pass on the way out.

The bills land on their own while you are somewhere else.

## New mechanics

| Name | Kind | Rule |
|---|---|---|
| dosed | status | Up to 10. The first dose starts a 6 s clock that is never refreshed; at zero, 20 per dose at once, through the doser (tags poison, dot) |
| corroded | status | Up to 3, 10 s. Front armour and worn armour (Disease's flesh) each lose a third per stack. Applies through a frontal block |
| sapped | status | While tethered + 2 s: deals 30% less, moves at 70% |
| statuses | field | A hit payload may carry a list of {id, stacks} to apply more than one status |
| no_heal | field | Zone: no heals on enemies inside. blocks_status cannot be applied; ends_status is removed |
| stun_per_stack | behaviour | consume_status removes the stacks and Stuns for stun_per_stack each (to stun_max) instead of paying their damage |
| gather_into | behaviour | Detonate: moves consume_status from everyone within gather_radius into the target, up to gather_cap |
| tether | field | Channel shape: locked to one enemy; breaks past break_range or behind wall or stone |
| dose_clock | field | While the buff lasts, your Dosed clocks run this long instead of 6 s |

## Rune effects

| Rune | Effect |
|---|---|
| Poison | status dosed 2 |
| Purge | bonus dosed +0.4 |
| Contaminate | status dosed; duration x1.3 |
| Cleanse | reflux x0.7 |
| Corrode | status corroded |
| Neutralise | interrupts; power x0.9 |
| Linger | duration x1.6; status dosed |
| Flush | reach x1.2; shove +1 |
| Sap | status sapped |
| Stimulate | windup x0.75; reflux x1.15 |

A duration multiplier on a skill that doses lengthens the Dosed clock: a later, bigger bill.

## Open
- **Poison's opposite runes are all "clearing" verbs** (Purge, Cleanse, Neutralise, Flush), so each is turned into an
  attack. These are the weakest verb fits in this set; Brent should check them:
  - Purge: the whole bill now.
  - Neutralise: cancel the bill for a seizure.
  - Flush: gather everyone's doses into one body.
  - Cleanse: deny the censer its heal and frenzy.
- **Constructs take doses** in this draft, because the books say nothing either way. If Brent rules "no body, no
  poison", Poison joins Dream and Disease as useless in the Netherecho, and that is too many.
- **Clean Air and Shutter (Dream) overlap on support enemies.** The split is that Clean Air stops the drug (Frenzied,
  heals) and Shutter stops morale and orders.
