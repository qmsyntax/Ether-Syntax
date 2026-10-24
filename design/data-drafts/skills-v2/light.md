# Light skills v2: the ranged caster

Draft for Brent, 2026-10-24, to `ROLES-BRIEF.md`. Nothing here is built. Data: `light.json`, `light-runes.json`.
Tags: **[B]** Brent's ruling, **[MODEL]** our invention; everything untagged is [MODEL]. All names are original.

**Role [B 2026-10-24]: ranged caster - reveal, smite.** Light every enemy in the room, then hit the Lit ones harder.
Paladin and support are Holy's now [B]: no wards, heals or auras here.

**Rule:** Light arrives at once along a dead straight line and stops on the first opaque thing; whatever it touches is Lit (shown through any cover, front armour counts half), and a light hit on a target that is already Lit Sears it: +25%, and the Lit starts again.

**Reflux: low** (as before): a caster that keeps casting. **Bands:** cheap, long instant lines (Dayline 60 at 16 m);
one dear, heavy smite (Sunlance 90-280, 18 essence); everything else mid. Close range is a burst that lights and
staggers (Noonburst) and a glare, not a fight.

## Skills (12: 10 serve the role directly)

| Skill | Rune | Kind | What it does | Starter | Status |
|---|---|---|---|---|---|
| Dayline | Shine | beam | An instant line of daylight, 16 m: the first thing on it takes 60 and is Lit for 6 s. Walls, stone and a raised shield stop it. | ranged | existing |
| Dusk Well | Dim | ground_zone | Point, 10 m: a pool of dusk 4 m across for 7 s. Nothing outside can see or shoot into it, and nothing inside can see out - but Lit enemies stay in plain view, and against the dusk they stand out: your light does 20% more to a Lit enemy inside it. |  | changed |
| Glint | Flash | new:streak | You are a streak of light: up to 7 m along your aim in an instant, through enemies, searing each one you pass for 20 and lighting it. A wall, stone or a raised shield stops you short. | movement | changed |
| Still Lamp | Glow | prop | Point, 9 m: hang a steady lamp for 12 s. Every enemy within 5 m of it is Lit while it stays: it cannot hide and its armour's gaps show, and your Sears on anyone in its light are 10% heavier. One lamp at a time; it blocks nothing. |  | changed |
| Noonburst | Radiate | melee_burst | Light and heat pour out of you: everything within 3.5 m with a clear line to you takes a heavy hit and is Lit. A raised shield shades whoever holds it. | close | existing |
| Gathered Light | Absorb | detonate | Every Lit enemy within 12 m that has a clear line to you gives its light back: it takes 60 and loses Lit, and the ray coming home hits everything between it and you for 40. |  | existing |
| Hard Glare | Glare | melee_burst | A cone of hard light, 8 m long: everything in it takes 20 and is Blinded for 3 s. Archers lose their aim; others only swing at what is right in front of them. |  | existing |
| Clear Eye | Clarity | self_buff | For 6 s you see every gap: each enemy within 15 m is Lit at once, and your hits on Lit enemies ignore front armour completely. |  | existing |
| Glancing Ray | Reflect | beam | A ray that glances off walls, stone and raised shields up to twice, 14 m in all, hitting the first body on each leg for 55 and lighting it. Bank it off a wall to reach the back of a shield line. |  | existing |
| Burning Glass | Bend | delayed_blast | Bend the light through a lens onto one spot up to 14 m away: a bright point for 0.8 s, then it burns through - 130 to everything within 1.2 m, and 40 poise. Put it on a Lit enemy and the point follows it; anyone it burns that was Lit is Seared. Needs a clear line from you. |  | new |
| Sunlance | Ray | charge_release | Hold to draw the light into one line (up to 1.4 s, walking at 40%), then let it go: a lance of light 18 m long through every body on it, 90 to 280 by the charge, 50 poise, and Lit. Walls, stone and raised shields still stop it. Dear: the caster's big smite. |  | new |
| Prism Bolt | Prism | projectile | A shard of light: 50 to the first enemy it hits, and there it breaks into four rays fanned 60 degrees on through it, 7 m each, 30 and Lit to the first body each finds. Into a crowd it lights the whole pack for the Sears that follow. |  | new |

Starters: **Dayline** (ranged), **Noonburst** (close - the light that pushes melee off), **Glint** (movement - a
streak that sears what it passes).

The loop: Dayline / Prism Bolt / Still Lamp light them -> every further light hit Sears (+25%) -> Burning Glass on the
Lit one follows it -> Gathered Light or Sunlance to cash in.

### Dropped

- **Bent Light** (Bend): Going unseen is Dark's now (the assassin), and false images are Dream's (the enchanter); Light is the ranged caster that reveals. Bend is re-meant to gathering light through a lens (Burning Glass).

## Runes: 10 -> 12

| Rune | Meaning | Opposite | Role | Draw | Effect | Change |
|---|---|---|---|---|---|---|
| Shine | illuminate | Dim | branch | -0.6 | status lit | kept |
| Dim | dull the light | Shine | link | +0.4 | power x0.9; reflux x0.7 | kept |
| Flash | a sudden burst of light | Glow | cap | -0.8 | windup x0.75; status dazed | kept |
| Glow | a steady soft light | Flash | frame | -0.3 | duration x1.5; reflux x0.85 | kept |
| Radiate | send light and heat outward | Absorb | branch | -0.9 | reach x1.3; cost x1.1 | kept |
| Absorb | draw light and heat in | Radiate | link | +0.9 | bonus lit +0.3; reflux x0.85 | kept |
| Glare | a blinding glare | Clarity | branch | -0.7 | status blinded | kept |
| Clarity | restore and sharpen sight | Glare | frame | +0.3 | power x1.1; reach x1.15 | kept |
| Reflect | turn light, and shots, back | Bend | link | -0.2 | jumps +1 | kept |
| Bend | bend light through a lens to a burning point | Reflect | link | +0.3 | power x1.2; reach x0.9 | re-meant |
| Ray | all the light in one line | Prism | cap | -0.7 | pierce +1; power x1.1 | new |
| Prism | split the light into many rays | Ray | branch | +0.6 | jumps +2; power x0.75 | new |

- **Bend** (re-meant): Was 'bend light: false images, or nothing' (Bent Light, going unseen). False images are Dream's and going unseen is Dark's now; a ranged caster bends light to burn. Role and draw kept (a link that draws inward). Effect was 'windup x0.8; reach x1.15': concentrated, it is harder and a little shorter.
- **Ray** (new): Named Ray, not Lance (Disease already has Lance). The smite: the one light that passes bodies. A Cap (it ends a structure, as a line ends in its point) with a giving draw (all of it sent outward).
- **Prism** (new): The caster's crowd answer: one shard becomes a fan. A Branch (it splits) that draws in before it gives out; opposite draw to Ray, so the pair bonds ionic.

## New mechanics

Mechanics from the 2026-10-22 drafts (Soaked, Chilled, Lit, Unseen, light level, sees_caster...) are built and not repeated; only what is new in v2 is listed.

- **sear** (field, affinity rule): Affinity key 'sear_vs_lit' (Light 0.25): a hit tagged light on a target that was Lit before the hit does that much more and refreshes Lit. Reveal first, smite second. Lit and the opaque rule are already built (2026-10-22 drafts) and are not redefined.
- **lit_bonus (zone)** (field, from Dusk Well): A zone with lit_bonus: the caster's light hits on a Lit enemy standing in it do that much more (on top of the Sear).
- **sear_bonus (lamp)** (field, from Still Lamp): A lamp prop with sear_bonus adds that much to the Sear (sear_vs_lit) on light hits against enemies within its light_radius.
- **follows_lit** (field, from Burning Glass): A delayed_blast cast on an enemy that is Lit tracks it: the blast lands where that enemy is when the delay ends. On anything else it lands on the spot, as delayed_blast does now.
- **split** (field, from Prism Bolt): A projectile with 'split' ends on its first hit and casts split.count instant light lines from that point, fanned over split.arc_deg around its flight, each split.range long, each hitting the first body it meets with split.damage and split.on_hit, and stopping on walls, stone and raised shields as all light does.

## Notes and open questions

- **'Smite' is a kind name already** (hex / seize / gaze are kind `smite`), so Light's payoff is called **Sear**, and
  no Light skill uses the `smite` kind.
- **Ray and Prism have no workbook ids** yet; `LGT-6a` / `LGT-6b` are proposals.
- **Sunlance pierces bodies**, against Light's rule that a body stops light; the Ray rune is the stated exception.
- **Holy (Light + Life)** will draw on Glow, Radiate and Shine; nothing here gives allies anything.
- **Dusk Well still hides**: it is the caster's one piece of cover, and it overlaps Dark's Pall (which now vanishes
  you at your feet). If Light should not hide at all, Dim needs a new skill.
