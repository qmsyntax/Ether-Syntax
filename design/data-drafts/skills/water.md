# Water skills on base runes (draft, 2026-10-22)

Draft for Brent. Nothing here is built. All [MODEL] unless marked. Brief: `BRIEF.md`. Data: `water.json`.

**Rule:** Water moves bodies: every water skill shoves, drags or sets up a shove, and a shoved body that hits something is Crushed.  
**Reflux tier:** middling.  
**Skills:** 18 (6 existing, 2 changed, 10 new). Starters marked S.

| Skill | Rune | Kind | What it does | Starter |
|---|---|---|---|---|
| Water Bolt | Surge | bolt | First enemy hit is Soaked and knocked back a step. | S |
| Breaker | Surge | burst | A wide blow that throws everyone it hits 4 m away from you. Stand so the wall is behind them. | S |
| Sluice Step *(changed)* | Sweep | dash | A short dash straight through enemies. Each one you pass is Soaked and swept 2 m along with you, the way you are going. | S |
| Undertow | Ebb | displace | Point, 9 m: every enemy within 4 m of the spot is dragged up to 4 m toward it and Soaked. No damage of its own - but bodies that collide Crush each other. |  |
| Riptide Lash | Ebb | displace | One enemy within 10 m is hauled to arm's length, takes 60, is Soaked and interrupted - and arrives with its back to you for a second. |  |
| Standing Pool | Flood | zone | Point, 9 m: a pool 3.5 m across for 8 s. Enemies in it are Soaked and 30% slower, and a shove that starts in it goes twice as far. No damage. |  |
| Backwash *(changed)* | Splash | buff | 6 s or three blows, whichever ends first: each melee hit on you is halved, and the water splashes off you - whoever threw the blow, and everyone else within 2 m of you, is shoved 3 m and Soaked. |  |
| Pressure Jet | Gush | channel (held) | Hold: an 8 m stream, 1 m wide, at the first enemy in the line: 90 damage a second and it is pushed back 5 m a second. Pinned against a wall or stone it takes 1.5x. You turn slowly and walk at 45% while holding. 10 essence a second. |  |
| Drawdown *(new)* | Drain | detonate | Every Soaked enemy within 8 m has the water torn out of it toward you: its Soak ends and it is dragged 3 m toward you. You get 2 essence back for each. Your Standing Pool in range empties toward you too, dragging those in it twice as far, and is gone. |  |
| Drench *(new)* | Soak | marked blast | Point, 10 m: a cloudburst gathers for 0.6 s, then falls on a 3 m circle. Everyone under it is Waterlogged for 6 s and interrupted. A Waterlogged heavy enemy is shoved as if it were light, and an elite as if it were heavy. |  |
| Wringing Grip *(new)* | Dry | strike | One enemy within reach: you grip it and wring the water out. A 1.6x blow, +90 if it was Soaked (+180 if Waterlogged) - the grip uses the Soak up - and it reels back 1 m. Little more than a slap on a dry target. |  |
| Upwelling *(new)* | Float | displace | Point, 9 m: a spring bursts up under everyone within 2.5 m. 30 damage; light enemies are lifted Aloft and come down 2 m out from the spring (4 m, since Aloft doubles a shove). Heavy enemies lose 50 poise and slide 1 m. |  |
| Drowning Hold *(new)* | Drown | seize (new) | One enemy within 8 m: a ball of water closes over its head for 3 s. It is interrupted, cannot attack, cast, drum or call for help, and takes 20 at once and 15 a second. When the water lets go it heaves the enemy 3 m away from you, so put the wall behind it first. |  |
| Steady Drip *(new)* | Drip | seize (new) | Cheap. One enemy within 10 m drips for 10 s: every second it is nudged half a step away from you and loses 8 poise, and its poise does not recover while it drips. Leave it on a big enemy and it staggers on its own. |  |
| Siltfall *(new)* | Settle | detonate | Everything you moved settles. Every enemy within 10 m that a water skill shoved or dragged in the last 1.5 s sinks where it now stands: Pinned (60% slower) for 2 s and 30 poise. Bodies still sliding finish their slide first. |  |
| Seepage *(new)* | Seep | seize (new) | One enemy within 9 m: water soaks in under its guard for 0.6 s, then wells up behind it - 50 damage that ignores its shield and armour, and a 1.5 m tug toward you. For 4 s its shield and armour count for nothing, against anyone. |  |
| Tidal Bore *(new)* | Wave | bolt | Dear. A wall of water 5 m wide rolls 12 m forward from you. Everyone it meets is picked up and carried to where it breaks: 45 damage, Soaked, 30 poise. If it breaks against a wall, everyone it carries is Crushed. Heavy enemies are dropped halfway; elites split it. |  |
| Slack Water *(new)* | Slack | burst | The tide stops to turn. Everything within 4.5 m is interrupted and hangs still for 2 s (60% slower), and the next shove or drag on each of them goes twice as far. Your water reflux drops by 20. No damage. |  |

## New mechanics

- **shove_dir "along"** (field, Sluice Step): A dash payload's shove pushes the body the way the dash is travelling, not away from the caster.
- **Backwash payload** (field, Backwash): The splash is now an on_hit payload (shove 3, Soaked) applied to the attacker and to everyone within radius (2 m) of you, so modifiers can reach it; it replaces the old top-level shove.
- **new:channel** (behaviour, Pressure Jet): design/05 Appendix A behaviour 8 (not built): held, essence per second (cost with cost_per_s), payload every tick to the first enemy on the line.
- **refund_per_stack** (field, Drawdown): Essence returned to the caster for each status stack the skill consumes, never more than the skill cost.
- **pool_pull_mult** (field, Drawdown): Enemies standing in one of the caster's own water zones within range are pulled this many times as far, and the zone ends.
- **waterlogged** (status, Drench): 6 s, 1 stack. Counts as Soaked (shoves x1.5, conducts). The target is also shoved as one weight class lighter: heavy as light, elite as heavy.
- **waterlogged_stacks** (field, Wringing Grip): A consume_status of soaked counts a Waterlogged target as this many stacks.
- **shove_dir "from_point"** (field, Upwelling): A shove in a point-cast payload pushes each body away from the aimed point.
- **new:seize** (behaviour, Drowning Hold): An instant effect on the one enemy under the cursor (or your locked target) within range; walls and stone block it; it is checked before essence is spent. With a delay, the target is marked and the hit lands that many seconds later wherever it has moved.
- **drowning** (status, Drowning Hold): 1 stack, lasts the skill's duration. Cannot attack, cast, drum or call for reinforcements; 15 damage a second through the caster; ends early after 150 damage taken.
- **release_shove** (field, Drowning Hold): When the skill's status ends, the target is shoved this far away from the caster (a Crush if it meets something).
- **dripping** (status, Steady Drip): 1 stack, lasts the skill's duration. Every second: nudged nudge_per_s away from the caster (too soft to Crush) and loses poise_per_s poise; poise does not regenerate while Dripping.
- **adrift** (status, Siltfall): 1 stack, 1.5 s. Put on any body when a water shove or pull on it ends. Nothing on its own; Siltfall consumes it.
- **seeped** (status, Seepage): 1 stack, lasts the skill's duration. The target's front block and armour do nothing.
- **ignores block** (behaviour, Seepage): The hit that applies Seeped already ignores front block and armour.
- **carry** (behaviour, Tidal Bore): A projectile with carry picks up each light enemy it touches and moves it along with it until it ends; heavy enemies ride half its remaining distance; elites are hit but not carried. If it stops on a wall, every carried body is Crushed by its remaining distance.
- **width (projectile)** (field, Tidal Bore): A projectile may be this wide across its line instead of a point.
- **stilled** (status, Slack Water): 1 stack, 2 s. 60% slower; the next shove or pull on it goes twice as far and ends the status.
- **vent_reflux** (field, Slack Water): Lowers the caster's reflux on the skill's affinity by this much when cast.
