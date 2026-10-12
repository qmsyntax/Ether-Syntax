# Affinity skills and combat v0 — making five affinities five different games

Draft for Brent to approve or redline, 2026-10-11. Nothing here is built. Every number is a first guess.
Tags: **[B]** Brent's ruling, **[C]** read in the books (paraphrased notes only), **[F]** fan source,
**[MODEL]** our invention. Anything untagged inside a section headed [MODEL] is [MODEL].
All skill, technique and enemy names are original to this project; two existing names that are not are flagged in §8.

---
## 1. One-page summary

1. **Each affinity gets one rule nobody else has** [MODEL]: water *moves bodies*, fire *runs on its own heat*,
   earth *builds stone that stays*, wind *is paid for by moving*, lightning *marks a target and overloads it*.
   You feel the rule on the first key press, not in the numbers.
2. **Eight skills per affinity, 40 in all**, built from 15 shared behaviours (today there are 3). Three per
   affinity are the starter kit; the other five are learned from scrolls [C: scrolls] and compete for the same
   essence to level [B].
3. **Reflux stays the pacing system** [B] and behaves differently per affinity: fire wants it high, wind sheds it
   by running, lightning only sheds it by finishing a target, earth barely makes any but keeps it.
4. **No skill hurts its caster** [B]. The health-as-ammunition route stays where it is: the overcharged strike.
5. **Skills do not depend on the three health layers.** They deal damage to one pool; "wound" below means
   whatever the separate health redesign defines as a lasting injury.
6. **Constructs change what a skill does, not just its numbers** [B: concept shapes the upgrade]: each skill
   names the two concepts that transform it (a bolt that pierces, a wall that lasts, a strike you can hold).
7. **Combat gets four small rules**: poise and stagger, interruptible wind-ups, a bonus for hitting from behind,
   and a dash that costs something to repeat. Base single-target strikes [B] become the way to cash in a stagger
   and to work reflux off.
8. **Seven enemy archetypes plus a phased elite**, each punishing one bad habit: kiting, clumping, frontal
   spam, ignoring the back line, standing in a telegraph.
9. **Enemies stop forming a ball.** Melee enemies take turns around you (a slot ring), so "run in a circle
   then AoE the clump" stops being free.
10. **Tempering grows from 6 to 18 techniques**, all still passive and all about the body [B], each described
    in a sentence a player can check with their own eyes.
11. **Cross-affinity rules: one per pair, ten in total**, for the rare two- and three-affinity characters [B]
    and for realms that supply a status themselves (rain soaks everyone).
12. **First build step**: water versus lightning, three skills each, in the existing arena — the exact pair
    Brent said felt the same.

---
## 2. What makes each affinity itself [MODEL]

| | Water | Fire | Earth | Wind | Lightning |
|---|---|---|---|---|---|
| **Fantasy** | You decide where everyone stands. | You get hotter, and so does everything near you. | You change the room and refuse to be moved. | You are only dangerous while you are moving. | One target, three touches, gone. |
| **Signature** | **Shove and Crush** | **Heat** | **Standing stone** | **Slipstream** | **Live marks and Overload** |
| **Status it applies** | Soaked | Alight | (none — it staggers) | Aloft | Live (1-3 marks) |
| **Reflux** | Normal — the reference affinity | Is your damage bonus; sheds slowly | Little made, sheds at half speed | Sheds only while you move | Never sheds in a fight except by Overload |
| **Essence / reflux cost** | Middling / middling | Cheap / high | Dear / low | Cheap / low | Dear / middling |
| **Rewards** | The player who reads the room | The gambler who rides the edge | The planner who picks a spot | The player who cannot sit still | The player who picks one target and finishes it |
| **Weak when** | In open ground with nothing to hit things against | Reflux is cold, or locked | Caught in the open with no time to set up | Cornered or standing still | Marks are spread thin and nothing reaches three |

### 2.1 Water — Shove and Crush
- Every water skill **pushes or pulls**. A shoved enemy slides at 14 m/s for the stated distance.
- **Crush**: if a shoved enemy hits a wall, a stone, or another enemy before it has gone the full distance, it
  takes **15 + 10 per metre it had left**, loses 30 poise, and is interrupted. A body it hit takes half.
- **Soaked** (6 s): the target is shoved 50% farther. Soaked is also the hook for three cross-affinity rules (§4).
- Heavy enemies are shoved half as far, elites a quarter — never zero, so the rule always reads.
- In the hands: your first bolt knocks the target back a step; your first strike throws three men into a wall.

### 2.2 Fire — Heat
- **Heat is fire reflux.** All fire damage is multiplied by `1 + 0.6 x heat/100` — +30% at 50, +48% at 80.
  Fire skills are cheap in essence and leave a lot of reflux (as the current data already says).
- Fire reflux sheds at **half** the normal rate in a fight, so heat you build stays. The lock at 100 [existing]
  is the cliff edge: the best fire play sits between 60 and 95 and never touches 100.
- **Alight**: 8 damage a second per stack for 5 s, up to 5 stacks, refreshed by any new stack. When an Alight
  enemy dies, or stands within 1.2 m of another enemy for a full second, one stack jumps across.
  Damage over time the character caused pays out to talents that care [B].
- One skill (Backdraft) spends the heat on purpose. That is fire's only way down without sitting to meditate.
- In the hands: the reflux ring is a second damage bar. You watch it the way other affinities watch essence.

### 2.3 Earth — Standing stone
- Earth skills leave **stone** in the room: slabs, pillars, rubble. Stone blocks movement and blocks shots —
  theirs and yours (your own earth skills pass). 150 health, 12 s life, **three at a time**; a fourth crumbles the oldest.
- Any earth strike that hits your stone **shatters** it: a 4 m cone of shrapnel away from you, 80 damage, 40 poise.
- **Braced**: during an earth wind-up you take 40% less damage and cannot be staggered or shoved. Every earth
  skill has a wind-up (0.3-0.8 s). You commit; in return you are allowed to.
- Earth deals the most poise damage in the game and has no fast movement skill in its starter kit.
- In the hands: the first key raises a wall between you and the thing running at you.

### 2.4 Wind — Slipstream
- **Slipstream** is ten pips. +1 for every 1.5 m you travel (walking or dashing). After half a second
  standing still, −1 every half second.
- Every wind skill is weak at zero pips and **spends** pips for its real effect (stated per skill).
  At 5 or more pips you also move 10% faster.
- **Lee**: a wind hit that lands on an enemy's back does +50%.
- **Aloft** (1.2 s): a light enemy is thrown into the air — it cannot act, and takes +25%. Heavy enemies lose 50 poise instead.
- Wind reflux sheds at three times the normal rate while you are moving and not at all while you stand, in a fight.
- In the hands: a row of pips that fills as you run and drains the moment you stop to think.

### 2.5 Lightning — Live marks and Overload
- Lightning does not travel. Its skills land the instant you press, on whatever you pointed at.
- Each lightning hit leaves **Live** marks on the target (up to 3, lasting 8 s, shown as pips over its head).
- The third mark is an **Overload**: 150 damage to that target, a 1 s stun (this interrupts anything, elites
  included), and a 60-damage arc to **every other marked enemy within 12 m**, wherever they stand. The
  overloaded target's marks clear; the others keep theirs.
- Lightning reflux does **not shed in a fight**. Each Overload grounds 12 of it. Finish targets or seize up.
- In the hands: one-two-three on a single body, then the room flashes. Spreading single marks around achieves nothing until one of them reaches three.

---
## 3. Skill lists [MODEL]

**Reading the entries.** `behaviour` names the code behaviour (Appendix A); **NEW** marks its first use.
Targeting is one of: *aimed* (along your facing, which follows the cursor), *point* (a spot on the ground
within range), *target* (the enemy under the cursor or your locked attack target), *self*.

**Cost tiers.** A full first star holds 99 essence and a new character starts with about 20 [B: baby star].

| Tier | Essence | Channelled | | Reflux tier | Reflux per essence |
|---|---|---|---|---|---|
| cheap | 6-8 | 4 / s | | low | x0.7 |
| mid | 10-14 | 6 / s | | middling | x1.0 |
| dear | 18-26 | 10 / s | | high | x1.4 |

**What the six concepts do in general** [B: concept shapes the upgrade; MODEL: the shapes]. A skill entry
lists only the two that change it most; any other concept applies its general line.

| Concept | General effect when bound | The feel |
|---|---|---|
| Acceleration | Projectile, dash and shove speed +40%; wind-ups and charge times −30% | Sooner |
| Piercing | Goes through: projectiles pass through targets, strikes ignore a frontal block, poise damage +50% | Through |
| Compression | Essence cost −25%; areas 20% smaller and 25% harder-hitting | Denser |
| Tension | The skill can be **held** up to 1 s for up to +50% effect (skills that already charge: longer hold, higher ceiling) [C: a hold-to-charge upgrade exists in the setting] | Held |
| Reach | Range, area and duration +50% | Farther |
| Stillness | Reflux left −30%; statuses the skill applies last 50% longer; things it leaves behind linger 50% longer | Lasting |

Stage still adds +10% damage per stage as now [existing]. Tension never adds self-harm [B].

### 3.1 Water — starter kit: W1, W2, W3

**W1 Water Bolt** *(exists)* — `projectile` — cheap / middling
A fist of water, thrown. Aimed; 20 m/s, 30 m. First enemy hit: 70 damage, Soaked, shoved 1.5 m.
Concepts: *Piercing* passes through and shoves every body in the line; *Acceleration* doubles the shove to 3 m.
Cousin: every affinity's cheap ranged skill — this is the only one that moves its target.

**W2 Breaker** *(replaces Tsunami Strike — see §8)* — `melee_burst` — mid / middling
The wave arrives. Aimed; 120-degree arc, 3.1 m reach, no wind-up. 2.0x strike damage and each enemy is shoved
4 m straight away from you. This is the Crush-maker: stand so the wall is behind them.
Concepts: *Reach* widens to 180 degrees and 4.5 m; *Tension* hold up to 1 s for shove up to 8 m.
Cousin: Landslide Blow (earth) is narrower, slower and staggers instead of moving.

**W3 Sluice Step** *(replaces Hydraulic Flex — see §8)* — `dash` — cheap / low
Pour yourself through the gap. Direction of movement keys, else facing; 4.7 m in 0.18 s. You pass **through**
enemies and Soak each one you pass. Ends on the far side of the pack — which is where the wall is not.
Concepts: *Acceleration* drags passed enemies 2 m along behind you; *Reach* 7 m.
Cousin: other dashes go around or stop at bodies; only this and Stepped Leader cross a line of enemies.

**W4 Undertow** — `displace` **NEW** — mid / middling
The floor of the room leans. Point, 9 m range; every enemy within 4 m of the point is pulled 4 m toward it and
Soaked. No damage of its own (bodies that collide Crush each other). Interrupts light enemies.
Concepts: *Compression* pulls all the way to the point and holds them 0.8 s; *Reach* 6 m radius.
Cousin: Updraft (wind) lifts instead of gathering.

**W5 Riptide Lash** — `displace` — mid / middling
A rope of water for one throat. Target, 10 m; that enemy is pulled to 1.5 m in front of you, takes 60, is
Soaked and interrupted, and is turned to face away from you for 1 s.
Concepts: *Piercing* drags a shield-carrier's guard open for 3 s; *Tension* hold to then throw the target 6 m in the aimed direction on release.
Cousin: the only single-target pull in the game. It is the answer to archers, drummers and censer-bearers (§6).

**W6 Standing Pool** — `ground_zone` **NEW** — mid / low
A tide that forgot to leave. Point, 9 m; 3.5 m radius for 8 s. Enemies inside are Soaked and 30% slower;
every shove that starts or passes inside the pool goes twice as far. No damage.
Concepts: *Stillness* 12 s and Soaked lingers 6 s after leaving; *Reach* 5 m radius.
Cousin: Slag Pool (fire) damages; this one only sets up.

**W7 Pressure Jet** — `channel` **NEW** — dear / high
Everything behind one finger-width. Aimed, held; 8 m stream, 1 m wide. 90 damage a second to the first enemy in
the line and it is pushed back 5 m/s. An enemy pinned against a wall or stone takes 1.5x. You turn slowly
(120 degrees a second) and walk at 45% while holding.
Concepts: *Piercing* the stream passes through to everything in the line; *Compression* 6/s instead of 10/s.
Cousin: Bellows Breath (fire) is a short wide cone that stacks a status; this is a long thin line that moves one body.

**W8 Backwash** — `self_buff` **NEW** — mid / low
Let it hit the water instead. Self; 6 s or three hits, whichever ends first: each melee hit on you is halved and
the attacker is shoved 3 m and Soaked.
Concepts: *Stillness* five hits; *Reach* the shove is 5 m and catches enemies within 2 m of the attacker.
Cousin: Stonehide (earth) reduces everything and slows you; Static Coat (lightning) marks instead of moving.

### 3.2 Fire — starter kit: F1, F2, F3

**F1 Cinder Spit** *(exists)* — `projectile` — cheap / high
A coal from the mouth. Aimed; 24 m/s, 30 m. 55 damage and 1 Alight. Half the recovery of other bolts — it is
meant to be spammed, and spamming it is how heat is built.
Concepts: *Compression* costs 25% less essence but the same reflux — pure heat-building; *Piercing* passes through, lighting each.
Cousin: weakest cheap bolt on its own; strongest at 80 heat.

**F2 Kiln Fist** *(exists, changed)* — `targeted_strike` **NEW** — mid / high
Fire the hand, then find out what it breaks. Target, within strike reach + 1 m (you step in); 0.2 s wind-up.
3.0x strike damage on **one** enemy and 2 Alight. If the target was already Alight, every stack on it is spent
for +40 damage and the blow bursts 2 m, putting 1 Alight on each enemy caught. Interrupts.
Concepts: *Tension* hold up to 1 s, up to 4.5x; *Piercing* ignores a frontal block and does double poise damage.
Cousin: Thunderclap Palm (lightning) is the other single-target strike; that one builds toward a stun, this one cashes in burns.

**F3 Flashover** *(exists, changed)* — `dash` — cheap / high
The room does not burn slowly. 4.2 m in 0.14 s; leaves a line of flame behind you for 3 s (1 m wide; 1 Alight
a second to enemies in it). Does not pass through enemies.
Concepts: *Stillness* the line lasts 6 s; *Reach* 6.5 m.
Cousin: the only dash that leaves something on the ground.

**F4 Bellows Breath** — `channel` — mid / high
Aimed, held; cone 5 m long, 60 degrees. 50 damage a second and 1 Alight every half second to everything in it.
You walk at 45% while holding. Each second held also adds the reflux — this is the fastest way to get hot.
Concepts: *Reach* 7.5 m; *Acceleration* Alight every 0.3 s.
Cousin: Pressure Jet (water).

**F5 Slag Pool** — `ground_zone` — mid / middling
Lobbed to a point, 9 m; 3 m radius, 6 s. 25 damage a second and 1 Alight a second to enemies standing in it.
Enemies will path around it if they can, so it also closes a doorway.
Concepts: *Stillness* 10 s; *Compression* 2.4 m radius at 31 damage a second and cheaper.
Cousin: Standing Pool (water). The two overlap on purpose — see the steam rule in §4.

**F6 Backdraft** — `melee_burst` — mid / none
Open the door. Self, full circle, 5 m, 0.3 s wind-up. Damage = **4 x the heat you carry above 20**
(320 at full heat, 120 at 50; the Heat bonus is not applied on top), and fire reflux drops to 20. Leaves no
reflux of its own. Useless when cold.
Concepts: *Compression* drops reflux only to 40, so you stay hot; *Reach* 7.5 m.
Cousin: nothing else in the game spends reflux. It is fire's release valve and its finisher at once.

**F7 Stoke** — `self_buff` — cheap / (special)
Self, instant. Adds **25 heat** at once, and for 6 s your base strikes each put 1 Alight on what they hit.
Stoke is how fire uses the plain attack: light a man with your hands, then Kiln Fist him.
Concepts: *Stillness* 10 s; *Tension* hold to add up to 45 heat.
Cousin: Static Coat (lightning) also changes base strikes, but triggers on being hit.

**F8 Pyre Call** — `detonate` **NEW** — mid / middling
Every fire you set answers. Self, 10 m; every Alight enemy in range loses its stacks and each stack bursts for
35 damage in 2 m. Rewards spreading burns first and firing this once.
Concepts: *Reach* 15 m and bursts 3 m; *Stillness* leaves 1 stack behind on each target.
Cousin: Dead Short (lightning) is the same behaviour on a different status; that one stuns, this one is pure damage.

### 3.3 Earth — starter kit: E1, E2, E3 (deliberately no movement skill — see §8 Q3)

**E1 Slingstone** *(exists)* — `projectile` — mid / low
A stone has all the time there is. Aimed; 0.3 s wind-up (Braced), 14 m/s, 24 m. 120 damage, 45 poise damage,
interrupts. If it hits your own stone it shatters it toward the far side.
Concepts: *Piercing* punches through one body and keeps going; *Acceleration* no wind-up and 20 m/s.
Cousin: slowest bolt in the game and the only starter bolt that interrupts.

**E2 Raise Slab** — `prop` **NEW** — cheap / low
Point, 8 m; a wall 3 m wide, 0.6 m thick, across the line between you and the point, up in 0.35 s. Enemies
standing where it rises take 20 and are shoved 1 m off it. Blocks movement and shots for 12 s.
Concepts: *Reach* 5 m wide and 18 s; *Stillness* 20 s and 300 health.
Cousin: Ground Rod (lightning) is the other placed object, and it blocks nothing.

**E3 Landslide Blow** *(exists, changed)* — `melee_burst` — mid / low
The hill does not swing. It stops holding on. Aimed; 0.6 s wind-up (Braced); 60-degree arc, 3.5 m. 3.2x strike
damage, 80 poise damage — it staggers anything that is not an elite — and shatters every stone in the arc.
Concepts: *Tension* hold up to 1.5 s for up to 5x and a 5 m reach; *Piercing* ignores frontal blocks.
Cousin: Breaker (water). Same key position, opposite feel: slow, narrow, and nobody goes anywhere.

**E4 Bedrock Shove** *(exists, changed)* — `dash` — mid / low
Shoulder first. Facing only; 3.5 m in 0.3 s, Braced throughout. You do **not** pass through: the first enemy
you meet is carried with you and then shoved 3 m (Crush applies), 50 poise damage. A heavy enemy stops you dead and takes 60 poise damage.
Concepts: *Reach* 5.5 m and the carried enemy collects others; *Acceleration* 0.2 s.
Cousin: the only dash that is an attack on a body rather than a way past it.

**E5 Pillar** — `delayed_blast` **NEW** — mid / low
Point, 9 m; a 1.2 m circle is marked for 0.5 s, then a column punches up: 120 damage, 60 poise damage,
interrupts, and the column stays as stone. Hit it with Landslide Blow and it becomes the shrapnel.
Concepts: *Acceleration* 0.25 s mark; *Compression* cheaper and a thinner column that does 150.
Cousin: Downdraft (wind) is the other marked-spot skill; that one comes from above and leaves nothing.

**E6 Stonehide** — `self_buff` — mid / low
Self; 8 s. You are Braced the whole time (40% less damage, cannot be staggered or shoved) and move 25% slower.
Concepts: *Stillness* 12 s; *Compression* the slow is only 10%.
Cousin: Backwash (water).

**E7 Tremor** — `melee_burst` — dear / low
Self, full circle, 5 m, 0.5 s wind-up (Braced). 60 damage, **interrupts every enemy in the ring**, slows them
40% for 3 s, and shatters all your stone at once (each piece throws its shrapnel outward from you).
Concepts: *Reach* 7.5 m; *Stillness* the slow lasts 5 s and becomes a 1 s root for light enemies.
Cousin: Backdraft (fire) is the other full-circle burst; that one is damage, this one is control.

**E8 Quarry Throw** — `charge_release` **NEW** — dear / middling
Hold to tear a boulder out of the floor (rooted, Braced, up to 1.5 s); release to lob it to the cursor, up to
14 m. 150-400 damage in 2.5 m by how long you held, 80 poise damage, and it leaves rubble: a stone that also
slows enemies within 2 m of it by 40%.
Concepts: *Tension* hold to 3 s for up to 650; *Reach* 21 m and 3.7 m blast.
Cousin: Stored Bolt (lightning) is the other charged skill — a line, instant, and you can walk while holding it.

### 3.4 Wind — starter kit: A1, A2, A3

**A1 Cutting Gust** *(exists, changed)* — `projectile` — cheap / low
Air has an edge. Aimed; 32 m/s, 12 m, **passes through everything**. 45 damage, and spends up to 3 pips for +15 each.
Concepts: *Reach* 18 m and spends up to 5 pips; *Acceleration* knocks light enemies Aloft at 3 pips spent.
Cousin: the only starter bolt that pierces without a construct; the weakest one fired from a standstill.

**A2 Tailwind** *(exists, changed)* — `dash` — cheap / low
Something behind you agrees you should leave. 6.6 m in 0.22 s — the longest dash — and +3 pips. It is the one
dash with **no recovery** (§6.3): you can strike or cast the instant it ends. It does no damage and passes through nothing.
Concepts: *Acceleration* +5 pips; *Reach* 10 m.
Cousin: every dash. This is the pure one.

**A3 Crosscut** *(replaces Downdraft in the kit)* — `targeted_strike` — cheap / low
Target, 7 m; you cut **through** the enemy and stop 2 m behind it. 1.6x strike damage, +10% per pip, spends all
pips; it always counts as a hit from behind (Lee, and §6.3's rear bonus). 0.25 s recovery.
Concepts: *Piercing* cuts through every enemy on the line to the target; *Tension* hold to store the cut, release from up to 10 m.
Cousin: Kiln Fist and Thunderclap Palm are strikes you stand in front of; this one changes sides.

**A4 Downdraft** *(exists, changed)* — `delayed_blast` — mid / low
Bring the sky down. Point, 8 m; 0.25 s mark, 4 m radius. 50 damage, interrupts, pins enemies (60% slower, 2 s),
**destroys enemy projectiles in the area**, and deals +100 to anything Aloft. Shatters stone.
Concepts: *Compression* 3.2 m and enemies are knocked flat for 1 s; *Stillness* leaves a 4 s zone that keeps swatting projectiles.
Cousin: Pillar (earth).

**A5 Updraft** — `displace` — mid / low
Point, 8 m; enemies within 2.5 m are thrown Aloft for 1.2 s (heavy: −50 poise). Spends up to 4 pips: +0.2 s each.
No damage. It is a set-up: everything Aloft takes +25% from everyone.
Concepts: *Reach* 3.7 m; *Stillness* Aloft 1.8 s base.
Cousin: Undertow (water) gathers on the ground; this takes them off it.

**A6 Crosswind Veil** — `self_buff` — mid / low
Self; 5 s. Enemy projectiles aimed at you curve away and miss, and Slipstream does not drain. Melee still lands.
Concepts: *Stillness* 8 s; *Reach* covers allies and summons within 4 m.
Cousin: Backwash answers melee; this answers the back line.

**A7 Gale Lane** — `ground_zone` — mid / low
Aimed; a lane 10 m long and 2.5 m wide from your feet, 6 s. Inside it you move 40% faster and gain pips at
double rate; enemies are pushed 3 m/s down the lane and their projectiles fly at half speed.
Concepts: *Reach* 15 m; *Acceleration* enemies pushed 6 m/s (enough to Crush against a wall at the end).
Cousin: Standing Pool and Slag Pool hold a place; this one points somewhere.

**A8 Spindrift** — `channel` — mid / low
Self, held; you keep **full movement speed**. Every 0.25 s the nearest enemy within 3 m takes 25 (with Lee if
you are behind it). Costs 6 essence a second and 1 pip every half second; ends when the pips run out.
Concepts: *Reach* 4.5 m and hits the nearest two; *Compression* 4/s and 1 pip a second.
Cousin: the only channel you can run with — the other three slow or root you.

### 3.5 Lightning — starter kit: L1, L2, L3

**L1 Arc Lash** *(exists, changed)* — `beam` **NEW** — cheap / middling
It was there and now it is here. Aimed; instant line, 9 m, first enemy. 85 damage and 1 Live mark. Cannot be
dodged, blocked by a body or outrun; stone and walls stop it.
Concepts: *Piercing* hits everything on the line; *Reach* 13.5 m.
Cousin: other bolts travel and can miss a moving target. This cannot — and it is short.

**L2 Thunderclap Palm** *(exists, changed)* — `targeted_strike` — mid / middling
Target, strike reach + 1 m; no wind-up. 2.2x strike damage on one enemy, **2 Live marks**, interrupts.
Lash then Palm is three marks: the starter kit contains one complete Overload for 20 essence.
Concepts: *Tension* hold up to 1 s for 3 marks on its own; *Acceleration* no recovery after it.
Cousin: Kiln Fist (fire).

**L3 Stepped Leader** *(exists, changed)* — `blink` **NEW** — mid / middling
Find the path, then take all of it at once. Point, 6 m; you are simply there — over enemies, pits and Slag
Pools, not through walls or stone. 1 Live mark on each enemy within 1.5 m of where you arrive. 0.3 s recovery.
Concepts: *Reach* 9 m; *Piercing* passes through your own stone and through walls up to 1 m thick.
Cousin: the dearest movement skill and the only one with no travel at all.

**L4 Forked Path** — `chain` **NEW** — mid / middling
Target, 9 m; hits it, then jumps to up to 3 more enemies within 5 m of each other. 50 damage and 1 mark each.
It never puts two marks on one body — it primes the room for the arc, it does not Overload anything.
Concepts: *Reach* 6 jumps of 7.5 m; *Stillness* marks from it last 14 s.
Cousin: the only chaining skill. Compare Cutting Gust, which needs them in a line.

**L5 Ground Rod** — `prop` — cheap / low
Point, 8 m; a thin iron-grey rod, 10 s, blocks nothing. Whenever you cast a lightning skill within 8 m of it,
the rod also arcs to the nearest enemy within 5 m of itself: 40 damage, 1 mark. One rod at a time.
Concepts: *Stillness* 16 s; *Reach* arcs to the nearest two.
Cousin: Raise Slab (earth). The rod makes one cast land in two places — it is a second pair of hands.

**L6 Stored Bolt** — `charge_release` — dear / high
Hold up to 1.2 s (walking at 45%); release an instant line 12 m long through **everything**. 100-300 damage and
1, 2 or 3 marks by how long you held — a full charge Overloads the whole line.
Concepts: *Tension* hold to 2 s for up to 450; *Compression* 25% cheaper and a 1.2 m wide line becomes 0.6 m.
Cousin: Quarry Throw (earth).

**L7 Static Coat** — `self_buff` — mid / middling
Self; 6 s. Any enemy that hits you in melee takes 25 and 1 mark. Every second base strike you land adds 1 mark.
Concepts: *Stillness* 10 s; *Acceleration* every base strike marks.
Cousin: Stoke (fire). This is lightning's reason to stand in and trade.

**L8 Dead Short** — `detonate` — dear / high
Self, 12 m; every marked enemy Overloads now at a fraction of full effect — 1 mark 40%, 2 marks 70%, 3 marks
100% of the 150 and of the stun. These Overloads ground **no** reflux.
Concepts: *Reach* 18 m; *Compression* cheaper, and one-mark targets count as two.
Cousin: Pyre Call (fire). It is the panic button; a clean three-mark Overload is always the better deal.

### 3.6 Counts and overlap check

| Behaviour | Water | Fire | Earth | Wind | Lightning |
|---|---|---|---|---|---|
| projectile | W1 | F1 | E1 | A1 | — |
| melee_burst | W2 | F6 | E3, E7 | — | — |
| dash | W3 | F3 | E4 | A2 | — |
| targeted_strike | — | F2 | — | A3 | L2 |
| beam / chain / blink | — | — | — | — | L1 / L4 / L3 |
| channel | W7 | F4 | — | A8 | — |
| charge_release | — | — | E8 | — | L6 |
| ground_zone | W6 | F5 | — | A7 | — |
| prop | — | — | E2 | — | L5 |
| delayed_blast | — | — | E5 | A4 | — |
| displace | W4, W5 | — | — | A5 | — |
| self_buff | W8 | F7 | E6 | A6 | L7 |
| detonate | — | F8 | — | — | L8 |

Lightning has no projectile and no ordinary dash at all; earth has no starter movement; wind has no burst;
fire's melee is single-target. No two starter kits share more than one behaviour with the same role.

---
## 4. Cross-affinity interactions [MODEL]

One rule per pair, so the whole table is ten lines and can be learned as "what happens when A meets B".
Most characters have one affinity [B: 87.5%], so these matter in three places: the rare two- and
three-affinity character, parties, and **realms and enemies that supply a status** (a rain realm keeps
everything Soaked; an enemy fire-thrower sets its own side Alight). Build the first six; 7-10 can wait.

| # | Pair | Rule | In one breath |
|---|---|---|---|
| 1 | Water + Lightning | A lightning hit on a **Soaked** target also puts 1 mark on every other Soaked enemy within 4 m | Wet things conduct |
| 2 | Water + Fire | Fire meeting **Soaked** makes **steam**: the Soak and the new Alight cancel, and a 2 m cloud hides whoever stands in it from ranged enemies for 3 s. Slag Pool on Standing Pool: one big cloud, 4 s, 15 damage a second | Water and fire make cover |
| 3 | Water + Earth | Crush against **your own stone** does 1.5x and does not break the stone | A wall you brought with you |
| 4 | Water + Wind | An **Aloft** enemy is shoved twice as far (stacks with Soaked) | Nothing to hold on to |
| 5 | Fire + Wind | A wind hit on an **Alight** enemy adds 1 stack and blows 1 stack onto each enemy within 3 m behind it; Gale Lane over fire carries the flames down the lane | Wind feeds fire |
| 6 | Fire + Lightning | An **Overload** on an Alight target bursts its stacks like Pyre Call (35 per stack, 2 m) | Flashpoint |
| 7 | Fire + Earth | Fire on **stone** bakes it: the stone puts 1 Alight a second on enemies within 2 m, and its shrapnel carries 2 Alight | Hot rock |
| 8 | Earth + Lightning | Lightning hitting **your stone** shatters it, and the shrapnel leaves 1 mark on everything it hits | Split rock |
| 9 | Earth + Wind | Shrapnel thrown inside a **Gale Lane**, or by Downdraft, flies twice as far and passes through bodies | Grit in the wind |
| 10 | Wind + Lightning | An **Overload** on an Aloft target arcs marks instead of damage: every marked enemy in range gains 1 mark | It finds the next one |

Rules for all ten: an interaction never needs a menu, never costs extra, and is visible (steam is a cloud,
conduction draws a line between the bodies).

---
## 5. Tempering, rethought

Kept from the rulings and notes: passive, all run at once, "simply make the body tougher" [B]; grouped by
affinity, a stage and a 0-100% bar, trained by harming the body so it adapts [C]; stage cap stars + 1 [I].
Everything below is [MODEL].

**What was confusing, and the fix.** A water character saw two techniques whose effects read "+8 superficial
health" and "reflux sheds 15% faster" with no way to tell what either meant in a fight. So: every technique
now states its effect as **something you can watch happen**, the tempering screen shows a "you will notice"
line, and nothing mentions a health layer.

**The rule of thumb for what belongs here**: it changes what happens *to* the body (how hard it is to hurt,
move, stop, or exhaust). It never adds a button, never deals damage, never triggers an attack.

| Technique | Who | Per stage | You will notice |
|---|---|---|---|
| **Callus** *(exists)* | anyone | +8 maximum health | The bar is longer |
| **Hard Knit** | anyone | Health returns 20% faster between fights | Less waiting after a wall |
| **Rooted Stance** | anyone | Your own poise +20% | Heavy hits stop knocking you out of your swing |
| **Slow Tide** *(exists)* | water | Reflux sheds 15% faster, every affinity | The rings drain faster |
| **Yielding Flesh** | water | The first hit after 5 s without being hit does 12% less | The opening blow of each exchange is soft |
| **Brine Blood** | water | Burning, bleeding and other lingering harm on you ends 20% sooner | Fires on you go out quickly |
| **Kiln-Cured Hide** *(exists)* | fire | 5% less damage from every hit | Everything hurts a little less |
| **Banked Coals** | fire | Reflux pain starts 6 points later (50, 56, 62...) | You can run hotter before skills get dearer |
| **Seared Shut** | fire | A hit that would leave a lasting wound has a 10% chance not to | Fewer injuries follow you home |
| **Bedrock Bones** *(exists, changed)* | earth | 8% less damage from heavy attacks | Brutes and commanders hit softer |
| **Ballast** | earth | You are shoved 25% less far and stagger 20% shorter | You stay where you put yourself |
| **Settled Weight** | earth | While not moving, 6% less damage | Standing your ground is safer than backing off |
| **Thin Air Lungs** *(exists)* | wind | 4% faster on your feet | You outrun what you could not |
| **Loose Joints** | wind | Dash recovery 15% shorter; the repeat-dash penalty window 15% shorter | You can act sooner out of a dash |
| **Glancing Skin** | wind | 8% less damage from projectiles while moving | Arrows on the run barely bite |
| **Live Wire Nerves** *(exists)* | lightning | Base strikes recover 5% sooner | You hit faster |
| **Jolt Reflex** | lightning | After being hit, +10% movement for 1.5 s | Getting hit throws you clear |
| **Scorched Channels** | lightning | A locked affinity unlocks 5 points sooner (60, 65, 70...) | Lock-outs are shorter |

**Starting and learning.** A character starts as now: Callus plus the first-listed technique of each
affinity held (so 2, 3 or 4). The other two per affinity, and the other two general ones, are learned from
**tempering manuals** — bought at the yard ($2,500 first guess), found as elite drops, read once [C: scroll-style
learning; whether a scroll is consumed is unknown to Brent — treat as consumed]. A manual for an affinity you
do not hold cannot be learned. A character can eventually hold 3 general + 3 per affinity; with stage cap
stars + 1 and sessions that cost health, nobody finishes them all early — the same "too many plates" pressure
as abilities [B].

**Training** keeps its shape: a session costs health now and adds progress. With one health pool the
programmer needs only this from the health redesign: a session takes a fixed bite of current health and is
refused below 30%. If the redesign has lasting wounds, a session should leave a short "training ache" wound —
decide there, not here.

Four of the existing six (reflux shedding, movement, strike speed) already stretch "tougher" toward "fitter".
I kept them and kept the new ones on the same side of that line; if Brent reads [B] strictly, cut Jolt
Reflex and Loose Joints first.

---
## 6. Making combat less repetitive [MODEL]

Today's loop: run in a circle, the pack follows in a ball, turn, area skill, repeat. Three things make that
optimal — every enemy walks straight at you, nothing punishes retreating, and nothing in the pack needs
different handling from the rest. The fix is on both sides.

### 6.1 Enemy archetypes

Names continue the existing realm-invader set (Masked Skirmisher, Hide-Bound Brute, Wall Commander). Health and
damage are at strength 1.0; the player has about 100 health and a 60-damage strike.

| Archetype | What it does | Telegraph | Counter | The mistake it punishes |
|---|---|---|---|---|
| **Masked Skirmisher** *(exists)* — 240 hp | Walks up, swings for 10. Now takes a **slot** (6.2) instead of piling in | 0.45 s wind-up glow (as now) | Anything | None. It is the baseline the others are read against |
| **Pavise Bearer** — 320 hp, 100 poise | Carries a body-length shield: 80% less damage from the front 120 degrees; shots and beams stop on it. Advances slowly, shield-bashes for 14 and a 2 m shove. Two standing side by side cover each other's flank | Plants the shield and it flares 0.7 s before the bash | Get behind it (Crosscut, Sluice Step, Stepped Leader); break its poise — the shield drops for 3 s; Riptide Lash turns it round | Pressing the area skill into its face |
| **Rampart Archer** — 120 hp | Holds at 9-12 m. Aims 1.0 s, looses for 18. Backs off at walking pace if you come within 4 m; helpless in melee | A thin line from bow to you for the whole second. The aim locks 0.3 s before release: change direction late and it misses; run straight and it leads you | Close the gap, pull it in, break line of sight with stone, Downdraft or Crosswind Veil | Ignoring the back line; kiting in straight lines |
| **Harrier** — 140 hp, speed 8.5 (you: 6.5) | Circles at 7 m and does nothing while you fight. When you have moved **away** from the pack for 1.5 s it pounces: 8 m leap, 20 damage and you are staggered 0.6 s | Drops to a crouch 0.5 s, eyes lit | **Turn and hit it**: any hit during the crouch or in the air knocks it down, staggered 2 s. A pounce that misses leaves it stuck 1 s | Running away |
| **Hide-Bound Brute** *(exists, reworked)* — 700 hp, 160 poise | Slow. Overhead slam: 3 m circle, 45 damage, staggers you and may leave a wound. Front is armoured (30% less) | 1.2 s wind-up with a filling circle on the ground and a **white flash** — the mark of an interruptible attack | Interrupt it (any skill that says "interrupts", or break its poise), or step out. A missed slam leaves it stuck 1.5 s with its back open | Standing in the circle; having nothing that interrupts |
| **Censer-Bearer** — 200 hp | Walks in the middle of the pack swinging a smoking censer; weak swing for 8. **When it dies it bursts**: every enemy within 4 m heals 40% and is frenzied (+30% speed and attack rate) for 6 s | A visible smoke ring at 4 m at all times; the censer flares white for 0.8 s after the killing blow, then bursts | Kill it away from the others — pull it out, shove it off, or shove the others away during the 0.8 s. Or kill it last | Area-killing the clump it is standing in |
| **War Drummer** — 180 hp | Does not fight. Stays 6 m behind the line. Allies within 6 m attack 25% faster and have +50% poise; every 10 s a drum roll makes one Skirmisher's next attack heavy | Ring on the ground; raised sticks 1 s before a roll (interruptible) | Kill it first. Blink, Crosscut or Tailwind to it; Riptide Lash it to you; Slingstone interrupts the roll | Fighting the front line as if it were the whole fight |
| **Wall Commander** *(exists, now a phased elite)* — 1400 hp, 300 poise | **Phase 1 (to 60%)**: duels. Blocks from the front; answers a blocked hit with a fast counter-swing. **Phase 2 (60-30%)**: calls three Skirmishers and a Drummer, and adds a 6 m sweep. **Phase 3 (under 30%)**: charges the length of the room for 60 — and if the charge ends in a wall or stone it is stunned 3 s and takes 1.5x | Sweep: a cone drawn on the floor 0.8 s. Charge: a lane drawn on the floor 1.0 s, white flash at the start (interruptible only by an Overload stun or a poise break) | Phase 1: flank or break poise. Phase 2: kill the Drummer. Phase 3: put a wall behind you and step aside | Treating the boss as a bigger Skirmisher |

One later addition worth keeping in mind, not in the first build: a **Sapper** that walks to the player's stone
and breaks it, so earth has something that answers it.

### 6.2 Encounter rules

| Rule | What it is | Smallest version that proves it |
|---|---|---|
| **Slot ring** | At most 6 melee enemies may stand in striking range of you, one per 60-degree slot; the rest wait and circle at 4-5 m. A pack is now a ring with a second rank, not a ball, so one arc never catches all of it | A slot table on the player; an enemy with no slot holds at 4.5 m. Test with 10 Skirmishers |
| **Turn rate** | Enemies turn at 240 degrees a second instead of snapping to face you, so a back exists to get behind | One number in `enemies.json`; watch a Brute fail to track a Crosscut |
| **Wall recipes** | Each wall of the passage is built from a small recipe (a front line, a back line, one problem) and never introduces more than one archetype the player has not met | Hand-write five recipes: Skirmishers; + Archers; + Pavise pair; + Harrier; Brute + Drummer at the gate |
| **One problem per pack** | A pack has at most one Censer-Bearer and one Drummer; Harriers come in ones and twos | Part of the recipe format |
| **Rooms have edges that matter** | Chambers get two or three pieces of cover or pillars and at least one narrow point | Add three static blocks to the test arena; water and earth immediately have something to use |

### 6.3 Player-side depth

All of this must work with click-to-attack [B] — no block button, no timing windows shorter than a third of a second.

| Idea | Rule | Why it helps | Smallest version that proves it |
|---|---|---|---|
| **Poise and stagger** | Enemies have poise. Hits remove it (base strike 20; skills as listed, default 15). It refills at 30 a second after 3 s unhit. At zero: **Staggered** for 1.5 s — its attack is cancelled, it cannot act, it takes +30%. The player has poise too (100): only heavy attacks stagger you, for 0.4 s | Gives every fight a second bar to work on and makes big enemies a problem to solve rather than a longer health bar | Poise on the Brute only, a thin bar under its health, stagger state. One afternoon of feel |
| **Opening** | A base strike on a Staggered enemy does double damage | The reason to click one enemy instead of pressing 2 again | One multiplier in `deal_damage` when the target is staggered and the hit is tagged `melee` and not `ability` |
| **Working it off** | Every base strike that lands sheds 1 reflux from your hottest affinity [fits the bible's "aggression is the cooldown reset"] | Base strikes become how you earn your next cast; fights become cast, strike, strike, cast | One line; watch the ring fall as you hit |
| **Interrupts** | Some enemy attacks are flagged interruptible and show a white flash at the start of the wind-up. A hit from a skill marked "interrupts", or a poise break, cancels the attack and staggers the attacker 0.8 s | Gives a reason to hold a skill for the right moment instead of firing on sight | The Brute's slam, and one interrupting skill per starter kit |
| **Rear hits** | A hit on an enemy's back 120 degrees does +30% (wind's Lee adds on top) | Makes where you stand matter for every affinity, and makes movement skills offensive | Needs the turn rate above. Show a small mark on a rear hit |
| **Dash commitment** | (a) After any dash, 0.25 s of **recovery**: you cannot strike or cast. (b) **Winded**: a second movement skill inside 2.5 s costs double essence and double reflux. (c) Dashes do not make you untouchable — you avoid a hit by not being there. Tailwind is exempt from (a); nothing is exempt from (b) | The dash stops being free. It is priced through reflux, not a cooldown [B] | Two numbers in `balance.json`; a faint "winded" tint on the dash icon |
| **Skill recovery** | Each skill has a short recovery (0.15-0.5 s, on the data) during which you cannot dash | Casting in the wrong place can be punished, so placement matters | One key per ability, default 0.2 |

What I deliberately left out: a block or parry button, stamina, combo strings, and invulnerable rolls. Each
would fight click-to-attack or duplicate reflux.

---
## 7. Build order

Each step ends in something Brent can play. S = a day or two of work, M = up to a week, L = more.

| Step | Size | What gets built | What it proves | How to test |
|---|---|---|---|---|
| **1. Water versus lightning** | **M** | The shared hit payload and status set (Appendix B); shove and Crush; Soaked; Live marks and Overload; lightning's reflux rule; behaviours `targeted_strike`, `beam`, `blink` and the changed `projectile`, `melee_burst`, `dash`. Skills **W1 Water Bolt, W2 Breaker, W3 Sluice Step** and **L1 Arc Lash, L2 Thunderclap Palm, L3 Stepped Leader**. Three static blocks in the arena. Cross rule 1 comes free | That two affinities can share an arena and feel like different games — Brent's point 1 | Self-test: shove distance, Crush arithmetic, three marks Overload, arc reaches marked enemies only, reflux grounds 12. By hand: Brent plays one water and one lightning character back to back |
| **2. Combat rules** | **M** | Poise and stagger, Opening, working it off, interrupts, rear hits and turn rate, dash recovery and Winded, slot ring. Brute reworked; Rampart Archer; Harrier | That the loop is no longer kite-and-burst — Brent's point 2 | Self-test each rule's arithmetic; by hand with the two step-1 characters |
| **3. Fire, earth, wind starter kits** | **L** | Heat, Alight and its spread; stone, shatter and Braced; Slipstream, Lee and Aloft; behaviours `prop`, plus flame-trail and carry options on `dash`. Nine skills: F1-F3, E1-E3, A1-A3. Per-affinity reflux rules. HUD: heat tint on the fire ring, Slipstream pips, stone count | All five affinities distinct with three skills each | Self-test per rule; a dual-affinity character for cross rules 2-5 |
| **4. The rest of the enemies** | **M** | Pavise Bearer, Censer-Bearer, War Drummer, Wall Commander phases; wall recipes in the passage; cover in chambers | That each pack asks a different question | Bot runs still pass; by hand, a full passage |
| **5. The other 25 skills, and learning them** | **L** | Behaviours `channel`, `charge_release`, `ground_zone`, `delayed_blast`, `displace`, `self_buff`, `detonate`, `chain`. Skill scrolls as shop stock and drops; the per-skill concept rules in data; bind preview rows for the new keys | Build variety, and the "too many plates" pressure [B] with real choices behind it | Self-test per behaviour; by hand over several sessions |
| **6. Tempering and the remaining cross rules** | **M** | Twelve new techniques, manuals, reworded effects; cross rules 6-10. Do this **after** the health redesign lands | Brent's point 3 | Self-test; the tempering screen screenshot |

Steps 1 and 2 are independent and could be swapped; I put skills first because it answers the sharper complaint
with the smaller change.

---
## 8. Open questions for Brent

1. **Two existing skill names are the books' names.** Tsunami Strike and Hydraulic Flex appear in our own
   research notes as the protagonist's water abilities, although the data file says every name is ours.
   *Recommend:* rename to **Breaker** and **Sluice Step** now (ids can stay for save compatibility).
2. **Reflux above 80 currently damages you on every cast** (`burn_self_damage`). That sits awkwardly beside
   "abilities do not hurt their caster", and fire is now designed to live above 80. *Recommend:* replace the
   burn with strain — above 80, that affinity's skills have 50% longer recovery — and keep the lock at 100.
3. **Earth's starter kit has no movement skill** (bolt, wall, heavy strike), breaking the current
   "ranged, strike, movement" pattern on purpose. *Recommend:* yes — it is the fastest way to make earth feel
   like earth; Bedrock Shove is the first scroll an earth character will want.
4. **A new character has 20 essence**, which is one or two skills per fight. Lightning's opening combo was
   costed to fit exactly (8 + 12). *Recommend:* keep 20 for now, since "working it off" and base strikes carry
   the early fights; revisit after step 2 and raise to 30-40% if the first ten minutes feel starved.
5. **How are the other five skills per affinity learned?** *Recommend:* scrolls [C], consumed on reading:
   two per affinity sold in town (rotating stock, $3,000-8,000), the rest as passage rewards and elite drops,
   so a run can change your build.
6. **Should a dash ever make you untouchable?** I have said no — you dodge by leaving the spot.
   *Recommend:* no, but if step 2 feels unfair against the Archer, give Tailwind alone 0.1 s.
7. **One rule per affinity pair makes ten cross rules, not eight.** *Recommend:* accept ten because "one per
   pair" is easier to remember than a list with gaps; build six first.
8. **Does the slot ring fit the fiction?** Six attackers at a time is a game rule; the invaders already fight
   in formations at higher tiers [C: shield walls and formations], so waiting ranks read as discipline.
   *Recommend:* yes, and let late walls raise the ring to eight.

---
## Appendix A — the 15 behaviours

Each is one `kind` in `abilities.json` and one function reached from `cast_ability`'s `match`. All of them read
the common keys `cost`, `reflux_per_cost`, `recovery`, `windup`, `braced` and the hit payload `on_hit`
(Appendix B), and route damage through `deal_damage` with tags `["ability", <affinity>, <skill id>]` plus
`"melee"` or `"projectile"` where that is true, so talent effects keep working.

1. **projectile** *(exists, extended)* — Spawns a `Projectile` along the facing. Each frame it advances
   `speed x delta`, checks enemies and stone, applies the payload to the first thing hit and frees itself —
   unless `pierce` is set, in which case it remembers who it has hit and carries on. Keys: `damage`, `speed`,
   `life`, `pierce` (count), `spend_pips`, `pip_damage`.
2. **melee_burst** *(exists, extended)* — After `windup`, applies the payload once to every hittable within
   `reach_bonus` + strike range inside `arc_deg` (360 = full circle). No per-frame work. Keys: `damage_mult` or
   `damage`, `reach_bonus`, `arc_deg`, `shatter_props`, `damage_per_heat`, `vent_to`, `shove_from` ("caster").
3. **dash** *(exists, extended)* — Sets a velocity for `dash_time`. Each frame while dashing: if `pass_through`,
   enemies are ignored for collision and `on_pass` is applied once to each one overlapped; if `carry`, the first
   enemy met is moved with the caster and released with the payload at the end; if `trail`, a ground zone
   segment is dropped every metre. Then `recovery`. Keys: `dash_speed`, `dash_time`, `pass_through`, `on_pass`,
   `carry`, `trail` (a zone definition), `gain_pips`, `no_recovery`.
4. **targeted_strike** — Needs an enemy (hovered or locked) within `range`. Moves the caster to strike distance
   over at most 0.15 s (or, with `through`, to `through_dist` behind the target), waits `windup`, applies the
   payload to that one enemy. If `consume_status` is set, removes that status first and adds `per_stack_damage`
   and an optional `burst` (radius + payload). Keys: `range`, `damage_mult`, `through`, `through_dist`,
   `consume_status`, `per_stack_damage`, `burst`, `spend_pips`, `pip_mult`, `force_rear`.
5. **beam** — One instant ray from the caster along the facing, `range` long, `width` wide. Stops at walls and
   stone; hits the first enemy, or all of them if `pierce`. Draws a line for 0.1 s. Keys: `range`, `width`, `damage`, `pierce`.
6. **chain** — Applies the payload to the target, then repeatedly to the nearest not-yet-hit enemy within
   `jump_range` of the last one, `jumps` times, 0.05 s apart. Keys: `range`, `jumps`, `jump_range`, `damage`.
7. **blink** — Clamps the cursor point to `range`, refuses a point inside a wall or stone, moves the caster
   there in one frame, applies `on_arrive` to enemies within `arrive_radius`, then `recovery`. Keys: `range`,
   `arrive_radius`, `on_arrive`, `through_props`.
8. **channel** — While the key is held and essence lasts: each frame charges `cost_per_s x delta` (and its
   reflux), scales movement by `move_factor` and turning by `turn_rate`; every `tick` seconds applies the
   payload to the shape — `line` (first enemy or all), `cone`, or `nearest` (within `radius`). Ends on release,
   empty essence, a lock, or `pip_cost_per_s` running out. Keys: `shape`, `length`, `width` or `arc_deg`,
   `radius`, `tick`, `damage_per_s`, `push_per_s`, `pinned_mult`, `move_factor`, `turn_rate`, `pip_cost_per_s`.
9. **charge_release** — Key down starts a charge (movement scaled by `move_factor`, `braced` if set); each
   frame the charge grows toward `charge_max`. Key up fires `release`, which is another behaviour's definition
   (`beam`, or a lobbed `delayed_blast`), with damage and marks interpolated between `min` and `max`. Keys:
   `charge_max`, `move_factor`, `release`, `damage_min`, `damage_max`, `steps` (for marks).
10. **ground_zone** — Spawns a zone node at a point (`circle`, radius) or from the caster (`lane`, length x
    width) for `duration`. Every `tick` it applies the payload to enemies inside; each frame it applies its
    continuous effects — `slow`, `push_per_s` along the lane, `shove_mult`, `projectile_speed_mult`, and
    `caster_speed_mult` / `pip_gain_mult` for the caster. Enemy pathing treats damaging zones as costly.
    Keys: as named, plus `range`, `tick`, `damage_per_s`.
11. **prop** — Spawns a static body at a point after `rise_time`: `shape` slab / column / rod / rubble, with
    `hp`, `duration`, `blocks_movement`, `blocks_shots`. Keeps a per-caster list and frees the oldest past
    `max_count`. `on_rise` payload hits enemies standing there. A prop with `relay` listens for the caster's
    casts of `relay_affinity` within `relay_radius` and applies `relay_hit` to the nearest enemy within
    `relay_range`. `shatter()` applies the shrapnel cone and frees it. Keys: as named, plus `shrapnel`.
12. **delayed_blast** — Draws a ground marker at a point for `delay`, then applies the payload once to
    everything in `radius`. Options: `kill_projectiles`, `bonus_vs_status` + `bonus_damage`, `leave_prop` (a prop
    definition), `shatter_props`. Keys: as named, plus `range`.
13. **displace** — Moves enemies without needing damage. `shape` single / circle at a point; `vector` toward
    caster / toward point / away / up. Starts a shove of `distance` on each (Appendix B does the travel and
    the Crush), or applies Aloft for `aloft_time`. Keys: `range`, `radius`, `distance`, `stop_short`,
    `turn_target`, `aloft_time`, `spend_pips`, `pip_time`.
14. **self_buff** — Adds a timed effect object to `player.effects` (the same hook pipeline talents use), removed
    after `duration` or `charges`. The effect implements only what it needs: `on_incoming` (scale, retaliate),
    `on_outgoing` (add a status to base strikes), `on_tick`. Re-casting refreshes, never stacks. Keys:
    `duration`, `charges`, `incoming_mult`, `retaliate` (payload), `strike_status`, `strike_every`,
    `move_speed_mult`, `braced`, `deflect_projectiles`, `freeze_pips`, `add_reflux`.
15. **detonate** — Finds every enemy within `radius` carrying `status`, removes or reduces it, and for each
    stack applies `per_stack` (payload, optionally with its own burst radius) or triggers the status's own
    finisher scaled by `scale_by_stacks`. Keys: `radius`, `status`, `per_stack`, `leave_stacks`,
    `trigger` ("overload"), `scale_by_stacks`, `grounds_reflux`.

## Appendix B — shared pieces the behaviours rely on

**Hit payload (`on_hit`)** — one dictionary used everywhere a skill touches an enemy:
`damage` or `damage_mult`, `status` + `stacks`, `shove` (metres) + `shove_dir` (away / toward / aim),
`poise` (default 15), `interrupts` (bool), `marks`. One function, `Player.apply_hit(target, payload, tags)`,
calls `deal_damage` and then the status, shove, poise and interrupt calls on the enemy.

**Status set on enemies** — a small object on `enemy.gd` holding `{id: {stacks, time_left}}`, ticked in
`_physics_process`, defined in a new `game/data/statuses.json`:

| Status | Stacks | Lasts | Effect | Keys |
|---|---|---|---|---|
| Soaked | 1 | 6 s | Shoves on it x1.5 | `shove_mult` |
| Alight | 5 | 5 s, refreshed | 8 damage a second per stack, tagged `dot`, dealt through the caster's `deal_damage`; spreads 1 stack on death or after 1 s within 1.2 m | `dps_per_stack`, `spread_radius`, `spread_time` |
| Live | 3 | 8 s | At 3: Overload (150, stun 1 s, arc 60 to marked enemies within 12 m, grounds 12 reflux) | `overload_damage`, `stun`, `arc_damage`, `arc_radius`, `grounds` |
| Aloft | 1 | 1.2 s | Cannot act, +25% damage taken; light enemies only | `damage_taken_mult` |
| Staggered | 1 | 1.5 s | Cannot act, +30% damage taken, base strikes double | `damage_taken_mult`, `strike_mult` |

**Shove** — the enemy is given a velocity of 14 m/s along a direction and a distance budget; each frame the
budget falls; on a collision with world, stone or another enemy while budget remains, Crush is applied and the
shove ends. Scaled by `shove_resist` in `enemies.json` (1.0 light, 0.5 heavy, 0.25 elite).

**Per-affinity rules** — new keys on each entry in `affinities.json`: `reflux_shed_mult_combat`,
`shed_requires_moving`, `damage_per_reflux` (fire), `shed_on_overload` (lightning). Slipstream lives on the
player (`pips`, gained in `_physics_process` from distance moved) and exists only if wind is held.

**Enemy data** — new keys in `enemies.json`: `poise`, `turn_rate`, `shove_resist`, `weight` (light / heavy /
elite), `front_block`, `behaviour` (melee / ranged / pouncer / support / burster), `keep_range`,
`attacks` (list of `{windup, damage, shape, interruptible, heavy}`), `aura`, `on_death`, `phases`.

**Concept rules per skill** — an optional `concepts` block on an ability
(`"concepts": {"piercing": {"pierce": 99}, "reach": {"arc_deg": 180, "reach_bonus": 2.2}}`) that
`ability_stats` applies instead of the generic multipliers in `constructs.json`; `preview_bind` already shows
before and after for any key it is taught to label.

**Not specified here, on purpose**: the health pool and wounds (separate redesign), talent interactions
(Furnace Gut vents reflux at the cap and will want a second look once fire runs on heat), and icons.
