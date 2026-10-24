# Lightning skills v2: the role rebuild (draft, 2026-10-24)

Draft for Brent to the brief in `ROLES-BRIEF.md`. Nothing here is built. Everything is [MODEL] unless tagged; the role and parents are [B] (`design/affinities/framework.md`). Data: `lightning.json`, `lightning-runes.json`. Started from `design/data-drafts/skills/lightning.json` (2026-10-22).

**Role:** spellblade: strike, blink, strike again, and let three touches go off as a burst; every burst makes you faster.  
**Rule:** Lightning marks a target and overloads it: every lightning hit leaves Live marks, and the third mark is an Overload - a burst that stuns the target and arcs to every other marked enemy within 12 m - that leaves you Quickened for 1.5 s.  
**Reflux tier:** middling. Unchanged: middling, and it still sheds in a fight only by Overloading.  
**Skills:** 12 (7 existing, 5 changed). 8 serve the role directly, 4 give range and utility.

## How the parents show

- **Fire (burst):** the Overload is the burst; Dead Short is Pyre Call for marks; Thunderclap Palm is Kiln Fist's heavy, bursting blow; Static Coat is Stoke's coated hands (the same coat key); Stored Bolt is a build-then-spend; Arc is Fire's new Catch (fire leaps body to body) at lightning's speed.
- **Wind (speed):** every Overload now Quickens you (the rule); Stepped Leader is Tailwind made instant; Forked Path and Stored Bolt carry you through and behind like Crosscut; Bell Jar is Dead Air over one body; Dead Line is Lull for sound.
- **Its own:** Live marks and the Overload, Ground and the rod, Insulate. It has no heat and no pips: it takes its parents' shapes, not their resources.

## Numbers

Bands unchanged (it sits between its parents: Fire's payoffs are dearer, Wind's are cheaper). Stored Bolt and Dead Short stay dear (18-20) as the burst; the blade skills stay mid (8-14).

## Skills

| Skill | Rune | Kind | What it does | Starter | Serves |
|---|---|---|---|---|---|
| Arc Lash | Arc | beam | Instant and short: it cannot miss what it points at. 85 damage and a Live mark, then it arcs to one more enemy within 4 m for the same. Walls stop it. | **ranged** | role |
| Thunderclap Palm | Thunder | targeted_strike | One enemy in reach: a heavy blow, 2 Live marks, and it stops whatever it was doing. The crack Dazes and staggers everyone within 2.5 m of it, the target too. | **close** | role |
| Stepped Leader *(changed)* | Quicken | blink | You are simply there, up to 6 m away: over enemies and gaps, not through walls or stone. Everything beside where you land takes 30 and a Live mark, and you are Quickened for 2 s after. | **movement** | role |
| Static Coat *(changed)* | Charge | self_buff | 6 s: every bare strike you land adds a Live mark and sparks on to the nearest other enemy within 3 m, marking it too; an enemy that hits you in melee takes 25 and a mark. |  | role |
| Stored Bolt *(changed)* | Charge | charge_release | Hold up to 1.2 s, walking slowly; let go and you are the bolt: you cross 4 m at a tap, 8 m at a full hold, through everything in the way. Each body you pass takes 80 to 220 and 1 to 3 Live marks by how long you held. A full charge Overloads the whole line. |  | role |
| Dead Short | Discharge | detonate | Every marked enemy within 12 m Overloads now: 40% of the full blow and stun at 1 mark, 70% at 2, all of it at 3. It grounds no reflux. |  | role |
| Forked Path *(changed)* | Arc | chain | One enemy within 9 m, then up to three more within 5 m of each other: you flash from one to the next, striking each from behind for 1.2x strike damage and a Live mark, and stop behind the last. Never the same body twice. |  | role |
| Seize Up | Stun | melee_burst | Everything within 3 m locks up: 30 damage, and Stunned for 0.4 s for every Live mark it carries (0.2 s if none). It spends no marks. |  | role |
| Plumb Bolt | Strike | smite | One enemy within 14 m is struck from straight above: 100 damage, 30 poise and a Live mark. Bodies, shields and low walls between you do not stop it. |  | utility |
| Ground Rod | Ground | rod | Point, 8 m: a rod for 10 s that blocks nothing. Each lightning skill you cast within 8 m of it also arcs from the rod to the nearest enemy within 5 m: 40 and a mark. One rod at a time. |  | utility |
| Bell Jar | Insulate | smite | One enemy within 12 m is sealed under a jar of still air for 6 s: 30 damage and a Live mark. Nothing passes in or out of it: no auras, no death burst, no arcs. Overload it and the whole arc stays inside: +60 for every other marked enemy within 12 m. |  | utility |
| Dead Line *(changed)* | Silence | ground_zone | Point, 9 m: a ring 3 m across hums for 6 s. Enemies inside cannot cast, drum or call for help. Each takes 20, a Live mark and an interrupt once, on entering. |  | utility |

**What changed, skill by skill:**

- **Arc Lash**: No change in play; its recovery (the default 0.12 s) is written out for the speed aspect.
- **Thunderclap Palm**: No change in play; its recovery (the default 0.12 s) is written out for the speed aspect.
- **Stepped Leader**: The landing now strikes (30) as well as marking: the spellblade arrives cutting.
- **Static Coat**: Every bare strike marks (was every second one), and sparks on to a second enemy within 3 m: the spellblade's imbue, on the coat key Fire's Stoke and Poison use (strikes_per_mark is gone).
- **Stored Bolt**: Released as a streak that carries you (it was a beam from where you stood): the spellblade's charged lunge.
- **Dead Short**: No change in play; recovery written out for the speed aspect.
- **Forked Path**: It now carries you and strikes with your weapon (1.2x strike damage, from behind) instead of a flat 50 sent from where you stand. Cost 12 -> 14.
- **Plumb Bolt**: No change in play; recovery written out for the speed aspect.
- **Dead Line**: Entering now also costs 20 (it only marked and interrupted), so power has a number.

## Rune changes

| Rune | Opposite | Role | Draw | Effect | Change |
|---|---|---|---|---|---|
| Strike | Ground | link | -0.6 | `power x1.2; speed x1.2` | kept |
| Ground | Strike | frame | +0.4 | `reflux x0.75` | kept |
| Charge | Discharge | frame | +0.6 | `marks +1` | kept |
| Discharge | Charge | cap | -1 | `bonus live +0.4` | kept |
| Arc | Insulate | branch | -0.5 | `jumps +1` | kept |
| Insulate | Arc | cap | +0.3 | `status insulated` | kept |
| Quicken | Stun | link | -0.4 | `windup x0.7; speed x1.2` | kept |
| Stun | Quicken | cap | +0.7 | `status stunned` | kept |
| Thunder | Silence | branch | -0.7 | `poise x1.3; status dazed` | kept |
| Silence | Thunder | cap | +0.5 | `interrupts` | kept |

- **Insulate** (kept): Effect changed: it was 'cost x0.85', which did not describe isolating a target (the 2026-10-22 draft said so). It now applies Insulated, the status Bell Jar is built on. Draws on Wind's Buffer and Lull: a cushion of still air round one body.

## New mechanics

- **quicken_on_overload** (field, the affinity rule): Affinity rule key: each Overload the caster causes leaves them Quickened (the existing player state) for this many seconds (1.5); a new Overload refreshes it.
- **release streak** (field, Stored Bolt): A charge_release may release as a streak (the built Glint kind): you cross range (range_min at a tap, range at a full hold) in an instant, through bodies, applying on_pass to each one within pass_radius.
- **carries_caster** (field, Forked Path): A chain that takes the caster with it: you appear behind each target as it is struck (a hit from behind), and stay behind the last one. A wall or stone between two targets ends the chain there.

**Reused, defined elsewhere:** coat (Poison's key, on Fire's Stoke), quickened (player state, built), smite, beam jumps, insulated, muted, zone on_enter, stun by marks, burst statuses (built). Streak (Light's Glint) as a release.

## Ascension fields

Each skill's `ascension` names the field each boost acts on (power, reach, speed or duration, cost). Where a skill deals no damage, power acts on its main effect, as `magnitude` does in abilities.json.

## Open questions

- Quickened on every Overload (1.5 s) plus Stepped Leader's 2 s may be a lot of Quickened uptime in a pack fight; it is the spellblade's loop, but its feel is untested - needs Brent.
- Forked Path now carries the caster; with walls between targets it ends early. That rule is a guess.
