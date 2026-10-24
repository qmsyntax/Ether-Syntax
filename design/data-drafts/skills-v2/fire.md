# Fire skills v2: the role rebuild (draft, 2026-10-24)

Draft for Brent to the brief in `ROLES-BRIEF.md`. Nothing here is built. Everything is [MODEL] unless tagged; the role and parents are [B] (`design/affinities/framework.md`). Data: `fire.json`, `fire-runes.json`. Started from `design/data-drafts/skills/fire.json` (2026-10-22).

**Role:** burst caster: build burns and heat cheaply, then cash both in at once in a few big, dear hits.  
**Rule:** Fire runs on its own heat: fire reflux is a damage multiplier, and fire skills build it, scale with it, or spend it.  
**Reflux tier:** high. Unchanged: the burst caster is the one that runs hottest.  
**Skills:** 14 (6 existing, 6 changed, 2 new). 10 serve the role directly, 4 give range and utility.

## Numbers

The role shifts fire's bands up [MODEL]: the builders stay cheap (Cinder Spit 7, Flashover 7, Stoke 6), the payoffs get dearer and heavier (Kiln Fist 14, Pyre Call 16, Hiss 10, White Heat 24 for a 150 base bolt, above the 45-120 band because it is the one big hit and has a 0.6 s wind-up). Payoffs that spend heat (Backdraft, Hiss) leave no reflux of their own, so the loop is build, cash in, build again.

## Skills

| Skill | Rune | Kind | What it does | Starter | Serves |
|---|---|---|---|---|---|
| Cinder Spit | Ignite | projectile | A quick, cheap bolt that sets its target Alight. Weak cold; it is how you get hot. | **ranged** | role |
| Kiln Fist *(changed)* | Burn | targeted_strike | One enemy in reach: a heavy blow, 2 Alight, interrupts. If it was already burning, every stack is spent for +45 and the blow bursts, setting 2 Alight on everything within 2.5 m. | **close** | role |
| Flashover *(changed)* | Ignite | dash | A short dash that leaves a line of flame for 3 s: anything standing in it takes 12 and catches. It does not carry you through enemies. | **movement** | utility |
| Pyre Call *(changed)* | Explode | detonate | A short breath in, then every Alight enemy within 10 m loses its stacks, and each stack bursts for 45 in 2 m. Spread the burns first; call them once. |  | role |
| Backdraft | Implode | melee_burst | Open the door. First every enemy within 5 m is drawn 2 m toward you, then the blast: they take 4 x the heat you carry above 20, and your fire reflux drops to 20. 320 at full heat; nothing when cold. |  | role |
| Bellows Breath | Blaze | channel | Hold: a cone of fire 5 m long and 60 degrees wide. 50 damage a second and 1 Alight every half second to everything in it. You walk at 45% while holding. 6 essence a second, and every second of it heats you - the fastest way to get hot. |  | role |
| Stoke *(changed)* | Blaze | self_buff | At once, +25 heat, and a gust of it: everything within 2.5 m takes 20 and catches. For 6 s every bare strike you land sets its target Alight. |  | role |
| Slag Pool | Smoulder | ground_zone | Lobbed to a point, 9 m: 3 m across for 6 s. 25 a second and 1 Alight a second to enemies standing in it. |  | role |
| Hiss *(changed)* | Quench | smite | One burning enemy within 9 m: every Alight stack on it goes out at once and it takes 50 per stack, all now. Your fire reflux drops 6 per stack. Five stacks: 250 damage and 30 heat off. |  | role |
| Wickpinch | Snuff | smite | Costs no essence: it burns 15 of your heat instead, and cannot be cast below 15. One enemy within 7 m has its flame pinched out: whatever it was doing is interrupted - even an attack not marked interruptible - and it loses 40 poise. A Censer-Bearer snuffed this way no longer bursts when it dies. |  | utility |
| Flashpan | Flare | melee_burst | A flash of flame from your hands across a 90-degree cone 6 m deep. 30 damage, and everyone in it that is facing you is Blinded for 1 s plus 1 s for every 30 heat you carry (up to 4 s). Archers lose their aim. |  | utility |
| Smokepall *(changed)* | Smother | ground_zone | Lobbed to a point, 9 m: a pall of smoke 3 m across. Enemies in it are Slowed, ranged enemies cannot see into or through it, and burns inside neither run down nor go easy: Alight on them ticks 25% harder. Lasts 4 s, plus 1 s for every 20 heat you carry (up to 9 s). |  | utility |
| White Heat *(new)* | Sear | smite | Dear and slow: a 0.6 s wind-up, then one enemy within 14 m is struck by a point of white heat: 150 damage and 60 poise, and your Heat bonus counts twice on it. Cold it is a good hit; at full heat it is the biggest single blow fire has. |  | role |
| Brushfire *(new)* | Catch | smite | One burning enemy within 10 m: its fire leaps to everything within 4 m of it. Each takes 30 and as many Alight stacks as the target carries, up to 3. Light one well, then let it catch. |  | role |

**What changed, skill by skill:**

- **Kiln Fist**: Burst tier: cost 12 -> 14, +40 -> +45 a stack, and the burst is wider (2 -> 2.5 m) and lays 2 stacks, not 1, so the close starter spreads burns. on_hit.status_s (5 s, Alight's own) made explicit for the duration aspect.
- **Flashover**: The trail now burns for 12 a tick (it only set Alight), so the power aspect has a number.
- **Pyre Call**: Burst tier: cost 12 -> 16, reflux 1.0 -> 1.4, 35 -> 45 a stack, and a 0.25 s wind-up (the big spell is read before it lands, and gives the speed aspect a number).
- **Stoke**: strike_status became a coat (Poison's weapon-coating key); a 2.5 m flare (20 and Alight) on cast, so the buff has a reach and lights the crowd before the burst.
- **Hiss**: Burst tier: cost 8 -> 10, 48 -> 50 a stack. Kind is smite (as built; the draft's new:seize). recovery 0.12 (the default) made explicit for the speed aspect.
- **Smokepall**: Burns inside tick 25% harder as well as being banked, so cover also feeds the burst (and power has a number).

## Rune changes

| Rune | Opposite | Role | Draw | Effect | Change |
|---|---|---|---|---|---|
| Burn | Quench | link | -0.5 | `status alight 2` | kept |
| Quench | Burn | cap | +0.7 | `reflux x0.7; power x1.1` | kept |
| Ignite | Snuff | link | -0.4 | `status alight; windup x0.9` | kept |
| Snuff | Ignite | cap | +0.6 | `interrupts` | kept |
| Explode | Implode | branch | -1 | `reach x1.3; power x1.15; cost x1.15` | kept |
| Implode | Explode | cap | +1 | `pull +1.5` | kept |
| Blaze | Smoulder | branch | -0.8 | `power x1.2; reflux x1.2` | kept |
| Smoulder | Blaze | frame | +0.4 | `duration x1.5; status alight` | kept |
| Flare | Smother | branch | -0.6 | `status dazed` | kept |
| Smother | Flare | cap | +0.8 | `interrupts; status slowed` | kept |
| Catch | Sear | branch | -0.8 | `jumps +1; power x0.9` | new |
| Sear | Catch | cap | +0.7 | `power x1.35; reach x0.8` | new |

- **Catch** (new): Added for 'spreading burns', half of the role, which no rune said outright: Burn and Ignite start a fire on one body, Blaze spreads it in front of you, but nothing made a burn leap from body to body. A branch (spreads or splits), drawing outward (-0.8, as Blaze). As a modifier its hit jumps on, as Lightning's Arc does: Catch is the parent concept Arc grows from.
- **Sear** (new): Added for 'big hits': the one big, single, heat-scaled blow a burst caster is built round. A cap (ends a structure: everything goes into it), drawing inward (+0.7, as Quench). Base beats universal on its own ground: it is a stronger Focus (power x1.3; reach x0.8).

## New mechanics

- **coat on a self_buff** (field, Stoke): Poison's coat key (poison.json, Venom Edge: every bare strike and ranged-weapon shot carries the coat's payload) used by a self_buff: coat {duration, payload} with no charges lasts its duration. Replaces Stoke's strike_status; Lightning's Static Coat and Metal's Red Iron use it too. One coat at a time.
- **on_cast (radius)** (field, Stoke): A self_buff's on_cast payload hits every enemy within radius of the caster once, as the buff starts.
- **zone dps_mult** (field, Smokepall): A ground_zone's dps_mult {status: x} makes that status's damage over time tick x times as hard on enemies inside (the status engine's dps_mult key, read from the zone as well as from statuses).
- **heat_scale** (field, White Heat): The fire Heat bonus on this hit counts heat_scale times: a hit whose Heat bonus is +b does (1 + b x heat_scale) of its damage.
- **spread_stacks** (field, Brushfire): Every enemy within spread_radius of the target gains as many stacks of spread_stacks (a status) as the target carries, up to spread_max each; the target keeps its own.

**Reused, defined elsewhere:** smite (as built), hard_interrupt, quells_censer, heat_cost, blinded, pull_before_blast, blocks_sight, banks, life_per_heat, status_s_per_heat, needs_facing (all from the 2026-10-22 draft, now in the game).

## Ascension fields

Each skill's `ascension` names the field each boost acts on (power, reach, speed or duration, cost). Where a skill deals no damage, power acts on its main effect, as `magnitude` does in abilities.json.

## Open questions

- White Heat's heat_scale 2 assumes the Heat bonus is linear in reflux; at full heat it is about 330 by that arithmetic. Brent should feel whether the one big hit is big enough or too big next to Backdraft (320 at full heat, but an area).
- Brushfire needs the target already burning (needs_status). Cast on a cold target it is refused before essence is spent, as smites are.
- Catch's modifier (jumps +1) makes fire hits arc like lightning's Arc; that is deliberate (Catch is Arc's parent concept) but the two may read as the same rune to a player.
