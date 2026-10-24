# Metal skills v2: the role rebuild (draft, 2026-10-24)

Draft for Brent to the brief in `ROLES-BRIEF.md`. Nothing here is built. Everything is [MODEL] unless tagged; the role and parents are [B] (`design/affinities/framework.md`). Data: `metal.json`, `metal-runes.json`. Started from `design/data-drafts/skills/metal.json` (2026-10-22).

**Role:** armoured duellist: pick one enemy, chain it to you, take its blows on your blade, and heat your edge on it until one cut ends it.  
**Rule:** Metal is worn and wielded: its hits ignore front armour and do +25% per metal class the target wears, and every metal blow on the same enemy heats your edge (Edge Heat, up to 5, +8% each); strike another, or go 3 s without a metal blow, and it cools.  
**Reflux tier:** high. Unchanged: worked metal runs hot, and the duel's rhythm (skill, strike, strike) works reflux off.  
**Skills:** 11 (7 changed, 3 existing, 1 new). 8 serve the role directly, 3 give range and utility.

## How the parents show

- **Earth (ground):** armour you stand in (Plating is Stonehide worn), the guard you stand and take blows on (Turn the Edge is Root in steel), the spall (Earth's shrapnel), the point-first lunge (Bedrock Shove), one body held fast (Iron Clasp is Bury), the Taunt (Earth's status, on one enemy).
- **Fire (forge):** Edge Heat is Fire's heat narrowed to one opponent - a multiplier you build and then spend (Whetted Cut cashes it as Hiss cashes a burn); Red Iron is Stoke in iron (the same coat, setting Alight); the weld itself is fire's heat; Rust Bloom is a Slag Pool for iron.
- **Its own:** the metal class, Stripped (turning its own bonus off), the weapon as its material (strikes scale with damage_mult).

## Numbers

Mid essence (7-12), high reflux. Its blows scale with the weapon (damage_mult 1.6-3.2) and Edge Heat adds up to +40% on one enemy, so a duel goes up while a crowd fight does not.

## Skills

| Skill | Rune | Kind | What it does | Starter | Serves |
|---|---|---|---|---|---|
| Weld Line *(changed)* | Fuse | projectile | A line of molten iron thrown at one enemy, 9 m: 30 damage, it is dragged 3 m toward you, and for 5 s it is welded to you and Taunted - it fights you, and if you walk away it comes along, out of its pack. | **ranged** | role |
| Splitting Blow *(changed)* | Sunder | targeted_strike | One enemy in reach: a cleaving blow, 2.4x strike damage and 60 poise. If it wears metal, its armour splits open and the pieces fly on behind it: 30 per metal class to everyone within 2.5 m. | **close** | role |
| Breakthrough | Breach | dash | Drive forward 5 m, point first. A bare enemy in the way stops you and is knocked back 1.5 m. One that wears metal is punched through: 40 damage, you carry on past it, and it is Stripped for 4 s. | **movement** | role |
| Red Iron *(new)* | Forge | self_buff | You draw the iron red-hot: your Edge Heat is full on the next enemy you strike, everything within 2 m takes 20 as the heat comes off you, and for 6 s every bare strike you land sets its target Alight. |  | role |
| Whetted Cut *(changed)* | Hone | charge_release | Hold to draw your weapon's edge keen, up to 1.5 s, walking at 45%. Let go for one cut across 60 degrees and 3.3 m: 1.6x strike damage at a tap, up to 3.2x at a full hold - and it spends your Edge Heat for +0.3x a stack. |  | role |
| Turn the Edge *(changed)* | Dull | self_buff | A 0.5 s guard, Braced. The first blow aimed at you from within 2.5 m is taken on your blade and does nothing: the attacker is Dulled for 6 s, Staggered (your next strike on it is an Opening), and becomes your Edge Heat target with 2 stacks. The ringing Dulls anyone else within 2 m. If nothing comes, half the essence comes back. |  | role |
| Plating *(changed)* | Plate | self_buff | For 8 s the metal you wear thickens: every blow on you does 30% less, and a blade that lands on you from within 2.5 m is Dulled for 3 s. You move at full speed. |  | role |
| Wrench | Strip | targeted_strike | One enemy in reach: you get a grip on its armour and wrench it off. 1.6x strike damage, interrupted, and Stripped for 8 s: no front armour, and it takes 20% more from everything. It no longer counts as armoured, so metal loses its own bonus on it. |  | role |
| Iron Slug *(changed)* | Forge | projectile | You hammer a slug out of the iron you carry and hurl it: 70 damage and 35 poise. Like every metal hit it ignores a raised shield and hits plate hardest: 105 on a plated enemy. |  | utility |
| Iron Clasp | Seal | smite | One enemy within 9 m: a band of iron snaps shut round its arms. 25 damage, interrupted, and Shackled for 2.5 s: it can still walk, but cannot attack. Each metal class it wears adds 1 s. |  | utility |
| Rust Bloom *(changed)* | Rust | ground_zone | Point, 9 m: rust blooms over a circle 3.5 m across for 7 s. Anything inside that wears metal is Rusting: 6 damage a second per metal class, and its front armour is halved. Bare skin does not care. |  | utility |

**What changed, skill by skill:**

- **Weld Line**: Was Spot Weld (two enemies welded together, a chain). Now one enemy welded to you, pulled in and Taunted: the duellist's ranged starter. Same rune, same verb (two into one piece). Renamed; id kept. Cost 12 -> 8 (starter tier); 45 -> 30 damage.
- **Splitting Blow**: One target now (was a 120-degree cleave): the duellist's close starter. 1.8x -> 2.4x, 50 -> 60 poise; the spall still reaches the pack behind it.
- **Whetted Cut**: Spends Edge Heat for +0.3x a stack (five stacks: +1.5x): the duel's finisher.
- **Turn the Edge**: Was a 360-degree sweep (it sat too near Earth's Tremor). Now a parry on the counter key set (Holy's Abiding Guard, with Wind's refund_unused): Wind slips behind, Metal stands and takes it on the blade.
- **Plating**: 25% -> 30% less, and no longer slows you (was 10% slower): the armoured duellist moves; the area tank (Stonehide, 40% less, 25% slower) does not. attacker_reach (2.5 m) is now a number.
- **Iron Slug**: No longer the ranged starter (Weld Line is). Numbers unchanged; it keeps metal's plain ranged hit.
- **Rust Bloom**: No change in play: Rusting's 6 a second per class is written on the payload so power has a field.

## Rune changes

| Rune | Opposite | Role | Draw | Effect | Change |
|---|---|---|---|---|---|
| Forge | Rust | frame | +0.2 | `power x1.2; windup x1.1` | kept |
| Rust | Forge | link | -0.5 | `status rusting` | kept |
| Fuse | Sunder | frame | +0.5 | `status fused` | re-meant |
| Sunder | Fuse | branch | -0.7 | `poise x1.3; reach x1.1` | kept |
| Seal | Breach | cap | +0.6 | `status shackled` | kept |
| Breach | Seal | link | -0.6 | `pierce +1; poise x1.25` | kept |
| Hone | Dull | link | +0.5 | `power x1.2; poise x0.85` | kept |
| Dull | Hone | link | -0.4 | `status dulled; poise x1.2` | re-meant |
| Plate | Strip | frame | -0.2 | `braced; duration x1.25` | kept |
| Strip | Plate | cap | +0.6 | `status stripped` | kept |

- **Fuse** (re-meant): Re-meant to cover the duel: Fuse now also joins an enemy to you (Weld Line), not only two enemies together. Draws on both parents: Fire's heat welds, Earth holds it to your ground. Role, draw and effect kept.
- **Dull** (re-meant): Re-meant to cover the parry: blunting an edge now includes taking the blow on your blade (Turn the Edge is a counter). Draws on Earth's Root: stand and take it. Role, draw and effect kept.

## New mechanics

- **Edge Heat (focus)** (behaviour, the affinity rule): Metal rule, player-side like Slipstream's pips: a metal hit on the same enemy as your last metal hit adds 1 Edge Heat (up to focus_max 5); each stack makes metal hits focus_mult (+8%) harder. A metal hit on another enemy starts again at 1 on that one; focus_cools_s (3 s) with no metal hit drops it to 0. Area side-effects (spall, bursts) neither add nor reset it. Keys on the affinity: focus_max, focus_mult, focus_cools_s. It is Fire's heat (a multiplier you build) narrowed to one opponent.
- **tether_to_caster** (field, Weld Line): The Fused status's partner is the caster: the enemy is held within tether_m of you while it lasts. Walk away and it is dragged after you, out of its pack; you are not held. A stone or wall between you breaks it.
- **set_focus** (field, Red Iron): A skill with set_focus 'max' fills Edge Heat to focus_max on the next enemy you hit with metal.
- **focus_spend** (field, Whetted Cut): The skill spends all Edge Heat when it lands: + per_focus_mult x the stacks spent to its damage_mult.
- **focus_gain** (field, Turn the Edge): On a counter, the attacker becomes your Edge Heat target with this many stacks added.
- **attacker_reach** (field, Plating): A self_buff's attacker_status lands only on melee attackers within this distance of you (a long reach weapon from farther does not get it).

**Reused, defined elsewhere:** taunted (Earth), the counter key set (Holy, with Wind's additions), coat (Poison's key, as Fire's Stoke uses it), metal class, rusting, fused, shackled, stripped, dulled, spall, pass_armoured (built).

## Ascension fields

Each skill's `ascension` names the field each boost acts on (power, reach, speed or duration, cost). Where a skill deals no damage, power acts on its main effect, as `magnitude` does in abilities.json.

## Open questions

- Earth versus Metal: Earth Taunts many and holds an area (aura, stone, pits), slow and light-hitting. Metal Taunts one, chained to it, moves at full speed in its armour, parries, and hits harder the longer it stays on that one. Neither raises stone; Metal has no aura and no Braced wind-ups except Turn the Edge's guard.
- Edge Heat is a second player-side counter beside Slipstream's pips (and Fire's heat). Three resources to read on a Fire+Metal or Wind+Metal character may be a lot for the HUD.
- Weld Line drags its target after you when you walk away. Against a Wall Commander or a Brute that may want heavy_lasts_mult or a weight check; untested - needs Brent.
