# Rune sets v0 — base runes per affinity, and the universal runes

Working draft with Brent, 2026-10-21. Nothing is built. Supersedes design/13 §2-3 (its 16 letters mixed concepts
with measures). design/13's cage, facets, flaws and forms are parked until this layer settles.
Tags: **[B]** Brent's ruling, **[C]** read in the books (paraphrased notes only), **[F]** fan source,
**[MODEL]** our invention. All rune names and meanings are original to this project.

## 1. The model [B 2026-10-21]

- **Two buckets.** **Base runes** belong to an affinity. **Universal runes** can be used by anyone.
- **The skill is the verb.** Every skill is built on one base rune of its affinity, delivered through a form (bolt,
  burst, dash, zone, beam, strike, buff...). Further runes are **added** to it as its means: the affinity's other base
  runes, and universal runes.
- **Combinations follow the effect · means idea.** The skill (its base rune) is the effect; each added rune reshapes
  how it is delivered.
- **Every base rune has an opposite**, inside its own affinity, so an affinity works its domain in both directions.
  The universal runes are paired too.
- **Base beats universal on its own ground** [MODEL]. Where a universal rune and a base rune mean much the same thing
  (universal Repel against water's Surge), the base rune is stronger and carries its affinity's rule.

## 2. Universal runes [B 2026-10-21: keep these as one table, no early or late]

What each does when added to a skill as a means.

| Rune | As a means | Opposite | As a means |
|---|---|---|---|
| **Motion** | it travels, or moves what it touches | **Stillness** | it is held in place; what it touches is held |
| **Haste** | sooner and faster | **Delay** | later: delayed, built up |
| **Curve** | it bends and seeks | **Straight** | a true line that cannot be turned aside |
| **Rise** | lifts | **Fall** | brings down, knocks flat |
| **Expand** | grows outward, bigger | **Contract** | draws inward, smaller and denser |
| **Near** | close, and stronger close | **Far** | at a distance, with reach |
| **Focus** | concentrated on a point or an edge | **Scatter** | spread wide |
| **One** | a single target takes all of it | **Many** | many targets, or many copies |
| **Within** | inside the target, past armour | **Without** | outside, around: a shell |
| **Here** | at the spot | **Elsewhere** | displaced: it lands, or moves you, somewhere else |
| **Persist** | lasts | **Fade** | short, ends early, stronger while it lasts |
| **Hold** | charged by holding it | **Loose** | let go at once |
| **Repeat** | happens again | **Once** | one time, all of it at once |
| **Before** | acts on what was: undo, rewind | **After** | acts on what comes: foresight, the next hit |
| **Bind** | joins, holds, tethers | **Sever** | cuts, separates |
| **Attract** | pulls toward | **Repel** | pushes away |
| **Give** | grants to the target | **Take** | takes from the target, to you |
| **Self** | acts on the caster | **Other** | acts on others |
| **Order** | makes form and structure | **Entropy** | unmakes it |
| **Pure** | cleanses | **Tainted** | corrupts, sickens |
| **Reveal** | shows | **Veil** | hides |
| **Calm** | soothes, steadies | **Fury** | enrages, frenzies |
| **Will** | commands | **Yield** | gives way: softens, absorbs, submits |
| **Remember** | marks and effects stick | **Forget** | loses track, lets go |
| **Essence** | carried by clean essence | **Reflux** | carried by spent heat |
| **Life** | carried by vitality | **Death** | carried by ending |
| **Soul** | strikes the soul | **Body** | strikes the flesh |
| **Fate** | certain | **Chance** | random |

28 pairs, 56 runes.

## 3. The affinities and their base runes

**[B 2026-10-21] The roster was too short, and every affinity gets a deep dive.** Each deep dive lives in
`design/affinities/<name>.md` and **replaces** that affinity's first-pass entry below. Done so far: **water**.

| Status | Affinities |
|---|---|
| Named in the reading notes [C] | fire, water, earth, wind, lightning, metal, light, blood, life, death [F], nature, dream, poison, disease (the notes' "miasma", renamed [B]) |
| Added by Brent [B] | **dark**, **ice** (ice takes water's Freeze) |
| Proposed, for Brent's yes or no [MODEL] | **sound** (vibration, sonic force, silence), **gravity** (weight, orbits, crushing), **space** (distance, folding, portals), **time** (haste, delay, rewind), **mind** (telekinesis, thought; dream keeps sleep and illusion), **beast** (claws, senses, the animal within), **spirit** (ghosts, constructs, the Netherecho itself: touches canon soul mechanics, so the riskiest) |
| Hybrids, not base affinities | perished water [C], life flame [F]; natural ones: steam (fire + water), magma (fire + earth), storm (wind + lightning), sand (earth + wind), mud (water + earth), ash (fire + death), crystal (earth + light) |
| Unique | fusion [C] |

The first-pass entries below are the original fourteen plus first passes for ice and dark (2026-10-22). Water's has been replaced by its deep dive. The rune workbook `design/runes-workbook.xlsx` holds every base rune with a character assigned, one sheet per affinity.

Each affinity has **one rule nobody else has** (design/05 §1 for the first five; [MODEL] for the rest) and **five
pairs** of base runes. "Skills" lists design/05's 40 skills on each rune; a dash means no skill yet, which is where
new skills come from.

### Water — moves bodies (shove and Crush)

| Rune | Opposite | Skills |
|---|---|---|
| **Surge**: push away | **Ebb**: draw in | Water Bolt, Breaker, Backwash / Undertow, Riptide Lash |
| **Flow**: liquid in motion | **Freeze**: locked solid, ice | Sluice Step / — |
| **Soak**: saturate | **Wring**: pull the water out of a body | Standing Pool / — |
| **Crush**: water as dense as stone | **Mist**: water as vapour, cover | Pressure Jet / — |
| **Mirror**: reflects shots and sight | **Murk**: clouds sight | — / — |

### Fire — runs on its own heat

| Rune | Opposite | Skills |
|---|---|---|
| **Ignite**: start a burn | **Quench**: put it out, and cash the heat in | Cinder Spit, Flashover / — |
| **Radiate**: heat outward | **Absorb**: heat drawn into you | Bellows Breath / Stoke |
| **Consume**: burn away | **Fuse**: weld, cauterise, set like glass | Kiln Fist, Pyre Call / Slag Pool |
| **Burst**: blast outward | **Implode**: flame rushing inward | — / Backdraft |
| **Flare**: blinding light | **Smoke**: smothering dark | — / — |

### Earth — builds stone that stays

| Rune | Opposite | Skills |
|---|---|---|
| **Raise**: stone up | **Sink**: ground down, pits | Raise Slab, Pillar / — |
| **Harden**: solidify, armour | **Crumble**: break stone and guard | Stonehide / Landslide Blow |
| **Root**: anchor, stand firm | **Quake**: shake, unbalance | Bedrock Shove / Tremor |
| **Weigh**: add mass | **Buoy**: lighten, to lift and throw | Slingstone / Quarry Throw |
| **Shard**: sharp crystal | **Sand**: fine grit that blinds and abrades | — / — |

### Wind — paid for by moving (Slipstream)

| Rune | Opposite | Skills |
|---|---|---|
| **Gust**: moving air | **Lull**: dead air; shots drop | Gale Lane, Spindrift / — |
| **Updraft**: lift | **Downdraft**: slam down | Updraft / Downdraft |
| **Shear**: cutting air | **Buffer**: cushioning air | Cutting Gust, Crosscut / Crosswind Veil |
| **Tailwind**: carried along | **Headwind**: stalled, slipstream stolen | Tailwind / — |
| **Whirl**: spin together | **Disperse**: blow apart | — / — |

### Lightning — marks a target, then overloads it

| Rune | Opposite | Skills |
|---|---|---|
| **Charge**: build up marks | **Discharge**: release them | Static Coat, Stored Bolt / Dead Short, Thunderclap Palm |
| **Arc**: jump between targets | **Insulate**: block a jump, isolate a target | Arc Lash, Forked Path / — |
| **Positive**: a polarity | **Negative**: the other (like signs push apart, unlike pull together) | — / Ground Rod |
| **Quicken**: nerves in overdrive | **Paralyse**: nerves locked | Stepped Leader / — |
| **Sense**: read the world through charge | **Jam**: scramble casts and calls for help | — / — |

### Metal — worn and carried metal is its material [MODEL]
Armoured enemies are a liability against metal: their own gear can be pulled, rung or stripped.

| Rune | Opposite |
|---|---|
| **Forge**: shape and harden metal | **Rust**: corrode it |
| **Draw**: pull metal, and whoever wears it | **Spurn**: push metal, and its wearer, away |
| **Hone**: sharpen | **Dull**: blunt edges, theirs included |
| **Plate**: armour up | **Strip**: tear armour off |
| **Ring**: metal resonates; the ringing stuns | **Deaden**: silence and damp it |

### Blood — works the blood that is already out [C: blood storage and blood-to-metal techniques exist; MODEL: the rule]
**[B 2026-10-21] Blood does not pay in health.** First-pass rule, to be settled in its deep dive: the wounds you open
spill blood, and blood skills work that spilled and stored blood, like water working the water that is there.

| Rune | Opposite |
|---|---|
| **Bleed**: open wounds | **Staunch**: close them |
| **Drink**: take blood in | **Spill**: give it out, as a weapon or a gift |
| **Thicken**: clot it hard: blood armour, blood blades | **Thin**: quick-flowing; speed, reach |
| **Race**: the heart pounds | **Stall**: the heart slows |
| **Brand**: a blood mark that links you to a target | **Disown**: break every blood link |

### Life — works inside living bodies [C: life practitioners work inside a body, with consent; MODEL: the rule]
Strongest on the living; does nothing to stone, constructs or the dead.

| Rune | Opposite |
|---|---|
| **Mend**: heal | **Wither**: harm from within |
| **Swell**: grow muscle and body | **Waste**: wither it away |
| **Vigour**: stamina, energy | **Exhaust**: fatigue |
| **Regrow**: restore what was lost, limbs included | **Arrest**: stop healing |
| **Rouse**: heighten the senses | **Numb**: dull pain and feeling |

### Death — what has died stays useful [C: death affinity and undeath exist; MODEL: the rule]
Corpses are its material, and anything below half health is its prey.

| Rune | Opposite |
|---|---|
| **Reap**: finish the dying | **Spare**: hold a life at the edge, for capture or mercy |
| **Raise**: the dead get up | **Lay**: put them down for good |
| **Rot**: decay | **Preserve**: stop decay, the user's own body included |
| **Haunt**: what dies lingers as a spirit | **Exorcise**: banish spirits and constructs |
| **Doom**: a mark that ends the target when it runs out | **Reprieve**: lift a doom |

### Nature — grows from the ground and keeps growing [C: nature is named; MODEL: the rule]
What it plants stays, spreads and gets stronger over time.

| Rune | Opposite |
|---|---|
| **Sprout**: grow plants | **Wilt**: kill them, clear ground |
| **Tangle**: vines bind | **Unravel**: free what is bound |
| **Bloom**: act now, in flower | **Seed**: plant it to act later |
| **Thorn**: barbs and briar | **Moss**: soft ground that cushions |
| **Feed**: nourish | **Starve**: deprive of soil and light |

### Light — straight and instant; reveals the hidden [MODEL: the rule]

| Rune | Opposite |
|---|---|
| **Shine**: illuminate | **Shade**: bend light away; dim |
| **Lance**: a beam | **Glow**: a soft field |
| **Expose**: show the hidden and invisible | **Mirage**: bend light into false images, or nothing |
| **Dazzle**: blind | **Clarity**: restore and sharpen sight |
| **Halo**: a radiance that strengthens allies | **Eclipse**: blot all light out |

### Dream — the mind [C: dream is a named, valued affinity; MODEL: the rule]
It needs the target to see it or to sleep, and it grows stronger on the dazed and sleeping.

| Rune | Opposite |
|---|---|
| **Sleep**: put to sleep | **Wake**: rouse, break a trance |
| **Phantasm**: an illusion | **Dispel**: break illusions |
| **Nightmare**: terror | **Reverie**: bliss, calm |
| **Muddle**: confuse | **Clarify**: clear the mind |
| **Whisper**: plant a command | **Shut**: close the mind to others |

### Poison — doses stack inside a body and come due later [MODEL: the rule]

| Rune | Opposite |
|---|---|
| **Envenom**: dose a target | **Purge**: clear doses |
| **Sap**: weaken | **Stimulate**: strengthen (poison as a drug) |
| **Steep**: build slowly and quietly | **Spike**: everything due at once |
| **Spread**: pass it on to others | **Inure**: build tolerance |
| **Linger**: leave residue that stays | **Flush**: clean an area out |

### Disease — a cloud that only harms flesh [B 2026-10-21: renamed from Miasma; C: miasma is flesh-only and armour counters it; MODEL: the rest]
Armour, stone and constructs ignore it; it lingers and drifts.

| Rune | Opposite |
|---|---|
| **Billow**: spread the cloud | **Clear**: disperse it |
| **Fester**: wounds rot | **Seal**: wounds closed off |
| **Choke**: suffocate | **Breathe**: give air |
| **Cling**: it sticks to flesh and follows | **Lift**: it rises away |
| **Plague**: it jumps body to body | **Quarantine**: it stays in one |

### Ice — what it freezes stays frozen [B 2026-10-21: ice is its own affinity, taking water's Freeze; MODEL: the rule]
Cold builds up on a target until it locks solid; frozen things turn brittle and break.

| Rune | Opposite |
|---|---|
| **Freeze**: lock solid | **Thaw**: release, melt free |
| **Rime**: build ice (walls, armour, spikes) | **Shatter**: break ice; brittle things burst |
| **Frost**: creeping cold on the ground that grips and slows | **Slick**: glazed ice that slides; fast and slippery |
| **Brittle**: make a thing fragile | **Toughen**: cold-harden it |
| **Stasis**: deep cold that halts everything | **Frostbite**: cold that burns |

### Dark — strongest where the light is weakest [B 2026-10-21: dark is an affinity; MODEL: the rule]
Shadows are places it can use: it hides in them, moves through them and feeds on light.

| Rune | Opposite |
|---|---|
| **Deepen**: make it darker | **Dawn**: let the light back in |
| **Cloak**: hide in the dark | **Silhouette**: make a target stand out against it |
| **Shadowstep**: move through shadows | **Pin**: nail a target's shadow, and the target with it |
| **Devour**: swallow light and energy | **Disgorge**: release what was swallowed |
| **Dread**: fear of the dark | **Hush**: the dark as rest and quiet |

**Totals**: 16 affinities. Water has 8 pairs (its deep dive); the other 15 have 5 pairs each, so 83 pairs and 166
base runes. 25 of the first five's runes already carry a design/05 skill.

## 4. Hybrids and uniques

- **A hybrid affinity** [C: perished water; F: life flame] writes with both parents' base runes and gets one pair of
  its own [MODEL]. Perished water would be water plus death; life flame, fire plus life. Their own pairs are not
  designed yet.
- **A character with two affinities** (not a hybrid) can add one affinity's base rune to the other's skill as a
  means: water's Freeze on fire's Ignite gives fire that leaves things brittle.
- **The unique "fusion" affinity** [C] is not designed. It is the obvious home for a rule that breaks the others.

## 5. Overlaps to watch

- Several universal runes sit close to an affinity's ground:
  - Life ↔ Death sits near the Life and Death affinities.
  - Pure ↔ Tainted sits near Poison and Disease.
  - Reveal ↔ Veil sits near Light.
  - Remember ↔ Forget, Will ↔ Yield and Calm ↔ Fury sit near Dream.

  The rule in section 1 settles it: the base rune is the strong, specific version.
- Some names clash across affinities:
  - Raise is used twice: Earth (stone) and Death (the dead).
  - Clear (Disease), Clarity (Light) and Clarify (Dream) are too alike.

  Rename before any of this reaches the game, so every rune name is unique.

## 6. Open

1. Five pairs per affinity, or deeper?
2. Lightning's Positive ↔ Negative and Sense ↔ Jam: does that fit how lightning reads in the books?
3. (Settled: blood does not pay in health [B 2026-10-21].)
4. The rules for the nine new affinities are [MODEL]; the books may say more about each.

## 7. Rulings on words (Brent, 2026-10-22)

- **Words are built in the skill, and the skill's level decides how much it can hold** [B]: not the stars. Level 0
  holds 4 runes, level 1 holds 6, and so on; each level allows more runes and more complex combinations.
  (Whether the skill's own base rune counts in the 4 is open.)
- **Combinations should be non-linear, with emergent results, and some must not work at all** [B]. The working
  proposal (bonds, shapes, thresholds, failure modes, bond strength against load) is being discussed; not yet ruled.
- **Bonds use chemistry** [B]: each rune gets a **valence** (1-4 bonds) and an **electronegativity**; single bonds
  only, no chirality. The electronegativity difference sets the bond's kind (even, polar, ionic) and Pauling's
  formula its strength; a word forms when every valence is filled.
- **Affinities have positions on five axes** [B: add mind/matter; MODEL: the axes and values]: Heat (cold to hot),
  Substance (fluid or free to solid), Vitality (death to life), Light (conceals to reveals), Mind/Matter. Two runes'
  affinities bond only if their positions line up: the cosine below −0.7 refuses, below 0 weakens. Universal runes
  have no position and bond with anything; hybrids sit between their parents. First values in the workbook's
  sliders; they refuse Fire–Ice, Light–Dark, Life–Death, Death–Nature, Nature–Disease, Metal–Dream, Earth–Dream.
- **"Unstable" is reopened** [B: does not like the strain-on-cast version]; to be redesigned.
- **Valence and electronegativity come from what a rune is, not from dice** [B: logical, not random; MODEL: the
  rule]. Each rune has a **role** and a **draw**:
  - The role sets valence: **Cap** 1 (ends a structure), **Link** 2 (takes in and passes on), **Branch** 3 (spreads
    or splits), **Frame** 4 (holds a structure together).
  - The draw runs from −1 (gives or releases outward) to +1 (takes or holds inward).
  - Electronegativity = 2.5 + draw × the role's spread (Cap 1.5, Link 1.0, Branch 0.7, Frame 0.4). So Caps sit at
    the extremes (1.0 to 4.0) and Frames near the middle, as in chemistry: few-bond elements pull hardest or give
    most easily; carbon, with four, bonds with anything.
  - Opposite runes usually have opposite draws, so a rune bonded to its own opposite makes a strong, ionic bond.
  - First pass in the workbook (Base Runes K-N, Bond Rules): 65 Links, 35 Caps, 34 Branches, 32 Frames.
- **The base runes were replaced by the revised set** [B 2026-10-22: "I like them"]. The data-backed proposal is in
  `design/runes-data/revised-rune-set.md` and is now in the workbook. IDs, characters and opposite pairs are
  unchanged. Section 3's first-pass tables and the water deep dive's §4 are history; the workbook is the source of
  truth for rune names, meanings, roles and draws.

## 8. Rulings on seals, discovery and structure (Brent, 2026-10-23)

- **The structure must matter** [B: "there does not appear to be any difference when building out the runes based on
  structure"]. Today a rune's strength depends only on its distance and the one bond on its own side of the path;
  what is bonded further out never counts, ionic "transfer" takes nothing, and shapes do nothing. Structure v2 fixes
  this (below).
- **Seals form at vestige binding** [B]. A skill just levels until its stage is full; binding the vestige is when its
  runes are sealed in. Before the first binding a skill has no word.
- **Seals can be reformed at the next level** [B]: when forming the level 2 seal you may rework level 1 and add level
  2 on top.
- **The word is concentric circles, one per level, stacking outward** [B]. Each seal adds a ring around the skill.
- **A discovered rune is permanent knowledge** [B], usable in any number of seals. Runes are **found through
  exploration and combat** [B]. Proposed sources [MODEL]: subduing a Netherecho construct reveals a rune of its concept
  (constructs carry concepts in the books); kills can reveal runes of the enemy's nature; inscriptions in realms,
  dungeons and Netherecho sites; universal runes rarer and deeper.
- **Structure v2** [MODEL, approved in outline by Brent 2026-10-23]:
  - strength = the ring's fade x the product of every bond's transmission along the path to the skill;
  - an ionic bond really transfers: the weaker rune's effect leaves it and is carried by the stronger rune;
  - shape traits: a closed ring lasts longer (a large one repeats once); a radial chain through several rings reaches
    further and faster; a rune with three or more bonds spreads its effect; a balanced first ring does not fade.
- **Bind no matter what; the skill's own rune grows with the rings** [B 2026-11-03, section 13]: "Forcing all valence to
  be filled is not right. Also, forcing the ring to be complete is wrong. let them bind and close no matter what. Also,
  the base run may need to have valence added each new ring so it can connect directly. At least one." This reverses
  the closed-word rule (sections 9, 11) and the full rings of section 12. Closed words, full rings, closed and great
  rings are rewards (descriptions and shape traits), not requirements.

## 9. Built (2026-10-23): seals, rings, structure v2, discovery

What the game does now, and the calls made where Brent has not ruled. Rule set `bond_v2`
(`game/scripts/runes/ring_rules.gd`, interaction `effects_v2.gd`); numbers from Bond Rules rows 43-59 through
`tools/runes/export_runes_json.py`; discovery data `game/data/rune_discovery.json` from `tools/runes/rune_sources.py`.

- **Seals** [B]: a skill has no word before its first binding. Binding a construct opens the seal screen: the draft is
  the sealed word, every inner ring may be reworked and the new ring added; the bind's roll seals it, a failed bind
  forms no seal. Binding with the draft untouched keeps the word as it is (so a skill can always advance) [MODEL;
  superseded by section 11: the new ring must be formed]. A seal must be a closed word, as the lock was (Bond Rules
  B36) [MODEL]. The B key opens the seal screen too.
- **Test characters** keep a free edit: any rune, any time, "Seal now", and a free-edit seal need not be closed [MODEL;
  superseded by section 11: no free edit].
- **Ring capacity** [MODEL, OPEN]: "Runes it adds" (C47:C51) is read as *each ring holds the ring inside plus its
  adds*: 3, 5, 7, 9, 11. The other reading (each ring holds exactly its adds: 3, 2, 2, 2, the "+2 per level" of row
  52) leaves the great ring (a closed ring of 5) impossible. One data switch, `ring_capacity`, picks the reading.
- **The skill's own rune** bonds only to ring 1, so it counts as filled once it holds as many bonds as ring 1 has
  places (a four-bond rune could otherwise never close a level 1 seal) [MODEL; superseded by section 13: it bonds to
  any ring and gains a bond per ring past the first]. A seal must be closed [superseded by section 13: it need not be].
- **Strength** [B outline, MODEL detail]: paths run inward (to the same ring or one further in, never back out, no rune
  twice); the strongest path counts; each bond's factor is read from the side further out *along the path*.
- **Ionic** [B outline, MODEL detail]: a rune weaker in two ionic bonds hands its effect to the partner with the most
  pull; hand-overs chain to the strongest; the skill's own rune on the weak side loses its nature and nothing carries
  it (as before); on the strong side it carries what it takes at full strength.
- **Traits** [MODEL detail]: a closed ring is three or more runes, each bonded to two on its ring, one piece, and joined
  to the skill; a branch rune is any but the skill's own; a spoke starts from a ring-1 rune bonded to the skill. The
  great ring's repeat is a generic `rune_repeat` patch read in `Player._perform_cast`: the same cast again at 40% of its
  stage multiplier (damage), 0.45 s later. Skills that move you, are held, or last (dash, blink, grapple, streak,
  channel, charge_release, self_buff, summon, rod, prop, seed) cannot repeat; their great ring gives the fallback
  (a quarter of the 40%) as damage instead. A trait with nothing to change in a skill also takes the fallback.
- **Discovery** [B sources, MODEL numbers]: a new character knows its starting skills' runes and, per affinity, its
  first Cap and first Link that no starter skill is built on. Learning a skill later also teaches its own rune
  [MODEL]. Subduing a construct reveals runes of its concept (vestige 1 base; remnant 1, 30% universal; deeper more);
  each concept's runes are the nearest rune profiles to a hand-set concept profile, three per affinity plus three
  universal. A kill reveals a rune of the enemy kind's nature with a small chance (4%; brute and drummer 8%, commander
  25%; 10% of those universal). Rune stones: two in The Stubble (zones.json), two in the passage (walls 3 and 8, the
  deeper one universal). Only runes the character can use and does not know are revealed; when a pool is exhausted
  nothing is found (a stone falls back to any base rune of yours).

Not built: rune acquisition by trade or teaching, hybrid affinities' runes, reactions between opposites, "unstable",
any cost to rework a ring, and a sound or animation for discovery beyond the HUD card.


## 10. Built (2026-10-23, second pass): building the seal, strength on on/off effects, ionic conversion

Brent's two requests of 2026-10-23: "Redo the interface. Make the bonds selectable for deletion and allow click and
drag to create the bonds. As it is currently it's buggy when trying to build the structure." [B] and "do both fixes"
(Bond Rules rows 62-74) [B].

**The old board's building bugs**, reproduced by scripted clicks before the rebuild (each now has a self-test check):

1. A palette click joined the new rune to whatever rune had last been clicked, even only to read it, and sent it a
   ring further out.
2. That pick stayed after the placement, so the next "click A, click B" joined the stale pick to A instead.
3. Clicking two bonded runes, one after the other (to read the second), parted their bond.
4. Clicking an empty place only aimed at its ring: the rune was set at another place on that ring (280 px away in
   the probe), and the aimed ring stayed aimed.
5. Runes jumped when bonded (the layout re-placed every rune by its partners each frame), so the next click landed on
   a different rune or on empty space.
6. A bond between two runes of one ring that were not neighbours was drawn along the ring, through the rune between
   them, so it looked bonded to that rune.
7. With a full rune picked, a palette rune was refused outright ("X is full") although the ring had room.
8. Right-click removed a rune and all its bonds at once, with no way back.
9. Dragging from the palette did nothing.
10. A click picked the first rune by index whose circle held the point, not the nearest.
11. Esc closed the screen, and the draft with it (it still does when nothing is in progress).

**The controls** [B request, MODEL detail]: drag a palette rune onto an empty place, or click it and then the place
(places that take it glow; the others are marked and say why when pointed at); a rune is set alone, never bonded by
a placement. Press on a rune or the core and drag to another: a live line follows; over a rune that takes it, the
bond is drawn as it would be, with its kind and dominant side in words; runes that would take it glow in the colour
of that bond, the others dim with the reason ("full", "not an adjacent ring", "alignment refuses", "already
bonded"); let go on one to bond, anywhere else (or Esc) to cancel. Click a rune or a bond (hit along its curve) to
select it; the panel shows a bond's kind, dominance, transmission, the runes whose strongest way in runs through it,
and any hand-over and conversion. Delete or Backspace, its x, or right-click deletes a selected bond; Delete,
Backspace or right-click takes a rune out with its bonds. Empty space deselects; hover lights what is under the
cursor. Ctrl+Z / Ctrl+Y step through the draft's history (Undo / Redo buttons too); nothing is committed until the
bind. The keys are InputMap actions (seal_delete, seal_delete_alt, seal_undo, seal_redo). A rune keeps the place it
was set in (the word's "places", layout only).

**On/off effects grow with strength** [B rows 66-70; MODEL detail]: a status a rune adds lasts base x (1 + (strength -
1) x 1.0), at most x2.5; each full 1.0 of strength above 1 adds a stack where the status stacks; an interrupt above
strength 1 also applies the new status Silenced (cannot start an attack, no calls for help) for 1.5 s per strength
above 1. A status the skill already applies is only ever lengthened by a rune, never cut short [MODEL]. A status a
rune adds at a strength below 1 lasts less than its base (the rule as written) [MODEL, OPEN]. The skill's own rune's
signature does not grow (only what a word adds) [MODEL, OPEN].

**Ionic conversion** [B rows 71-72; MODEL detail]: the rune that ends up holding a weaker rune's effect gains its
strength x rate (1.0), up to 3.0. For an outer rune that is its strength - the stronger of its own way in and the way
in through the rune it hands to, as if that bond passed it on whole (otherwise a ring-2 rune handing inward over its
only bond would give nothing) [MODEL]. For the skill's own rune it is the share of its signature that bond takes:
its factor's shortfall from 1, split over its bonds by what each takes - all of it when it is taken whole [MODEL].
The skill's own rune on the strong side converts nothing [MODEL, OPEN]. Worked example (self-test; v2 2026-10-24:
Tidal Bore and Pressure Jet are dropped, so the examples moved to the v2 skills on the same runes): Drown takes Wave
on Sluice Step - 1.5 + 1.0 = 2.5, "converted from Wave's shove and reach"; a 2.25 s silence; Dazed x2.5 (7.5 s on a
real hit). Drown off Flood on Breaker (on Surge): 0.675 + 0.75 = 1.425.

Not built: moving a placed rune to another place (take it out and set it again), dragging a bond's end to re-route
it, touch or gamepad controls for the board, and a sound for any of it. Feel is untested - needs Brent.


## 11. Ruling and build (2026-10-23, third pass): the level lock, built from the skill outward

Brent, looking at a Water test character's free edit (rings 1-3 open at once, nothing sealed) and at the ethercosm's
main page ("needs a eidolon" on every skill, "Bind the eidolon of Acceleration x3 - form the seal" buttons in the
panel): "wait....something is wrong....you should have to build out to in....the binding of the constructs should
come with each level lock. You should not be able to build level 2 until level 1 is fully formed with construct. The
levels all LOCK together. No binding the constructs on the main page, only with the runes." [B]

- **One level, one ring, one construct, bound together** [B]. A level lock is one act on the seal screen: build the
  forming ring, choose the construct of the right tier on that screen, bind. The ring and the construct lock together;
  the forming ring cannot be left empty (an untouched draft no longer binds). "Build out to in" is read as from the
  skill outward: ring 1 first [MODEL reading of B]. At a lock the sealed rings may still be reworked (section 8), and
  the whole word is sealed as one ("the levels all LOCK together") [B].
- **Never more than one forming ring; ring N+1 only after ring N** [B]. In the rules (`RingRules`), not only the
  screen: no rune is set on ring k while a ring inside it is not formed, and a seal is refused while any ring up to the
  one being formed is not. Inside a draft a ring counts as formed when at least one rune on it is joined to the skill
  through runes no further out than that ring [MODEL]: the ring reaches the skill from inside. (A seal must also be
  closed, so every rune of a sealed word is joined; "formed" only fixes the order.)
- **No binding from the main page** [B]. The ethercosm's panel shows a full skill's state ("Ready for its level N lock:
  needs a <tier>") and one "Open the seal" button; its bind buttons and bind previews are gone, as is the inventory's
  bind button (it opens the seal too). The B key opens the seal of the first skill ready for its lock and binds
  nothing. On the seal screen the carried constructs of the tier are listed by concept, each with what it would do
  once bound; with none carried the ring can be laid out but not bound, and the screen says why.
- **Test characters follow the same rule** [B]. No free edit. They start every skill at stage 0 with a full bar and
  four stars (the stage cap is stars + 1, so the asura lock is reachable) and carry three of every construct; after a
  bind that takes, the bar is refilled so the next lock opens at once (a test override, `balance.json` skills
  `test_refill_after_bind`) [MODEL]. Binds otherwise follow the normal rules: they can fail and the construct is used
  up. Tests that need a big word build it lock by lock through a code-only test hook that waives only the closed-word
  rule.
- **Old saves** [MODEL]: a skill bound under the earlier flow may be at stage N with no word, or with fewer sealed
  rings than N. Its next lock opens rings 1..N+1 as usual but they are still built inside out: it forms every missing
  inner ring, in order, plus the new one, and the bind needs all of them formed. Nothing is taken from the skill.

Not built: a separate cost or ritual for reworking a sealed ring at a lock; keeping a failed bind's draft (a failed
bind reopens the lock on the sealed word). Open for Brent: whether a ring must be *full* (every place used) to count as
formed, rather than reaching the skill; whether an old save should instead lose the stages its word never had. Feel is
untested - needs Brent. [Both answered by section 12: a ring is formed only when full; old saves are not supported.]

**Superseded by section 12** (2026-10-24): "a ring counts as formed when at least one rune on it is joined to the skill"
(now: every place filled); "with none carried the ring can be laid out but not bound" (now: the lock does not open
without the construct); the old-save rule (removed); the construct being chosen for the player when the seal opens (now
the player sets the keystone). The rest of section 11 stands.


## 12. Ruling and build (2026-10-24): full rings, the keystone, all or nothing

Brent, 2026-10-24 [B]: "dont worry about old saves at all. Every slot should be filled to be fully formed. Then a
vestige is placed over the top with its effect being worth more than a regular rune...and that locks the level. At
each level you can redo all levels available. But once locked, you have to wait until the next full level. You have to
be able to lock the current level (have a proper construct for it) before you can reform. Its all or nothing at each
level."

- **Fully formed means full** [B]. A ring is formed only when every one of its places holds a rune (ring capacity 3, 5,
  7, 9, 11 under the "grows" reading of section 9). Ring N+1 cannot be started until ring N is full
  (`RingRules.ring_formed`, `unformed_below`, `first_unformed`; reason `ring_unformed`). The word's own rules still
  apply on top at the bind: closed, every bond valid, no alignment refused. Repeats are allowed (params
  `allow_repeats`, as before) [MODEL, unchanged].
- **The keystone** [B rule, MODEL numbers]. Once the forming ring is full, the chosen construct - vestige at lock 1,
  remnant at 2, then spirit, eidolon, asura - is set over the ring as its keystone and sealed with the word
  (`RuneWord.keystones`: one per ring, {ring, tier, concept}). Its concept's effect counts for more than a regular rune's:
  every multiplier of the concept (constructs.json `mods`, or its `fallback` when the skill has none of those fields)
  has its distance from 1 scaled by the tier's weight: m' = max(floor, 1 + (m - 1) x w), w = weight_base +
  weight_per_tier x the tier's place (vestige 0 ... asura 4). Numbers in `runes.json` bond_v2 `keystone` (with a
  `_note`): weight_base 1.25, weight_per_tier 0.25 (vestige 1.25, remnant 1.5, spirit 1.75, eidolon 2.0, asura 2.25),
  mult_floor 0.1 [MODEL]. A regular rune works at its strength, at most 1.0 before ionic conversion, so every keystone
  outweighs any unconverted rune. Example: a vestige of Acceleration over a skill's ring 1 takes its speed x1.5 to
  x1.625 (written for Water Bolt's flight speed; Water Bolt is dropped in v2, the arithmetic is the same). These are not in the workbook yet (Brent adds them; the exporter carries them as `KEYSTONE_RULES` until then).
- **Folded, not counted twice** [MODEL]. A construct's concept now reaches a skill ONLY as the keystone of a sealed
  ring, through the word's effects (`RingRules.effects` puts the keystones' patch ahead of the runes', as the concept
  was applied before the runes before). The ability's `bound` list is kept as a record of the binds and changes nothing.
  So a skill shows its keystones on the seal screen (the board draws each as a wedge crowning its ring; the panel's
  KEYSTONE choice and "Keystones" list; the construct buttons' tooltips), on the ethercosm's "What it does" (the numbers
  hold them, with a line per keystone), in the HUD tooltip and on the inventory's soul tab.
- **No lock without the construct** [B]. The seal screen of a skill opens only when its bar is full AND a construct of
  the tier is carried (`Player.can_open_seal`). Otherwise the ethercosm's main page says what is missing ("LockMissing")
  and offers no way into the lock; the inventory and the HUD say the same; the B key opens nothing and says it. The
  old "the ring can be laid out, not bound" state is gone.
- **Redo everything up to the current ring at a lock; nothing between locks** [B]. As section 11: at a lock every sealed
  ring may be reworked (it must stay full); between locks the word cannot be changed. The keystones of sealed rings stay
  (the constructs bound earlier are not given back).
- **All or nothing** [B]. The bind locks the whole level - every reworked inner ring, the new ring full, the construct
  set as its keystone - or changes nothing. Bind is enabled only when every ring up to the current one is full, the
  word is closed and the keystone is chosen, and says which is missing, in that order. The existing bind roll is kept
  (80% takes, balance "binding"); on a failure the word stays exactly as it was before the lock opened, and the
  existing loss and wound rules apply (the construct is used up, a Soul-burn wound). **Open for Brent: whether a failed
  bind should cost the construct and wound at all under all-or-nothing, or be kept as it is.**
- **Old saves are not supported** [B: "dont worry about old saves at all"]. The section 11 old-save rule, its shot and
  its test are removed. Loading stays safe: a skill at stage N whose word has fewer full rings (or none) loads as it is,
  and its next lock simply starts from what it has - every ring 1..N+1 must be full to bind. Its earlier binds' concepts
  (which lived in `bound`) no longer apply until it has keystones [MODEL: the simplest safe choice]. Keystones load only
  over sealed rings.
- **Test characters** as before: stage 0, four stars, a full bar, three of every construct tier and concept, the bar
  refilled after a bind. The self-test walks one through all five locks with every ring full and every word closed
  (35 runes by lock 5), and cast_every_skill seals every skill through two locks with full rings.
- **A new character's starting runes** [check, `tests/full_ring_check.tscn`]: for every single-affinity start (16
  affinities x 3 pairs of root skills), the exhaustive search finds a closed word with ring 1 full and with rings 1-2
  full for 47 of the 48 starting skills. **Set Solid (Ice) cannot lock even its first level** with the runes it starts
  knowing (Freeze 4 bonds, Thaw 2, Frost or Glaze 2; ice has no one-bond rune): with the skill's own rune needing three
  bonds, ring 1's three runes have an odd number of bonds left, so no closed word exists. The starting runes were not
  changed; open for Brent.

Not built: a separate cost for reworking; a choice of where on the ring the keystone sits (it always crowns the top);
the keystone's own animation or sound. Feel is untested - needs Brent.

**Superseded by section 13** (2026-11-03): "Fully formed means full", "ring N+1 cannot be started until ring N is
full", the bind needing every ring full and the word closed, and "every ring 1..N+1 must be full" for an old save's
next lock. The keystone, the lock needing its construct, rework at a lock, the failed bind's rules and the rest of
section 12 stand.


## 13. Ruling and build (2026-11-03): bind no matter what, and the skill's own rune grows with the rings

Brent, 2026-11-03 [B], on the level 2 lock of a Riptide Lash test character (ring 1 sealed 3 of 3, ring 2 filled 5 of 5,
the remnant of Compression set as the keystone, Bind refused: "Only a closed word can be sealed; this one is open - not
a word yet", "1 open bond to fill"): "trying to bind the second ring and I cant. something is off with our mechanics
here. Forcing all valence to be filled is not right. Also, forcing the ring to be complete is wrong. let them bind and
close no matter what. Also, the base run may need to have valence added each new ring so it can connect directly. At
least one."

- **Bind no matter what** [B]. A level lock binds when the skill's bar is full and a construct of the tier is carried
  (unchanged, `Player.can_open_seal`), the keystone is chosen, and the draft breaks no hard rule: a rune over its
  valence, a bond between affinities that refuse each other, a bond across rings that do not touch, more runes on a
  ring than it has places, runes on a ring the skill does not have (`RuneRules.can_seal`, reason `problems`). Not
  needed any more: a closed word (every valence filled), every place of a ring filled, every rune joined to the skill,
  or any rune at all on the new ring. The 80% roll and a failed bind's consequences are unchanged.
- **Data switches, not deleted rules** [MODEL]. `runes.json` bond_v2 `seal_needs_closed` false and the new
  `seal_needs_full_rings` false (both from the exporter's `RING_RULES`, not the workbook; true puts the old rule back).
  With full rings off, `RingRules.ring_formed` is always true, so `unformed_below` / `first_unformed` are 0 and the
  `ring_unformed` refusals never fire; `ring_full` keeps the description ("2 of 5").
- **Inside out, by level** [B, section 11, kept]. Ring k takes runes only from the level-k lock on (`RuneContext.rings`);
  ring k-1 no longer has to be full first. A ring reworked at a later lock may be left with empty places.
- **The skill's own rune grows** [B rule, MODEL number]. Its valence is its rune's + `anchor_valence_per_ring` (1, "at
  least one") for each ring the skill has beyond ring 1 (`RingRules.node_valence` / `anchor_extra`; at a lock the
  forming ring counts), and it may bond straight to a rune on any ring (`anchor_bonds_any_ring` true;
  `RingRules.rings_bond`). Every other rune keeps the adjacent-ring rule. The board's sockets for the core follow
  (`describe_node`). A closed word now asks the core for its grown valence, up to the places it can reach (`anchor_needs`).
- **What an open or partial word does** [MODEL, from effects_v2 as built]. A sealed word's effects apply whether or not it
  is closed (`locked_effects`). A rune works at its strength along its strongest inward path to the skill; a rune joined
  to nothing has strength 0 and does nothing; an open bond carries nothing and costs nothing. The skill's own rune's
  nature is scaled by the bonds it has (none if it has none). Keystones work in full whatever the ring holds. Closed
  rings, great rings, spokes, branches and balanced are found from the shape as before - the rewards for filling.
- **On the seal screen** the banner says to set runes on the ring "as many as you like" and that the bind locks the
  level as it stands; the status lines say "N bonds still open - optional; an open bond carries nothing", "Not every
  rune is joined to the skill - a rune joined to nothing does nothing", "Empty places on ring k - allowed"; the lock note
  reads "Ready: the <keystone> over ring k, ring k holds n of N, bonds still open (optional)". A closed word shows
  "CLOSED - every bond filled". Shot: `--shot-ui=seal-lock-open` (lock 2 with ring 1 bound 2 of 3, ring 2 2 of 5, Drown
  bonded straight to the skill's own rune).
- **Tests**: the test hook `Player.test_bind_unclosed` and `RuneContext.closure_waived` are gone (every bind is like
  that now). The self-test's level-lock block checks the switches, a partial open word sealing and still working, a rune
  joined to nothing carrying nothing, an empty lock binding, the core's valence 2, 3, 4, 5, 6 at rings 1-5 (Surge), the
  core bonding straight to ring 2 and 3 while a ring 1 rune cannot reach ring 3, over-valence / refused / far bonds and a
  missing keystone still blocking. `ui_click_probe` binds a part-filled, open ring 1 and then, at lock 2, bonds the core
  straight to a ring 2 rune and binds ring 2 at 2 of 5, with the keystone still required and a failed bind changing
  nothing.

Open for Brent: whether a closed word itself (all valence filled) should earn something beyond the shape traits it
already makes possible; whether the core's extra bonds should be +1 per ring or more; whether an empty new ring should
really be allowed to lock a level (it is, by "no matter what"). Feel is untested - needs Brent.


## 14. Ruling and build (2026-11-04): a construct carries a word - vestiges for every rune, and up the ladder

Brent, 2026-11-04 [B]: "There should be vestiges for every rune word we have....and so on up the complexity ladder."
Asked how to read it, he answered [B]:

1. **Vestiges**: one for each of our 262 runes (206 affinity base runes + 56 universal runes): "a vestige of Flood",
   "a vestige of Motion". Its keystone effect is the rune's own effect at keystone weight.
2. **Higher tiers carry words of more runes**: a remnant carries a named two-rune word, a spirit a three-rune word, an
   eidolon four, an asura five. A set per affinity and universal ones; the six hand-made concepts (Acceleration,
   Piercing, Compression, Tension, Reach, Stillness) become the first universal remnants, each spelled from real runes.
   The keystone applies all of the word's runes' effects at the tier's weight. Order matters (design/13 section 1:
   Rest+Motion is not Friction).
3. **Fit**: a construct whose word is all universal runes fits any skill. One containing an affinity rune fits only
   skills that could hold that rune (the game's existing rule for which runes may be placed; hybrids follow it). Wild
   spawns lean toward the player's affinities so drops stay useful.

This is also his framing of 2026-10-21 (design/13 brief): "The base is a set of runes for base concepts, like vestiges
(friction, speed, destruction). The runes are like the letters of those concepts." [B]

**The catalogue** [B rule; MODEL words]. `game/data/constructs.json` is now GENERATED by `tools/runes/construct_words.py`
(run by `export_runes_json.py` after every export, and on its own). "words": id -> {label, tier, runes (ordered),
meaning, affinity ("" = universal), form}. Vestiges are made from the rune list, never authored: the id is the rune id
("WAT-1a"), the label the rune's name. The higher tiers are the script's `WORDS` table; every name and meaning is ours
[MODEL] (no book text, no canon names). The generator refuses: a rune id that does not exist, a word whose length is not
its tier's (`tier_runes`: 1, 2, 3, 4, 5), a word mixing two affinities (an affinity word uses one affinity plus universal
runes), two words spelled alike, a legacy target that is not a universal word of its tier, an affinity with no remnant.

| Tier | Words | Universal | Per affinity |
|---|---|---|---|
| vestige | 262 | 56 | 10-12 (one per rune) |
| remnant | 68 | 14 | 3 each |
| spirit | 28 | 7 | 1 each (2 for fire, earth, ice) |
| eidolon | 10 | 3 | water, earth, ice, metal, death, light, holy |
| asura | 6 | 2 | fire, lightning, life, disease |

Examples [MODEL]: Acceleration = Motion + Haste; Piercing = Focus + Within; Compression = Contract + Essence; Tension =
Bind + Hold; Reach = Far + Expand; Stillness = Stillness + Calm; Friction = Motion + Stillness and Lurch = Stillness +
Motion (the same letters, the other way round); Destruction = Entropy + Once (Brent's own example word); Undertow = Ebb
+ Drown (water); Wildfire = Burn + Catch (fire); Momentum = Motion + Haste + Persist (spirit); Drowning Tide = Flood +
Ebb + Drown + Settle (water eidolon); Unmaking = Entropy + Sever + Within + Once + Death (universal asura).

**What a keystone of a word does** [B rule, MODEL how]. Each op of the word's runes goes through the effects
interaction's own op rules (`effects_v1.keystone`, with effects_v2's on/off rules) as a rune at strength = the tier's
keystone weight (section 12: 1.25 vestige ... 2.25 asura): a multiplier m becomes max(floor, 1 + (m - 1) x weight); an
amount (shove, pull, marks, jumps, a bonus) is multiplied by the weight; a status, interrupt or brace always takes hold
(the weight is above the status threshold), and lasts longer, gains a stack at weight 2 and up, and an interrupt
silences, as any rune of that strength would; what the skill cannot use lands as the runes' fallback (a share as power,
or as a cost cut). If even that has nowhere to go, every hit's damage takes `fallback_damage_all` (x1.1) weighted - so
no bind is ever wasted (the self-test runs every word of every tier over a bolt, a lash and a strike). A keystone never
hurts its caster: no op names the caster's health, and a status lands on what the skill hits [B: skills never hurt
their caster; Blood never pays in health]. Trade-offs come with the word (Delay's longer wind-up, Expand's lighter
hits): they are its meaning, scaled like the rest [MODEL]. The word's order names it; it does not change the
arithmetic [MODEL]. The concept `mods` / `fallback` of 2026-09 are retired: nothing reads them.

**Fit** [B rule; the game's existing rule]. A rune may be set by a character who holds its affinity, and a universal
rune by anyone (`Player.can_use_rune`; the palette is per character, not per skill). So a word fits when each of its
runes passes that rule (`ConstructWords.fits`, `Player.construct_fits`): a water vestige does not fit a fire
character's skills; a universal one fits every skill. Hybrids follow the same rule (a holy character takes holy words,
not light ones unless it also holds light). Enforced in `Player.can_open_seal` (a carried construct of the tier that does
not fit does not count: reason `no_fit`, "none of the N vestiges you carry fits it: the vestige of Flood is a water
word ..."), `open_seal`, `choose_seal_construct` and `can_bind_seal` (reason `unfit`). The seal screen's keystone list
scrolls; the fitting words come first, grouped by affinity (the skill's own, the character's others, universal), each
button showing the word's glyphs and name and, as its tooltip, the word's runes, meaning and what it does over this ring
of this skill; the ones that do not fit follow under "Does not fit this skill (n)", greyed and disabled, the reason in
the tooltip. Open for Brent: whether a word whose rune refuses the skill's own affinity (an ice word on a fire skill of
a fire + ice character) should be unfit too; today it fits, because its runes could be set there.

**Wild words and drops** [B rule, MODEL numbers]. A wild construct's word is drawn by class (`ConstructWords.pick_wild`,
balance.json nether `word_weights`): own affinities 0.55, universal 0.35, affinities the player lacks 0.1 (an empty class
gives its share to the rest). Enemy drops use the same draw. Nothing spawns an eidolon or an asura yet, so they have no
`wild` numbers (constructs.json `_note` says so). zones.json's placed constructs are converted: the old remnants keep
their ids; each placed vestige of an old concept became the vestige of the rune closest to it (Tension -> Hold,
Stillness -> Stillness, Compression -> Contract, Reach -> Far, Acceleration -> Motion; Piercing would be Within).

**Discovery** [B rule, MODEL detail]. Subduing a construct reveals `reveals` runes by tier (unchanged): first the word's
own runes the player can use and does not know (in random order), then the runes nearest the word, as before
(`rune_discovery.json` construct.words.<id>: per affinity, the nearest rune profiles to the mean of the word's runes'
profiles; universal only with the tier's `universal_chance`). The word's own universal rune is revealed whatever the
tier [MODEL], so universal runes are now found more readily than section 8's "rarer and deeper" - open for Brent.

**Names, art, saves**. "Vestige of Flood", "Remnant of Acceleration" (`ConstructWords.title`); the HUD, inventory, board
and seal screen show the word's runes as glyphs. The art keeps the six silhouettes: each word takes the one its runes
lean to (constructs.json "form", from its ops) and is tinted by its affinity's colour, or a pale neutral when universal
[MODEL]. Old saves [B: "don't worry about old saves"]: carried constructs and keystones with the six old concept ids
load as the words they now are at their tier (constructs.json "legacy": a vestige of an old concept becomes the rune
closest to it, a spirit / eidolon / asura a universal word of that tier); a construct naming no word is dropped. Test
characters carry `test_constructs_each` of every word that fits them, at every tier.

Not built: a word's order changing its effect; eidolon / asura wild numbers; any change to the workbook (untouched).
Feel is untested - needs Brent.
