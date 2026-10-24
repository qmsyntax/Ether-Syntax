# Nature v2: the druid (draft, 2026-10-24)

Data: `nature.json`, `nature-runes.json`. Nothing is built. Tags: **[B]** Brent, **[MODEL]** ours. All names original.

**Role** [B: framework.md; Brent wants Nature to buff too]: druid - growth, beasts, buffs.
**Parents: Earth + Life.**

## How each parent shows

- **Earth: ground that stays.** Growth stays where it is planted and ages like standing stone holds; Heartwood is a
  wall that draws the pack onto itself (Earth's area tank); In the Green halves shoves and poise loss (Earth's
  footing); beasts are given up by the ground.
- **Life: it is alive.** Growth heals what stands in it; beasts are living (Life can heal them, Death's thralls it
  cannot); Overgrowth is Life's Strengthen on you and your pack; harvests feed your body.

## Rule

Growth stays and ages (sprout, grown, bloom) and spreads on open ground; **you and your beasts standing in your
growth are In the Green** - regrowing 1.5 health a second and hard to move - and any patch can be called up as a
beast [MODEL]. Reflux low (0.5), unchanged.

## Skills (13 on 12 runes; 10 serve the role)

| Skill | Rune | Kind | What it does | Starter | Status |
|---|---|---|---|---|---|
| Overgrowth | Grow | self buff | 8 s, you and beasts in 8 m: +20% damage, half poise loss, 2 health per hit | | new |
| Dwindling Gall | Shrink | smite | Dwindled 8 s: one class lighter, reach -30% | | existing |
| Thornburst | Sprout | delayed blast | 60 + Slowed, leaves bramble | **ranged** | existing |
| Heartwood | Sprout | prop | A growing trunk; draws enemies in 5 m for its first 6 s | | changed (from Grow) |
| Sere Ground | Wilt | field pulse | Kill your patches for damage by age | | existing |
| Greening | Flourish | field pulse | Patches age; 6 s: In the Green heals x2 and hits +15% | | changed |
| Heartrot | Blight | chain | 40 x3, Blighted: shields and bows rot | | existing |
| Reaping Sweep | Harvest | melee burst | 1.8x, 180 degrees; each patch reaped: +15%, 1 essence, 3 health | **close** | changed |
| Scatter Seed | Sow | seed | Five hidden seeds: 35 + Rooted, snarevine | | existing |
| Vine Reach | Tangle | grapple | Haul to a point, 20 + Rooted, land In the Green | **movement** | changed |
| Unwinding | Unravel | detonate | Fling every held enemy 3 m | | existing |
| Call the Brake | Herd | summon | A patch gives up a briar hound (2 from bloom), up to 3 | | new |
| Unleash the Pack | Unleash | smite | Mark a Quarry; every beast leaps on it; 6 s wild | | new |

Role: Overgrowth, Thornburst, Heartwood, Sere Ground, Greening, Reaping Sweep, Scatter Seed, Vine Reach, Call the
Brake, Unleash the Pack. Utility: Dwindling Gall, Heartrot, Unwinding.

The loop: plant (Thornburst, Scatter Seed, Vine Reach) -> stand in it (In the Green) -> call hounds from it -> buff
and loose them -> cash patches in (Reaping Sweep, Sere Ground).

## Rune changes

- **Grow** re-meant: any living thing, you and your beasts included (Overgrowth). Heartwood moved to Sprout.
- **Flourish** re-meant: also strengthens the living standing in the growth.
- **New pair Herd / Unleash**: Herd (link, draw +0.6, EN 3.1) gathers beasts out of the growth and marks a Quarry (first named Beckon; Unholy has it); Unleash
  (branch, draw -0.8, EN 1.94) lets them go wild. Now 12 runes.

## New mechanics [MODEL]

- **In the Green** (affinity rule state): 1.5 health a second, shoves x0.5, poise loss x0.5, for you and your summons
  on your growth.
- **Overgrown** buff, **Unleashed** summon buff, **Quarry** status (your summons switch to it, x1.3).
- **Summon `needs: growth`**, scaled by patch age; the **briar hound** beast (life.json's generalised summon).
- **command**: a smite that makes your summons leap to its target.
- **decoy_radius / decoy_s** on any prop (Death Mask's decoy, reused).
- **green_heal_mult / green_damage_mult**, **per_patch_heal**.

## Unsure

- Up to three hounds plus a tree that draws enemies may make the druid too safe; feel untested, needs Brent.
- Beasts need models; the Stubble's procedural stand-in rig (`CreatureRig`) is the likely start.
- Whether a beast should also stand In the Green on its own patches when the druid is elsewhere (written: yes).
