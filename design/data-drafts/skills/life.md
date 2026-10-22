# Life: skills on base runes (draft, 2026-10-22)

Data: `life.json`. Nothing is built. Tags: **[B]** Brent's ruling, **[C]** books (paraphrased notes),
**[MODEL]** ours. All names are original.

## Rule

**Life works inside living bodies.** Its harm passes armour and shields. It hits the **hale** (above half health)
25% harder and does nothing to the unliving. Its healing fills the bar fast but closes wounds slowly.
[C: life practitioners work inside a body; MODEL: the rest]

Refined from design/14, which gave Life only a weakness ("nothing on stone, constructs or the dead"). Two hooks
are added that you feel on the first cast:
- It goes past armour, because it is already inside.
- It is strongest on the healthy. That makes Life the opener and Death (which preys on the dying) its mirror.

**Reflux: middling (1.0).** Body work is ordinary, careful work, and a healer must keep casting through a fight.

## Healing and wounds [B: one bar plus wounds with hidden sinks]

- **Knit** (Heal) fills the bar first, never past the ceiling the wounds have cut. Once the bar is full, the rest
  goes into the oldest wound's sink at a quarter rate (4 heal points make 1 sink point). Life can always top you
  up, but in a fight it barely touches a wound.
- **Regrowth** (Regrow) is the wound skill. You stand still and it pours 1.5 points a second into the oldest
  sink, then the next. A lost arm mends at half rate, which rest never does. Any blow breaks it. A 15-point
  wound costs about 40 essence, so it competes with the healer and the inn rather than replacing them.
- No other Life skill heals. A filled sink closes its wound and gives its share of the bar back empty, as now.
  Talent healing (`_spend_heal_points`) is unchanged and separate.

## Skills

| Skill | Rune | Kind | What it does | Starter |
|---|---|---|---|---|
| Knit | Heal | self buff | 6 s of 5 health a second; the bar first, then wounds at a quarter rate | |
| Withering Needle | Wither | projectile | 45 and 1 Withering (7/s, up to 3), past armour | **ranged** |
| Fresh Stride | Renew | dash | 5.2 m; never Winds you and clears Winded; 15% faster for 3 s | **movement** |
| Wearying Sweep | Exhaust | melee burst | 1.7x all round, 3 m; Spent 4 s (25% slower, attacks 30% slower) | **close burst** |
| Corded Muscle | Strengthen | self buff | 7 s: bare strikes +40% damage and +50% poise damage; you lose half the poise | |
| Wasting Grip | Weaken | targeted strike | 2.0x; Wasted 6 s (deals 30% less, poise cut to 60%) | |
| Fever Break | Cure | self buff | Ends every harmful thing on you; 5 s of halved new ones | |
| Turn the Stomach | Sicken | hex | Sick 8 s: retches every 2.5 s, losing its action | |
| Regrowth | Regrow | channel | Standing still: 1.5 sink a second into wounds, a lost arm included | |
| Unmending | Arrest | delayed blast | 3 m: 30 and Arrested 8 s (no healing, no poise back, Life statuses frozen) | |

## Rune effects (added to a skill)

| Rune | Effect |
|---|---|
| Heal | reflux x0.75; duration x1.1 |
| Wither | status withering; power x1.1 |
| Renew | speed x1.15; cost x0.9 |
| Exhaust | status spent |
| Strengthen | power x1.2; poise x1.25 |
| Weaken | status wasted |
| Cure | cost x0.85; reflux x0.9 |
| Sicken | status sick |
| Regrow | duration x1.4 |
| Arrest | status arrested |

Heal, Cure and Regrow have no op for "heals" in the effect syntax. They read as "eases the strain of casting"
and "lasts", which is the nearest honest thing.

## New mechanics [MODEL]

- **Hale** (derived status): a living target above half its health; Life harm does x1.25.
- **Living** (enemy key): false for constructs, spirits, stone and the animated. Life does nothing to them.
- **Inside**: Life harm ignores armour, front armour and front_block.
- **Withering**: up to 3 stacks, 6 s, 7 a second each, past armour.
- **Spent**: 4 s, moves at 75%, attacks at 70% rate.
- **Wasted**: 6 s, deals 70%, maximum poise 60%.
- **Sick**: retches every 2.5 s (the action is cancelled, it stands 0.5 s). It does not spread; spreading is
  Disease's.
- **Arrested**: no healing, no poise refill, and Withering, Spent, Wasted and Sick on it stop counting down.
- Life healing order (above), `clears_winded`, and the Corded Muscle and Fever Break buffs.

## Unsure

- The stat groups have no field for healing or buff strength (`heal_per_s`, `strike_mult`, `sink_per_s`), so a
  power rune on Knit, Corded Muscle or Regrowth falls back to a cost cut. I suggest adding those fields to the
  power group in the workbook.
- The lost-arm rule. `balance.night.arm_restored` suggests the arm has its own regrowth track; I wrote "half
  rate into the lost-arm wound", and the code may need it said differently.
- Fever Break mostly guards against statuses that do not exist on the player yet (poison, disease). Today it
  clears stagger and Winded.
