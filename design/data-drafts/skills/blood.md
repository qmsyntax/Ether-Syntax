# Blood: skills on base runes (draft, 2026-10-22)

Data: `blood.json`. Nothing is built. Tags: **[B]** Brent's ruling, **[C]** books (paraphrased notes),
**[MODEL]** ours. All names are original.

## Rule

**Blood works blood that is already out.** Its hits open **Bleeding**; bleeding enemies spill **pools** on the
floor; you keep what you drink as **held blood** (up to 10). Blood skills spend Bleeding, pools or held blood,
never your health. [B: blood never pays in health; C: blood storage exists; MODEL: the three places and the count]

Refined from design/14, which said "spilled and stored blood" without saying where it is or how much. Now each
skill names exactly what it spends. Blood never heals; healing belongs to Life.

**Reflux: low (0.7).** The blood does the work and essence only steers it. The limit is how much blood is out.

## Skills

| Skill | Rune | Kind | What it does | Starter |
|---|---|---|---|---|
| Red Lancet | Bleed | projectile | Thrown blade: 50 and 2 Bleeding | **ranged** |
| Tourniquet | Staunch | self buff | 6 s: blows open no wounds; each one that would costs 2 held blood | |
| Deep Draught | Drink | channel | Hold: draws Bleeding stacks and pools within 5 m into held blood | |
| Outpour | Spill | melee burst (cone) | Pours out all held blood: 30 + 18 per measure in a 6 m cone, and leaves pools | |
| Clotblade | Clot | melee burst | 1.8x sweep; each Bleeding stack on a target sets hard for +22 and +12 poise | **close burst** |
| Thinblood Rush | Thin | dash | 4.8 m dash between bodies; each pool crossed carries you 1.5 m further | **movement** |
| Hammering Heart | Pulse | detonate | Every bleeder within 10 m: 3 heartbeats of 8 per stack, each dropping a pool; stacks kept | |
| Heavy Heart | Still | ground zone | 3 m, 6 s: Sluggish (slower, slower wind-ups); pools it touches go still too | |
| Gullet Knot | Choke | hex | 30 and interrupts; a bleeding target is Choked 2.5 s (no attacks, shots, casts or calls) | |
| Long Breath | Breathe | self buff | Breathe out 4 held blood for 6 reflux each; 6 s of doubled poise and fast shedding | |

The starter loop: Lancet opens, Clotblade cashes the cuts in, Rush rides what they spill. Held blood arrives
with the first scroll skills (Deep Draught fills it; Outpour, Tourniquet and Long Breath spend it), and with
every kill of an enemy that was bleeding.

## Rune effects (added to a skill)

| Rune | Effect |
|---|---|
| Bleed | status bleeding 1 |
| Staunch | duration x1.3; reflux x0.9 |
| Drink | reach x1.15; bonus bleeding +0.25 |
| Spill | reach x1.25; cost x1.1 |
| Clot | power x1.1; poise x1.2; braced |
| Thin | speed x1.25; reach x1.1; power x0.9 |
| Pulse | windup x0.8; power x1.1; reflux x1.1 |
| Still | status sluggish |
| Choke | interrupts; status choked |
| Breathe | reflux x0.8; windup x0.9 |

## New mechanics [MODEL]

- **Bleeding** (status): up to 5 stacks, 6 s. 4 a second per stack, doubled while the target moves or attacks.
  Every 1.5 s it drips a pool. Enemies only. It is not the player's wound system.
- **Blood pool** (field): 1 m and 1 measure; pools that touch merge (up to 2 m and 3 measures); 15 s; at most 12
  in a level. An enemy that dies bleeding leaves a 2 m, 3-measure pool.
- **Held blood** (resource): 0-10 beads. Filled by Drink, and +2 when an enemy you made bleed dies. Thins away
  out of a fight (1 every 5 s). Never health, never healing.
- **Sluggish** (status): 30% slower, wind-ups x1.5, Bleeding on it ticks at half.
- **Choked** (status): cannot start an attack, shoot, cast or send for help; walks at half speed.
- **Hex** (behaviour, new kind, shared with life, death and nature): the target under the cursor within range
  takes the hit at once. There is no travel, and it needs line of sight.
- Smaller keys: `spend_blood`, `consume_status` on a melee burst, `pool_bonus_m` on a dash, `stills_pools` on a
  zone, detonate `beats`, and the Tourniquet and Long Breath buffs.

## Unsure

- Whether a blood character should start with any way to fill held blood. Here the starters never touch it, on
  purpose; it might feel like a missing bar until the first scroll.
- Tourniquet changes when wounds open. That needs a hook in `take_hit` before the wound rules run.
- Heavy Heart (Still) slows Bleeding, which Hammering Heart (Pulse) wants fast. That is the opposite pair
  working as designed, not a bug.
