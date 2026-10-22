# Death: skills on base runes (draft, 2026-10-22)

Data: `death.json`. Nothing is built. Tags: **[B]** Brent's ruling, **[C]** books (paraphrased notes),
**[F]** fan source, **[MODEL]** ours. All names are original.

## Rule

**What has died stays useful.** For a Death fighter every enemy corpse lies 20 s, and Death skills spend corpses.
A living target below half health is **Dying** and takes 30% more from Death. [F: death archs and undeath;
MODEL: the numbers]

Refined from design/14, which named the two halves but not how long a corpse lasts (today 8 s,
`balance.combat.corpse_lie_s`), how a skill finds one, or what "prey" does. A skill that needs a corpse snaps to
the nearest one and is refused, with nothing spent, if there is none. Dying is the mirror of Life's hale.

**Reflux: high (1.4).** Working an ending is heavy on the channels. Lay to Rest turns corpses into essence and
sheds reflux, the way Backdraft is fire's way down.

## Skills

| Skill | Rune | Kind | What it does | Starter |
|---|---|---|---|---|
| Endstroke | Kill | targeted strike | 2.0x (+30% on the Dying); a non-elite left under 15% dies | **close burst** |
| Last Mercy | Spare | hex | Spared 4 s: cannot go below 1; if Dying, it kneels helpless | |
| Rise Again | Animate | summon | A corpse fights for you 15 s (120 health, 15 a blow); two at a time | |
| Lay to Rest | Lay | field pulse | Up to 4 corpses within 6 m are buried: +5 essence, -8 reflux each; enemies beside them are dragged down | |
| Rotting Bolt | Rot | projectile | 50 and Rotting (armour and shield at half, no poise back); a corpse it hits bursts for 60 | **ranged** |
| Embalm | Preserve | self buff | 5 s: you cannot drop below 1 health; wounds still open; no healing | |
| Lingering Shade | Haunt | ground zone | On a corpse: 3 m, 8 s, 15/s and Dread (they back out and will not enter); the corpse stays | |
| Banishing Line | Exorcise | beam | 10 m through everything: 55, interrupts; triple on constructs, spirits, the animated | |
| Gravestep | Vanish | blink | 6 m, or 12 m onto a corpse; anyone aiming at you loses the aim | **movement** |
| Death Mask | Manifest | prop | A likeness of you draws every enemy within 6 m for 5 s, then falls apart for 40 | |

The corpse is a choice: raise it, burst it, bury it for essence, step onto it, or haunt it (which does not use
it up).

## Rune effects (added to a skill)

| Rune | Effect |
|---|---|
| Kill | bonus dying +0.4 |
| Spare | status spared; power x0.85 |
| Animate | duration x1.3; speed x1.15 |
| Lay | poise x1.3; interrupts |
| Rot | status rotting |
| Preserve | duration x1.4; reflux x0.9 |
| Haunt | status dread; duration x1.15 |
| Exorcise | interrupts; power x1.1 |
| Vanish | reach x1.2; windup x0.85 |
| Manifest | power x1.1; poise x1.2 |

## New mechanics [MODEL]

- **Dying** (derived status): a living target under half health; Death does x1.3.
- **Corpse** (field): lies 20 s for a Death fighter; spent once by the skills that use it.
- **Spared**: health cannot fall below 1 (so no death-burst); a Dying target kneels and cannot act.
- **Rotting**: armour, front armour and front_block at half; poise does not refill.
- **Dread**: backs out of the haunted circle, will not path into it, and a ranged enemy inside loses its aim.
- **Summon** (new kind): a corpse becomes a thrall for a time. A thrall is not living, and its kills are yours.
- **Field pulse** (new kind, shared with nature): acts on the caster's own field pieces (here corpses) in a
  radius.
- `execute_below`, `hits_corpses` and `corpse_burst` on a projectile, `breaks_aim`, `unliving_mult`, the decoy
  prop, and the Embalm buff.

## Unsure

- Embalm is a "cannot die for 5 s" skill. It respects "no skill hurts its caster" (nothing happens when it ends)
  and the wound model (blows still open wounds), but it is strong. It is dear (18) for that reason; Brent may
  want it rarer still.
- Last Mercy has no damage, so it shows the Censer-Bearer answer best. Holding a target at the edge for capture
  has no use until there is a capture system.
- Thralls are the first player allies in the game. They need slots in the ring, a target rule and a model look
  (`set_dead_look` on the enemy's own rig).
