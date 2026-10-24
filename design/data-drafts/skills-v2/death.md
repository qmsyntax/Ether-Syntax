# Death v2: the necromancer (draft, 2026-10-24)

Data: `death.json`, `death-runes.json`. Brief: `ROLES-BRIEF.md`. Nothing is built. All [MODEL] unless marked; the
role is Brent's framework [B 2026-10-24]. All names are original.

**Role:** necromancer: corpses, thralls and the dying. Death alone raises the dead.

**Rule:** What has died stays useful: every enemy corpse lies 20 s for you and Death skills spend it, up to three of your dead fight for you as thralls, and a living target below half health is Dying and takes 30% more from Death.

**Reflux:** high (1.4), unchanged. Lay to Rest and Bone Burst are its ways down: corpses and thralls are spent for
essence or for damage.

## What changed from the 2026-10-22 draft

The old Death was a corpse caster with one summon. Now the dead are the kit: three thralls at once (one cap for the
affinity), a way to aim them (Grave Mark), a way to keep them up (Embalm, moved off the caster), a way to spend them
(Bone Burst), a way to move through them (Gravestep swaps with one), and a way to get one without waiting for a
corpse (Last Mercy captures a kneeling enemy). Rotting Bolt, Endstroke and Gravestep stay the starters.

## Skills

| Skill | Rune | Kind | What it does | Starter | Status |
|---|---|---|---|---|---|
| Endstroke | Kill | strike | One enemy in reach: 2.0x strike damage, 30% more if it is Dying (below half). Anything short of an elite left under 15% of its health dies outright. | **close** | existing |
| Last Mercy | Spare | smite | One enemy within 10 m is Spared for 4 s: nothing can take it below 1 health. If it is below half, it kneels and does nothing, and while it kneels your Death skills can take it as a corpse: Rise Again raises it on the spot. |  | changed |
| Rise Again | Animate | summon | Point at a corpse within 10 m: it gets up and fights for you for 20 s, with 120 health, hitting the nearest enemy for 15 a blow. Up to three of your dead walk at once. Without a corpse nothing happens and nothing is spent. |  | changed |
| Lay to Rest | Lay | field pulse | Every corpse within 6 m of you (up to 4) goes into the ground for good. Each gives you back 5 essence and takes 8 off your death reflux, and the ground drags down the enemies standing next to it: 40 poise damage and interrupted. |  | existing |
| Rotting Bolt | Rot | bolt | A clot of decay thrown along your aim: 50 and Rotting for 6 s (its armour and shield count for half, and lost poise does not come back). If it hits a corpse instead, the corpse bursts: 60 and Rotting to everything within 2.5 m. | **ranged** | existing |
| Embalm | Preserve | buff | For 8 s your thralls within 12 m are embalmed: they take 40% less damage and their time stops running down. Corpses near you stop decaying while it lasts. |  | changed |
| Lingering Shade | Haunt | zone | Point at a corpse within 10 m, or where something died in the last 10 s: its shade lingers there for 8 s in a 3 m circle. Enemies inside take 15 a second and are Dreading: they back out and will not walk in. The corpse is left for other uses. |  | existing |
| Banishing Line | Exorcise | beam | An instant line 10 m long through everything: 55, 20 poise damage, and interrupts. Constructs, spirits and anything animated take triple. |  | existing |
| Gravestep | Vanish | blink | You pass out of sight and step out up to 6 m away, 12 m onto a corpse, or 14 m onto one of your thralls: you trade places with it, and it arrives with 40 health back. Every enemy that was aiming at you loses its aim. | **movement** | changed |
| Death Mask | Manifest | placed | Point, 8 m: a likeness of you takes form out of grave-dust. For 5 s every enemy within 6 m turns on it instead of you. Raised on a corpse it is made of the body: it stands 8 s with twice the health, and the corpse is spent. When it breaks or its time runs out, it falls apart: 40 and Rotting to everything within 3 m. |  | changed |
| Grave Mark | Bid | smite | One enemy within 12 m is marked for the grave for 6 s: every thrall of yours goes for it at once, hitting 50% harder and 30% faster, and it is Rotting while the mark lasts. |  | new |
| Bone Burst | Unbind | detonate | Let your dead go. Every thrall of yours within 12 m comes apart at once: 70, plus a quarter of the health it had left, to everything within 2.5 m of it, and Rotting. Nothing is left of them. |  | new |

The loop: Endstroke and Rotting Bolt make and burst corpses; Rise Again (or Last Mercy and then Rise Again) gets
three dead up; Grave Mark sends them at the archer; Embalm keeps them standing; when they are about to fall, Bone
Burst. Lay to Rest buries the leftovers for essence and reflux.

## Runes (12)

| Rune | Meaning | Opposite | Role | Draw | Effect | Change | Why |
|---|---|---|---|---|---|---|---|
| Kill | finish the dying | Spare | cap | +1.00 | `bonus dying +0.4` | kept | Serves the role as it is. |
| Spare | hold a life at the edge, for capture or mercy | Kill | link | -0.50 | `status spared; power x0.85` | kept | Kept; its skill now reads 'capture' as claiming the body: a kneeling Spared enemy can be raised without waiting for a corpse. |
| Animate | the dead get up | Lay | frame | -0.40 | `duration x1.3; speed x1.15` | kept | The core necromancer verb. Kept; Rise Again now walks three dead at once. |
| Lay | put them down for good | Animate | cap | +0.60 | `poise x1.3; interrupts` | kept | Serves the role as it is. |
| Rot | decay | Preserve | branch | -0.40 | `status rotting` | kept | Serves the role as it is. |
| Preserve | stop decay: in the dead you keep, and in your own body | Rot | frame | +0.40 | `duration x1.4; reflux x0.9` | re-meant | Its skill moved from the caster ('cannot die for 5 s', which was too strong and served no role) to the thralls: a necromancer preserves its dead. Role and draw kept; the effect still reads as 'lasts longer'. |
| Haunt | what dies lingers as a spirit | Exorcise | link | +0.30 | `status dread; duration x1.15` | kept | Serves the role as it is. |
| Exorcise | banish spirits and constructs | Haunt | cap | -0.70 | `interrupts; power x1.1` | kept | Kept as the utility pair: Death's answer to constructs and casters. |
| Vanish | pass out of sight and reach | Manifest | link | +0.40 | `reach x1.2; windup x0.85` | kept | Kept; its skill now also swaps with a thrall. |
| Manifest | appear; take form | Vanish | branch | -0.50 | `power x1.1; poise x1.2` | kept | Kept; the likeness can now be made from a corpse. |
| Bid | the dead do your bidding: send them, and they go | Unbind | link | +0.60 | `status bidden` | new | A necromancer needs a way to aim its dead. A Link (it takes the word in and passes it on to the thralls); draw +0.6 because it holds the dead to your will. |
| Unbind | let your dead go, and what held them goes outward | Bid | branch | -0.70 | `reach x1.2; power x1.15; duration x0.8` | new | The sacrifice that every necromancer kit has: the thralls as a resource to spend. A Branch (one release spreads into a burst round every body), draw -0.7 because it releases outward; opposite Bid's hold, so the pair bonds ionically. |

No rune renamed or dropped. Two new: **Bid** and **Unbind**. Preserve is re-meant (its skill now acts on your dead).

## New mechanics

- **dying** (status, Endstroke): Derived, never applied: a living target below half its health. Death hits on it do x1.3 (affinity key dying_mult). Shown as a faint mark over its head while a Death fighter is in the fight.
- **execute_below** (behaviour, Endstroke): A strike key: after the hit, a non-elite target whose health is below that fraction of its maximum dies at once (the kill is yours, with every on-kill rule).
- **corpse** (field, Endstroke): An enemy's body where it fell. For a character holding Death it lies 20 s instead of balance.combat.corpse_lie_s. Death skills that need one target a corpse within their range (the cursor snaps to the nearest corpse) and are refused, with nothing spent, if there is none. A corpse can be spent once; Lingering Shade does not spend it.
- **hex** (behaviour, Last Mercy): Defined in blood.json (gullet_knot): a target within range takes on_hit at once, no travel, needs line of sight.
- **spared** (status, Last Mercy): 1 stack, lasts the skill's duration: the target's health cannot fall below 1 (no death, so no death-burst). If it is Dying it kneels: it cannot move or act. When Spared ends, the next blow can kill it as normal.
- **captures** (behaviour, Last Mercy): A Spared enemy that is kneeling (below kneels_below, not an elite) counts as a corpse for every Death skill that needs one; spending it kills it at once (the kill is yours) and the skill goes on as if on its corpse.
- **summon** (behaviour, Rise Again): A new kind: spends a corpse and puts a thrall (an ally body using the corpse's model with set_dead_look) at it for duration. A thrall walks to the nearest enemy and strikes; enemies may attack it; it is not living (Life cannot touch it). Its kills are credited to the caster. A third pushes out the oldest.
- **field_pulse** (behaviour, Lay to Rest): A new kind: acts on the caster's own field pieces (corpses here; growth patches in nature.json) within radius of the caster or of an aimed point. Per piece it pays a reward or a burst, and on_hit lands on enemies within drag_radius of each piece once.
- **rotting** (status, Rotting Bolt): 1 stack, 6 s: the target's armour, front armour and front_block count at half, and its poise does not refill.
- **hits_corpses** (behaviour, Rotting Bolt): A projectile key: corpses are in its path like bodies; one hit bursts (corpse_burst payload in its radius) and is spent.
- **embalmed** (behaviour, Embalm): A self_buff that acts on the caster's thralls within radius: their damage taken is multiplied by thrall_incoming_mult and their own duration does not count down while it lasts; with corpse_hold, corpses within radius of the caster do not age. It does nothing to the caster.
- **thrall buffs** (field, Embalm): Any self_buff key starting thrall_ (thrall_incoming_mult, thrall_damage_mult, thrall_rate_mult, thrall_time_paused) is applied to every thrall the caster has within the buff's radius, read in the thrall's own take_hit / attack, never on the player.
- **dread** (status, Lingering Shade): 1 stack, 1.5 s, refreshed while in the zone: the target moves away from the zone's centre, will not path into it (the zone is a blocked area in its routing), and a ranged enemy inside loses its aim.
- **unliving_mult** (behaviour, Banishing Line): A damage multiplier against targets with living false (enemies.json; defined in life.json).
- **breaks_aim** (behaviour, Gravestep): A movement key: every enemy winding up a ranged attack on the caster loses it (as interrupt(), without the stagger).
- **swap_thrall** (behaviour, Gravestep): A blink key: a point on one of the caster's thralls within thrall_range swaps the two (the thrall lands where the caster stood) and heals the thrall swap_heal.
- **decoy** (behaviour, Death Mask): A prop key: while it stands, enemies within radius take it as their target instead of the player (it holds slots like the player); it has hp and blocks nothing. When it breaks or its life ends it deals damage within collapse_radius.
- **bidden** (status, Grave Mark): 1 stack, the skill's duration: every thrall of whoever applied it takes it as its target (if it can reach it) and deals thrall_damage_mult and attacks thrall_rate_mult as fast against it. Nothing else.
- **consume_thralls** (behaviour, Bone Burst): A detonate key: every thrall of the caster within range ends at once; each deals damage plus hp_frac of its remaining health, with on_hit, to every enemy within burst_radius of it. A thrall unbound leaves no corpse.

Kept from the 2026-10-22 draft and still used: dying, corpse, spared, rotting, dread, summon, field_pulse,
execute_below, hits_corpses, corpse_burst, breaks_aim, unliving_mult, decoy.

## Unsure

- Three thralls at once is a guess. Each is a body in the fight with its own target and slot; the cap is one
  number (`thrall_cap`).
- Embalm's old form ("cannot die for 5 s") is gone. It was the strongest defensive skill in any draft and served no
  role; if Brent wants it back, it fits Unholy's Shroud better than Death.
- Last Mercy's capture makes a kneeling enemy count as a corpse. It must not work on elites (excluded), or Rise Again
  becomes "take the Commander".
- Bone Burst and Lay to Rest both spend what you have; Bone Burst is the only one that spends thralls.
