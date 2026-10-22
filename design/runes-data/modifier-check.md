# Modifier cross-check

Made by `tools/runes/check_modifiers.py`. For each skill, every rune that could be added to it (its affinity's other base runes and the universal runes) is classed: **direct** (all its ops act on something real in the skill), **partial**, or **fallback** (none do; it only turns into a little extra power).

## Blood

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Tourniquet | Staunch | self_buff | 22 of 65 (33%) |
| Long Breath | Breathe | self_buff | 22 of 65 (33%) |
| Thinblood Rush | Thin | dash | 25 of 65 (38%) |
| Hammering Heart | Pulse | detonate | 43 of 65 (66%) |
| Heavy Heart | Still | ground_zone | 46 of 65 (70%) |
| Outpour | Spill | melee_burst | 55 of 65 (84%) |
| Gullet Knot | Choke | new:hex | 55 of 65 (84%) |
| Deep Draught | Drink | channel | 57 of 65 (87%) |
| Clotblade | Clot | melee_burst | 58 of 65 (89%) |
| Red Lancet | Bleed | projectile | 59 of 65 (90%) |

This affinity's runes that act on the fewest of its skills: Bleed 3/9, Clot 5/9, Still 5/9, Choke 5/9, Drink 6/9, Thin 7/9

Listed as good modifiers, but the maths gives them nothing to act on:

- Clotblade + Bleed (`status bleeding 1`)
- Thinblood Rush + Clot (`power x1.1; poise x1.2; braced`)
- Hammering Heart + Choke (`interrupts; status choked`)

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Deep Draught + Spill: giving blood out while drinking it in. The numbers would still apply (wider, dearer) but t
- Outpour + Drink: drinking back what you are pouring out. The numbers would land (+25% on the bleeding, more

## Dark

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Muffle | Hush | self_buff | 32 of 65 (49%) |
| Shadow Slip | Shadowstep | blink | 38 of 65 (58%) |
| Pall | Obscure | ground_zone | 47 of 65 (72%) |
| Hungry Dark | Devour | melee_burst | 47 of 65 (72%) |
| Daybreak | Lighten | detonate | 48 of 65 (73%) |
| Blot | Darken | projectile | 49 of 65 (75%) |
| Silhouette | Expose | new:smite | 57 of 65 (87%) |
| Shadownail | Pin | delayed_blast | 59 of 65 (90%) |
| Knell | Resound | ground_zone | 60 of 65 (92%) |
| Night Spill | Disgorge | melee_burst | 60 of 65 (92%) |

This affinity's runes that act on the fewest of its skills: Expose 5/9, Pin 5/9, Lighten 7/9, Darken 7/9, Obscure 8/9, Resound 8/9

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Daybreak + Expose: Daybreak already Exposes everything it catches; the status op does not stack. Falls back.
- Pall + Expose: Expose is Obscure's opposite: outlining what you are hiding. Obscure keeps the pull, but t
- Silhouette + Obscure: Obscure is Expose's opposite and pulls harder (2.62 vs 1.9): hiding the thing you are outl
- Shadownail + Shadowstep: Shadowstep is Pin's opposite: moving the thing you nail down. The maths would lengthen its
- Hungry Dark + Disgorge: Disgorge is Devour's opposite and the bond is ionic (4.0 vs 1.8): Devour takes the whole p
- Night Spill + Devour: Devour is Disgorge's opposite and the bond is ionic (4.0 vs 1.8): it eats the spill. Disgo

## Death

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Embalm | Preserve | self_buff | 21 of 65 (32%) |
| Rise Again | Animate | new:summon | 34 of 65 (52%) |
| Gravestep | Vanish | blink | 34 of 65 (52%) |
| Lay to Rest | Lay | new:field_pulse | 41 of 65 (63%) |
| Last Mercy | Spare | new:hex | 46 of 65 (70%) |
| Death Mask | Manifest | prop | 47 of 65 (72%) |
| Banishing Line | Exorcise | beam | 53 of 65 (81%) |
| Lingering Shade | Haunt | ground_zone | 57 of 65 (87%) |
| Endstroke | Kill | targeted_strike | 58 of 65 (89%) |
| Rotting Bolt | Rot | projectile | 59 of 65 (90%) |

This affinity's runes that act on the fewest of its skills: Animate 5/9, Lay 5/9, Rot 5/9, Exorcise 5/9, Manifest 5/9, Kill 5/9

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Endstroke + Spare: a killing blow that holds the life at the edge. The numbers would land (Spared, 15% weaker
- Last Mercy + Kill: finishing the life you are holding. Last Mercy deals no damage on a hit, so the bonus has 
- Rotting Bolt + Pure: cleansing the rot. The reflux cut lands; the word contradicts itself.
- Lingering Shade + Exorcise: banishing the spirit you called up. The numbers would land (interrupts, 10% harder) but th
- Lingering Shade + Attract: pulling enemies into ground they flee. The pull would land and fight the Dread every tick;

## Disease

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Festering Hands | Fester | self_buff | 20 of 65 (30%) |
| Inured Blood | Immunise | self_buff | 35 of 65 (53%) |
| Dispersal | Clear | dash | 39 of 65 (60%) |
| Lancing Cut | Lance | targeted_strike | 41 of 65 (63%) |
| Fever Break | Disinfect | detonate | 42 of 65 (64%) |
| Teeming Fog | Overrun | ground_zone | 44 of 65 (67%) |
| Plaguebloom | Billow | melee_burst | 49 of 65 (75%) |
| Contagion | Spread | chain | 50 of 65 (76%) |
| Fever Flask | Infect | delayed_blast | 53 of 65 (81%) |
| Sealing Clot | Contain | projectile | 55 of 65 (84%) |

This affinity's runes that act on the fewest of its skills: Overrun 0/9, Spread 1/9, Infect 1/9, Fester 3/9, Lance 5/9, Disinfect 6/9

Listed as good modifiers, but the maths gives them nothing to act on:

- Fever Flask + Persist (`duration x1.5`)
- Fever Flask + Fester (`status infected; duration x1.3`)
- Fever Break + Fall (`poise x1.3`)
- Contagion + Fester (`status infected; duration x1.3`)
- Sealing Clot + Persist (`duration x1.5`)
- Lancing Cut + Persist (`duration x1.5`)
- Plaguebloom + Persist (`duration x1.5`)
- Plaguebloom + Infect (`status infected 2`)
- Plaguebloom + Overrun (`poise x1.4`)
- Dispersal + Infect (`status infected 2`)
- Dispersal + Persist (`duration x1.5`)
- Teeming Fog + Infect (`status infected 2`)

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Fever Flask + Disinfect: Its own opposite: a flask that kills the disease it carries. The fallback is a bonus again
- Fever Break + Billow: Spreading a cloud on the skill that ends the sickness contradicts it; the fallback widens 
- Contagion + Contain: Its own opposite: keeping the sickness in one body. The fallback shrinks the jump radius t
- Contagion + One: One body taking all of it is the opposite of a spread; the fallback adds damage the 20-a-b
- Contagion + Focus: Concentrating on a point shrinks the jump radius to 2.4 m; the spread chokes.
- Sealing Clot + Billow: A cloud from a sealed clot contradicts it; there is no area to widen, so the fallback only
- Lancing Cut + Contain: Lancing lets the sickness out; sealing it in contradicts that, and the fallback shrinks th
- Plaguebloom + Clear: Its own opposite: dispersing the cloud it makes. The fallback shoves everyone out of the c
- Plaguebloom + Contain: A billowing cloud kept in one body is a contradiction; the fallback shrinks the bloom to 2
- Teeming Fog + Clear: Dispersing the fog contradicts it; the fallback shoves bodies out of it every tick.

## Dream

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Doubling Step | Conjure | dash | 26 of 65 (40%) |
| Shattered Dream | Dispel | detonate | 29 of 65 (44%) |
| Changeling Mask | Mimic | new:gaze | 42 of 65 (64%) |
| Read the Tell | Unmask | new:gaze | 42 of 65 (64%) |
| Errand | Whisper | new:gaze | 42 of 65 (64%) |
| Quiet Hour | Soothe | ground_zone | 47 of 65 (72%) |
| Night Terror | Dread | melee_burst | 53 of 65 (81%) |
| Rousing Blow | Wake | targeted_strike | 55 of 65 (84%) |
| Dozing Mote | Sleep | projectile | 56 of 65 (86%) |
| Shutter | Shut | delayed_blast | 56 of 65 (86%) |

This affinity's runes that act on the fewest of its skills: Sleep 6/9, Wake 7/9, Dread 7/9, Unmask 7/9, Whisper 7/9, Shut 7/9

Listed as good modifiers, but the maths gives them nothing to act on:

- Dozing Mote + Persist (`duration x1.5`)
- Doubling Step + Persist (`duration x1.5`)
- Doubling Step + Elsewhere (`reach x1.3`)
- Doubling Step + Remember (`duration x1.3`)
- Shattered Dream + Wake (`bonus asleep +0.5; poise x1.2`)
- Shattered Dream + Fall (`poise x1.3`)
- Night Terror + Persist (`duration x1.5`)
- Night Terror + Remember (`duration x1.3`)
- Night Terror + Fall (`poise x1.3`)
- Changeling Mask + Persist (`duration x1.5`)
- Changeling Mask + Remember (`duration x1.3`)
- Read the Tell + Persist (`duration x1.5`)
- Read the Tell + Remember (`duration x1.3`)
- Read the Tell + Many (`jumps +1; power x0.85`)
- Errand + Persist (`duration x1.5`)
- Errand + Many (`jumps +1; power x0.85`)
- Shutter + Persist (`duration x1.5`)

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Dozing Mote + Dread: Terror and sleep fight each other: the fallback makes the target flee instead of nodding, 
- Dozing Mote + Repel: Shoving a body you are lulling makes no sense; the fallback knocks the target out of your 
- Rousing Blow + Scatter: One waking spread thin: the strike has one target, so the fallback only takes 15% off the 
- Rousing Blow + Soothe: A soothing blow is a contradiction, and Soothed ends the moment it is hit; the fallback do
- Night Terror + Soothe: Its own opposite: calm and terror cancel. The fallback Soothes them, which ends at once be
- Night Terror + Attract: Pulling in the very enemies you are sending running is a contradiction; the fallback drags
- Night Terror + Fury: Enraging what you are terrifying makes no sense (and frenzy is the enemy's tool); the fall
- Quiet Hour + Dread: Its own opposite: terror in a zone of calm. The fallback sends everyone in it running, out
- Quiet Hour + Repel: A shove every tick is a hit that breaks Soothed, so the zone would undo itself.
- Changeling Mask + Unmask: Its own opposite: revealing the disguise you are laying. The fallback (Read) ends the mask
- Changeling Mask + Repel: Shoving the masked one away from the allies you want to fight it defeats the skill.
- Read the Tell + Mimic: Its own opposite: putting a mask on the face you are unmasking; the fallback Masks the tar
- Read the Tell + Repel: A gaze has no force; the fallback is a free shove that moves the target out of the reach y
- Errand + Sleep: Putting it to sleep (or Dazing it) at the moment of the order means it never walks; the tw
- Errand + Dread: A Terrified enemy runs away from you, not to your spot; the fallback overrides the errand.
- Errand + Repel: A shove is a hit, and a hit breaks the command; the fallback undoes the skill.
- Shutter + Whisper: Its own opposite: planting a command in a mind you are closing; the fallback pulls them to
- Shutter + Rise: Lifting bodies has nothing to do with the mind; the fallback is a free Updraft.

## Earth

12 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Stonehide | Harden | self_buff | 21 of 65 (32%) |
| Bedrock Shove | Root | dash | 36 of 65 (55%) |
| Burrow | Tunnel | dash | 48 of 65 (73%) |
| Tremor | Quake | melee_burst | 49 of 65 (75%) |
| Landslide Blow | Crumble | melee_burst | 57 of 65 (87%) |
| Raise Slab | Raise | prop | 57 of 65 (87%) |
| Quarry Throw | Dig | charge_release | 58 of 65 (89%) |
| Slingstone | Dig | projectile | 59 of 65 (90%) |
| Pillar | Raise | delayed_blast | 59 of 65 (90%) |
| Sinkhole | Sink | prop | 61 of 65 (93%) |
| Cairn | Bury | new:seize | 61 of 65 (93%) |
| Cave-In | Collapse | delayed_blast | 61 of 65 (93%) |

This affinity's runes that act on the fewest of its skills: Root 0/11, Tunnel 1/11, Crumble 7/11, Raise 7/10, Sink 10/11, Quake 10/11

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Pillar + Sink: its own opposite: a column that rises into a pit. Maths lets it act (Mired); it should not
- Sinkhole + Raise: its own opposite: a pit that rises. Maths lets it act (poise); it should not
- Cairn + Dig: its own opposite: tearing up the ground you are covering them with. Maths lets it act (pow
- Burrow + Collapse: its own opposite: the tunnel caving in on you. Maths lets it act (a Stun on surfacing); it
- Cave-In + Rise: lifts Aloft what the rock is falling on. Maths lets it act; it should not

## Fire

12 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Stoke | Blaze | self_buff | 16 of 65 (24%) |
| Wickpinch | Snuff | new:seize | 34 of 65 (52%) |
| Pyre Call | Explode | detonate | 39 of 65 (60%) |
| Smokepall | Smother | ground_zone | 46 of 65 (70%) |
| Flashover | Ignite | dash | 47 of 65 (72%) |
| Kiln Fist | Burn | targeted_strike | 48 of 65 (73%) |
| Hiss | Quench | new:seize | 49 of 65 (75%) |
| Bellows Breath | Blaze | channel | 50 of 65 (76%) |
| Flashpan | Flare | melee_burst | 53 of 65 (81%) |
| Backdraft | Implode | melee_burst | 55 of 65 (84%) |
| Slag Pool | Smoulder | ground_zone | 55 of 65 (84%) |
| Cinder Spit | Ignite | projectile | 57 of 65 (87%) |

This affinity's runes that act on the fewest of its skills: Burn 4/11, Ignite 4/10, Smoulder 6/11, Snuff 8/11, Quench 9/11, Implode 9/11

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Cinder Spit + Snuff: its own opposite: a spit that puts the fire out as it lights it. Maths lets it act; it sho
- Flashover + Snuff: maths lets it through, but on a payload that repeats every tick it re-interrupts every tic
- Flashover + Implode: a trail that drags everyone standing in it toward its middle line every tick. Maths lets i
- Bellows Breath + Smother: maths lets it through, but on a payload that repeats every tick it re-interrupts every tic
- Bellows Breath + Snuff: maths lets it through, but on a payload that repeats every tick it re-interrupts every tic
- Slag Pool + Snuff: maths lets it through, but on a payload that repeats every tick it re-interrupts every tic
- Wickpinch + Ignite: its own opposite: lights the thing it puts out. Maths lets it act (status and recovery); i
- Flashpan + Smother: its own opposite: smoke over the flash. Maths lets it act (interrupt and slow); it should 
- Smokepall + Flare: its own opposite: a flash inside the smoke. Maths lets it act (Dazed); it should not

## Ice

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Ice Shell | Toughen | self_buff | 20 of 65 (30%) |
| Whiteout | Snow | ground_zone | 45 of 65 (69%) |
| Craze | Brittle | delayed_blast | 47 of 65 (72%) |
| Runoff | Melt | beam | 52 of 65 (80%) |
| False Spring | Thaw | detonate | 53 of 65 (81%) |
| Black Ice | Glaze | dash | 54 of 65 (83%) |
| Fracture | Shatter | targeted_strike | 54 of 65 (83%) |
| Set Solid | Freeze | melee_burst | 57 of 65 (87%) |
| Hoarline | Frost | projectile | 57 of 65 (87%) |
| Icicle | Rime | projectile | 60 of 65 (92%) |

This affinity's runes that act on the fewest of its skills: Toughen 4/9, Freeze 4/9, Frost 5/9, Glaze 5/9, Rime 5/9, Thaw 8/9

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Black Ice + Frost: Frost is Glaze's opposite and pulls harder (2.9 vs 2.0, polar): Glaze keeps only half its 
- Whiteout + Melt: Melt is Snow's opposite and pulls harder: melted snow is slush, not a blind, and its damag
- Icicle + Melt: A melted icicle is a splash of water. The maths would let it through (a damage bonus on Ch
- Fracture + Rime: Rime is Shatter's opposite and pulls harder (2.62 vs 1.87, polar): the hammer grows spikes

## Life

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Knit | Heal | self_buff | 22 of 65 (33%) |
| Fever Break | Cure | self_buff | 22 of 65 (33%) |
| Regrowth | Regrow | channel | 22 of 65 (33%) |
| Corded Muscle | Strengthen | self_buff | 23 of 65 (35%) |
| Fresh Stride | Renew | dash | 24 of 65 (36%) |
| Turn the Stomach | Sicken | new:hex | 57 of 65 (87%) |
| Withering Needle | Wither | projectile | 58 of 65 (89%) |
| Wearying Sweep | Exhaust | melee_burst | 58 of 65 (89%) |
| Wasting Grip | Weaken | targeted_strike | 58 of 65 (89%) |
| Unmending | Arrest | delayed_blast | 60 of 65 (92%) |

This affinity's runes that act on the fewest of its skills: Wither 4/9, Exhaust 4/9, Weaken 4/9, Sicken 4/9, Arrest 4/9, Strengthen 5/9

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Turn the Stomach + Cure: curing the sickness as you give it. The numbers would land (cheaper, less reflux) but the 
- Unmending + Regrow: restoring what the skill stops from mending. The numbers would land (40% longer) but the v

## Light

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Clear Eye | Clarity | self_buff | 23 of 65 (35%) |
| Bent Light | Bend | self_buff | 23 of 65 (35%) |
| Gathered Light | Absorb | detonate | 31 of 65 (47%) |
| Dusk Well | Dim | ground_zone | 36 of 65 (55%) |
| Still Lamp | Glow | prop | 36 of 65 (55%) |
| Glint | Flash | new:streak | 47 of 65 (72%) |
| Dayline | Shine | beam | 52 of 65 (80%) |
| Hard Glare | Glare | melee_burst | 52 of 65 (80%) |
| Glancing Ray | Reflect | beam | 52 of 65 (80%) |
| Noonburst | Radiate | melee_burst | 54 of 65 (83%) |

This affinity's runes that act on the fewest of its skills: Reflect 0/9, Shine 1/9, Flash 4/9, Glare 4/9, Clarity 8/9, Bend 8/9

Listed as good modifiers, but the maths gives them nothing to act on:

- Dayline + Reflect (`jumps +1`)
- Hard Glare + Persist (`duration x1.5`)
- Clear Eye + Far (`reach x1.4; power x0.9`)

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Dayline + Curve: Light that bends breaks the affinity's rule; on an instant line it only nudges reach and d
- Dayline + Attract: A ray of light that hauls its target 1.5 m toward you has no meaning; the fallback is a fr
- Dayline + Rise: Light does not lift bodies; the fallback is a free Aloft on a cheap bolt, a second skill h
- Gathered Light + Radiate: Its own opposite: sending light out on a skill that draws it in. The fallback only stretch
- Hard Glare + Clarity: Its own opposite: restoring sight on a skill that takes it away; the fallback only adds 10
- Hard Glare + Dim: A dimmed glare is a contradiction; the fallback just weakens it.
- Glancing Ray + Curve: A bent ray stops being a reflection: the bank shot depends on straight legs. The fallback 
- Glancing Ray + Absorb: Absorbing light on a skill that throws it back is contradictory; the fallback is a bonus a
- Glancing Ray + Near: A shorter path ruins the bank shot (11.9 m); +20% damage does not make up for missing the 

## Lightning

12 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Dead Short | Discharge | detonate | 28 of 65 (43%) |
| Static Coat | Charge | self_buff | 40 of 65 (61%) |
| Dead Line | Silence | ground_zone | 42 of 65 (64%) |
| Stepped Leader | Quicken | blink | 47 of 65 (72%) |
| Thunderclap Palm | Thunder | targeted_strike | 48 of 65 (73%) |
| Stored Bolt | Charge | charge_release | 51 of 65 (78%) |
| Seize Up | Stun | melee_burst | 51 of 65 (78%) |
| Arc Lash | Arc | beam | 52 of 65 (80%) |
| Forked Path | Arc | chain | 52 of 65 (80%) |
| Plumb Bolt | Strike | new:smite | 54 of 65 (83%) |
| Ground Rod | Ground | rod | 55 of 65 (84%) |
| Bell Jar | Insulate | new:smite | 55 of 65 (84%) |

This affinity's runes that act on the fewest of its skills: Arc 0/10, Quicken 0/11, Silence 7/11, Strike 8/11, Stun 9/11, Thunder 9/11

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Stored Bolt + Discharge: It reads well (release the stored marks) but Charge and Discharge are opposites with an io
- Dead Short + Insulate: An insulated short does not short. The bond is ionic (2.95 vs 1.0), so Insulate takes the 
- Arc Lash + Insulate: Insulate is Arc's opposite and pulls harder (2.95 vs 2.15, polar): Arc's hold on the skill
- Forked Path + Insulate: Insulate is Arc's opposite and pulls harder (polar): the jumps are halved, which is the wh
- Dead Line + Charge: The maths would accept it (the zone has a payload) but the payload ticks every 0.5 s: a ma

## Metal

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Plating | Plate | self_buff | 19 of 65 (29%) |
| Breakthrough | Breach | dash | 42 of 65 (64%) |
| Rust Bloom | Rust | ground_zone | 44 of 65 (67%) |
| Iron Clasp | Seal | new:smite | 54 of 65 (83%) |
| Splitting Blow | Sunder | melee_burst | 55 of 65 (84%) |
| Whetted Cut | Hone | charge_release | 55 of 65 (84%) |
| Turn the Edge | Dull | melee_burst | 55 of 65 (84%) |
| Spot Weld | Fuse | chain | 56 of 65 (86%) |
| Iron Slug | Forge | projectile | 58 of 65 (89%) |
| Wrench | Strip | targeted_strike | 58 of 65 (89%) |

This affinity's runes that act on the fewest of its skills: Plate 4/9, Breach 5/9, Hone 7/9, Strip 7/9, Forge 7/9, Rust 8/9

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Splitting Blow + Fuse: Fuse is Sunder's opposite and pulls harder (2.7 vs 2.01): welding what you split. The weld
- Breakthrough + Seal: Seal is Breach's opposite and pulls harder (3.4 vs 1.9): sealing as you break through. The
- Whetted Cut + Dull: Dull is Hone's opposite: sharpening a blunt edge. Hone keeps the pull; the maths would sti
- Turn the Edge + Hone: Hone is Dull's opposite and pulls harder (3.0 vs 2.1): sharpening the blow that blunts. It

## Nature

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Greening | Flourish | new:field_pulse | 36 of 65 (55%) |
| Sere Ground | Wilt | new:field_pulse | 41 of 65 (63%) |
| Vine Reach | Tangle | new:grapple | 41 of 65 (63%) |
| Unwinding | Unravel | detonate | 52 of 65 (80%) |
| Thornburst | Sprout | delayed_blast | 55 of 65 (84%) |
| Dwindling Gall | Shrink | new:hex | 57 of 65 (87%) |
| Heartrot | Blight | chain | 57 of 65 (87%) |
| Reaping Sweep | Harvest | melee_burst | 59 of 65 (90%) |
| Scatter Seed | Sow | new:seed | 59 of 65 (90%) |
| Heartwood | Grow | prop | 60 of 65 (92%) |

This affinity's runes that act on the fewest of its skills: Tangle 5/9, Shrink 7/9, Blight 7/9, Unravel 7/9, Sprout 8/9, Wilt 8/9

Listed as good modifiers, but the maths gives them nothing to act on:

- Sere Ground + Blight (`status blighted`)

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Heartwood + Shrink: making smaller the thing that is Grow. The numbers would land (Dwindled on whoever it shov
- Heartwood + Wilt: a wilting tree. The rise hits 15% harder but the trunk lives 30% shorter; the word kills w
- Dwindling Gall + Grow: making larger the thing you are shrinking. The numbers would land (more range, more damage
- Heartrot + Flourish: making thrive the wood you are rotting. The numbers would land (harder, longer) but the ve
- Scatter Seed + Harvest: reaping seed before it has grown. The numbers would land (harder, cheaper) but the verbs c
- Scatter Seed + Wilt: seeds that die in the ground. The bursts hit 15% harder but the seeds wait 30% less; the w
- Unwinding + Attract: pulling in what you are flinging out. The pull lands against the shove; the word contradic

## Poison

10 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Sapping Tether | Sap | channel | 21 of 65 (32%) |
| Bitter Tonic | Stimulate | self_buff | 22 of 65 (33%) |
| Funnel | Flush | detonate | 28 of 65 (43%) |
| Clean Air | Cleanse | ground_zone | 35 of 65 (53%) |
| Fouling Slide | Contaminate | dash | 42 of 65 (64%) |
| Residue | Linger | ground_zone | 46 of 65 (70%) |
| Black Purge | Purge | targeted_strike | 48 of 65 (73%) |
| Counterdose | Neutralise | projectile | 51 of 65 (78%) |
| Caustic Spew | Corrode | melee_burst | 53 of 65 (81%) |
| Sting Dart | Poison | projectile | 54 of 65 (83%) |

This affinity's runes that act on the fewest of its skills: Poison 1/9, Linger 3/9, Contaminate 4/9, Purge 5/9, Corrode 5/9, Neutralise 5/9

Listed as good modifiers, but the maths gives them nothing to act on:

- Sting Dart + Contaminate (`status dosed; duration x1.3`)
- Black Purge + Fall (`poise x1.3`)
- Fouling Slide + Poison (`status dosed 2`)
- Caustic Spew + Fall (`poise x1.3`)
- Residue + Poison (`status dosed 2`)
- Funnel + Attract (`pull +1.5`)
- Sapping Tether + Poison (`status dosed 2`)
- Sapping Tether + Bind (`status pinned`)
- Sapping Tether + Essence (`cost x0.85`)

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Sting Dart + Purge: Its own opposite: clearing doses on the skill that gives them. The fallback is +40% agains
- Sting Dart + Neutralise: An antidote on the dosing dart: the meaning cancels. The fallback is an interrupting dart 
- Sting Dart + Rise: A dart does not lift a body; the fallback is a free Aloft on a 6-essence bolt.
- Fouling Slide + Cleanse: Its own opposite: cleaning the bodies you foul. The fallback only cools reflux, which read
- Caustic Spew + Neutralise: Its own opposite: rendering the acid harmless. The fallback interrupts and weakens a spray
- Caustic Spew + Rise: Acid does not lift; the fallback is a free Aloft burst.
- Counterdose + Purge: Calling the bill due on a skill that cancels it: the two cancel, and the fallback is only 
- Residue + Flush: Its own opposite: cleaning the area out. The fallback shoves everyone out of the slick eve

## Water

18 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Slack Water | Slack | melee_burst | 38 of 71 (53%) |
| Undertow | Ebb | displace | 45 of 71 (63%) |
| Drawdown | Drain | detonate | 45 of 71 (63%) |
| Sluice Step | Sweep | dash | 48 of 71 (67%) |
| Siltfall | Settle | detonate | 48 of 71 (67%) |
| Standing Pool | Flood | ground_zone | 49 of 71 (69%) |
| Backwash | Splash | self_buff | 50 of 71 (70%) |
| Drench | Soak | delayed_blast | 51 of 71 (71%) |
| Steady Drip | Drip | new:seize | 51 of 71 (71%) |
| Riptide Lash | Ebb | displace | 55 of 71 (77%) |
| Upwelling | Float | displace | 57 of 71 (80%) |
| Breaker | Surge | melee_burst | 58 of 71 (81%) |
| Pressure Jet | Gush | channel | 58 of 71 (81%) |
| Wringing Grip | Dry | targeted_strike | 60 of 71 (84%) |
| Drowning Hold | Drown | new:seize | 60 of 71 (84%) |
| Water Bolt | Surge | projectile | 61 of 71 (85%) |
| Tidal Bore | Wave | projectile | 62 of 71 (87%) |
| Seepage | Seep | new:seize | 66 of 71 (92%) |

This affinity's runes that act on the fewest of its skills: Seep 1/17, Soak 8/17, Gush 9/17, Settle 16/17, Flood 17/17, Drain 17/17

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Water Bolt + Ebb: pull 1.5 on a bolt that shoves 1.5: the two cancel and the target stays put. Maths lets it
- Breaker + Ebb: a pull added to a 4 m throw: the blow drags in and throws out at once. Maths lets it act; 
- Sluice Step + Settle: its own opposite: Mired in the moment they are swept along - the current both carries and 
- Undertow + Surge: a push away from the point inside a pull toward it: the two fight. Maths lets it act; it s
- Riptide Lash + Surge: shove 1.5 on a body you are hauling in: it lands a step short of you, which undoes the ski
- Standing Pool + Drown: maths lets it through, but on a payload that repeats every tick it re-interrupts every tic
- Backwash + Ebb: a pull on a skill whose point is throwing attackers off you: it drags them back into reach
- Pressure Jet + Ebb: a pull added to a stream that pushes: each tick drags in and pushes out. Maths lets it act
- Drawdown + Surge: shoves the drained bodies away while the water drags them in. Maths lets it act; it should
- Upwelling + Drown: its own opposite: held under while being floated. Maths lets it act; it should not
- Drowning Hold + Float: its own opposite: Aloft while held under. Maths lets it act; it should not
- Siltfall + Sweep: its own opposite: a current that carries them on, the moment they settle. Maths lets it ac
- Seepage + Splash: its own opposite: bursting outward on contact is exactly what seeping in is not. Maths let
- Tidal Bore + Ebb: drags back toward you the bodies it is carrying away. Maths lets it act; it should not

## Wind

12 skills. Share of candidate runes that really change each skill, lowest first:

| Skill | Rune | Kind | Runes that act on it |
|---|---|---|---|
| Tailwind | Carry | dash | 19 of 65 (29%) |
| Crosswind Veil | Buffer | self_buff | 20 of 65 (30%) |
| Dead Air | Lull | ground_zone | 34 of 65 (52%) |
| Gale Lane | Blow | ground_zone | 35 of 65 (53%) |
| Updraft | Lift | displace | 38 of 65 (58%) |
| Headwind | Stall | melee_burst | 50 of 65 (76%) |
| Downdraft | Drop | delayed_blast | 51 of 65 (78%) |
| Spindrift | Blow | channel | 51 of 65 (78%) |
| Blowout | Disperse | melee_burst | 51 of 65 (78%) |
| Dust Devil | Whirl | ground_zone | 55 of 65 (84%) |
| Cutting Gust | Lash | projectile | 57 of 65 (87%) |
| Crosscut | Lash | targeted_strike | 59 of 65 (90%) |

This affinity's runes that act on the fewest of its skills: Buffer 2/11, Drop 2/11, Lift 6/11, Lash 6/10, Stall 7/11, Blow 7/10

Listed as bad modifiers, but the maths lets them act fully (check the "why"):

- Crosscut + Buffer: its own opposite: a cushioned cut. Maths lets it act (shorter recovery); the word is nonse
- Gale Lane + Lull: its own opposite: dead air in a wind lane. Maths lets it act (less reflux); the word is no
- Spindrift + Lull: its own opposite: dead air while you run. Maths lets it act (less reflux); the word is non
- Dust Devil + Disperse: its own opposite: blowing apart what it gathers. Maths lets it act (reach, power); it shou
- Dust Devil + Lift: maths lets it through, but on a payload that repeats every tick, so nothing in it ever act
- Blowout + Whirl: its own opposite: pulls in what it blows apart. Maths lets it act; it should not

