# Blood v2: the berserker (draft, 2026-10-24)

Data: `blood.json`, `blood-runes.json`. Nothing is built. Tags: **[B]** Brent, **[MODEL]** ours. All names original.

**Role** [B: framework.md]: berserker with conjured blood weapons, fuelled by bleeding enemies and held blood.
**Never pays in the caster's own health** [B 2026-10-21]. **Parents: Life + Death.**

## How each parent shows

- **Life: the living body and its blood.** Only the living bleed; the heart (Pulse, Still), breath (Choke, Breathe)
  and vigour (Thinblood Rush) are the body's; a living foe's blood is drawn out (Deep Draught, Thirsting Glaive).
- **Death: what dies stays useful.** Kills feed you (Red Frenzy +2 blood a kill, Last Draught takes a body's blood
  whole); the finisher executes the Dying (Death's Kill); the pools a death leaves are fuel and road.
- Blood is what Life loses and Death leaves: so it never heals (Life's work) and never needs a corpse (Death's).

## Rule

Blood works blood that is already out: hits open Bleeding, bleeders spill pools, and you hold what you drink (up to
10). **Bloodrush**: every measure held makes your blows 2% harder [MODEL]. Blood skills spend Bleeding, pools or held
blood - never your health. Blood never heals. Reflux low (0.7), unchanged.

The berserker's choice is **hold or spend**: held blood is Bloodrush; spending it buys longer blood weapons, Outpour,
the frenzy's upkeep. Thirsting Glaive pulls the other way (it swings faster the emptier you are).

## Skills (12 on 12 runes; 10 serve the role; 1 dropped)

| Skill | Rune | Kind | What it does | Starter | Status |
|---|---|---|---|---|---|
| Red Lancet | Bleed | projectile | 50 + 2 Bleeding | **ranged** | existing |
| Tourniquet | Staunch | self buff | 6 s: no wounds open; each costs 2 blood, pools within 3 m first | | changed |
| Deep Draught | Drink | field pulse | Instant: 1 stack from each bleeder in 6 m and every pool in 4 m -> held blood | | changed |
| Outpour | Spill | melee burst | All held blood out in a 6 m cone: 30 + 18 a measure | | existing |
| Clotblade | Clot | melee burst + weapon | 1.8x sweep spending Bleeding; then clotblades 8 s (+1 s per blood): strikes 1.5x, each opens a Bleed | **close** | changed |
| Thinblood Rush | Thin | dash | 4.8 m through bodies, cutting each (15 + Bleed); pools carry you further | **movement** | changed |
| Red Frenzy | Pulse | self buff | 8 s: strikes and steps 25% faster, +20%, no light staggers, +2 blood a kill; burns 1 blood / 2 s after 3 s | | new |
| Heavy Heart | Still | ground zone | 3 m, 6 s: Sluggish and 8/s; stills pools | | changed |
| Gullet Knot | Choke | smite | 30, interrupt, Choked (2.5 s if Bleeding) | | existing |
| Long Breath | Breathe | self buff | Breathe out 4 blood (pools first) for reflux; 6 s doubled poise | | changed |
| Thirsting Glaive | Thirst | self buff + weapon | 10 s glaive: 3.6 m strikes at 1.3x, each draws a stack into held blood | | new |
| Last Draught | Sate | targeted strike | 2.2x + 20 a stack, +30% on the Dying; executes a bleeder under 15%; a kill gives its blood | | new |
| ~~Hammering Heart~~ | Pulse | detonate | Dropped: Pulse is now the caster's own heart; paying out Bleeding belongs in reach | | dropped |

Role: Red Lancet, Tourniquet, Deep Draught, Outpour, Clotblade, Thinblood Rush, Red Frenzy, Long Breath, Thirsting
Glaive, Last Draught. Utility: Heavy Heart, Gullet Knot.

The loop: open (Red Lancet, Thinblood Rush) -> conjure (Clotblade or Thirsting Glaive) -> fill (strikes, Deep
Draught, kills) -> frenzy -> finish (Last Draught) or dump (Outpour).

## Rune changes

- **Pulse** re-meant: the caster's own heart (frenzy), not the enemy's. Role and draw kept.
- **New pair Thirst / Sate**: Thirst (link, draw -0.4, EN 2.1), the hunger that reaches for blood; Sate (cap,
  draw +0.9, EN 3.85), drinking a body to the dregs. Now 12 runes.
- All others kept.

## New mechanics [MODEL]

- **Bloodrush** (rule): +2% damage per held blood.
- **conjure_weapon**: a blood weapon replaces the main hand's strikes for a time (melee_* overrides, on_strike
  payload, extend_per_blood); one at a time; only Blood conjures.
- **empty_rate_bonus** on a conjured weapon; **upkeep_blood_per_s** on a buff (ends when dry, never health).
- **Red Frenzy** buff; **pool_radius** (pools pay before held blood); **execute_needs**, **kill_blood**,
  **dying_mult** on a strike.
- Deep Draught uses death.json's **field_pulse** on pools and bleeders.

## Unsure

- Bloodrush plus Red Frenzy plus a blood weapon stack to about x1.2 x1.2 x1.5 on a strike; that may be too much at
  10 held blood. Feel and numbers untested, needs Brent.
- Conjured weapons replace the worn main hand; whether a worn weapon's own stats (and talents) should still apply
  under a blood weapon is open.
- Two conjured weapons (Clotblade, Thirsting Glaive) cannot be held at once; switching replaces.
