# Metal skills, one per base rune: draft v0

Draft for Brent, 2026-10-22, to the brief in `BRIEF.md`. Nothing here is built. Data: `metal.json`.
Tags: **[B]** Brent's ruling, **[MODEL]** our invention. Everything not tagged is [MODEL]. All skill names are original.

Metal is new. It uses the revised rune set's ten metal runes; the first pass's Draw/Spurn (magnetism) and Ring left with that revision. Kept apart from earth (no standing stone, no Braced wind-ups; its control is about weapons and armour, not footing).

## Rule

**Metal works the metal that is already there: your weapon is its material, so its blows scale with your strike, and an enemy's armour is its target: metal hits ignore front armour and do +25% per metal class the target wears (mailed +25%, plated +50%).** [MODEL]

*Refined from the first pass* (design/14: 'worn and carried metal is its material; armoured enemies are a liability: their own gear can be pulled, rung or stripped'). The revised rune set dropped Draw/Spurn (magnetism) and Ring, so 'pulled' and 'rung' had to go; 'stripped' stays (Strip). What was missing was a number the game can read: enemies.json has front_armour but nothing that says how much metal a body wears (the Hide-Bound Brute is armoured in hide). So: a metal class per enemy kind (0 bare, 1 mailed, 2 plated), a bonus per class, and front armour ignored. That makes 'armoured enemies are a liability' true on every hit, and gives metal a room to read, as water reads walls. 'Carried' becomes the weapon: metal's blows are strikes made with your own weapon (damage_mult), while its thrown and placed skills use flat damage like everyone else's. Strip takes an enemy's class to 0, so tearing armour off helps everyone except metal: a real choice. Kept apart from earth: metal has no standing stone and no Braced wind-ups, and its control is about weapons and armour (Shackled, Dulled, Fused), not footing.

**Reflux: high.** High (x1.4), with cheap-to-mid essence. Worked metal runs hot (forging, friction, ringing), and metal is the affinity that leans hardest on its own weapon, so it is the one best placed to work reflux off with bare strikes (design/05 6.3): skill, strike, strike, skill. A high tier makes that rhythm the way metal is played.

## Skills

| Skill | Rune | Kind | What it does | Starter |
|---|---|---|---|---|
| Iron Slug *(new)* | Forge (MET-1a) | projectile | You hammer a slug out of the iron you carry and hurl it: 70 damage and 35 poise. Like every metal hit it ignores a raised shield and hits plate hardest: 105 on a plated enemy. | **ranged** |
| Rust Bloom *(new)* | Rust (MET-1b) | ground_zone | Point, 9 m: rust blooms over a circle 3.5 m across for 7 s. Anything inside that wears metal is Rusting: 6 damage a second per metal class, and its front armour is halved. Bare skin does not care. |  |
| Spot Weld *(new)* | Fuse (MET-2a) | chain | One enemy within 9 m and the nearest other within 4 m of it are welded together for 5 s: 45 damage each, neither can move more than 4 m from the other, and both are 40% slower. A lone one is welded to the floor instead. Each metal class adds 1 s. |  |
| Splitting Blow *(new)* | Sunder (MET-2b) | melee_burst | A cleaving blow across 120 degrees: 1.8x strike damage and 50 poise. Every armoured enemy it hits has its metal split open, and the pieces fly on behind it: 30 per metal class to everyone within 2.5 m. | **close burst** |
| Iron Clasp *(new)* | Seal (MET-3a) | new:smite | One enemy within 9 m: a band of iron snaps shut round its arms. 25 damage, interrupted, and Shackled for 2.5 s: it can still walk, but cannot attack. Each metal class it wears adds 1 s. |  |
| Breakthrough *(new)* | Breach (MET-3b) | dash | Drive forward 5 m, point first. A bare enemy in the way stops you and is knocked back 1.5 m. One that wears metal is punched through: 40 damage, you carry on past it, and it is Stripped for 4 s. | **movement** |
| Whetted Cut *(new)* | Hone (MET-4a) | charge_release | Hold to draw your weapon's edge keen, up to 1.5 s, walking at 45%. Let go for one cut across 60 degrees and 3.3 m: 1.6x strike damage at a tap, up to 3.2x at a full hold. |  |
| Turn the Edge *(new)* | Dull (MET-4b) | melee_burst | A ringing sweep that blunts every edge near you: everything within 3.5 m takes 1.6x strike damage and 40 poise, and is Dulled for 6 s: its blows do 35% less and cannot stagger you. |  |
| Plating *(new)* | Plate (MET-5a) | self_buff | For 8 s the metal you wear thickens: every blow on you does 25% less, and a blade that lands on you is Dulled for 3 s. You move 10% slower. |  |
| Wrench *(new)* | Strip (MET-5b) | targeted_strike | One enemy in reach: you get a grip on its armour and wrench it off. 1.6x strike damage, interrupted, and Stripped for 8 s: no front armour, and it takes 20% more from everything. It no longer counts as armoured, so metal loses its own bonus on it. |  |

## Rune effects (as a modifier)

| Rune | Meaning | Effect |
|---|---|---|
| Forge | shape and harden metal | `power x1.2; windup x1.1` |
| Rust | corrode it | `status rusting` |
| Fuse | join metal into one piece | `status fused` |
| Sunder | split it apart | `poise x1.3; reach x1.1` |
| Seal | close and lock with metal | `status shackled` |
| Breach | break a seal; punch through plate | `pierce +1; poise x1.25` |
| Hone | sharpen | `power x1.2; poise x0.85` |
| Dull | blunt edges, theirs included | `status dulled; poise x1.2` |
| Plate | armour up | `braced; duration x1.25` |
| Strip | tear armour off | `status stripped` |

Each effect also names what the skills built on that rune do, so when another rune out-pulls the anchor, the right part of the skill shrinks (the `signature`).

## New mechanics

- **metal class** (field, from Iron Slug): enemies.json key 'metal': 0 bare, 1 mailed, 2 plated. Every hit tagged metal does +25% per class and ignores front_armour and blocks_shots.
- **rusting** (status, from Rust Bloom): 1 stack, 5 s, refreshed: 6 damage a second per metal class (none on bare enemies), dealt through whoever applied it; front_armour halved while it lasts.
- **fused** (status, from Spot Weld): 1 stack, the skill's duration: tethered to its partner (the other body the same cast fused): neither can move more than 4 m from the other, both 40% slower. With no partner, welded to the floor: Pinned for the duration.
- **spall** (behaviour, from Splitting Blow): 'spall': each enemy hit that wears metal throws pieces in a 60-degree fan away from you: spall.damage_per_class x its metal class to every other enemy within spall.radius of it. Bare enemies throw nothing.
- **shackled** (status, from Iron Clasp): 1 stack, the skill's duration: cannot start an attack (a wind-up in progress is interrupted); can still move, turn and keep its slot.
- **pass armoured** (behaviour, from Breakthrough): A dash with 'pass_armoured' passes through enemies of metal class 1+ (applying on_pass) and stops at bare ones (applying on_stop).
- **stripped** (status, from Breakthrough): 1 stack, the skill's duration (default 8 s): no front armour, takes 20% more from everything, and counts as metal class 0, so metal's own bonus is lost on it.
- **dulled** (status, from Turn the Edge): 1 stack, 6 s: its blows do 35% less damage and remove no poise from the player (they cannot stagger you).
- **smite** (behaviour): used by Iron Clasp; defined once in `lightning.json` (Plumb Bolt).

## Modifiers, checked

Every good and bad modifier was run through a copy of `effects_v1.gd`'s rules (one rune bonded straight to the skill's own rune; bond kind from electronegativity; universal runes at their placeholder 2.5). Every good one applies all its ops. Every bad one either falls back to the quarter-power consolation, is cancelled by an ionic bond, or out-pulls the skill's own rune; where the maths would accept a bad one, its entry says why it still makes no sense.

## Notes and open questions

- **Metal needs a new enemy key**, `metal` (0 bare, 1 mailed, 2 plated). Proposed: grunt 1, brute 0 (hide-bound), commander 2, archer 0, harrier 0, pavise 2, censer 1, drummer 0. The Hide-Bound Brute being bare is deliberate: the big enemy is metal's bad match.
- **Strip turns metal's own rule off** on that enemy (class 0). Breakthrough strips for 4 s, Wrench for 8. This is the main choice a metal player makes.
- **Weapon scaling.** Metal's blows (Splitting Blow, Whetted Cut, Turn the Edge, Wrench) use `damage_mult` like other strikes; its thrown and placed skills use flat damage. The rule's 'your weapon is its material' is that split.
- **Turn the Edge and Plating sit near earth's Tremor and Stonehide.** The differences: Turn the Edge Dulls (they hit softer) where Tremor slows and interrupts; Plating takes 25% off and Dulls attackers where Stonehide Braces you (40% off, no stagger, 25% slower).
- **The metal rule ignoring front armour** overlaps Plumb Bolt (from above) and Silhouette (every hit counts as from behind). Three affinities now answer the Pavise Bearer in different ways, which design/05 wanted.
