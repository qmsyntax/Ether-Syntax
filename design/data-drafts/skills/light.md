# Light: skills draft (2026-10-22)

Draft for Brent. Nothing is built. Data: `light.json`. All names are original; everything here is **[MODEL]** unless tagged.
Rune set: design/runes-data/revised-rune-set.md (LGT-1a to LGT-5b) [B 2026-10-22].

**Rule.** Light arrives at once along a dead straight line and stops on the first opaque thing; whatever it touches
is **Lit**: shown through any cover, with the gaps in its armour open (front armour counts half).

**Why the first-pass rule changed.** "Straight and instant; reveals the hidden" overlapped lightning, which is also
instant, and "reveals" had little to act on. Now:
- light is the affinity of the clear line. It never jumps, curves or travels, and walls, stone, bodies and raised
  shields stop it, so where you stand matters most.
- "reveal" has two concrete effects: a Lit body cannot hide, and its front armour counts half.

Lightning picks a target and jumps between bodies. Light needs a line and shows what is on it.

**Reflux: low (0.7).** Light leaves little heat. You pay with position instead.

**Against the new enemies.** A Pavise Bearer's raised shield stops every light line and shades it from Noonburst.
Light gets round it in three ways:
- Glancing Ray bounces off a wall or the shield itself to reach the back.
- Glint streaks past the line.
- Once the bearer is Lit by any route, front armour against every hit counts half (none at all under Clear Eye).

Constructs take light normally.

| Skill | Rune | Kind | What it does | Starter |
|---|---|---|---|---|
| Dayline | Shine | beam | Instant 16 m line: 60, Lit | ranged |
| Dusk Well | Dim | ground_zone | 4 m pool of dusk for 7 s: no sight in or out (Lit bodies excepted) | |
| Glint | Flash | new:streak | Instant 7 m streak through enemies, lighting each; stopped by walls, stone, shields | movement |
| Still Lamp | Glow | prop | A lamp for 12 s; everything within 5 m stays Lit | |
| Noonburst | Radiate | melee_burst | 360°, 3.5 m: 1.8x, Lit; walls and raised shields shade | close burst |
| Gathered Light | Absorb | detonate | Each Lit enemy in 12 m: 60, Lit removed, and its ray home hits everything between for 40 | |
| Hard Glare | Glare | melee_burst (cone, not melee) | 8 m cone: 20, Blinded 3 s | |
| Clear Eye | Clarity | self_buff | 6 s: all within 15 m Lit; your hits on Lit ignore front armour | |
| Glancing Ray | Reflect | beam | 14 m ray, bounces twice off walls, stone, shields; 55 and Lit on each leg | |
| Bent Light | Bend | self_buff | 5 s unseen beyond 3 m; first hit counts as from behind and ends it | |

**The starter loop.**
1. Dayline lights the target from far off.
2. Glint closes the gap and lights everything on the way.
3. Noonburst hits the ring, with front armour already halved on whatever is Lit.

## New mechanics (each defined once in the JSON)

| Name | Kind | Rule |
|---|---|---|
| lit | status | 1 stack, 6 s. Cannot be hidden: smoke, steam, darkness, a hides zone, invisibility; illusions it wears fall away. Front armour counts half against every hit |
| blinded | status | 1 stack, 3 s. Cannot aim: ranged attacks drop and cannot start. Melee only lands within 1.5 m in front. Cannot see, so Dream cannot reach it |
| opaque | behaviour | Light lines stop on walls, stone, bodies and raised shields. Area light (`needs_clear_line`) is shaded by walls, stone and shields, not bodies |
| streak | behaviour | Move the caster along the aim in one frame, through bodies (on_pass to each), stopping before a wall, stone or shield |
| hides | field | A zone that blocks sight both ways. Lit bodies are exempt |
| lamp | field | Prop shape that blocks nothing and applies its payload every tick to enemies in light_radius with a clear line to it |
| homing_ray | behaviour | A detonate's ray from each consumed target to the caster hits every other enemy on that line |
| bounces | field | A beam reflects off walls, stone and raised shields, hitting the first body on each leg |
| unseen | behaviour | Enemies beyond unseen_beyond cannot target the caster. Chasers go to the last place they saw you |

## Rune effects (as modifiers)

| Rune | Effect |
|---|---|
| Shine | status lit |
| Dim | power x0.9; reflux x0.7 |
| Flash | windup x0.75; status dazed |
| Glow | duration x1.5; reflux x0.85 |
| Radiate | reach x1.3; cost x1.1 |
| Absorb | bonus lit +0.3; reflux x0.85 |
| Glare | status blinded |
| Clarity | power x1.1; reach x1.15 |
| Reflect | jumps +1 |
| Bend | windup x0.8; reach x1.15 |

## Open
- Light and Dream conflict on purpose: a Blinded enemy cannot see, so Dream cannot touch it. Should one character
  holding both get a pair rule?
- Hard Glare uses melee_burst geometry but is not a melee hit (`not_melee`). It needs a tag so melee talents ignore it.
- Lit halves front armour against everyone's hits. In a party that is strong; tune Lit's length first.
