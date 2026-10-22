# Dream: skills draft (2026-10-22)

Draft for Brent. Nothing is built. Data: `dream.json`. All names are original; everything here is **[MODEL]** unless
tagged. Dream is a named, valued affinity in the books [C: book5-mechanics-notes, ch215]; its rules are ours.

**Rule.** A Dream skill takes hold only of a mind that can see it, or of one that is asleep. "See" means:
- the source (you, or the thing you made) is inside the target's front arc;
- no wall or stone is in between;
- the target is not Blinded.

Dream also:
- ignores armour and shields;
- does +30% to the Dazed and the Asleep, and its statuses last half again as long on them;
- never touches mindless things (constructs, stone).

**Why the first-pass rule changed.** It said "needs the target to see it or to sleep"; this makes "see" exact. Sight
is the existing front-arc test (`enemy.is_in_front`) plus a clear line, so Dream is the reverse of the rear-hit rule:
it wants the enemy looking at you. Two additions:
- the mind has no armour, so a Pavise Bearer, which watches you over its shield, is Dream's best target, while Light
  and bolts stop on that shield;
- constructs are concepts with nothing to dream with [B: constructs don't want anything], so Dream does nothing to them.

**Reflux: middling (1.0).** Dream already pays for its condition: in the wrong place half its casts do nothing.

**Against the new enemies.**
- **Pavise Bearer:** it watches you, so Dream lands from the front with no shield reduction.
- **Wall Commander:** an elite, so Sleep, Terror and commands only Daze it. Read the Tell works on it in full and
  makes its charge interruptible.
- **War Drummer and calls for help:** Shutter cuts the pack off from the drum and from reinforcements.
- **Constructs:** Dream does nothing to them.

| Skill | Rune | Kind | What it does | Starter |
|---|---|---|---|---|
| Dozing Mote | Sleep | projectile | Slow mote: 45. First Dazes, second puts a Dazed target to sleep 4 s | ranged |
| Rousing Blow | Wake | targeted_strike | 2.2x; on a sleeper double damage and 80 poise | |
| Doubling Step | Conjure | dash | Step 5 m; a phantom stays 3 s and those who saw you attack it | movement |
| Shattered Dream | Dispel | detonate | Every Dream spell within 10 m breaks: 50 each (100 on sleepers), all Dazed; phantoms burst 40 | |
| Night Terror | Dread | melee_burst | 360°, 4 m: 1.6x, Terrified 2 s (flee, no attacks) | close burst |
| Quiet Hour | Soothe | ground_zone | 3.5 m hush, 7 s: Soothed (30% slower, no new attacks); a hit snaps it | |
| Changeling Mask | Mimic | new:gaze | One enemy wears your face 4 s; its friends attack it | |
| Read the Tell | Unmask | new:gaze | 8 s: every attack it starts is interruptible; a hit in its wind-up staggers it. Works on elites | |
| Errand | Whisper | new:gaze (point) | The enemy nearest a spot walks to it and stands 2 s without attacking | |
| Shutter | Shut | delayed_blast | 3.5 m: 25; for 8 s no Drummed, no Roused, no calls for help | |

**The starter loop.**
1. Mote, then mote again: the front enemy sleeps.
2. Fight the others; Night Terror scatters the ring.
3. Terrified enemies turn their backs, so your strikes on them count as rear hits. They can no longer see you, so Dream
   cannot touch them until they turn back.

## New mechanics

| Name | Kind | Rule |
|---|---|---|
| sees_caster | behaviour | A Dream hit needs the source in the target's front arc, a clear line, and the target not Blinded, unless it is Asleep. Otherwise the hit does nothing |
| mind_weight | behaviour | Dream control statuses last half as long on heavy enemies. On elites they become Dazed. Constructs and stone take nothing |
| asleep | status | 4 s, cannot act. On a target that is not Dazed it Dazes instead. Any damage wakes it, and waking leaves Wakeful |
| wakeful | status | 6 s: cannot be put Asleep (sleep Dazes instead) |
| terrified | status | 2 s: walks away from the source and starts no attacks. Its back is to you |
| soothed | status | In the zone + 1 s: 70% speed, starts no attacks. Ends when hit |
| masked | status | 4 s: allies within lure_radius that see it treat it as the player; it fights back |
| read | status | 8 s: its attacks are interruptible, and a hit during wind-up staggers it. Ends Masked. Not reduced on elites |
| commanded | status | Walks to the point and stands stand_s without attacking; ends when hit. A sleeper does it on waking |
| shut | status | 8 s: Drummed and Roused end and cannot apply. It cannot call for help or answer a call. A Shut Drummer cannot drum |
| gaze | behaviour | Instant Dream effect on one enemy (or the one nearest a point) that passes sees_caster. Only walls and stone block it |
| leave_decoy | behaviour | A phantom at the dash start. Enemies that saw the cast target it until it breaks (1 hit, Lit, or Dispel) |

## Rune effects

| Rune | Effect |
|---|---|
| Sleep | status asleep |
| Wake | bonus asleep +0.5; poise x1.2 |
| Conjure | jumps +1; cost x0.9 |
| Dispel | interrupts; bonus dazed +0.2 |
| Dread | status terrified |
| Soothe | status soothed; reflux x0.85 |
| Mimic | status masked; cost x1.15 |
| Unmask | status read |
| Whisper | pull +2; interrupts |
| Shut | status shut |

## Open
- **Constructs.** Making them immune leaves Dream with nothing in the Netherecho. Today the projection casts no skills,
  so it costs nothing yet. Brent should rule before constructs fight in passages.
- **Waking.** Any damage wakes a sleeper, including your own area skills. That tension is intended; Wakeful stops a
  sleep lock.
- **Shutter and Clean Air (Poison) split the support enemies.** Shutter blocks morale and orders (drum, roused,
  calls). Clean Air blocks the drug (Frenzied, the censer's heal).
- **Mask and Errand need AI hooks:** an enemy choosing another enemy as its target, and walking to a point it was
  given. Neither exists yet.
