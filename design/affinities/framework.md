# Affinity framework: bases, hybrids, evolutions (2026-10-24)

Brent's ruling 2026-10-24 [B]: the base is narrow, and every other affinity is either a **hybrid** of two bases
or an **evolution** of one. Parents come from the midpoint test (`design/runes-data/hybrid-midpoints.md`,
`tools/runes/hybrid_midpoints.py`) [MODEL], except where Brent forced them [B]. No new affinities beyond these
18 (Storm, Twilight, Mist and Grave, which the test also suggested, are not added) [B].

Roles are the 2026-10-24 working table [B/MODEL]; how a hybrid's role, runes and five-axis position derive from
its parents is still to be designed.

## Bases (8)

| Affinity | Role |
|---|---|
| Water | Bruiser - heavy hits, shoves, crushes |
| Fire | Burst caster - big hits, spreading burns |
| Earth | Area tank - walls, terrain, immovable |
| Wind | Evasive monk - positioning, rear hits, speed |
| Light | Ranged caster - reveal, smite |
| Dark | Assassin - stealth, rear hits, darkness |
| Life | Healer - regrowth, the living only |
| Death | Necromancer - corpses, thralls, the dying |

## Hybrids (two parents)

| Affinity | Parents | Source | Role |
|---|---|---|---|
| Lightning | Fire + Wind | midpoint, lift +0.11 | Spellblade - marks in melee, detonates with casts |
| Ice | Earth + Wind | midpoint, lift +0.07 | Control caster - slow, freeze, shatter |
| Blood | Life + Death | midpoint, lift +0.07 | Berserker - conjured blood weapons, never your own health |
| Dream | Dark + Life | midpoint, lift +0.07 | Enchanter - sleep, charm, masks |
| Poison | Water + Death | **forced** [B] 2026-10-24 | Weapon coater - coatings, poison that pays out later |
| Disease | **[?] open** - the midpoint test's pick (Water + Death) is now Poison's | next best: Water + Life (lift +0.07), Life + Death (taken by Blood) | Plague caster - spreading attrition |
| Nature | Water + Earth | midpoint, lift +0.04 | Druid - growth, beasts, buffs (Brent: Nature also buffs) |
| Holy | Light + Life | **forced** [B] | Paladin / support - shields, wards, buffs |
| Unholy | Dark + Death | **forced** [B] (also the midpoint's pick) | Shadow knight - drain melee, fear, auras |

## Evolutions (one parent)

| Affinity | Parent | Source | Role |
|---|---|---|---|
| Metal | Earth | **forced** [B]; the midpoint test found no pair (lift -0.01) | Armoured duellist - armour, reflect, taunt |


## Open
- How a character gets a hybrid or evolution (held both parents? grown into?), and whether any can be rolled at creation.
- Holy and Unholy do not exist in the game yet: base runes, five-axis positions, skill drafts.
- No affinity owns bows / thrown weapons yet.
