# Fire skills on base runes (draft, 2026-10-22)

Draft for Brent. Nothing here is built. All [MODEL] unless marked. Brief: `BRIEF.md`. Data: `fire.json`.

**Rule:** Fire runs on its own heat: fire reflux is a damage multiplier, and fire skills build it, scale with it, or spend it.  
**Reflux tier:** high.  
**Skills:** 12 (6 existing, 2 changed, 4 new). Starters marked S.

| Skill | Rune | Kind | What it does | Starter |
|---|---|---|---|---|
| Kiln Fist | Burn | strike | One enemy in reach: a heavy blow, 2 Alight, interrupts. If it was already burning, every stack is spent for +40 and the blow bursts, lighting those beside it. | S |
| Cinder Spit | Ignite | bolt | A quick, cheap bolt that sets its target Alight. Weak cold; it is how you get hot. | S |
| Flashover | Ignite | dash | A short dash that leaves a line of flame for 3 s: anything standing in it catches. It does not carry you through enemies. | S |
| Pyre Call | Explode | detonate | Every Alight enemy within 10 m loses its stacks, and each stack bursts for 35 in 2 m. Spread the burns first; call them once. |  |
| Backdraft *(changed)* | Implode | burst | Open the door. First every enemy within 5 m is drawn 2 m toward you, then the blast: they take 4 x the heat you carry above 20, and your fire reflux drops to 20. 320 at full heat; nothing when cold. |  |
| Bellows Breath | Blaze | channel (held) | Hold: a cone of fire 5 m long and 60 degrees wide. 50 damage a second and 1 Alight every half second to everything in it. You walk at 45% while holding. 6 essence a second, and every second of it heats you - the fastest way to get hot. |  |
| Stoke *(changed)* | Blaze | buff | At once, +25 heat. For 6 s every bare strike you land sets its target Alight. Light a man with your hands, then Kiln Fist him. |  |
| Slag Pool | Smoulder | zone | Lobbed to a point, 9 m: 3 m across for 6 s. 25 a second and 1 Alight a second to enemies standing in it. |  |
| Hiss *(new)* | Quench | seize (new) | One burning enemy within 9 m: every Alight stack on it goes out at once and it takes 48 per stack, all now - what the burn would still have done, and a little more. Your fire reflux drops 6 per stack. Five stacks: 240 damage and 30 heat off. Leaves no reflux of its own. |  |
| Wickpinch *(new)* | Snuff | seize (new) | Costs no essence: it burns 15 of your heat instead, and cannot be cast below 15. One enemy within 7 m has its flame pinched out: whatever it was doing is interrupted - even an attack that is not marked as interruptible - and it loses 40 poise. A Censer-Bearer snuffed this way no longer bursts when it dies. |  |
| Flashpan *(new)* | Flare | burst | A flash of flame from your hands across a 90-degree cone 6 m deep. 30 damage, and everyone in it that is facing you is Blinded: it cannot aim and its blows miss you, for 1 s plus 1 s for every 30 heat you carry (up to 4 s). Archers lose their aim. Enemies with their backs to you are not blinded. |  |
| Smokepall *(new)* | Smother | zone | Lobbed to a point, 9 m: a pall of smoke 3 m across. Enemies in it are Slowed, ranged enemies cannot see into or through it, and Alight burns on enemies inside do not run down. Lasts 4 s, plus 1 s for every 20 heat you carry (up to 9 s). |  |

## New mechanics

- **pull_before_blast** (field, Backdraft): A melee_burst with a top-level pull drags every enemy within its reach that far toward the caster when the wind-up starts, before the hit.
- **Stoke on Blaze** (field, Stoke): Rune moved from Smoulder (FIR-4b) to Blaze (FIR-4a), approved; numbers unchanged. strike_status names what its bare strikes apply (it was implied by the buff id).
- **new:seize** (behaviour, Hiss): An instant effect on the one enemy under the cursor (or your locked target) within range; walls and stone block it; it is checked before essence is spent. With a delay, the target is marked and the hit lands that many seconds later wherever it has moved.
- **vent_per_stack** (field, Hiss): Lowers the caster's fire reflux by this much for each stack consumed (after the hit, so its Heat bonus is measured hot).
- **heat_cost** (behaviour, Wickpinch): The skill is paid in the caster's fire reflux instead of essence; it cannot be cast with less heat than this.
- **hard_interrupt** (field, Wickpinch): An interrupt that cancels any enemy wind-up, not only those marked interruptible (elites included).
- **quells_censer** (field, Wickpinch): A Censer-Bearer hit by it loses its death burst for good.
- **blinded** (status, Flashpan): 1 stack, time set by the skill. Cannot aim: its attacks on the caster miss and a ranged enemy loses its aim and must start again.
- **status_s_per_heat** (field, Flashpan): The applied status lasts status_s plus this many seconds per point of fire reflux, up to status_s_max.
- **needs_facing** (field, Flashpan): Only enemies whose front faces the caster take the status.
- **blocks_sight** (field, Smokepall): A zone that ranged enemies cannot see into or through: they cannot target anyone inside or beyond it.
- **banks** (field, Smokepall): A status on enemies inside the zone does not run down while they stay in it.
- **life_per_heat** (field, Smokepall): The zone lasts its life plus this many seconds per point of fire reflux at the cast, up to life_max.
