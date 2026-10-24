# Wind skills v2: the role rebuild (draft, 2026-10-24)

Draft for Brent to the brief in `ROLES-BRIEF.md`. Nothing here is built. Everything is [MODEL] unless tagged; the role and parents are [B] (`design/affinities/framework.md`). Data: `wind.json`, `wind-runes.json`. Started from `design/data-drafts/skills/wind.json` (2026-10-22).

**Role:** evasive monk: keep moving, do not be where the blow lands, and strike from behind.  
**Rule:** Wind is paid for by moving: running earns Slipstream pips, every wind skill spends (or earns) pips for its real effect, and wind hits from behind do half again (Lee).  
**Reflux tier:** low. Unchanged: the monk's reflux sheds by moving.  
**Skills:** 12 (8 existing, 3 changed, 1 new; 1 dropped). 9 serve the role directly, 3 give range and utility.

## Numbers

Wind keeps the bands of the 2026-10-22 draft: cheap to mid essence (6-12), light hits that grow with pips and with Lee (+50% from behind). The role is paid in position, not in bigger numbers.

## Skills

| Skill | Rune | Kind | What it does | Starter | Serves |
|---|---|---|---|---|---|
| Cutting Gust | Lash | projectile | A short gust that passes through everything in its line. Spends up to 3 pips for +15 each - weak from a standstill. | **ranged** | role |
| Crosscut | Lash | targeted_strike | One enemy within 7 m: you cut through and stop behind it. Always a hit from behind. Spends every pip for +10% each. | **close** | role |
| Tailwind | Carry | dash | The longest dash, +3 pips, and the only one with no recovery: you can strike or cast the instant it ends. | **movement** | role |
| Crosswind Veil *(changed)* | Buffer | self_buff | 5 s: enemy shots that would pass within 1.5 m of you curve away and miss, each one turned gives you a pip, and your Slipstream does not drain. Blades still land. |  | role |
| Gale Lane | Blow | ground_zone | A lane 10 m long from your feet, 6 s. In it you move 40% faster and gain pips twice as fast; enemies are pushed down it. |  | role |
| Spindrift | Blow | channel | Hold while you run: you keep full speed, and every 0.25 s the nearest enemy within 3 m takes 25 (with Lee if you are behind it). Costs 6 essence a second and 1 pip every half second; ends when the pips run out. |  | role |
| Downdraft *(changed)* | Drop | dash | You spring up and come down on a point up to 7 m away, over bodies and gaps. Everything within 3 m of where you land takes 60, is interrupted and Pinned for 2 s; anything Aloft takes 100 more. Spends up to 3 pips for +15 each. |  | role |
| Turning Palm *(new)* | Deflect | self_buff | A 0.6 s stance. The first blow, charge or pounce aimed at you from within 3 m misses: you slip behind the attacker and strike it for 1.8x strike damage from behind, it is left Turned for 1.5 s, and you gain 2 pips. If nothing comes, half the essence comes back. |  | role |
| Updraft | Lift | displace | Point, 8 m: enemies within 2.5 m are thrown Aloft for 1.2 s (+0.2 s a pip, up to 4) - helpless, and taking 25% more. Heavy ones lose poise instead. |  | utility |
| Dead Air | Lull | ground_zone | Spend every pip: a 4 m bubble of still air where you stand, lasting 1 s plus 1 s per pip spent. Enemy shots that enter it drop to the floor, your pips do not drain, and your wind reflux sheds while you stand in it. Step out and it ends. |  | utility |
| Dust Devil | Whirl | ground_zone | Point, 9 m: a whirlwind 3 m across that drags enemies toward its middle and cuts them for 15 every half second. It drifts at walking pace the way you were running when you cast it, taking them along. Lasts 1.5 s, plus 1 s per pip spent (up to 4). |  | utility |
| Blowout *(changed)* | Disperse | melee_burst | Everything within 4.5 m is blown apart: 30 damage and thrown 2 m outward, and each one lands Turned for 1 s, its back to you. Spends up to 4 pips: +0.5 m and +10 damage each. It also blows smoke and gas away and knocks shots in flight out of the ring. |  | role |

**Dropped:**

- **Headwind** (Stall): Stall became Deflect. Headwind stood its ground in a cone, slowed what came and took pips from it: the stand-and-stall job is an area tank's (Earth now has it), and the opposite of an evasive monk. Its one role-shaped part, earning pips from a fight, moved to Turning Palm, which earns them by not being hit.

**What changed, skill by skill:**

- **Crosswind Veil**: Pays a pip for every shot it turns (the evasive monk is paid for evading), and the deflect radius (1.5 m) is now a number, so reach has a field.
- **Downdraft**: Was a point-targeted delayed blast (you stayed put); now you leap there and the blast is your landing (positioning, the monk's way). It no longer knocks shots from the air (Dead Air and Veil do that) and it now spends pips, as every wind skill does.
- **Updraft**: No change in play: Aloft's own 1.2 s is written as on_hit.status_s so the duration aspect has a field.
- **Blowout**: The 1 s turn is now the Turned status (shared with Turning Palm and the Deflect rune) instead of a payload-only turn_s.

## Rune changes

| Rune | Opposite | Role | Draw | Effect | Change |
|---|---|---|---|---|---|
| Blow | Lull | link | -0.6 | `shove +1` | kept |
| Lull | Blow | cap | +0.5 | `interrupts; speed x0.85` | kept |
| Lash | Buffer | link | +0.3 | `power x1.2; speed x1.1` | kept |
| Buffer | Lash | frame | -0.2 | `duration x1.2; reflux x0.85` | kept |
| Lift | Drop | link | -0.4 | `status aloft` | kept |
| Drop | Lift | link | +0.5 | `poise x1.4; interrupts` | kept |
| Carry | Deflect | link | -0.5 | `speed x1.3; reach x1.15` | kept |
| Deflect | Carry | link | +0.6 | `status turned` | renamed |
| Whirl | Disperse | frame | +0.4 | `pull +1; reach x1.1` | kept |
| Disperse | Whirl | branch | -0.9 | `reach x1.3; power x0.9` | kept |

- **Deflect** (renamed): Stall ("stalled; slipstream stolen") was wind standing still against a rush, which is an area tank's verb, not an evasive monk's. Deflect keeps its place as Carry's opposite (go with the flow / turn the flow aside), its role (link: it takes the blow in and passes it on, aside) and its draw (+0.6: it takes in what comes at you). Its effect moves from Slowed to the new Turned status: a deflected foe is left facing the wrong way.

## New mechanics

- **gain_pips_per_deflect** (field, Crosswind Veil): With deflect_radius: enemy shots that would pass within deflect_radius of you curve away, and each one turned gives you this many pips.
- **leap** (field, Downdraft): A dash that goes over bodies, low stone and gaps and lands at the aimed point (not through walls or standing stone taller than you); on_arrive hits everything within arrive_radius of the landing.
- **counter (refund_unused)** (field, Turning Palm): The counter key set is Holy's (holy.json, Abiding Guard: a self_buff with window_s, counter_reach and a counter payload; the first blow that would land in the window is refused whole and the attacker takes the payload). Wind adds refund_unused: if the window passes with no blow, that share of the essence comes back (in place of Holy's patience_ward). A charge or pounce counts as a blow; a shot does not. Metal's Turn the Edge uses the same keys.
- **behind_dist** (field, Turning Palm): On a counter, the caster is moved to this far behind the attacker (a swept move; if the space is blocked, as far as it goes) before the counter payload lands.
- **turned** (status, Turning Palm): 1 stack, 1 s (heavy enemies half): it is spun to face away from you, so every hit on it counts as from behind (counts_rear) until it turns back. Keys: turn_away, counts_rear, lasts, heavy_lasts_mult. Replaces Blowout's turn_s payload field; Deflect's effect uses it.

**Reused, defined elsewhere:** Slipstream pips, Lee (rear_bonus), aloft, pinned, kill_projectiles, clears_clouds, pip_shove, drift, pull_per_s, shed_standing, ends_if_left (built), and the counter key set (Holy's). Turned and refund_unused are reused by Metal.

## Ascension fields

Each skill's `ascension` names the field each boost acts on (power, reach, speed or duration, cost). Where a skill deals no damage, power acts on its main effect, as `magnitude` does in abilities.json.

## Open questions

- Turning Palm, Metal's Turn the Edge and Holy's Abiding Guard share one counter key set. Wind's slips you behind the attacker; Metal's stands and takes it on the blade. Whether a counter window of 0.6 s feels fair against the telegraphed enemy attacks is untested - needs Brent.
- Downdraft becoming a leap gives wind a fourth way to move (Tailwind, Gale Lane, Turning Palm's slip). That is the role, but it overlaps Lightning's Stepped Leader (a blink); the difference is the landing blast and the 0.35 s in the air, where you can be hit.
