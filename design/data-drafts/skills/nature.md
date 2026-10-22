# Nature: skills on base runes (draft, 2026-10-22)

Data: `nature.json`. Nothing is built. Tags: **[B]** Brent's ruling, **[C]** books (paraphrased notes),
**[MODEL]** ours. All names are original.

## Rule

**Nature plants growth in the ground that stays, spreads and grows stronger with age.** Its skills plant growth,
feed it or cash it in. [C: nature is a named affinity; MODEL: the rule]

Refined from design/14 so it can be counted:
- A **patch** is 2 m across, with three ages: sprout x1, grown x1.5 (from 5 s), bloom x2 (from 15 s).
- Every 5 s each grown or bloom patch puts out one new patch beside it, up to 12 per caster.
- It spreads only on open ground (soil, grass, mud). On paved or rock floors it grows but does not spread.
- Fire burns it away (Alight on it, 2 s).

This gives Nature a sense of place like water's wetness: strongest in scrubland and swamp, weaker in the city
and the dungeon.

**Reflux: low (0.5).** The plants keep working after the cast; the price is time and ground, not heat.

## Skills

| Skill | Rune | Kind | What it does | Starter |
|---|---|---|---|---|
| Heartwood | Grow | prop | A trunk rises at a point: blocks walking and shots 30 s, toughens, spreads bramble at its foot | |
| Dwindling Gall | Shrink | hex | Dwindled 8 s: one weight class lighter, reach -30%; its death drops a bramble patch | |
| Thornburst | Sprout | delayed blast | 60 and Slowed in 1.5 m, and leaves a bramble patch | **ranged** |
| Sere Ground | Wilt | field pulse | Your patches within 4 m of a point die; each hits whoever stands in it for 30/45/60 by age | |
| Greening | Flourish | field pulse | Your patches within 12 m age once and spread once; 6 s at +50% | |
| Heartrot | Blight | chain | 40 to three bodies; Blighted 8 s (shields half, bows slower, +20% from Nature) | |
| Reaping Sweep | Harvest | melee burst | 1.8x in 180 degrees; each patch reaped adds 15% and 1 essence, and regrows | **close burst** |
| Scatter Seed | Sow | seed | Five hidden seeds: stepped on (or after 6 s) 35, Rooted 1 s, and a snarevine patch | |
| Vine Reach | Tangle | grapple | A vine hauls you 9 m to a point; enemies there Rooted 1 s; snarevine on the spot | **movement** |
| Unwinding | Unravel | detonate | Every enemy your vines hold within 10 m is flung 3 m for 40; your own holds break | |

The starter loop: Thornburst and Vine Reach plant; the patches grow while you fight; Reaping Sweep harvests them
and they grow back.

## Rune effects (added to a skill)

| Rune | Effect |
|---|---|
| Grow | reach x1.2; power x1.1; cost x1.1 |
| Shrink | status dwindled |
| Sprout | status slowed; duration x1.3 |
| Wilt | power x1.15; duration x0.7 |
| Flourish | power x1.1; duration x1.3 |
| Blight | status blighted |
| Harvest | power x1.1; cost x0.85 |
| Sow | windup x1.3; power x1.25; duration x1.2 |
| Tangle | status rooted |
| Unravel | shove +1; windup x0.9 |

## New mechanics [MODEL]

- **Growth** (field): patches with ages, spread, a cap of 12, the soil rule, and burned by fire. Kinds:
  - **Bramble**: Slowed, and 6 a second while moving.
  - **Snarevine**: Rooted 1 s on entering, once every 4 s per enemy.
- **Rooted** (status): cannot move or turn but can still strike what is in reach. Heavy enemies are held half as
  long, elites a quarter.
- **Dwindled**: one weight class lighter for shoves and Aloft; reach x0.7.
- **Blighted**: front_block halved, ranged aim x1.5, x1.2 from Nature. The rot is in its wooden gear, not its
  flesh, which keeps it clear of Disease and Life.
- **Seed** (new kind): hidden seeds that sprout when stepped on or on a timer.
- **Grapple** (new kind): moves you to a point by exact distance; counts as a dash.
- `leave_growth`, the growing prop (`hp_per_s`, `spread_every`), harvest keys, and `frees_caster`. Field pulse
  and hex are defined in death.json and blood.json.

## Unsure

- Growth is the most persistent thing in the game (it lasts the level). The cap of 12 per caster and fire
  burning it are the limits; performance and readability with 12 patches are untested.
- Shrink is hard to keep in Nature rather than Life. Here a plant does it (a gall) and leaves a plant behind.
- Blighted assumes enemies carry wooden shields and bows. The Pavise Bearer and the Rampart Archer fit;
  enemies.json may want a `wooden_gear` flag rather than assuming.
- The soil rule needs a biome flag (`soil`): scrubland, swamp and mountain true; city and dungeon false.
