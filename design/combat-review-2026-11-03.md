# Combat review: why the fights "feel a little not fun" (2026-11-03)

Brent's request (2026-11-03) [B]: "Lets focus on combat. Can you do a full review of our combat mechanics
against industry standards like D3 / D4? It feels a little not fun." Later, in his own words [B]: "it just doesn't
feel like there is much I can do to influence these fights. The skills seem hard to use." The look and feel he
wants is BG3 / Diablo 4 (CLAUDE.md "Style") [B].

This is a review, not a build. No game code or data was changed. Every number below is from the game's own data,
from reading the code, or from a headless probe that ran the real game (see section 8). Provenance tags follow
CLAUDE.md rule 2. "Measured" means a scripted player in a headless run: it proves what the numbers do to a
scripted player, **not** how the fights feel. Everything about feel is **untested - needs Brent**.

---

## 0. The short version

**A new character has almost nothing to decide in a fight.** It starts with a 20-essence tank [B], and its starter
skills cost 6-14. Nothing refills essence during a fight: no regeneration, no generator strike, nothing from a kill.
The only refill is meditation, and that roots you and stops for a second after every hit. So a new character
casts once or twice per fight. It spends the rest of the fight clicking the nearest enemy with a free bare strike.
That strike hits one target and does roughly what a ranged starter skill does. The character has no free evade.
Its dash costs essence it does not have, and it has no potion and no healing beyond 1% lifesteal. Against that,
enemies take 240-520 health per fight-minute off a 100-health body.

The measurements below put numbers on "not much I can do to influence these fights":

| What a new character does (8 base affinities, 3 places) | Stubble | Arena | Passage |
|---|---|---|---|
| Fight time with too little essence to cast anything, even after meditating to full between fights | **95%** | **96%** | **94%** |
| Skill casts per fight-minute (bare strikes per fight-minute) | 14 (114) | 11 (96) | 21 (118) |
| Share of the damage done by skills | **10%** | **9%** | **19%** |
| Health lost per fight-minute, from a 100-health body | 345 | 298 | 520 |
| Characters that died | **8 of 8**, at about 77 s | **8 of 8**, at wave 3-4 | **7 of 8**, at wall 3 |

[MODEL, measured]

At the middle of the curve the wall moves. A two-star character with a Dim Mote, four skills at stage 2 and a
139-essence tank casts plenty, and skills do 47-74% of its damage. But **40% of its key presses are refused
because reflux has locked the affinity** (water, fire, death and dark). It must then sit and meditate in the
middle of the fight to get the affinity back. [MODEL, measured]

The setting already points at the fix. The systems bible says essence is "harvested from kills" [F]. It says reflux,
not an empty tank, "is the real limiter on sustained casting" [F]. It also says raw essence manipulation is "always
available, weak, safe" [F]. The design for working reflux off by striking (design/05 6.3) meant fights to go
"cast, strike, strike, cast". That cannot happen while strikes refill nothing and the tank is the limit.

**Top five causes** (section 6):
1. Essence starvation: skills are a garnish for a new character.
2. No defensive agency: no free evade, no in-fight healing, no potion.
3. Skills barely beat the free strike, and the strike is single-target.
4. Lockout cliffs at both ends: an empty tank early, a reflux lock later.
5. Hard to use at the edges: no walk-into-reach, slow shots that miss, your own stone eats your shots, and a
   refusal is shown only as a log line.

Also lower down: thin packs, weak death feedback with no sound at all, and slow, invisible growth.

**Top recommendations** (section 7): strikes gather essence, plus an essence mote from every kill. Cheaper and
stronger starters. Strikes and combat shed reflux faster. A free, non-invulnerable sidestep priced in reflux.
Close skills walk you into reach, and slow shots get a little aim help. Draughts that heal the bar in a fight.
A juice pass with sound and death bursts. Then density and elites.

---

## 1. Agency and skill usability (Brent's words first)

### 1.1 Can the player change a fight's outcome by choice?

The table lists the tools a new character can actually reach in a fight. Each one needs a skill pick and the
essence to cast it.

| Tool | Where it is in Ether Syntax | Can a new character use it in a fight? | D4 equivalent |
|---|---|---|---|
| Free defensive move | None. Dashes cost 6-10 essence, are not invulnerable ("you avoid a hit by not being there", design/05 6.3) [B] and a second one within 2.5 s costs double (Winded) | Rarely: the dash costs half the tank | **Evade**: every class has it, free, about a 5 s cooldown ([Fextralife](https://diablo4.wiki.fextralife.com/Evade)) |
| Interrupts | Riptide Lash, Kiln Fist, Slingstone, and a poise break. Enemy wind-ups: grunt 0.45 s, brute slam 1.2 s, archer draw 1.0 s, beast charges 1.0-1.2 s (enemies.json) [MODEL] | Once per tank, if that skill was picked | CC skills on cooldowns; bosses have a stagger bar ([PureDiablo](https://www.purediablo.com/diablo4/Stagger_Meter)) |
| Crowd control | Shoves (water), Taunt (earth), Spent slow (life), Soaked, stagger at zero poise | Once or twice per fight | Many CC skills on 8-20 s cooldowns; Unstoppable to break CC ([Icy Veins](https://www.icy-veins.com/d4/guides/crowd-control-status-effects/)) |
| Positioning | Rear hits +30%; enemies turn at 240 deg/s; slot ring of 6; Water Crush against walls; Earth stone | Yes, with bare strikes: the one real choice a new character has | Positioning matters less; density and AoE matter more |
| Sustain in a fight | 1% Lifesteal (the talent the probes used): about 1.3 health a second at full strike rate; Life's Wearying Sweep, 3 health per target; Fresh Stride, 3 a second | Measured: **16-30 health a run** across a whole fight sequence | Potions (4 charges at the start, more from Renown, refilled from drops and at wells [?]; [Upcomer](https://upcomer.com/how-to-get-more-healing-potion-charges-in-diablo-4)), life on hit, healing on kill |
| Damage choices | Strike the nearest; one skill per tank | The skill's damage is 1-2 strikes' worth (section 3) | Generators every second; spenders every 2-3 s; a cooldown "big moment" |

[MODEL, measured; genre references cited]

**Verdict.** The decision space of a new character in a fight comes down to where to stand and whom to click
next. Interrupts, CC and dashes exist and are well designed (telegraphs, white flashes for interruptible attacks,
rear arcs), but the tank lets a player use one of them once per fight. A D4 player gets a free evade every few
seconds and resource back from basic skills, so the defensive and offensive verbs come round again within one
engagement. That is the gap Brent is describing.

### 1.2 Are the skills hard to use?

These findings come from reading `Player.cast_ability`, `_skill_target`, `projectile.gd` and `hud.gd`, and from the
probe's counts. One check applies to them all: a "hit" is damage credited to that skill within 2 s of the press.

| Check | What the code does | Measured | Verdict |
|---|---|---|---|
| **Targeting** for target skills (Riptide Lash, Kiln Fist, Crosscut, Hungry Dark, Endstroke) | Takes the hovered enemy, else the clicked one, else the **nearest**; it is refused only if that one is out of reach (`_skill_target`) | Refused for reach in **15 of 3,300 presses** (0.5%) with a player who presses at "about 3.5 m" for melee and 12 m for ranged | Forgiving. Not the problem |
| **Reach of close skills** | Reach plus the target's radius: 3.1-3.5 m. A press out of reach is **refused with a log line, and you do not walk in** (bare strikes do walk you in) | Melee bursts touched nothing on **26-42%** of mid casts (Tsunami 74% hit, Landslide 74%, Wearying Sweep 58%) | **Hard to use.** D3/D4 walk you into range on a target press |
| **Slow and wind-up projectiles** | Straight line to where the cursor was, no lead and no homing; 0.35 m hit radius plus the target's radius | Slingstone (14 m/s, 0.3 s wind-up) hit **32%** of mid casts; Withering Needle (22 m/s) **14%** (cause not fully traced) [?]; fast or instant ones hit 91-98% (Cutting Gust, Dayline, Crosscut, Cinder Spit) | **Hard to use** for the slow ones |
| **Your own stone** | A thrown Slingstone that meets your own Pillar shatters it (by design) | Mid earth: Slingstone did 10 damage per cast to enemies, and its shrapnel did 476 | A trap a new player will not read: the shot "vanishes" into the stone |
| **Essence costs** | 6-14 out of a 20 tank; no regeneration in a fight | A player who does not watch the orb (presses once a second): **95% of presses refused**, "Not enough essence" | **The main lockout** |
| **Reflux** | Locks at 100 and opens below 60, only by meditating; sheds 0.5/s in a fight and 1 per landed strike; high-tier affinities add 1.4 reflux per essence | Mid: **1,312 of 3,298 presses refused by a reflux lock** | **The second lockout** |
| **Recovery locks** | 0.06-0.35 s plus wind-ups up to 0.5 s; dash recovery 0.25 s; the input buffer is 0.3 s | 78 presses (2%) were busy and dropped | Fine (the feel pass fixed this) |
| **Unclear effects** | Floating numbers, "back", "OPENING", status chips; an affinity's rule is only in text | Not measurable headless | Untested - needs Brent |
| **What a refusal looks like** | `note()`: a line in the corner log. The slot dims when unaffordable (`hud.gd` 275). No sound, no flash on the slot, no reason shown at the cursor | - | Weak. The player sees "nothing happened" |
| **Hotbar at creation** | Pick 2 of 3 (ranged, close, movement); 4 of 6 slots empty | With a 20 tank, the second skill is used once per fight; picking the movement skill leaves one attack a fight | A meaningful choice on paper, an empty one in play |

[MODEL, measured]

Skills that do no damage are left out of the hit rates: Standing Pool, Lay to Rest and Stoke's buff. Glint scored
0 hits in 47 casts. That may be a gap in the meter (its pass hits may not carry its id) and is not trusted [?].

### 1.3 How much of the outcome comes from skills?

| Tier | Damage from skills | Bare strikes | Sling | Statuses and other |
|---|---|---|---|---|
| New (1 star, 2 starters at stage 0) | **11%** | 86% | 2% | 1% |
| Mid (2 stars, 4 skills at stage 2, Dim Mote) | 63% | 34% | 2% | 1% |

[MODEL, measured: arena and passage, all eight bases]

For a new character, the outcome of a fight is almost entirely bare strikes. **Skills are not where the
player's influence lives until roughly the second star.** Measured in the Stubble, the first star grows
0.43% a minute, so it would take hours of play to get there (section 2.7).

---

## 2. The loop as it actually is

### 2.1 Actions per second

| Action | Numbers | Source |
|---|---|---|
| Bare strike | 60 damage, every 0.45 s, about 133 per second; reach 2.3 m plus the target's radius; **one target**; 20 poise; sheds 1 reflux; +30% from behind; 2x on a staggered target (Opening) | balance.json "player", "combat" [MODEL] |
| Overcharge | Hold to charge up to 2 s; costs health and arm (self-harm) | balance.json "player" [MODEL] |
| Sling (ranged stance) | 45 damage every 0.8 s, 12 m; free | items.json cord_sling [MODEL] |
| Skills | **No cooldowns at all**: gated only by cost, recovery (0.06-0.35 s) and wind-ups (up to 0.5 s) | abilities.json [MODEL] |
| Movement skills | 6-10 essence; 0.25 s recovery; a second inside 2.5 s costs double; **priced through reflux, not a cooldown** | design/05 6.3 [B] |
| Measured | New: 96-118 strikes and 11-21 casts per fight-minute. Mid: 47-84 strikes and 100-260 casts per fight-minute | probe [MODEL, measured] |

### 2.2 The resource economy

- **The tank.** A baby star starts at 20% of a 100 tank, so **20 essence** [B]. A full first star holds 99 [B].
- **Costs.** The 24 base starters cost 6-14 (median 8). One tank buys **1-3 casts**.
- **What refills essence:**
  - **Meditation:** 4 a second, only after 0.8 s sitting still, and blocked for 1 s after any hit. A 20 tank takes
    about 5 s of sitting to fill [B for the rule, MODEL for the numbers].
  - **Satellites:** a Dim Mote gives 1 a second (2,400 in the shop, out of 10,000 starting money). A fresh
    character has none [B].
  - **Kills:** nothing, except three skills that pay essence on a kill (Hungry Dark's swallow, +4, and two others).
  - **Strikes:** nothing. They shed 1 reflux, which a new character never builds up.
- **Reflux.** Each cast adds cost x 0.4-1.4. It sheds 0.5 a second in a fight, 1.5 out of one and 6 while
  meditating. It costs more from 50, recovers slower from 80, and locks at 100 until it drops below 60. A new
  character can make at most 20 x 1.4 = 28 reflux per tank, so **reflux never matters at one star**. At two
  stars plus a satellite it is the wall.
- **Time to dry, and time dry.** From a full tank a new character is dry after its first one or two casts, in the
  opening seconds of a fight. It then spends **94-96% of fight time below the cheapest cost**, even with the
  scripted player meditating to full between every fight.

### 2.3 Enemies

| Place | What is in a fight | Enemies within 10 m (mean, max) | TTK, new character (first hit to death) | TTK, mid character |
|---|---|---|---|---|
| Stubble (unstarred beasts, camp strength 0.6-0.9) | 2-5 per camp; a Gleaner can fetch a second camp | 1.9 (6); 1-2 enemies **76%** of fight time | wren 1.4 s, hound 2.7 s, beetle 2.8 s, lurker 1.7 s, **hog 9.5 s** | wren 0.5, beetle 1.1, hound 2.9, hog 4.4 s |
| Arena waves | wave n: 2+n grunts, plus brutes, archers, harriers, pavises, censer, drummer | 2.4 (8-11) | grunt 1.1 s, archer 1.4, harrier 0.9, **brute 11.6 s**, pavise 2.8 | grunt 0.9, brute 5.4, pavise 2.3 |
| Passage walls | 2 + wall/2 grunts plus each wall's recipe (design/05 6.2) | 3.1 (6) | grunt 1.5 s, archer 1.3, pavise 5.1 | grunt 0.6, brute 4.1, pavise 2.1 |

[MODEL, measured]

- **Telegraphs.** Grunt and beast swings show only a "swing" flag, white when interruptible, with no shape on the
  floor. Brute slams are a circle (1.2 s). Archers draw a line (1.0 s). Charges show a lane (1.0-1.2 s). A swing
  misses if you step out of reach or behind before it lands (`enemy._land_melee`). But enemy reach (2.3 m)
  equals the player's, so stepping out costs a strike.
- **Slots.** At most 6 melee enemies close in; the rest wait at 4.5 m.
- **Poise.** Beasts have 90-400 poise against 20 per strike. It refills at 30 a second after 3 s unhit, and a
  stagger lasts 1.5 s with +30% damage taken. A Thornback needs 20 strikes in a row to stagger.
- **Elites.** Only the Wall Commander, at walls 5 and 10, with phases. There are **no affixed elites or champions,
  and none in the Stubble.**

### 2.4 Movement and mobility

- Running speed is **6.5 m/s**.
- Dashes cost essence and are not invulnerable.
- Wind's Slipstream gives +10% speed at 5 pips.
- **Measured walking:** 30% of Stubble play (camps are 40-60 m apart), 13% of passage play and 0% in the arena
  [MODEL, measured]. The Stubble's walk share is in the genre's normal range; walking is not the main problem.

### 2.5 Health, wounds and healing in a fight

- The body has **100 health** [MODEL].
- **Wounds.** A blow of 20 or more, or one that leaves you under 20%, cuts the ceiling by 8% for the wound's
  life. Its hidden sink must be healed [B for the rule].
- **Healing in a fight:**
  - natural healing never applies in a fight [B];
  - field dressings work out of combat only;
  - **nothing restores health during a fight except talents and Life skills**.
- **Measured in-fight healing:** 16-30 health a run for a new character (lifesteal) and 17-60 for mid, against
  240-520 lost per fight-minute.
- **Enemy damage.** Grunt 10 per 1.3 s; archer 17. Six grunts in the ring deal about 46 a second.
- **Killing blows.** The last six blows before each death were mostly ordinary swings: grunts (10), archers (17),
  pavises (14) and hounds (9-18). No single "unfair" blow; **death by attrition** with no way to stop it.

### 2.6 Feedback

The game has:
- floating numbers, tinted for a rear hit or an Opening;
- a 0.05 s hit-stop on landed melee hits (0.09 s heavy);
- a camera nudge of 0.06 m (0.14 m heavy);
- a body flash and stagger pose;
- a corpse that lies 8 s (20 s for Death) and sinks.

It does **not** have:
- **any audio:** no `AudioStream` exists anywhere in `game/scripts`;
- **particles:** no `GPUParticles`/`CPUParticles` either;
- death bursts, gibs or knockback on a kill;
- loot beams;
- a kill counter or streak.

[MODEL, read from code]

### 2.7 Rewards and growth

| Per minute of play | Stubble, new | Arena, new | Passage, new |
|---|---|---|---|
| Kills | 10.0 | 17.2 | 16.0 |
| Remains value picked up (sold in town only, [B]) | 136 | 201 | 292 |
| Star growth (% of capacity) | **0.43** | 3.2 | 2.8 |
| Skill bar progress (sum over skills; 100 fills a bar, which then needs a vestige) | 46 | 51 | 80 |

[MODEL, measured]

- **The first star.** It must grow 20% to 99%. At the Stubble's 0.43% a minute that is **about 3 hours**. In
  practice it is longer, because unstarred aura falls to 25% as the star fills (balance.json "unstarred") and
  meditation adds only 0.3% a minute. Brent's own target was "about two hours" for the second star [B]
  (balance.json "stars" `_note`).
- **Skill points.** One per 10% of star growth means **one skill point about every 23 minutes** in the Stubble.
- **What a kill pays visibly.** A few remains on the ground; no aura or essence number is shown.

---

## 3. What a skill is worth against the free strike

| Starter | Cost (% of a baby tank) | Damage to the main target | In bare strikes | Area | Damage per essence |
|---|---|---|---|---|---|
| Riptide Lash (water, ranged) | 12 (60%) | 60 | **1.0x** | one | 5.0 |
| Tsunami Strike (water, close) | 12 (60%) | 144 | 2.4x | 120 deg arc | 12.0 |
| Cinder Spit (fire, ranged) | 7 (35%) | 55 | **0.9x** | one | 7.9 |
| Kiln Fist (fire, close) | 14 (70%) | 180 (+45 per stack of Alight) | 3.0x | burst 2.5 m if Alight | 12.9 |
| Slingstone (earth, ranged) | 8 (40%) | 70 | 1.2x | one | 8.8 |
| Landslide Blow (earth, close) | 12 (60%) | 120 | 2.0x | 100 deg arc | 10.0 |
| Cutting Gust (wind, ranged) | 7 (35%) | 45 (+15 a pip) | **0.75x** | pierces | 6.4 |
| Crosscut (wind, close) | 7 (35%) | 96 | 1.6x | one | 13.7 |
| Blot (dark, ranged) | 8 (40%) | 60 | 1.0x | one, plus a Dark zone | 7.5 |
| Hungry Dark (dark, close) | 10 (50%) | 132 | 2.2x | one | 13.2 |
| Withering Needle (life, ranged) | 7 (35%) | 45 plus 7/s | **0.75x** | one | 6.4 |
| Wearying Sweep (life, close) | 10 (50%) | 102 | 1.7x | 360 deg, 3 m | 10.2 |
| Rotting Bolt (death, ranged) | 8 (40%) | 50 | **0.8x** | one (60 burst on a corpse) | 6.2 |
| Endstroke (death, close) | 12 (60%) | 120 | 2.0x | one | 10.0 |
| Dayline (light, ranged) | 7 (35%) | 60 | 1.0x | first on a 16 m line | 8.6 |
| Noonburst (light, close) | 10 (50%) | 108 | 1.8x | 360 deg, 3.5 m | 10.8 |

[MODEL, from abilities.json; strike = 60]

- **Ranged starters.** Every ranged starter does 0.75-1.2 strikes of damage for 35-60% of the tank. To a new
  player, pressing one feels like a slightly louder click.
- **Close starters.** They are better: 1.6-3.0 strikes, several with arcs. But they share the reach problem of
  section 1.2.
- **Movement starters.** Hydraulic Flex, Flashover, Bedrock Shove, Tailwind, Fresh Stride, Shadow Slip, Gravestep
  and Glint do little or no damage and spend the essence that would buy an attack.

---

## 4. Measurements

### 4.1 By place, tier and policy

Each row is the mean over its runs.

- **Policies.**
  - `A`/`P`/`S`: a careful player that meditates to full and rests to 70% health between fights.
  - `nomed-eager`: never meditates and presses unaffordable skills once a second.
  - `dash`: dodges telegraphs with its movement skill.
- **"Dry"** means fight time with essence below the cheapest skill on the bar.
- **"Touched nothing"** is the share of damaging casts that dealt no damage within 2 s.

| place | tier | policy | runs | died | survived s | fight % | walk % | meditate % | kills/min | casts / fight-min | strikes / fight-min | skill share | dry | touched nothing | HP lost / fight-min | in-fight heal / run | enemies within 10 m mean (max) | fight length s |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Stubble | new | S | 8 | 8 | 77 | 44% | 30% | 15% | 10.0 | 13.7 | 114 | 10% | **95%** | 0% | 345 | 21 | 1.9 (6) | 7.9 |
| Stubble | new | nomed-eager | 1 | 1 | 62 | 51% | 37% | 0% | 9.6 | 1.9 | 117 | 2% | **100%** | 0% | 338 | 18 | 2.4 (6) | 8.0 |
| Stubble | mid | S | 2 | 1 | 185 | 22% | 27% | 44% | 8.1 | 101 | 84 | 47% | 0% | 30% | 328 | 23 | 1.7 (5) | 4.9 |
| Arena | new | A | 8 | 8 | 58 | 60% | 0% | 15% | 17.2 | 11.0 | 96 | 9% | **96%** | 12% | 298 | 30 | 2.4 (8) | 10.6 |
| Arena | new | nomed-eager | 2 | 2 | 36 | 72% | 0% | 0% | 23.4 | 3.4 | 108 | 3% | **98%** | 0% | 316 | 23 | 2.5 (6) | 8.6 |
| Arena | mid | A | 8 | 7 | 132 | 32% | 0% | 45% | 13.6 | 150 | 63 | 54% | 15% | 30% | 261 | 60 | 2.4 (11) | 9.6 |
| Arena | mid | A, dash dodge | 1 | 1 | 121 | 31% | 0% | 55% | 11.9 | 116 | 80 | 42% | 0% | 54% | 321 | 33 | 2.4 (5) | 9.3 |
| Passage | new | P | 8 | 7 | 34 | 47% | 13% | 24% | 16.0 | 21.3 | 118 | 19% | **94%** | 0% | 520 | 16 | 3.1 (6) | 5.3 |
| Passage | mid | P | 8 | 1 | 90 | 21% | 5% | **62%** | 12.7 | 258 | 47 | 74% | 2% | 31% | 234 | 17 | 2.8 (7) | 4.5 |

[MODEL, measured]

Read the mid rows with the meditate column. Mid characters spend 45-62% of their time sitting to refill and to
unlock reflux.

### 4.2 Press outcomes

| Tier | Presses | Cast | Refused: no essence | Refused: reflux lock | Refused: no target in reach | Busy (buffer lapsed) |
|---|---|---|---|---|---|---|
| New, careful (arena and passage, 16 runs) | 98 | 95 | 0 (it only presses when it can pay) | 0 | 3 | 0 |
| New, eager (presses when dry; 2 arena runs plus 1 Stubble run) | 165 | 4 | **160 (97%)** | 0 | 1 | 0 |
| Mid, careful | 3,099 | 1,619 | 79 | **1,312** (water 570, death 332, fire 217, dark 139, life 16) | 11 | 78 |

[MODEL, measured]

### 4.3 How many enemies are in a fight at once

The table is the share of fight time with N enemies within 10 m.

| Place, tier | 0 | 1 | 2 | 3 | 4 | 5 | 6+ |
|---|---|---|---|---|---|---|---|
| Stubble, new | 2% | 37% | 39% | 11% | 8% | 2% | 1% |
| Arena, new | 5% | 31% | 29% | 14% | 10% | 5% | 6% |
| Passage, new | 0% | 18% | 19% | 22% | 21% | 12% | 8% |

[MODEL, measured]

### 4.4 What-if runs (in memory only; no data file changed)

The probe can change numbers in memory for one run: enemy health through `--whatif_hp`, and a "generator" through
`--whatif_strike_essence`, which gives each landed bare strike some essence back. The what-if rows use a player
that also steps off archers' drawn aim lines (`--lines=1`) and never meditates.

| What-if (new character, 4 runs each unless noted) | Died | Survived s | Casts / fight-min | Skill share | HP lost / fight-min | Kills / min |
|---|---|---|---|---|---|---|
| Arena, baseline A (meditates, does not read archer lines), 8 runs | 8 | 58 | 11.0 | 9% | 298 | 17.2 |
| Arena, **also steps off archer lines** (W0) | 4 | **114** | 8.1 | 7% | **209** | 16.9 |
| Arena, lines + **+2 essence per landed strike**, no meditation (W1) | 4 | 53 | **25.8** | **20%** | 217 | 22.9 |
| Arena, W1 + **every enemy at 60% health** (W2) | 4 | 62 | 24.6 | 19% | 245 | 23.5 |
| Passage, baseline P (meditates), 8 runs | 7 | 34 | 21.3 | 19% | 520 | 16.0 |
| Passage, W1 (generator, lines, no meditation) | **1** (3 cleared 4 walls) | 55 | 28.5 | 20% | **251** | 20.2 |
| Stubble, baseline S (rest to 70%), 8 runs | 8 | 77 | 13.7 | 10% | 345 | 10.0 |
| Stubble, **rest to full health** between fights | **4** | 85 | 13.2 | 9% | 331 | 9.1 |
| Stubble, generator + rest to full, 2 runs | **0** (both walked on until the walker stuck, at about 210 s) | 212 | **28.8** | 18% | 324 | 6.8 |

[MODEL, measured; n is small (2-4), so read these as direction, not size]

**What the what-ifs say:**

- **Resting to full does not save the new character in the Stubble.** It still dies on the fourth to sixth
  fight, so the deaths are the loop's, not the probe's impatience.
- **Reading the archers' lines doubles survival in the arena** (58 s to 114 s). The drawn telegraphs *are*
  real agency where they exist. Grunts and beasts have none drawn (Q5).
- **A generator triples casting and doubles the skills' share**: 8-14 to 25-29 casts per fight-minute, and 7-10%
  to 18-20% of damage.
  - **The passage and the Stubble:** it turned most deaths into clears.
  - **The arena:** it did not help survival. Without meditation and with constant casting, the scripted player
    stood in the ring longer.
  - **Not enough alone:** a generator needs a defensive answer beside it (R3, R5).
- **Cutting enemy health to 60% did not change survival.** The new character dies to incoming damage it cannot
  answer, not to slow kills.
- **A caveat on "dry":** with a generator, a player who spends the moment a skill is affordable hovers just under
  the cost, so "dry" stays above 90%. **Casts per fight-minute** is the honest measure of R1, not "dry".

---

## 5. Against the genre

| Axis | Ether Syntax now | Diablo 4 | Diablo 3 | PoE / Last Epoch / Grim Dawn | Gap |
|---|---|---|---|---|---|
| **Resource model** | One pool per character; 20 at the start; **no in-fight refill**; reflux heat per affinity | Basic skills *generate* (Barbarian Fury, Druid Spirit); Sorcerer Mana and Rogue Energy *regenerate* in combat ([Maxroll](https://maxroll.gg/d4/resources/barbarian-class-overview), [Game8](https://game8.co/games/Diablo-4/archives/414369)) | Primary resources generated by primary skills (Fury, Spirit) or regenerating (Arcane Power, Mana); Demon Hunter's Hatred plus a second pool, Discipline | PoE mana regen plus mana on hit and flask charges on kill; Last Epoch regenerating mana; Grim Dawn energy regen | **Largest gap.** Every genre reference gives the resource back during a fight |
| **Cooldowns vs cost** | Cost only (plus reflux) | Both: cheap spenders, plus cooldown skills (Teleport about 14 s, Leap about 17 s [?] per [PureDiablo](https://www.purediablo.com/diablo4/Teleport)) | Both | Both | A cooldown "big moment" is missing. Reflux can play that part (section 7) |
| **Density and pack size** | 1-3 enemies in range most of the time; camps of 2-5 | Packs of many trash plus an elite and its minions ([PureDiablo](https://purediablo.com/diablo4/Monster_Affixes)) | Dense packs, globe drops | PoE very dense | Thin. But density must come *after* the player can survive it |
| **TTK, trash vs elites** | New: trash 1.1-2.8 s, a hog 9.5 s, a brute 11.6 s; no elites in the Stubble | Trash in one or two hits at level, elites take longer [?] | Same shape | Same shape | Trash TTK is fine for single targets; it is the *one at a time* that is slow |
| **AoE vs single target** | The basic attack is **single target**; AoE only in skills (rare for a new character) | Basic skills often cleave; spenders are AoE | Primary skills often hit several | AoE is the norm | No cleave on the free attack |
| **Mobility** | 6.5 m/s; dashes cost essence; no free evade | **Evade** about 5 s cooldown, free, every class ([Fextralife](https://diablo4.wiki.fextralife.com/Evade)); movement-speed affixes | Mobility skills; no universal evade | Last Epoch a traversal skill on cooldown; PoE 2 a free dodge roll | No free defensive move |
| **CC and stagger bar** | Poise and stagger, interrupts, shoves, taunt | CC on enemies; bosses immune but fill a **stagger bar**; Unstoppable for the player ([PureDiablo](https://www.purediablo.com/diablo4/Stagger_Meter), [Icy Veins](https://www.icy-veins.com/d4/guides/crowd-control-status-effects/)) | CC with diminishing returns on elites [?] | Varied | Ours is good *design*; the new character can afford to use it once a fight |
| **Elites and champions with affixes** | Only the Wall Commander (phased); none in the Stubble | Elites with 1-3 affixes (Maxroll) or up to 4 (Fextralife) [?], with minions ([Maxroll](https://maxroll.gg/d4/resources/elites-affixes)) | Champion and rare packs with affixes | PoE rare mods | No "pack with a twist" moment |
| **Healing** | 100 health; no potion; lifesteal 1%; natural healing out of combat only [B] | Potions: 4 charges to start, up to about 10 [?], refilled from drops and wells ([Upcomer](https://upcomer.com/how-to-get-more-healing-potion-charges-in-diablo-4)); life on hit / on kill | Health globes from kills (about 10-15% each [?], [Diablo Wiki](https://diablo.fandom.com/wiki/Health_globes)) plus a potion | PoE 2 flasks refill from kills ([PoE2 Wiki](https://www.poe2wiki.net/wiki/Flask)) | **No in-fight recovery a player controls** |
| **Power-curve pacing** | First star to full: about 3+ hours in the Stubble; a skill point about every 23 min | Level ups every few minutes early; a new skill point per level | Same | Same | Growth is slow *and* invisible (no aura or growth number per kill) |
| **Loot cadence** | Remains on every kill; rare curios; money only from selling [B] | Frequent item drops; gold | Frequent drops; globes | Frequent drops | Remains are steady, but a kill gives no *instant* payoff |
| **Juice** | Numbers, 50 ms hit-stop, a camera nudge; **no sound, no particles**, corpses lie and sink | Sound on every hit; death physics, gibs, explosions; elemental death effects | Ragdolls, explosions, gibs | All of it | **Silent fights** are a large part of "not fun" (untested - needs Brent) |

Genre numbers are from community wikis and guides read on 2026-11-03. They vary between patches and seasons,
so treat each as approximate; `[?]` marks the uncertain ones.

---

## 6. Why it is "not fun": the causes, ranked by impact

1. **Essence starvation makes a new character's skills a garnish.**
   - **The evidence:**
     - dry 94-96% of fight time;
     - 11-21 casts per fight-minute against 96-118 strikes;
     - skills 9-19% of damage;
     - 95% of presses refused when the player does not watch the orb.
   - **The genre:** every reference refills the resource in a fight.
   - **Why it matters most:** this is Brent's "not much I can do to influence these fights". The skills are the
     choices, and the tank lets you make one per fight.
2. **No defensive agency.**
   - **The evidence:**
     - no free evade;
     - a dash costs 30-50% of the tank;
     - no potion;
     - 16-30 health of in-fight healing a run against 240-520 lost per fight-minute;
     - **23 of 24** new-character runs died, every one by attrition from ordinary swings, and **4 of 4** still died
    in the Stubble when resting to full between fights;
  - reading the archers' drawn lines doubled survival in the arena (section 4.4): agency exists where the
    telegraphs are drawn.
   - **The genre:** D4 gives every class a free Evade on about 5 s and potions; D3 gives globes; PoE 2 gives flasks
     on kill.
   - **What happens in play:** without these, a player who reads a telegraph has nothing to answer it with except
     walking away, which costs damage.
3. **Skills barely beat the free strike, and the strike is single-target.**
   - **The evidence:**
     - ranged starters do 0.75-1.2 strikes of damage for 35-60% of the tank;
     - the bare strike never hits more than one;
     - most fights are 1-3 enemies, so a "big moment" never happens.
   - **The genre:** a D4 spender is several times a generator's damage, and usually AoE.
4. **Lockout cliffs at both ends.**
   - **New:** an empty tank.
   - **Mid:** **40% of presses refused by a reflux lock**, and 45-62% of play spent meditating. The limiter flips
     from one wall to the other instead of shaping a rhythm. The design meant "cast, strike, strike, cast"
     (design/05 6.3); working it off at 1 reflux per strike against 1.4 per essence cannot keep up.
5. **Hard to use at the edges.**
   - **Reach:** close skills do not walk you into reach (refused instead), and melee bursts miss 26-42% at
     "about in range".
   - **Shots:** slow projectiles miss moving targets (Slingstone 32% hit).
   - **Your own stone:** it eats your Slingstone.
   - **Refusals:** shown only as a log line, with no sound or slot flash.
   - Targeting itself is forgiving; this is not the main cause, but it is what Brent feels when he says "the skills
     seem hard to use".
6. **Thin packs, no elites in the starting zone.**
   - 1-2 enemies 76% of Stubble fight time.
   - No affixed elites anywhere but the Wall Commander.
   - Lower than causes 1-3, because more enemies today would only kill the new character faster: the newbie
     already dies.
7. **Silent, low-juice kills.**
   - No audio and no particles; a death is a corpse that lies down and sinks.
   - Impact unmeasurable headless; probably larger than its rank suggests (untested - needs Brent).
8. **Slow, invisible growth.**
   - About 3+ hours to fill the first star in the Stubble; a skill point about every 23 minutes.
   - Kills show no growth number.
   - Matters for the session loop more than the fight loop.

What the evidence does **not** support:
- **Walking too much.** Walking is 30% of Stubble play, a normal share.
- **Bullet sponges as a general problem.** Grunt and beast TTK is 1-3 s. The exceptions are the hog, the brute and
  the Thornback.
- **Responsiveness.** Only 2% of presses lapsed in the buffer, and the feel pass already handled input.

---

## 7. Recommendations, ranked by fun gained per effort

Each recommendation gives:
- what it changes;
- the knobs or systems it touches;
- the setting rule it must respect;
- how to measure it.

The probe in section 8 measures each one: rerun it with the change and compare against section 4's baseline.

### 7.1 Quick data tweaks (numbers only, no new system)

| # | Change | Knobs | Setting rule | How we know it worked |
|---|---|---|---|---|
| Q1 | **Cheaper, stronger starters.** Ranged starters cost 4-5 and do at least 1.5x a strike; close starters cost 6-8 | The v2 drafts `design/data-drafts/skills-v2/*.json` via `tools/skills/emit_abilities.py` (abilities.json is generated) | None broken. Efficient abilities "look plain" [F], so a cheap skill can be plain | New tier: casts per fight-minute 11-21 up to at least 30; skill share 10% up to at least 30%; dry share of fight time 95% down to under 60% |
| Q2 | **Strikes and combat shed reflux faster**, so mid characters get a rhythm, not a lock: `strike_sheds_reflux` 1 -> 3, `reflux.shed_in_combat` 0.5 -> 2 | balance.json "combat", "reflux" | Reflux stays "the real limiter" [F]; the dash stays priced through reflux [B] | Mid: reflux-lock refusals 40% of presses down to under 10%; time spent meditating 45-62% down to under 25% |
| Q3 | **A faster, earlier breather.** Meditation 4/s -> 8/s; `settle_s` 0.8 -> 0.5; the block after a hit (1.0 s, `player._meditate_block`, currently in code) moved to data | balance.json "meditation" (and one constant into data) | Meditation still roots you [B] and still "gathers wisps" [B] | Time to refill a baby tank 5 s -> 2.5 s; mid meditation share down |
| Q4 | **Bigger first tank, if Brent agrees.** `first_star_start_pct` 20 -> 40 | balance.json "stars" | **Brent's ruling** [B]: the baby star "starts at 20% so it can still pay for one ability". Ask before changing | New tier: dry share down; casts per fight up |
| Q5 | **Draw the swing.** Give grunt and beast swings a small floor arc during the wind-up, as the brute circle does | `enemy._update_melee_telegraph` (one dictionary), hud drawing | None | Feel only: untested - needs Brent |

### 7.2 New systems (code), ranked

| # | Change | Knobs and systems | Setting rule | How we know it worked |
|---|---|---|---|---|
| **R1** | **Strikes gather essence** (a generator). Each landed bare strike gathers 1.5-2 essence: "raw essence manipulation", always available, weak, safe [F]. One line beside the strike's reflux shed in `Player.deal_damage`, and one number `combat.strike_gathers_essence` | `Player.deal_damage` (the bare-strike block), balance.json "combat" | **Fits** LAW 1b [F]; the strike stays the "working it off" move of design/05 | Already measured as what-if W1 (section 4.4): +2 per strike took casts per fight-minute from 8-14 to 25-29 and skill share from 7-10% to 18-20%, and turned most passage and Stubble deaths into clears. Target with Q1: at least 30 casts per fight-minute and a 30-50% skill share. Use casts per minute, not "dry" |
| **R2** | **Essence from kills.** A small mote rises from each kill, worth the kind's `aura_value` x k, gathered by walking through it (or auto within 2 m) | `Player._on_kill`, a pickup like the Netherecho wisp, balance.json | **Fits**: essence "harvested from kills" [F]; reads as a D3 globe but gives essence, not health | Kills per minute up (chains: kill -> cast -> kill); dry share down |
| **R3** | **A free sidestep.** A short (2.5-3 m), **not invulnerable** step on its own key, costing **reflux, not essence**, with Winded after two | `Player` dash code (exact distance), Keybinds, balance.json "combat" | **Fits** [B]: dashes are priced through reflux, not a cooldown, and are not invulnerable (design/05 6.3). It is not an i-frame roll, so the "no invulnerable rolls" choice stands | Deaths in the careful-player runs (23 of 24 now); health lost per fight-minute; feel needs Brent |
| **R4** | **Make skills land.** (a) A close skill pressed out of reach walks you in and casts, as a bare strike does, cancelled by any other input. (b) Slow projectiles lead the target a little, or get a wider hit radius. (c) Your own stone does not stop your own shots unless the skill asks. (d) A refusal flashes the slot and shows the reason at the cursor | `Player.cast_ability` (keep the target, walk, then cast), `projectile.gd` `hit_radius`, `stone.gd`, `hud.gd` | None | Cast that touched nothing: melee bursts 26-42% down to under 10%; Slingstone hit rate 32% up to over 80%; reach refusals 0 |
| **R5** | **Draughts that heal in a fight.** A consumable with charges, healing the **bar only, never a sink** (as natural healing), refilled in town or from kills | items.json consumable `use` (drop `out_of_combat`), `Player.use_consumable`, a hotbar slot | **Needs Brent's ruling**: CLAUDE.md "Health" says natural healing refills the bar only, and talent healing follows its own order. A draught that heals the bar only keeps wounds meaningful | Survival in the careful runs; feel needs Brent |
| **R6** | **Juice pass.** Sound on hit, kill and cast (CC0, recorded in MANIFEST); a death burst (particles in the affinity's colour); knockback on a killing blow; bigger, coloured numbers for skill hits | `game/assets/audio`, `tools/assets/MANIFEST.csv`, `enemy.gd` death path, `FloatText` | Asset rules: CC0 preferred, every file in the manifest; **downloads need Brent's yes each time** [B] | Untested - needs Brent |
| **R7** | **Density with a reason: swarms and one champion.** Stubble camps of 6-10 weak beasts (wrens at 0.4 strength) beside today's camps, and one *affixed* champion per camp (a few data affixes: Vampiric, Waller, Frenzied - our own names) | zones.json camps, enemies.json, a small affix table read in `enemy.setup` | The Stubble stays **unstarred** [B]; champions stay mortal-tier | Enemies within 10 m: 1.9 up to 3-5; kills per minute up; skill share up (AoE pays). **Do after R1-R3**, or the newbie dies faster |
| **R8** | **Show growth on a kill.** A small "+aura" or star-growth tick on a kill; a star-fill bar that visibly moves; a skill point sooner (`points.per_star_pct` 10 -> 5) | hud.gd, skill_tree.json "points" | Latent aura is hidden [B] ("cannot be tested externally"), so show the **star's capacity growth**, never the aura threshold | Time to first skill point, about 23 min down to about 10 min in the Stubble |

Ranking:
- **R1 + R2 + Q1 + Q2 are the core fix.** They give the player a resource rhythm, and every other change is
  worth more once the player can cast.
- **R3 + R5 give defensive agency.**
- **R4 makes the skills land.**
- **R6-R8 add the payoff.**

---

## 8. How this was measured, and how to rerun it

### 8.1 The probe

The probe scripts are in `C:\Users\qmsyntax\AppData\Local\Temp\claude\3c515764271446d6\030d1be6-e370-46d9-bc4f-8172e6305d16\scratchpad\combat-review\`.
They live outside the repo, so copy them somewhere permanent if they are to be kept.

| File | What it is |
|---|---|
| `README.md` | How to rerun (also below) |
| `run.gd` | A SceneTree launcher (`-s`) that loads the driver |
| `driver.gd` | The probe |
| `meter.gd` | A read-only `TalentEffect` appended to `player.effects`, which sees every hit dealt and taken |
| `batch.sh` | Runs configs one Godot at a time and appends to `results.jsonl` |
| `aggregate.py`, `summarise.py` | Tables |
| `configs-fast.txt` | Arena and passage |
| `configs-stubble.txt` | The Stubble |
| `configs-whatif.txt` | The what-if runs |
| `results-fast.jsonl`, `results-stubble.jsonl`, `results-whatif.jsonl` | The raw data |

What `driver.gd` does:
- Loads `main.tscn` in test mode, so no save is written.
- Makes a **real character** through `main.begin_character`, with 1% Lifesteal and the first two roots of one base
  affinity. It is **not invulnerable** and has no `bot` flag.
- Plays it as a careful new player:
  - strikes the nearest foe and slings at runners and archers;
  - steps out of drawn circles, cones, lanes and scald rings;
  - presses a skill through `Player.press_slot` (the real key path, with its buffer) when the foe "looks close
    enough" (3.5 m for close skills, 12 m otherwise);
  - between fights, picks up the remains, meditates to full and rests to 70% health.
- The **mid** character is two stars (99 + 40), the whole kit plus the first tier-2 skill, every skill at stage 2,
  a Dim Mote and Iron Knuckles [MODEL for this probe].

### 8.2 To rerun

Run from Git Bash, one Godot at a time:

```
cd <scratchpad>/combat-review
bash batch.sh configs-fast.txt        # about 10 minutes
bash batch.sh configs-stubble.txt     # about 10-60 minutes (the Stubble runs at about real time headless)
python -I aggregate.py results.jsonl
```

A single run:

```
<console exe> --headless --fixed-fps 60 --path game -s <scratchpad>/combat-review/run.gd -- --scenario=arena|stubble|passage --aff=water --tier=new|mid --meditate=1 --minutes=8
```

Options:
- `--press=eager`: press when dry.
- `--dodge=dash`: use the movement skill to dodge.
- `--lines=1`: step off archer aim lines.
- `--rest=1.0`: rest to full health.
- `--whatif_strike_essence=N`, `--whatif_hp=M`, `--whatif_sat=N`: in-memory what-ifs.

Each run prints one `PROBE {json}` line.

### 8.3 What was not measured, or is limited

- **Feel of any kind** (hit weight, readability, sound, whether a cast "feels" like it did something): untested -
  needs Brent.
- **A human's play.** The scripted player is careful but simple:
  - it never kites, never uses the Netherecho, never retreats from a fight and never uses the herd's neutrality;
  - it meditates only between fights;
  - it does not read swing wind-ups (only drawn shapes), and archer lines only with `--lines=1`.

  Death rates are therefore an **upper bound** for a skilled player and a fair picture for a new one.
- **The Stubble's chain pulls.** In the Stubble the scripted player visits the nearest live camp next and rests
  to 70% health. In every new run a Gleaner fetched the sounder into the well-watch fight, and death came around
  the fourth or fifth fight (hounds and wrens). `newbie_duels` already shows singles and pairs are winnable; the
  probe shows the *run* of fights is not. Resting to full health between fights did not change that (4 of 4 died,
  section 4.4).
- **The Stubble walker sometimes sticks.** The probe's own walker stuck twice in the Stubble (mid water, and both
  generator runs) after 210-285 s. Those runs ended as "stuck", not as deaths, and their numbers cover the time
  before.
- **Hit detection.** A "hit" is damage carrying the skill's id within 2 s. Glint's 0 of 47 is probably a meter gap
  [?]. Withering Needle's 14% hit rate for the mid character was not traced to a cause [?].
- **Walls cleared for a passage death.** The game resets `cleared` when you wake in town. "Died at wall 3" is
  inferred from the kills (2 + 4 + part of wall 3) and the last blows (pavises), not read directly.
- **Not run:** two-affinity characters, hybrids, Holy and Unholy, thralls (Death's tier-2), and any rune words or
  keystones (every probe skill is unsealed).
- **D4/D3 numbers** are from community sources, approximate and patch-dependent (section 5).

---

## 9. Provenance summary

- `[B]` Brent's rulings used here:
  - the 20% baby star;
  - satellites are found or bought;
  - dashes priced through reflux, not cooldowns;
  - skills never hurt their caster;
  - money only from selling;
  - Health and wounds as in CLAUDE.md;
  - the Stubble stays unstarred;
  - meditation roots you;
  - his 2026-11-03 words.
- `[F]` from `design/01-systems-bible-v0.md` LAW 1b: essence harvested from kills; reflux the real limiter;
  raw essence manipulation always available and weak.
- `[MODEL]` everything else: every number in the game's data, the probe's policies and every recommendation.
- `[?]` the uncertain genre figures and the two meter gaps above.
