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
