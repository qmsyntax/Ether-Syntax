# Wind skills on base runes (draft, 2026-10-22)

Draft for Brent. Nothing here is built. All [MODEL] unless marked. Brief: `BRIEF.md`. Data: `wind.json`.

**Rule:** Wind is paid for by moving: running earns Slipstream pips, and every wind skill spends (or earns) pips for its real effect.  
**Reflux tier:** low.  
**Skills:** 12 (8 existing, 0 changed, 4 new). Starters marked S.

| Skill | Rune | Kind | What it does | Starter |
|---|---|---|---|---|
| Cutting Gust | Lash | bolt | A short gust that passes through everything in its line. Spends up to 3 pips for +15 each - weak from a standstill. | S |
| Crosscut | Lash | strike | One enemy within 7 m: you cut through and stop behind it. Always a hit from behind. Spends every pip for +10% each. | S |
| Tailwind | Carry | dash | The longest dash, +3 pips, and the only one with no recovery: you can strike or cast the instant it ends. | S |
| Downdraft | Drop | marked blast | Point, 8 m, 4 m wide: 50, interrupts, pins enemies for 2 s, knocks their shots out of the air, and does +100 to anything Aloft. |  |
| Updraft | Lift | displace | Point, 8 m: enemies within 2.5 m are thrown Aloft for 1.2 s (+0.2 s a pip, up to 4) - helpless, and taking 25% more. Heavy ones lose poise instead. |  |
| Crosswind Veil | Buffer | buff | 5 s: enemy shots aimed at you curve away and miss, and your Slipstream does not drain. Blades still land. |  |
| Gale Lane | Blow | zone | A lane 10 m long from your feet, 6 s. In it you move 40% faster and gain pips twice as fast; enemies are pushed down it. |  |
| Spindrift | Blow | channel (held) | Hold while you run: you keep full speed, and every 0.25 s the nearest enemy within 3 m takes 25 (with Lee if you are behind it). Costs 6 essence a second and 1 pip every half second; ends when the pips run out. |  |
| Dead Air *(new)* | Lull | zone | Spend every pip: a 4 m bubble of still air where you stand, lasting 1 s plus 1 s per pip spent. Enemy shots that enter it drop to the floor, your pips do not drain, and your wind reflux sheds while you stand in it. Step out and it ends. Cast from a standstill it is one breath long. |  |
| Headwind *(new)* | Stall | burst | A wall of wind in front of you, a 70-degree cone 6.5 m long: 20 damage, enemies in it are Slowed for 3 s, a charge or pounce in it stops dead, and you take 1 pip from each enemy caught (up to 4). The one wind skill that pays you for standing your ground. |  |
| Dust Devil *(new)* | Whirl | zone | Point, 9 m: a whirlwind 3 m across that drags enemies toward its middle and cuts them for 15 every half second. It drifts at walking pace the way you were running when you cast it, taking them along. Lasts 1.5 s, plus 1 s per pip spent (up to 4). |  |
| Blowout *(new)* | Disperse | burst | Everything within 4.5 m is blown apart: 30 damage and thrown 2 m outward, and each one lands facing away from you for 1 s, so your next hit is from behind. Spends up to 4 pips: +0.5 m and +10 damage each. It also blows smoke and gas away and knocks shots in flight out of the ring. |  |

## New mechanics

- **pip_seconds (zone)** (field, Dead Air): With spend_all_pips, the zone lasts its life plus this many seconds per pip spent.
- **shed_standing** (field, Dead Air): Inside the zone the caster's wind reflux sheds at the moving rate while standing.
- **ends_if_left** (field, Dead Air): The zone ends the moment the caster steps out of it.
- **interrupts_moving** (field, Headwind): Interrupts only an attack that moves its user (a charge, a pounce, a leap).
- **gain_pips_per_hit** (field, Headwind): Pips the caster gains for each enemy the skill hits, up to gain_pips_max.
- **pull_per_s** (field, Dust Devil): A zone that drags enemies inside toward its centre at this speed.
- **drift** (field, Dust Devil): The zone moves at drift_speed along the caster's movement direction at the cast (still if the caster was standing).
- **turn_s (payload)** (field, Blowout): A hit payload that turns each target to face away from the caster for this long (Riptide Lash's turn, for any payload).
- **pip_shove** (field, Blowout): Extra shove per pip spent.
- **clears_clouds** (field, Blowout): Ends enemy smoke, gas and cloud zones that overlap the burst.
