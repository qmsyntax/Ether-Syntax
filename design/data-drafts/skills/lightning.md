# Lightning skills, one per base rune: draft v0

Draft for Brent, 2026-10-22, to the brief in `BRIEF.md`. Nothing here is built. Data: `lightning.json`.
Tags: **[B]** Brent's ruling, **[MODEL]** our invention. Everything not tagged is [MODEL]. All skill names are original.

Lightning is in the game. Its seven built skills stay on the runes `runes.json` gives them; Stored Bolt (design/05 L6, not built) goes on Charge; four new skills fill Strike, Insulate, Stun and Silence. Arc and Charge carry a second skill, which the brief allows once every rune has one. Its rune effects already exist in `runes.json` and are not changed here.

## Rule

**Lightning marks a target and overloads it: every lightning hit leaves Live marks, and the third mark is an Overload that stuns the target and arcs to every other marked enemy within 12 m.** [MODEL]

**Reflux: middling.** Unchanged from design/05: middling reflux per essence, but lightning reflux does not shed in a fight except by Overloading (each grounds 12). Finish targets or seize up.

**Approved changes applied** [B]:

- **Arc Lash** arcs to 1 more enemy within 4 m (Brent, approved). Needs `jumps` on a beam.
- **Stepped Leader** leaves you Quickened for 2 s after landing (Brent, approved). Quickened is new, defined below.
- **Thunderclap Palm** also Dazes and staggers everyone within 2.5 m of the target, the target too (Brent, approved).

## Skills

| Skill | Rune | Kind | What it does | Starter |
|---|---|---|---|---|
| Plumb Bolt *(new)* | Strike (LIG-1a) | new:smite | One enemy within 14 m is struck from straight above: 100 damage, 30 poise and a Live mark. Bodies, shields and low walls between you do not stop it. |  |
| Ground Rod | Ground (LIG-1b) | rod | Point, 8 m: a rod for 10 s that blocks nothing. Each lightning skill you cast within 8 m of it also arcs from the rod to the nearest enemy within 5 m: 40 and a mark. One rod at a time. |  |
| Static Coat | Charge (LIG-2a) | self_buff | 6 s: an enemy that hits you in melee takes 25 and a Live mark, and every second bare strike you land adds a mark. |  |
| Stored Bolt *(design/05, not built)* | Charge (LIG-2a) | charge_release | Hold up to 1.2 s, walking slowly; let go for an instant line 12 m long through everything: 100 to 300 damage and 1 to 3 Live marks by how long you held. A full charge Overloads the whole line. |  |
| Dead Short | Discharge (LIG-2b) | detonate | Every marked enemy within 12 m Overloads now: 40% of the full blow and stun at 1 mark, 70% at 2, all of it at 3. It grounds no reflux. |  |
| Arc Lash *(changed)* | Arc (LIG-3a) | beam | Instant and short: it cannot miss what it points at. 85 damage and a Live mark, then it arcs to one more enemy within 4 m for the same. Walls stop it. | **ranged** |
| Forked Path | Arc (LIG-3a) | chain | One enemy within 9 m, then up to three more within 5 m of each other: 50 and 1 Live mark each. Never the same body twice. |  |
| Bell Jar *(new)* | Insulate (LIG-3b) | new:smite | One enemy within 12 m is sealed under a jar of still air for 6 s: 30 damage and a Live mark. Nothing passes in or out of it: no auras, no death burst, no arcs. Overload it and the whole arc stays inside: +60 for every other marked enemy within 12 m. |  |
| Stepped Leader *(changed)* | Quicken (LIG-4a) | blink | You are simply there, up to 6 m away: over enemies and gaps, not through walls or stone. A Live mark on everything beside where you land, and you are Quickened for 2 s after. | **movement** |
| Seize Up *(new)* | Stun (LIG-4b) | melee_burst | Everything within 3 m locks up: 30 damage, and Stunned for 0.4 s for every Live mark it carries (0.2 s if none). It spends no marks. |  |
| Thunderclap Palm *(changed)* | Thunder (LIG-5a) | targeted_strike | One enemy in reach: a heavy blow, 2 Live marks, and it stops whatever it was doing. The crack Dazes and staggers everyone within 2.5 m of it, the target too. | **close burst** |
| Dead Line *(new)* | Silence (LIG-5b) | ground_zone | Point, 9 m: a ring 3 m across hums for 6 s. Enemies inside cannot cast, drum or call for help. Each is interrupted and takes a Live mark once, on entering. |  |

## New mechanics

- **smite** (behaviour, from Plumb Bolt): kind 'smite': an instant hit on the enemy under the cursor (or your locked target) within 'range', no travel and no wind-up; checked before essence is spent. With 'from_above' nothing between you and it blocks it and a frontal block (front_armour, blocks_shots) does not apply.
- **beam jumps** (behaviour, from Arc Lash): A beam may carry 'jumps' and 'jump_radius': after the first enemy it hits, the payload jumps to the nearest not-yet-hit enemy within jump_radius, as a chain does. (effects_v1 only lets 'jumps +n' act on kind chain; it should read the jumps field instead.)
- **insulated** (status, from Bell Jar): 1 stack, 'duration' seconds. Nothing passes into or out of the target: allies' auras (drummed, a Censer-Bearer's burst) skip it, its own aura and death burst go nowhere, Overload arcs and Soaked conduction skip it. An Overload on it does not arc out; it takes +arc_damage (60) for every other marked enemy within arc_radius instead, and those keep their marks.
- **quickened** (status, from Stepped Leader): On the player, 2 s: move 20% faster and every recovery (skill, strike, dash) is 30% shorter. Re-applying refreshes.
- **stun by marks** (behaviour, from Seize Up): A payload with 'stun_per_mark' sets Stunned to stun_per_mark x the target's Live marks (stun_min if none), read before any mark the hit adds; 'elite_stun_mult' scales it on elites.
- **burst statuses** (behaviour, from Thunderclap Palm): A targeted_strike's 'burst' (exists for Kiln Fist) may carry 'statuses', applied to every enemy within burst_radius of the target, the target included.
- **muted** (status, from Dead Line): 1 stack, 1 s, refreshed while inside: cannot cast, start a drum roll or a Wall Commander's call, or send the reinforcements signal. Plain attacks still land.
- **zone on_enter** (field, from Dead Line): A ground_zone's 'on_enter' payload is applied once to each enemy, when it is first inside (at the cast, or when it walks in); 'payload' is applied every tick.

## Modifiers, checked

Every good and bad modifier was run through a copy of `effects_v1.gd`'s rules (one rune bonded straight to the skill's own rune; bond kind from electronegativity; universal runes at their placeholder 2.5). Every good one applies all its ops. Every bad one either falls back to the quarter-power consolation, is cancelled by an ionic bond, or out-pulls the skill's own rune; where the maths would accept a bad one, its entry says why it still makes no sense.

## Notes and open questions

- **Three single-target lightning skills now exist** (Plumb Bolt, Bell Jar, Thunderclap Palm). They differ by job: Plumb Bolt is reach and raw damage, Bell Jar is isolation, the Palm is the close finisher and the starter.
- **Bell Jar is the lightning answer to the Censer-Bearer and the War Drummer** (design/05 6.1): a jarred censer's burst goes nowhere; a jarred enemy gets no drum. Seize Up and Dead Line round out the 'stop them' side lightning lacked.
- **Insulate's existing effect (cost x0.85) does not describe Bell Jar.** When something out-pulls Insulate on Bell Jar, the effect system shrinks its cost cut, not its seal. The signature names the seal anyway; the rune's effect may want a second look.
- **`jumps +n` only works on kind `chain`** in `effects_v1.gd`. Arc Lash now jumps as a beam, so Arc and Many cannot add a jump to it. Reading the `jumps` field instead of the kind would fix it.
- **Thunderclap Palm staggering elites.** The approved text says 'staggers everyone within 2.5 m'. Applied as a status, that ignores poise, elites included. If that is too strong on the Wall Commander, the burst could take 100 poise instead.
