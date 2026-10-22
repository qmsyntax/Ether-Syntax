# Earth skills on base runes (draft, 2026-10-22)

Draft for Brent. Nothing here is built. All [MODEL] unless marked. Brief: `BRIEF.md`. Data: `earth.json`.

**Rule:** Earth builds stone that stays: its skills raise, use or break your stone, wind up Braced, and break poise.  
**Reflux tier:** low.  
**Skills:** 12 (8 existing, 0 changed, 4 new). Starters marked S.

| Skill | Rune | Kind | What it does | Starter |
|---|---|---|---|---|
| Slingstone | Dig | bolt | The slowest bolt and the heaviest. It stops what it hits mid-swing and all but staggers it. Thrown into your own stone, it shatters it. | S |
| Landslide Blow | Crumble | burst | A narrow, slow, crushing blow: it staggers anything short of an elite, moves nobody, and shatters every stone of yours in its arc. | S |
| Raise Slab | Raise | placed | A wall of stone across your aim, up to 8 m away. It blocks movement and shots - theirs and yours - for 12 s. Three at a time. | S |
| Pillar | Raise | marked blast | Point, 9 m: a circle is marked for half a second, then a column punches up - 120, 60 poise, interrupts - and stays as stone. |  |
| Stonehide | Harden | buff | 8 s Braced: 40% less damage, and nothing staggers or shoves you. You move 25% slower. |  |
| Bedrock Shove | Root | dash | Shoulder first, 3.5 m, Braced throughout. The first enemy you meet is thrown 3 m and loses 50 poise; a heavy one stops you dead and loses 60. |  |
| Tremor | Quake | burst | Everything within 5 m takes 60, is interrupted and slowed for 3 s - and every stone you have standing shatters outward at once. |  |
| Quarry Throw | Dig | charge (held) | Hold to tear a boulder out of the floor (rooted and Braced, up to 1.5 s), release to lob it at the cursor, up to 14 m. 150 to 400 damage in 2.5 m by how long you held, 80 poise, and it leaves rubble: a stone that also slows enemies within 2 m of it by 40%. |  |
| Sinkhole *(new)* | Sink | placed | Point, 9 m, 0.5 s wind-up (Braced): the floor drops into a pit 2.5 m across for 10 s. Enemies standing there fall in for 30 damage and 40 poise. Inside they are Mired and need 1.5 s to climb out; enemies walk round it, and shots fly over it. It counts as one of your three stones. |  |
| Cairn *(new)* | Bury | seize (new) | One enemy within 8 m, 0.4 s wind-up (Braced): earth heaps over it. It is Buried for 2.5 s - it cannot move or act, and blows land on the stone, not on it. Shatter the cairn (Slingstone, Landslide Blow, Tremor) and the one inside takes 120 and is Staggered. Elites are Pinned instead. The cairn counts as one of your three stones. |  |
| Burrow *(new)* | Tunnel | dash | 0.3 s wind-up (Braced), then you go under the floor and come up 6 m on, 0.4 s later, passing beneath enemies, stone and shots (a slam on the ground can still find you). Where you surface the ground heaves: enemies within 1.5 m lose 40 poise and are pushed 1.5 m off. Surface beside your own stone and it shatters away from you. |  |
| Cave-In *(new)* | Collapse | marked blast | Dear. Point, 10 m, 0.4 s wind-up (Braced): rock comes down on a 3 m circle a full second later. Everything still under it takes 130 and 70 poise and is Stunned for 1 s, elites included. The rubble stays for 15 s: nothing can walk through it, but shots pass over. It counts as one of your three stones. |  |

## New mechanics

- **new:charge_release** (behaviour, Quarry Throw): design/05 Appendix A behaviour 9 (not built): hold to charge, release fires a delayed_blast whose damage runs from damage to damage_full over charge_max.
- **prop shape "pit"** (behaviour, Sinkhole): A prop that is a hole, not a block: it does not block shots; enemies path round it; anyone inside is Mired and needs climb_out_s to leave; it counts toward the caster's stone limit and is not shattered (shatter on it does nothing).
- **climb_out_s** (field, Sinkhole): Seconds an enemy inside a pit needs to climb out.
- **new:seize** (behaviour, Cairn): Same as water.json: an instant effect on one enemy under the cursor within range; walls and stone block it. Here with a wind-up.
- **buried** (status, Cairn): Lasts the skill's duration. Cannot move or act; hits on it land on the cairn (a stone of the caster's with 150 health) instead. Elites take Pinned instead.
- **shatter_bonus** (field, Cairn): When a cairn is shattered, the enemy inside takes this much and is Staggered, besides the normal shrapnel.
- **under** (field, Burrow): A dash that goes under the floor: it passes beneath bodies, stone and shots; ground attacks (slams, zones) still hit you. It does not make you untouchable.
- **blocks_shots false** (field, Cave-In): A prop that blocks walking but not shots (a low heap).
