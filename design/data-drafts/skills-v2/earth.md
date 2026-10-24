# Earth skills v2: the role rebuild (draft, 2026-10-24)

Draft for Brent to the brief in `ROLES-BRIEF.md`. Nothing here is built. Everything is [MODEL] unless tagged; the role and parents are [B] (`design/affinities/framework.md`). Data: `earth.json`, `earth-runes.json`. Started from `design/data-drafts/skills/earth.json` (2026-10-22).

**Role:** area tank: hold a piece of ground, wall it and shake it, and make everything in it come for you.  
**Rule:** Earth holds its ground: its skills raise, use or break your stone, wind up Braced, break poise, and call the enemy onto you.  
**Reflux tier:** low. Unchanged, and Quarry Throw comes down to it.  
**Skills:** 13 (12 changed, 1 new). 10 serve the role directly, 3 give range and utility.

## Numbers

The tank's bands shift down [MODEL]: hits are lighter (Landslide Blow 3.2x -> 2x, Slingstone 120 -> 70, Pillar 120 -> 90, Cave-In 130 -> 100) and every skill is one step cheaper (starters 8-12, the dearest 18). What earth does in place of damage is hold: Braced, Taunted, Mired, stone.

## Skills

| Skill | Rune | Kind | What it does | Starter | Serves |
|---|---|---|---|---|---|
| Slingstone *(changed)* | Dig | projectile | A slow, heavy stone thrown Braced: 70 damage, 45 poise, it stops what it hits mid-swing, and it Taunts it for 4 s - it drops what it was doing and comes for you. Thrown into your own stone, it shatters it. | **ranged** | role |
| Landslide Blow *(changed)* | Crumble | melee_burst | A broad, slow, crushing blow across 100 degrees, Braced: 2x strike damage and 60 poise to everything in it, and each one is Taunted for 4 s. It moves nobody, and shatters every stone of yours in its arc. | **close** | role |
| Bedrock Shove *(changed)* | Root | dash | Shoulder first, 3.5 m, Braced throughout. The first enemy you meet is thrown 2 m and loses 50 poise (a heavy one stops you dead and loses 60), and everything within 3 m of where you stop is Taunted for 4 s. | **movement** | role |
| Raise Slab *(changed)* | Raise | prop | A wall of stone across your aim, up to 8 m away. It blocks movement and shots - theirs and yours - for 12 s. Three at a time. |  | role |
| Pillar *(changed)* | Raise | delayed_blast | Point, 9 m: a circle is marked for half a second, then a column punches up - 90, 60 poise, interrupts - and stays as stone. |  | role |
| Sinkhole *(changed)* | Sink | prop | Point, 9 m, 0.5 s wind-up (Braced): the floor drops into a pit 2.5 m across for 10 s. Enemies standing there fall in for 30 damage and 40 poise. Inside they are Mired and need 1.5 s to climb out; enemies walk round it, and shots fly over it. It counts as one of your three stones. |  | role |
| Stonehide *(changed)* | Harden | self_buff | 8 s Braced: 40% less damage, and nothing staggers or shoves you. You move 25% slower, and the ground within 2.5 m of you thickens: enemies in it are Mired. |  | role |
| Tremor *(changed)* | Quake | melee_burst | Everything within 5 m takes 50, is interrupted and Slowed for 3 s - and every stone you have standing shatters outward at once. |  | role |
| Cave-In *(changed)* | Collapse | delayed_blast | Point, 10 m, 0.4 s wind-up (Braced): rock comes down on a 3 m circle a full second later. Everything still under it takes 100 and 70 poise and is Stunned for 1 s, elites included. The rubble stays for 15 s: nothing can walk through it, but shots pass over. It counts as one of your three stones. |  | role |
| Millstone *(new)* | Weigh | self_buff | For 6 s you are as heavy as the hill: nothing moves, staggers or throws you, and you walk at 60%. Every enemy within 6 m is drawn toward you, 1 m a second, and Taunted while it stays inside. When it ends the ground settles under you: everything within 3 m takes 60 and 40 poise. |  | role |
| Quarry Throw *(changed)* | Buoy | charge_release | Hold to tear a boulder out of the floor (rooted and Braced, up to 1.5 s), release to lob it at the cursor, up to 14 m. 110 to 280 damage in 2.5 m by how long you held, 80 poise, and it leaves rubble: a stone that also slows enemies within 2 m of it by 40%. |  | utility |
| Cairn *(changed)* | Bury | smite | One enemy within 8 m, 0.4 s wind-up (Braced): earth heaps over it. It is Buried for 2.5 s - it cannot move or act, and blows land on the stone, not on it. Shatter the cairn and the one inside takes 120 and is Staggered. Elites are Pinned instead. The cairn counts as one of your three stones. |  | utility |
| Burrow *(changed)* | Tunnel | dash | 0.3 s wind-up (Braced), then you go under the floor and come up 6 m on, 0.4 s later, passing beneath enemies, stone and shots. Where you surface the ground heaves: enemies within 1.5 m lose 40 poise and are pushed 1.5 m off. |  | utility |

**What changed, skill by skill:**

- **Slingstone**: The tank's ranged starter is now a taunt: 120 -> 70 damage, cost 12 -> 8, and it Taunts for 4 s. Its reach to the back rank is its point, not its damage.
- **Landslide Blow**: Lighter and wider for the tank: 3.2x -> 2x, 80 -> 60 poise, arc 60 -> 100 degrees, wind-up 0.6 -> 0.5 s, cost 16 -> 12, and everything it hits is Taunted.
- **Bedrock Shove**: Now the movement starter (Raise Slab was the third kit skill, but it does not move you). Cost 12 -> 8 (cheap tier), shove 3 -> 2 m, and it Taunts everything within 3 m of where you stop.
- **Raise Slab**: No longer a starter (Bedrock Shove is the movement starter). Numbers unchanged.
- **Pillar**: Tank tier: 120 -> 90, cost 12 -> 10.
- **Sinkhole**: Tank tier: cost 12 -> 10.
- **Stonehide**: Cost 12 -> 10, its 40% made explicit as incoming_mult, and a 2.5 m aura that Mires enemies beside you (the area tank's ground; it gives reach a field).
- **Tremor**: Tank tier: 60 -> 50, cost 18 -> 14.
- **Cave-In**: Tank tier: 130 -> 100, cost 20 -> 16.
- **Quarry Throw**: Moved from Dig to the new Buoy rune. Tank tier: 150-400 -> 110-280, cost 22 -> 18, reflux 1.0 -> 0.4 (earth's usual).
- **Cairn**: Tank tier: cost 14 -> 12. Kind is smite (as built; the draft's new:seize).
- **Burrow**: Tank tier: cost 12 -> 10.

## Rune changes

| Rune | Opposite | Role | Draw | Effect | Change |
|---|---|---|---|---|---|
| Raise | Sink | frame | -0.2 | `poise x1.3` | kept |
| Sink | Raise | link | +0.5 | `status mired` | kept |
| Harden | Crumble | frame | +0.4 | `power x1.15; speed x0.9` | kept |
| Crumble | Harden | branch | -0.6 | `poise x1.5` | kept |
| Root | Quake | frame | +0.6 | `braced; poise x1.2` | kept |
| Quake | Root | branch | -0.7 | `reach x1.2; poise x1.3` | kept |
| Dig | Bury | link | -0.4 | `power x1.15; cost x0.9` | kept |
| Bury | Dig | cap | +0.7 | `status pinned` | kept |
| Tunnel | Collapse | link | -0.3 | `through; reach x1.1` | kept |
| Collapse | Tunnel | cap | +0.6 | `status pinned; poise x1.3` | kept |
| Weigh | Buoy | frame | +0.7 | `status taunted; poise x1.15` | new |
| Buoy | Weigh | link | -0.6 | `reach x1.25; speed x1.15` | new |

- **Weigh** (new): Added for the tank's missing verb: calling enemies onto you. In earth's own terms that is weight: you become the heaviest thing in the room and the room leans toward you. It revives the first pass's Weigh (design/14 section 3). A frame (holds a structure together: the heavy centre everything bonds to), drawing inward (+0.7).
- **Buoy** (new): Weigh's opposite, also from the first pass. Quarry Throw moves here from Dig. A link (takes in and passes on: lifts, then throws), drawing outward (-0.6, as Weigh's mirror).

## New mechanics

- **taunted** (status, Slingstone): 1 stack, the skill's status_s (elites half, heavy_lasts_mult 0.5): it comes for whoever taunted it and attacks only them. A ranged or support enemy walks in to strike in melee instead of keeping its distance or tending its friends, and lures, decoys and thralls do not draw it. Keys: forced_target 'source', closes_in. Applying it again refreshes it. Used by Earth (many at once) and Metal (one).
- **aura** (behaviour, Stonehide): A self_buff's aura {radius, tick_s, payload, pull_per_s} applies its payload every tick_s to each enemy within radius of the caster (a hold lands once per target per cast, as zones do) and drags them toward the caster at pull_per_s. It moves with you.
- **on_end** (field, Millstone): A self_buff's on_end payload hits every enemy within its radius of the caster once, when the buff runs out.
- **immovable (self)** (field, Millstone): While a self_buff with immovable lasts, the caster cannot be shoved, pulled, staggered, thrown Aloft or knocked down; damage still lands.

**Reused, defined elsewhere:** standing stone, Braced, shatter and shrapnel, pit and rubble props, buried, mired, pinned, stunned (built).

## Ascension fields

Each skill's `ascension` names the field each boost acts on (power, reach, speed or duration, cost). Where a skill deals no damage, power acts on its main effect, as `magnitude` does in abilities.json.

## Open questions

- Earth versus Metal [B: both tank-side]: Earth Taunts many at once (Landslide Blow's arc, Bedrock Shove's ring, Millstone's 6 m), holds an area with stone and pits, is slow (Stonehide, Millstone) and hits light. Metal Taunts one enemy, chained to it, hits harder the longer it stays on that one, parries, and moves at full speed in its armour. Neither raises stone; Metal has no aura.
- There are no party allies, so a taunt's value is what it does to enemy behaviour: the archer, Censer and Drummer walk in and fight in melee, and decoys no longer pull them away. Whether that is worth a starter slot is untested - needs Brent.
- Millstone's 1 m/s draw is gentle on purpose (enemies keep their footing and their slot ring); a stronger pull would bunch them for Tremor and Cave-In too well.
