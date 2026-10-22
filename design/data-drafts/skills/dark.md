# Dark skills, one per base rune: draft v0

Draft for Brent, 2026-10-22, to the brief in `BRIEF.md`. Nothing here is built. Data: `dark.json`.
Tags: **[B]** Brent's ruling, **[MODEL]** our invention. Everything not tagged is [MODEL]. All skill names are original.

Dark is new, added by Brent [B 2026-10-21]. It uses the revised rune set's ten dark runes. Kept apart from light (dark never travels as a beam and never lights anything) and from the area control of water and wind (dark zones change who can see, not where bodies are).

## Rule

**Dark is strongest where the light is weakest: every spot is Lit, Dim or Dark; dark hits do +25% to a target standing in Dark and -20% in Lit, you are Unseen while you stand in Dark, and dark skills make their own Dark.** [MODEL]

*Refined from the first pass* (design/14: 'strongest where the light is weakest; shadows are places it can use: it hides in them, moves through them and feeds on light'). Kept, and turned into something the game can count, in the shape of water's wetness: three light levels instead of a sliding scale. 'Strongest' is +25% on targets in Dark; 'hides in them' is Unseen; 'moves through them' is Shadow Slip, which can only land in a shadow; 'feeds on light' is Hungry Dark. The missing piece in the first pass was where darkness comes from in a lit room: dark skills leave Dark ground, and every body throws a shadow behind it. This keeps dark apart from light (dark never travels as a beam and never lights anything: Silhouette outlines a target against the dark, Daybreak gives up your own dark to do it) and from wind and water's area control (dark zones change who can see, not where bodies are).

**Reflux: middling.** Middling (x1.0). Dark's swing comes from where the fight is (Lit, Dim or Dark), not from heat, so its reflux stays neutral like water's, the reference affinity. A per-affinity shed rule could come later (sheds faster while you stand in Dark: resting in the shadows), but it is not needed for the rule to read.

## Skills

| Skill | Rune | Kind | What it does | Starter |
|---|---|---|---|---|
| Blot *(new)* | Darken (DRK-1a) | projectile | A blot of darkness, thrown: 60 damage, and where it lands the ground goes Dark in a circle 2.5 m across for 6 s. Hit them again while they stand in it. | **ranged** |
| Daybreak *(new)* | Lighten (DRK-1b) | detonate | Every pool of your darkness within 12 m lifts at once. Each enemy standing in one is caught in the sudden light: Dazed for 1.5 s and Exposed for 4 s. You lose the dark you made. |  |
| Pall *(new)* | Obscure (DRK-2a) | ground_zone | Point, 10 m: a pall of darkness 3.5 m across for 7 s. Nothing sees into it or through it: an aim from outside cannot pick out anything inside, and enemies inside are Blinded. It counts as Dark. |  |
| Silhouette *(new)* | Expose (DRK-2b) | new:smite | One enemy within 12 m is outlined against the dark for 6 s: every hit on it counts as from behind (+30%, and a raised shield does not help). If it stands in Dark it is Blinded as well. |  |
| Shadow Slip *(new)* | Shadowstep (DRK-3a) | blink | Sink into the dark and rise from another shadow up to 10 m away: a Dark spot, or the shadow behind an enemy, which puts you at its back. Your first hit within 1 s counts as from behind. It cannot take you into the light. | **movement** |
| Shadownail *(new)* | Pin (DRK-3b) | delayed_blast | Point, 9 m: a black nail is driven into the shadows in a circle 1.5 m across. Whatever stands there after a quarter second takes 50 and is Shadowbound for 2.5 s (4 s in Dark): rooted where it stands, though it can still turn and swing. |  |
| Muffle *(new)* | Hush (DRK-4a) | self_buff | For 6 s you make no sound. Striking no longer reveals you while you are Unseen, an enemy you hit that was not facing you takes +50%, and anything you kill raises no alarm. |  |
| Knell *(new)* | Resound (DRK-4b) | ground_zone | Point, 10 m: a tolling note rings over a circle 3 m across, three tolls 0.6 s apart, each 35 damage and 20 poise. In Dark the echo answers: two more tolls. |  |
| Hungry Dark *(new)* | Devour (DRK-5a) | melee_burst | The dark around you feeds. Everything within 3 m takes 1.6x strike damage; for each one hit you take back 2 essence (up to 4 hits) and swallow 1 light (up to 5). The ground under you goes Dark for 5 s, and any fire it touches goes out. | **close burst** |
| Night Spill *(new)* | Disgorge (DRK-5b) | melee_burst | Let out what the dark swallowed: a cone 6 m long. 30 damage, plus 30 for every light swallowed, to everything in it, and the ground it covers goes Dark for 5 s. At 3 or more they are Dazed. |  |

## Rune effects (as a modifier)

| Rune | Meaning | Effect |
|---|---|---|
| Darken | make it darker | `power x1.15; duration x1.2` |
| Lighten | let the light back in | `status dazed; windup x0.85` |
| Obscure | hide a thing in darkness | `status blinded; duration x1.2` |
| Expose | make a hidden target stand out | `status exposed` |
| Shadowstep | move through shadows | `reach x1.35; windup x0.9` |
| Pin | nail a target's shadow, and the target with it | `status shadowbound` |
| Hush | smother sound | `windup x0.8; duration x1.2` |
| Resound | sound carries and echoes in the dark | `reach x1.2; poise x1.2` |
| Devour | swallow light and energy | `cost x0.85; reflux x0.85` |
| Disgorge | release what was swallowed | `power x1.25; reflux x1.15` |

Each effect also names what the skills built on that rune do, so when another rune out-pulls the anchor, the right part of the skill shrinks (the `signature`).

## New mechanics

- **light level** (field, from Blot): Every spot is Lit, Dim or Dark. A level has a base (open day Lit; dungeons, swamps and night Dim); fires, Alight bodies, torches and light skills make Lit circles; dark ground makes Dark; the 1.5 m behind every enemy and stone, away from the main light, is Dark (its shadow). Dark hits do +25% to a target in Dark, -20% in Lit.
- **dark ground** (field, from Blot): A zone with 'dark': true counts as Dark whatever the light, for its life; a Lit source inside it (fire, a light skill) wins where they overlap.
- **unseen** (status, from Blot): On the player while standing in Dark: enemies more than 4 m away lose sight of you (ranged ones cannot start an aim; melee ones without a slot go to where they last saw you). Striking or casting reveals you for 1 s.
- **lift dark** (behaviour, from Daybreak): detonate with 'consume_zone': every zone of that kind the caster owns within range ends at once, and on_hit is applied to every enemy standing in one.
- **blinded** (status, from Pall): 1 stack, 3 s (refreshed while in the zone that gives it): cannot see past 2 m. A ranged enemy cannot aim; a melee enemy swings at where it last saw you and gives up its slot.
- **blocks sight** (field, from Pall): A zone with 'blocks_sight': enemy aims and lines of sight that start outside it cannot pass into or through it.
- **exposed** (status, from Silhouette): 1 stack, the skill's duration (default 6 s): every hit on it counts as a rear hit (balance.combat rear_mult, frontal block ignored), and it cannot be hidden or Unseen.
- **shadow landing** (behaviour, from Shadow Slip): blink with 'needs_shadow': the point must be Dark (light level), or an enemy, in which case you arrive in its shadow, 1 m behind it and facing its back; a Lit point is refused before essence is spent. 'rear_window': your hits in that time count as rear hits.
- **shadowbound** (status, from Shadownail): 1 stack, 2.5 s: cannot move from the spot (can turn and attack); shoves and pulls do not move it. Standing in Lit halves what is left.
- **muffled** (behaviour, from Muffle): self_buff: hits do not break Unseen; a hit on an enemy whose front arc you are outside does unaware_mult; a kill sends no reinforcements signal and wakes no one nearby.
- **dark echo** (field, from Knell): A zone with 'dark_extra_ticks' runs that many more ticks if its centre is Dark when it would end.
- **swallowed** (status, from Hungry Dark): On the player: a store of up to 5 swallowed light, 12 s from the last gain. Hungry Dark adds swallow_per_hit per enemy hit, +1 for each fire it puts out; Night Spill spends all of it.
- **douse** (behaviour, from Hungry Dark): 'douses': fire zones in the area end, and Alight is removed from every enemy hit.
- **spend store** (behaviour, from Night Spill): A skill with 'consume' spends all of that player store: per_stack_damage for each, and 'daze_at' or more also Dazes.
- **smite** (behaviour): used by Silhouette; defined once in `lightning.json` (Plumb Bolt).

## Modifiers, checked

Every good and bad modifier was run through a copy of `effects_v1.gd`'s rules (one rune bonded straight to the skill's own rune; bond kind from electronegativity; universal runes at their placeholder 2.5). Every good one applies all its ops. Every bad one either falls back to the quarter-power consolation, is cancelled by an ionic bond, or out-pulls the skill's own rune; where the maths would accept a bad one, its entry says why it still makes no sense.

## Notes and open questions

- **The light level is the biggest new system in these drafts.** It needs Lit, Dim and Dark per spot, read from a level base, light sources, dark zones and shadows behind bodies. It is designed to be circles and offsets, not ray-traced light. If it proves too costly, the fallback is to count only dark ground and enemy shadows (no Lit), which keeps every skill working.
- **The starter loop**: Blot a group (the spot goes Dark), Hungry Dark there (+25%, essence back, and you are Unseen in the dark it leaves), Shadow Slip behind the archer. 20 essence for the first two.
- **Dark has two self-centred bursts** (Hungry Dark, Night Spill) that form one pair: the first fills the swallowed store, the second empties it.
- **Unseen and Blinded overlap ice's Whiteout and wind's Crosswind Veil** in what they answer (archers). Whiteout blinds and chills; Veil bends shots; Pall blocks sight lines and makes Dark.
- **Dark's sound runes** (Hush, Resound) are kept as the revised set has them. Lightning's Silence also cuts calls. The split: Silence (Dead Line) jams *their* casts and calls; Hush (Muffle) quiets *you*.
