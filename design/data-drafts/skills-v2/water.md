# Water skills v2: the bruiser

Draft for Brent, 2026-10-24, to `ROLES-BRIEF.md`. Nothing here is built. Data: `water.json`, `water-runes.json`.
Tags: **[B]** Brent's ruling, **[MODEL]** our invention; everything untagged is [MODEL]. All names are original.

**Role [B 2026-10-24]: bruiser - heavy hits, shoves and crushes.** A water fighter wins up close: it hauls the runner
in, throws bodies into walls, and is shored up by every Crush it causes.

**Rule:** Water moves bodies: its skills shove and drag, and a shoved body that meets a wall, stone or another body is Crushed; every Crush you cause shores you up with a 15 Ward (up to 60, for 6 s).

**Reflux: middling** (as before). **Bands:** melee multipliers sit at the top of the band (Breaker 2.4x, Wringing Grip
2.0x + 100 per Soak, Cataract up to 3.0x); cost tiers unchanged; the one ranged hit (Riptide Lash, 60) stays light.

## Skills (13: 9 serve the role directly)

| Skill | Rune | Kind | What it does | Starter | Status |
|---|---|---|---|---|---|
| Breaker | Surge | melee_burst | A wide, heavy blow (2.4x strike damage, 30 poise) that throws everyone it hits 4 m away from you. Stand so the wall is behind them. | close | changed |
| Cataract | Surge | charge_release | Hold to gather the weight of falling water over your fists (up to 1.2 s; you are Braced and walk at 30%), then bring it down: everything within 3 m takes 1.4x to 3.0x strike damage by the charge, is Soaked, loses 60 poise and is thrown 3 m outward. One already against a wall or stone takes half again and is Crushed where it stands. |  | new |
| Riptide Lash | Ebb | displace | One enemy within 10 m is hauled to arm's length, takes 60, is Soaked and interrupted - and arrives with its back to you for a second. Water's ranged starter: the bruiser does not shoot the runner, it hauls it in. | ranged | changed |
| Standing Pool | Flood | ground_zone | Point, 9 m: a pool 3.5 m across for 8 s. Enemies in it are Soaked and 30% slower, and a shove that starts in it goes twice as far. No damage. |  | existing |
| Drawdown | Drain | detonate | Every Soaked enemy within 8 m has the water torn out of it toward you: its Soak ends and it is dragged 3 m toward you. You get 2 essence back for each. Your Standing Pool in range empties toward you too, dragging those in it twice as far, and is gone. |  | existing |
| Drench | Soak | delayed_blast | Point, 10 m: a cloudburst gathers for 0.6 s, then falls on a 3 m circle. Everyone under it is Waterlogged for 6 s and interrupted. A Waterlogged heavy enemy is shoved as if it were light, and an elite as if it were heavy. |  | existing |
| Wringing Grip | Dry | targeted_strike | One enemy within reach: you grip it and wring the water out. A 2.0x blow, +100 if it was Soaked (+200 if Waterlogged) - the grip uses the Soak up - and it reels back 1 m. Little more than a hard slap on a dry target. |  | changed |
| Overboard | Heave | displace | Grab one enemy within reach, lift it on a column of water and hurl it up to 6 m toward where you aim (heavy ones half as far; an elite only staggers). 40 when you grab it; where it lands, everyone within 1.5 m takes 40 and is knocked aside. Thrown into a wall, stone or another body, it is Crushed. |  | new |
| Drowning Hold | Drown | new:seize | One enemy within 8 m: a ball of water closes over its head for 3 s. It is interrupted, cannot attack, cast, drum or call for help, and takes 20 at once and 15 a second. When the water lets go it heaves the enemy 3 m away from you, so put the wall behind it first. |  | existing |
| Backwash | Splash | self_buff | 6 s or three blows, whichever ends first: each melee hit on you is halved, and the water splashes off you - whoever threw the blow, and everyone else within 2 m of you, is shoved 3 m and Soaked. |  | existing |
| Seepage | Seep | new:seize | One enemy within 9 m: water soaks in under its guard for 0.6 s, then wells up behind it - 50 damage that ignores its shield and armour, and a 1.5 m tug toward you. For 4 s its shield and armour count for nothing, against anyone. |  | existing |
| Sluice Step | Wave | dash | You roll forward about 6.5 m as a wave. Every enemy you meet takes 30, is Soaked and is carried 3 m on ahead of you, the way you are going; one carried into a wall, stone or another body is Crushed. | movement | changed |
| Siltfall | Settle | detonate | Everything you moved settles. Every enemy within 10 m that a water skill shoved or dragged in the last 1.5 s hits the floor where it now stands: 40 damage, Pinned (60% slower) for 2 s and 30 poise. Bodies still sliding finish their slide first. |  | changed |

Starters: **Riptide Lash** (ranged - a pull, the bruiser's reach), **Breaker** (close), **Sluice Step** (movement - a
bull rush that carries bodies into the wall).

### Dropped

- **Water Bolt** (Surge): A cheap ranged bolt is a caster's tool. Water's ranged starter is now Riptide Lash, the bruiser's way to reach a runner (a pull, as the brief allows); Surge's second skill is Cataract, the heavy hit. Its soak-and-knock lives on in Drench and Breaker.
- **Undertow** (Ebb): Area pull with no damage that gathers bodies at a point, not at your fists. Drawdown (every Soaked enemy dragged to you) and Riptide Lash cover Ebb's role for a bruiser; Ebb keeps one skill.
- **Pressure Jet** (Gush): Its rune Gush is dropped. A held ranged stream is a caster's verb; its push-into-a-wall is Breaker's and Cataract's, and its pinned_mult is generalised as Cataract's against_wall_mult.
- **Upwelling** (Float): Its rune Float is re-meant as Heave (lift and throw one body). An area lift for 30 damage is control; Overboard takes the rune.
- **Steady Drip** (Drip): Its rune Drip is dropped (Gush and Drip go as a pair). Slow poise wear from 10 m is not a bruiser's; Cataract's 60 poise and Breaker's 30 do the staggering up close.
- **Tidal Bore** (Wave): A 20-essence rolling wall that overlapped Breaker, and its carry was never built. Wave's carry-to-the-wall moves into Sluice Step, where the wave is you.
- **Slack Water** (Slack): Its rune Slack is dropped. The still moment at the turn of the tide is Ice's ground now: Ice's Stasis rune and Dead Calm, which leaves its target Stilled (this skill's status, kept in statuses.json for Ice).

## Runes: 16 -> 12

| Rune | Meaning | Opposite | Role | Draw | Effect | Change |
|---|---|---|---|---|---|---|
| Flood | fill an area with water; the ground turns Wet | Drain | branch | -0.6 | reach x1.2; status soaked | kept |
| Drain | empty the water from an area or a target, and draw it in | Flood | link | +0.6 | pull +1; reflux x0.9 | kept |
| Surge | push bodies away | Ebb | link | -0.6 | shove +1.5 | kept |
| Ebb | draw bodies in | Surge | link | +0.6 | pull +1.5 | kept |
| Soak | saturate a target | Dry | link | -0.5 | status soaked | kept |
| Dry | pull the water out of a body: damage by how wet it is | Soak | cap | +0.8 | bonus soaked +0.4 | kept |
| Heave | lift a body bodily and throw it | Drown | link | -0.5 | shove +2 | renamed |
| Drown | water in the lungs: no casting, no calls for help, damage over time | Heave | cap | +0.9 | interrupts; status dazed | kept |
| Splash | burst outward on contact, spraying those near | Seep | branch | -0.7 | reach x1.25; power x0.9 | kept |
| Seep | soak in slowly, getting behind shields and armour | Splash | link | +0.4 | through | kept |
| Wave | a rolling wall of water that carries what it meets | Settle | branch | -0.5 | reach x1.2; poise x1.3 | re-meant |
| Settle | the water goes still, and what it carries sinks and stays | Wave | frame | +0.4 | status mired | kept |
| Gush | a sudden forceful jet | Drip | link | -0.8 | speed x1.3; power x1.1 | dropped |
| Drip | a slow steady trickle that wears and lingers | Gush | link | +0.3 | duration x1.4; cost x0.85 | dropped |
| Sweep | a current that carries things along | Settle | link | -0.4 | reach x1.3 | dropped |
| Slack | the still moment at the turn of the tide: everything pauses, reflux eases | Wave | cap | +0.5 | reflux x0.75 | dropped |

- **Heave** (renamed): Was Float ("buoyancy: lift, lighten, walk on water"). Buoyancy is a caster's lift; the bruiser lifts a body and throws it. Same id, role (link) and draw (-0.5: it gives outward), so its bonds are unchanged. Effect was 'shove +1; poise x0.8'.
- **Wave** (re-meant): Meaning widened to carry what it meets (Sweep's verb, Sweep is dropped). Opposite changed from Slack (dropped) to Settle: the wave carries, Settle drops what it carried. Role and draw kept.
- **Gush** (dropped): A held jet is a caster's verb (Pressure Jet). 16 runes had to come to 12.
- **Drip** (dropped): Goes with its opposite; slow wear at range is not a bruiser's.
- **Sweep** (dropped): Its verb (carry along) is folded into Wave; Sluice Step moves to Wave. Taken up by Ice as Floe (drifting ice).
- **Slack** (dropped): Stillness is Ice's half from Dark; Ice takes it up as Stasis, whose target comes out Stilled (Slack Water's status).

## New mechanics

Mechanics from the 2026-10-22 drafts (Soaked, Chilled, Lit, Unseen, light level, sees_caster...) are built and not repeated; only what is new in v2 is listed.

- **ward** (status, affinity rule): One shared player state with holy.json (Dawnward, which defines it in full) and unholy.json: a pool on the player taken before health (after armour and tempering, before talents), filled by 'ward' keys up to ward_cap 60 per body; each amount keeps its own timer and the oldest is spent first. Water only fills it (crush_ward); Ice Shell's old 'absorb' is a ward with an 'on_break'.
- **crush_ward** (field, affinity rule): Affinity key {per_crush, cap, lasts}: each Crush the caster causes adds per_crush Ward, never above cap from this source, each lasting 'lasts' s. Water: 15 / 60 / 6 s.
- **against_wall_mult** (field, from Cataract): A hit on a target already within 0.5 m of a wall, stone or another body does this much more and counts as a Crush (Water's rule, ward included) though the body does not move. Generalises Pressure Jet's pinned_mult.
- **throw_target** (behaviour, from Overboard): displace mode: one enemy within range is lifted and thrown toward the aimed point, up to 'throw' m times its shove_resist (elites: staggered, not thrown). It travels as a shove, so meeting a wall, stone or body is a Crush; where it stops, 'on_land' hits every other enemy within its radius. Checked before essence is spent.

## Notes and open questions

- **Game-side breakage when this is emitted:** `water_bolt` is the old ranged starter and `prime_default` kit; tests,
  bots and shots cast it by id. design/14 section 10's worked examples use Tidal Bore and Pressure Jet (dropped) and
  the shots `seal-drown-flood` use Pressure Jet. Those need re-pointing at the new kit (Riptide Lash / Breaker /
  Sluice Step) when the emitter runs.
- **Ward** is one pool shared with Holy (holy.json, Dawnward) and Unholy; Water only fills it through Crushes, and
  Ice Shell uses it. Holy's ward_cap is 60 per body, which is also Water's crush cap.
- Heavy and elite enemies still resist shoves (0.5 / 0.25); Drench (Waterlogged) and Seepage remain the answers.
